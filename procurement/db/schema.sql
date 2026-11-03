-- ============================================================================
-- grihostiOS Procurement / Sourcing & Supply-Chain Management
-- Internal schema — PostgreSQL 15+
--
-- PART 1  Vendor master & qualification
-- PART 2  RFQ, NDA and staged submission
-- PART 3  Evaluation, normalization, award and contract
--
-- Design notes
--   * Every state transition is append-only in audit_log (ISO 37001 traceability).
--   * Submissions are immutable once submitted; a new round creates a new row.
--   * Money is NUMERIC(18,2); never float.
--   * All timestamps are timestamptz in UTC.
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS proc;
SET search_path = proc, public;

CREATE TYPE vendor_status      AS ENUM ('pending','verified','conditional','suspended','blacklisted');
CREATE TYPE entity_type        AS ENUM ('sole_proprietor','partnership','private_ltd','public_ltd','llp','cooperative','other');
CREATE TYPE doc_type           AS ENUM ('brochure','trade_license','tin_certificate','vat_certificate',
                                        'bank_solvency','iso_certificate','audited_financials',
                                        'work_order_history','other');
CREATE TYPE rfq_status         AS ENUM ('draft','published','nda_open','technical_open','commercial_open',
                                        'normalization','tech_locked','final_commercial','awarded','cancelled');
CREATE TYPE stage_type         AS ENUM ('technical','commercial');
CREATE TYPE submission_status  AS ENUM ('draft','submitted','withdrawn','locked','disqualified');
CREATE TYPE norm_status        AS ENUM ('scheduled','in_progress','closed','escalated');
CREATE TYPE bg_type            AS ENUM ('performance','advance','retention','warranty');

-- ============================================================================
-- PART 1 — VENDOR MASTER & QUALIFICATION
-- ============================================================================

CREATE TABLE vendors (
    id                    BIGSERIAL PRIMARY KEY,
    reg_no                TEXT UNIQUE NOT NULL,              -- GH-VND-2026-0001
    legal_name            TEXT NOT NULL,
    trade_name            TEXT,
    entity_type           entity_type NOT NULL,
    incorporation_date    DATE NOT NULL,
    years_in_business     NUMERIC(5,2) GENERATED ALWAYS AS
                          (ROUND(EXTRACT(EPOCH FROM (now() - incorporation_date::timestamptz))
                                 / 31557600.0, 2)) STORED,
    is_young_company      BOOLEAN GENERATED ALWAYS AS
                          (incorporation_date > (now() - INTERVAL '5 years')::date) STORED,

    -- Young-company special condition (allowed, but must be justified + approved)
    young_company_justification TEXT,
    young_company_approved_by   TEXT,
    young_company_approved_at   timestamptz,

    tin                   TEXT,
    bin                   TEXT,
    vat_reg_no            TEXT,

    address_line          TEXT NOT NULL,
    district              TEXT NOT NULL,
    division              TEXT NOT NULL,
    postcode              TEXT,

    contact_person        TEXT NOT NULL,
    contact_designation   TEXT,
    mobile_bd             TEXT NOT NULL,                     -- E.164 +8801XXXXXXXXX
    mobile_verified_at    timestamptz,
    email                 TEXT NOT NULL,
    website               TEXT,

    business_category     TEXT[] NOT NULL DEFAULT '{}',
    employee_count        INTEGER,
    annual_turnover_bdt   NUMERIC(18,2),

    bank_name             TEXT,
    bank_branch           TEXT,
    bank_account_no       TEXT,

    status                vendor_status NOT NULL DEFAULT 'pending',
    status_reason         TEXT,
    created_at            timestamptz NOT NULL DEFAULT now(),
    updated_at            timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT mobile_bd_format CHECK (mobile_bd ~ '^\+8801[3-9][0-9]{8}$'),
    CONSTRAINT young_needs_justification CHECK (
        NOT is_young_company OR young_company_justification IS NOT NULL
    )
);

CREATE UNIQUE INDEX vendors_mobile_uq ON vendors (mobile_bd);
CREATE INDEX vendors_status_ix       ON vendors (status);
CREATE INDEX vendors_category_ix     ON vendors USING GIN (business_category);

-- Mobile OTP verification (registration is free; number is the identity anchor)
CREATE TABLE vendor_otp (
    id           BIGSERIAL PRIMARY KEY,
    mobile_bd    TEXT NOT NULL,
    otp_hash     TEXT NOT NULL,
    purpose      TEXT NOT NULL DEFAULT 'registration',
    expires_at   timestamptz NOT NULL,
    consumed_at  timestamptz,
    attempts     SMALLINT NOT NULL DEFAULT 0,
    created_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX vendor_otp_mobile_ix ON vendor_otp (mobile_bd, created_at DESC);

-- Brochure and supporting files. No licence or certificate is mandatory.
CREATE TABLE vendor_documents (
    id            BIGSERIAL PRIMARY KEY,
    vendor_id     BIGINT NOT NULL REFERENCES vendors(id) ON DELETE CASCADE,
    doc_type      doc_type NOT NULL,
    title         TEXT,
    file_name     TEXT NOT NULL,
    mime_type     TEXT NOT NULL,
    size_bytes    BIGINT NOT NULL,
    storage_key   TEXT NOT NULL,          -- R2 / S3 object key
    sha256        TEXT,
    is_mandatory  BOOLEAN NOT NULL DEFAULT FALSE,
    uploaded_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX vendor_documents_vendor_ix ON vendor_documents (vendor_id);

-- Integrity declarations captured at registration
CREATE TABLE vendor_declarations (
    id                      BIGSERIAL PRIMARY KEY,
    vendor_id               BIGINT NOT NULL REFERENCES vendors(id) ON DELETE CASCADE,
    no_conflict_of_interest BOOLEAN NOT NULL DEFAULT FALSE,
    no_bribery_undertaking  BOOLEAN NOT NULL DEFAULT FALSE,
    litigation_disclosed    BOOLEAN NOT NULL DEFAULT FALSE,
    litigation_details      TEXT,
    related_party_details   TEXT,
    declared_by             TEXT NOT NULL,
    declared_at             timestamptz NOT NULL DEFAULT now()
);

-- ============================================================================
-- PART 2 — RFQ, NDA AND STAGED SUBMISSION
-- ============================================================================

CREATE TABLE rfqs (
    id                 BIGSERIAL PRIMARY KEY,
    rfq_no             TEXT UNIQUE NOT NULL,                 -- GH-RFQ-2026-001
    title              TEXT NOT NULL,
    description        TEXT,
    category           TEXT,
    budget_estimate    NUMERIC(18,2),
    currency           CHAR(3) NOT NULL DEFAULT 'BDT',

    published_at       timestamptz,
    nda_deadline       timestamptz,                          -- B-1, day 1 of float
    prebid_meeting_at  timestamptz,                          -- B-0 alignment
    technical_due_at   timestamptz,                          -- B-2
    commercial_due_at  timestamptz,                          -- B-3

    status             rfq_status NOT NULL DEFAULT 'draft',
    created_by         TEXT NOT NULL,
    created_at         timestamptz NOT NULL DEFAULT now(),
    updated_at         timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT rfq_date_order CHECK (
        nda_deadline IS NULL OR technical_due_at IS NULL OR nda_deadline <= technical_due_at
    )
);

CREATE TABLE rfq_documents (
    id           BIGSERIAL PRIMARY KEY,
    rfq_id       BIGINT NOT NULL REFERENCES rfqs(id) ON DELETE CASCADE,
    doc_type     TEXT NOT NULL,          -- rfq_pack | tech_template | comm_template | nda_form | boq
    title        TEXT NOT NULL,
    file_name    TEXT NOT NULL,
    storage_key  TEXT NOT NULL,
    size_bytes   BIGINT,
    uploaded_at  timestamptz NOT NULL DEFAULT now()
);

-- Which vendors may see and act on an RFQ
CREATE TABLE rfq_invitations (
    id           BIGSERIAL PRIMARY KEY,
    rfq_id       BIGINT NOT NULL REFERENCES rfqs(id) ON DELETE CASCADE,
    vendor_id    BIGINT NOT NULL REFERENCES vendors(id) ON DELETE CASCADE,
    invited_at   timestamptz NOT NULL DEFAULT now(),
    viewed_at    timestamptz,
    UNIQUE (rfq_id, vendor_id)
);

-- B-1 — signed NDA, submitted on day 1
CREATE TABLE nda_acceptances (
    id             BIGSERIAL PRIMARY KEY,
    rfq_id         BIGINT NOT NULL REFERENCES rfqs(id) ON DELETE CASCADE,
    vendor_id      BIGINT NOT NULL REFERENCES vendors(id) ON DELETE CASCADE,
    signatory_name TEXT NOT NULL,
    designation    TEXT NOT NULL,
    signed_at      timestamptz NOT NULL DEFAULT now(),
    document_hash  TEXT NOT NULL,
    file_name      TEXT,
    storage_key    TEXT,
    ip_address     INET,
    UNIQUE (rfq_id, vendor_id)
);

-- Backend control of submission rounds. Round 2/3 only opens when toggled here.
CREATE TABLE submission_rounds (
    id          BIGSERIAL PRIMARY KEY,
    rfq_id      BIGINT NOT NULL REFERENCES rfqs(id) ON DELETE CASCADE,
    stage       stage_type NOT NULL,
    round_no    SMALLINT NOT NULL,
    is_open     BOOLEAN NOT NULL DEFAULT FALSE,
    opened_at   timestamptz,
    closed_at   timestamptz,
    opened_by   TEXT,
    note        TEXT,
    UNIQUE (rfq_id, stage, round_no)
);

-- One row per vendor / stage / round. Immutable after submit.
CREATE TABLE submissions (
    id             BIGSERIAL PRIMARY KEY,
    rfq_id         BIGINT NOT NULL REFERENCES rfqs(id) ON DELETE CASCADE,
    vendor_id      BIGINT NOT NULL REFERENCES vendors(id) ON DELETE CASCADE,
    stage          stage_type NOT NULL,
    round_no       SMALLINT NOT NULL DEFAULT 1,
    status         submission_status NOT NULL DEFAULT 'draft',
    payload        JSONB NOT NULL DEFAULT '{}'::jsonb,   -- template field responses
    total_amount   NUMERIC(18,2),                        -- commercial only
    currency       CHAR(3) DEFAULT 'BDT',
    submitted_at   timestamptz,
    locked_at      timestamptz,
    UNIQUE (rfq_id, vendor_id, stage, round_no)
);
CREATE INDEX submissions_rfq_ix ON submissions (rfq_id, stage, round_no);

CREATE TABLE submission_files (
    id             BIGSERIAL PRIMARY KEY,
    submission_id  BIGINT NOT NULL REFERENCES submissions(id) ON DELETE CASCADE,
    field_key      TEXT NOT NULL,
    file_name      TEXT NOT NULL,
    mime_type      TEXT,
    size_bytes     BIGINT,
    storage_key    TEXT NOT NULL,
    uploaded_at    timestamptz NOT NULL DEFAULT now()
);

-- ============================================================================
-- PART 3 — EVALUATION, NORMALIZATION, AWARD & CONTRACT
-- ============================================================================

CREATE TABLE evaluation_criteria (
    id           BIGSERIAL PRIMARY KEY,
    rfq_id       BIGINT NOT NULL REFERENCES rfqs(id) ON DELETE CASCADE,
    code         TEXT NOT NULL,
    name         TEXT NOT NULL,
    stage        stage_type NOT NULL DEFAULT 'technical',
    weight_pct   NUMERIC(5,2) NOT NULL,
    max_score    NUMERIC(5,2) NOT NULL DEFAULT 100,
    is_mandatory BOOLEAN NOT NULL DEFAULT FALSE,
    UNIQUE (rfq_id, code)
);

CREATE TABLE evaluators (
    id         BIGSERIAL PRIMARY KEY,
    rfq_id     BIGINT NOT NULL REFERENCES rfqs(id) ON DELETE CASCADE,
    full_name  TEXT NOT NULL,
    role       TEXT NOT NULL,
    email      TEXT
);

CREATE TABLE evaluations (
    id             BIGSERIAL PRIMARY KEY,
    submission_id  BIGINT NOT NULL REFERENCES submissions(id) ON DELETE CASCADE,
    evaluator_id   BIGINT NOT NULL REFERENCES evaluators(id) ON DELETE CASCADE,
    criterion_id   BIGINT NOT NULL REFERENCES evaluation_criteria(id) ON DELETE CASCADE,
    score          NUMERIC(5,2) NOT NULL,
    comment        TEXT,
    scored_at      timestamptz NOT NULL DEFAULT now(),
    UNIQUE (submission_id, evaluator_id, criterion_id)
);

-- Materialised ranking, refreshed after scoring
CREATE TABLE evaluation_summary (
    submission_id     BIGINT PRIMARY KEY REFERENCES submissions(id) ON DELETE CASCADE,
    technical_score   NUMERIC(6,2),
    commercial_score  NUMERIC(6,2),
    combined_score    NUMERIC(6,2),
    rank_no           INTEGER,
    is_responsive     BOOLEAN NOT NULL DEFAULT TRUE,
    computed_at       timestamptz NOT NULL DEFAULT now()
);

-- Two rounds of normalization between the parties
CREATE TABLE normalization_sessions (
    id            BIGSERIAL PRIMARY KEY,
    rfq_id        BIGINT NOT NULL REFERENCES rfqs(id) ON DELETE CASCADE,
    round_no      SMALLINT NOT NULL,
    scheduled_at  timestamptz,
    held_at       timestamptz,
    status        norm_status NOT NULL DEFAULT 'scheduled',
    chair         TEXT,
    minutes       TEXT,
    UNIQUE (rfq_id, round_no)
);

CREATE TABLE normalization_items (
    id                BIGSERIAL PRIMARY KEY,
    session_id        BIGINT NOT NULL REFERENCES normalization_sessions(id) ON DELETE CASCADE,
    vendor_id         BIGINT REFERENCES vendors(id),
    topic             TEXT NOT NULL,
    employer_position TEXT,
    vendor_position   TEXT,
    resolution        TEXT,
    is_resolved       BOOLEAN NOT NULL DEFAULT FALSE,
    raised_at         timestamptz NOT NULL DEFAULT now()
);

-- Final locking of technical understanding. May take more than one pass.
CREATE TABLE tech_locks (
    id            BIGSERIAL PRIMARY KEY,
    rfq_id        BIGINT NOT NULL REFERENCES rfqs(id) ON DELETE CASCADE,
    vendor_id     BIGINT NOT NULL REFERENCES vendors(id) ON DELETE CASCADE,
    passes_taken  SMALLINT NOT NULL DEFAULT 1,
    scope_hash    TEXT NOT NULL,
    locked_by     TEXT NOT NULL,
    locked_at     timestamptz NOT NULL DEFAULT now(),
    UNIQUE (rfq_id, vendor_id)
);

-- Final commercial offer, after technical lock
CREATE TABLE final_commercials (
    id             BIGSERIAL PRIMARY KEY,
    rfq_id         BIGINT NOT NULL REFERENCES rfqs(id) ON DELETE CASCADE,
    vendor_id      BIGINT NOT NULL REFERENCES vendors(id) ON DELETE CASCADE,
    amount         NUMERIC(18,2) NOT NULL,
    currency       CHAR(3) NOT NULL DEFAULT 'BDT',
    validity_days  SMALLINT NOT NULL DEFAULT 90,
    submitted_at   timestamptz NOT NULL DEFAULT now(),
    UNIQUE (rfq_id, vendor_id)
);

CREATE TABLE awards (
    id               BIGSERIAL PRIMARY KEY,
    rfq_id           BIGINT NOT NULL REFERENCES rfqs(id) ON DELETE CASCADE,
    vendor_id        BIGINT NOT NULL REFERENCES vendors(id) ON DELETE CASCADE,
    award_amount     NUMERIC(18,2) NOT NULL,
    currency         CHAR(3) NOT NULL DEFAULT 'BDT',
    award_letter_ref TEXT,
    awarded_at       timestamptz NOT NULL DEFAULT now(),
    awarded_by       TEXT NOT NULL,
    UNIQUE (rfq_id)
);

CREATE TABLE agreements (
    id             BIGSERIAL PRIMARY KEY,
    award_id       BIGINT NOT NULL UNIQUE REFERENCES awards(id) ON DELETE CASCADE,
    agreement_no   TEXT UNIQUE NOT NULL,
    signed_at      timestamptz,
    effective_date DATE,
    file_name      TEXT,
    storage_key    TEXT,
    status         TEXT NOT NULL DEFAULT 'draft'
);

CREATE TABLE work_orders (
    id              BIGSERIAL PRIMARY KEY,
    agreement_id    BIGINT NOT NULL REFERENCES agreements(id) ON DELETE CASCADE,
    wo_no           TEXT UNIQUE NOT NULL,
    issued_at       timestamptz NOT NULL DEFAULT now(),
    value           NUMERIC(18,2) NOT NULL,
    currency        CHAR(3) NOT NULL DEFAULT 'BDT',
    completion_date DATE,
    scope_summary   TEXT
);

-- Bank guarantee placed against the work order. The vendor can pledge this
-- instrument to a bank as security for working-capital finance.
CREATE TABLE bank_guarantees (
    id             BIGSERIAL PRIMARY KEY,
    work_order_id  BIGINT NOT NULL REFERENCES work_orders(id) ON DELETE CASCADE,
    bg_no          TEXT NOT NULL,
    bg_type        bg_type NOT NULL,
    amount         NUMERIC(18,2) NOT NULL,
    currency       CHAR(3) NOT NULL DEFAULT 'BDT',
    issuing_bank   TEXT NOT NULL,
    branch         TEXT,
    valid_from     DATE NOT NULL,
    valid_to       DATE NOT NULL,
    file_name      TEXT,
    storage_key    TEXT,
    verified_at    timestamptz,
    verified_by    TEXT,
    UNIQUE (work_order_id, bg_no)
);

-- ============================================================================
-- AUDIT — append only
-- ============================================================================

CREATE TABLE audit_log (
    id         BIGSERIAL PRIMARY KEY,
    entity     TEXT NOT NULL,
    entity_id  BIGINT,
    action     TEXT NOT NULL,
    actor      TEXT NOT NULL,
    at         timestamptz NOT NULL DEFAULT now(),
    payload    JSONB
);
CREATE INDEX audit_entity_ix ON audit_log (entity, entity_id, at DESC);

-- ============================================================================
-- VIEWS
-- ============================================================================

-- Vendor-facing gate: what a vendor may currently do on an RFQ
CREATE OR REPLACE VIEW v_vendor_rfq_gate AS
SELECT
    i.rfq_id,
    i.vendor_id,
    r.rfq_no,
    r.status,
    (n.id IS NOT NULL)                                   AS nda_done,
    (t.id IS NOT NULL)                                   AS tech_submitted,
    (c.id IS NOT NULL)                                   AS comm_submitted,
    COALESCE(tr.is_open, FALSE)                          AS tech_round_open,
    COALESCE(cr.is_open, FALSE)                          AS comm_round_open,
    COALESCE(tr.round_no, 1)                             AS tech_round,
    COALESCE(cr.round_no, 1)                             AS comm_round,
    (n.id IS NOT NULL AND COALESCE(tr.is_open, FALSE))   AS can_submit_technical,
    (t.id IS NOT NULL AND COALESCE(cr.is_open, FALSE))   AS can_submit_commercial
FROM rfq_invitations i
JOIN rfqs r              ON r.id = i.rfq_id
LEFT JOIN nda_acceptances n ON n.rfq_id = i.rfq_id AND n.vendor_id = i.vendor_id
LEFT JOIN submissions t  ON t.rfq_id = i.rfq_id AND t.vendor_id = i.vendor_id
                        AND t.stage = 'technical'  AND t.status = 'submitted'
LEFT JOIN submissions c  ON c.rfq_id = i.rfq_id AND c.vendor_id = i.vendor_id
                        AND c.stage = 'commercial' AND c.status = 'submitted'
LEFT JOIN submission_rounds tr ON tr.rfq_id = i.rfq_id AND tr.stage = 'technical'
                              AND tr.is_open
LEFT JOIN submission_rounds cr ON cr.rfq_id = i.rfq_id AND cr.stage = 'commercial'
                              AND cr.is_open;

-- Inter-vendor comparison for a given RFQ
CREATE OR REPLACE VIEW v_rfq_comparison AS
SELECT
    s.rfq_id,
    v.reg_no,
    v.legal_name,
    s.stage,
    s.round_no,
    s.total_amount,
    es.technical_score,
    es.commercial_score,
    es.combined_score,
    es.rank_no,
    s.submitted_at
FROM submissions s
JOIN vendors v                  ON v.id = s.vendor_id
LEFT JOIN evaluation_summary es ON es.submission_id = s.id
WHERE s.status = 'submitted'
ORDER BY s.rfq_id, s.stage, es.rank_no NULLS LAST;

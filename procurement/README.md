# Procurement — Sourcing & Supply-Chain Management

Internal procurement system for grihostiOS: vendor registration, staged RFQ
submission, evaluation, normalization, award and contract.

| Item | Value |
|---|---|
| Internal console | [`index.html`](./index.html) |
| Vendor portal | [`vendor-portal.html`](./vendor-portal.html) |
| Database schema | [`db/schema.sql`](./db/schema.sql) |
| Live paths | `/procurement/` and `/procurement/vendor-portal.html` |

---

## The three parts

### Part 1 — Vendor master & qualification

Free registration anchored on a **Bangladeshi mobile number** (`+8801XXXXXXXXX`),
verified by OTP. No licence or certificate is required to register.

A **company incorporated less than 5 years ago** may still register, but only
under the special condition: a written justification and a named approver are
mandatory, and the vendor is flagged `conditional` until procurement reviews it.
The database enforces this with a `CHECK` constraint, not just UI validation.

A **brochure** is the only expected upload. Trade licence, ISO certificates,
audited financials and work-order history are all optional attachments.

### Part 2 — RFQ and staged submission

Four submission levels:

| Level | Stage | Control |
|---|---|---|
| **B-0** | Pre-submission alignment | Pre-bid meeting; clarifications issued to all bidders equally |
| **B-1** | Signed NDA | Submitted on day 1 of the RFQ; unlocks the technical zone |
| **B-2** | Technical proposal | Templated; one-shot; immutable after submit |
| **B-3** | Commercial proposal | Templated; held separately from technical |

**Resubmission is blocked by design.** A submitted round cannot be edited. Round
2 or 3 only opens when procurement toggles it in the backend — the vendor portal
reads that flag and either shows the form or a locked panel.

### Part 3 — Evaluation, normalization, award

1. **Evaluation** — weighted technical criteria (T1–T5) scored per submission.
   Commercial score = lowest price ÷ this price × 100. Combined = technical × 70%
   + commercial × 30%. Ranking is computed live.
2. **Normalization ×2** — two minuted bilateral rounds. Scope must not change;
   only understanding is aligned.
3. **Technical lock** — final locking of technical understanding. Multi-pass
   allowed; a scope hash is recorded.
4. **Final commercial** — price submitted after the technical lock.
5. **Award** — single winner per RFQ, gated on all of the above.
6. **Agreement** — signed contract with number and effective date.
7. **Work order** — issued after signing, with value and completion date.
8. **Bank guarantee** — performance/advance BG in the employer's favour. This is
   the instrument the vendor can pledge to a bank as security for working-capital
   finance.

---

## Standards mapping

| Stage | International practice |
|---|---|
| Vendor registration | MDB eligibility screening; UNGM registration |
| B-0 alignment | World Bank / ADB pre-bid conference |
| B-1 NDA | Standard commercial practice; FIDIC confidentiality |
| B-2 / B-3 split | **Two-envelope / two-stage bidding** (World Bank, FIDIC) |
| Evaluation | MDB rated criteria; ISO 37001 controls |
| Normalization | FIDIC / MDB clarification phase |
| Technical lock | FIDIC Cl. 13 variation discipline |
| Final commercial | Best and final offer (BAFO) |
| Award | MDB notification of award |
| Agreement | FIDIC Short Form / Red Book |
| Bank guarantee | FIDIC Cl. 4.2 performance security |
| Audit | ISO 37001 anti-bribery; ISO 9001 traceability |

The **two-envelope principle** is the core control: technical and commercial
submissions are held separately, and price is only opened after the technical
evaluation is complete. This prevents price from influencing technical judgement.

---

## Data model

`db/schema.sql` is PostgreSQL 15+ and is split into the same three parts.

Key design decisions:

- **Submissions are immutable.** A new round inserts a new row keyed by
  `(rfq_id, vendor_id, stage, round_no)`.
- **Round control is a table**, not a column — `submission_rounds.is_open` is the
  single source of truth the vendor portal reads.
- **Money is `NUMERIC(18,2)`**, never float.
- **`audit_log` is append-only** for ISO 37001 traceability.
- **`v_vendor_rfq_gate`** computes exactly what a vendor may do next, so the
  portal and the API cannot disagree.
- **`v_rfq_comparison`** gives inter-vendor comparison per stage and round.

---

## Demo behaviour

Both pages share `localStorage` under the key `gh_procurement_v1`, so a vendor
registered in the portal appears immediately in the internal console and vice
versa. The OTP is fixed at `123456` for the demo.

To reset: clear `gh_procurement_v1` and `gh_vendor_session` from localStorage.

## Production notes

The static pages are a working prototype of the workflow. For production:

- Replace `localStorage` with the PostgreSQL schema via an API.
- Move file uploads to R2/S3 and store only the object key plus SHA-256.
- Send real OTPs through a Bangladeshi SMS gateway.
- Enforce the gates server-side — the client checks are UX only.
- Add authentication and role separation (vendor, evaluator, procurement officer,
  approver).

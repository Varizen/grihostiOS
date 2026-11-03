# RFQ — Proposal Submission Template

Bilingual (English first, Bangla directly beneath) proposal submission form for the
Architectural Design & Engineering invitation on the 1,692 sq ft site.

| Item | Value |
|---|---|
| File | `proposal-submission-template.html` |
| Document No. | `GH-ADS-2026-01` · Rev. 00 |
| Pages | 12 (A4, print-ready) |
| Language | English primary, Bangla secondary |
| Numerals | English digits only (0–9) |

## What it is

A printable, fillable template a bidder completes and returns. It mirrors the
existing [architecture-design-proposal.html](../architecture-design-proposal.html)
invitation: same brand system, same evaluation weights, same 11 deliverables — but
as a structured form to fill in rather than a page to read.

### Page map

| Page | Contents |
|---|---|
| 1 | Cover, document control, contents |
| 2 | Instructions to bidders, project particulars |
| 3 | Bidder particulars — firm profile, authorised contact |
| 4 | Key personnel, team capacity |
| 5 | Comparable project experience, references |
| 6 | Deliverables checklist, technical approach |
| 7 | Fee proposal (BDT) |
| 8 | Work programme, programme assumptions |
| 9 | Declaration, signature, company seal |
| 10 | Attachment checklist, submission packaging |
| 11 | For official use — receipt, evaluation scoring |
| 12 | Recommendation, decision, approval |

## Behaviour

- **Bengali digit guard** — typing ০–৯ in any field converts to 0–9 on input,
  preserving the caret position.
- **Print / Save as PDF** — hides the toolbar and prints one sheet per A4 page.
  `@page` uses 12 mm margins; each sheet is sized so content never spills.
- **Clear form** — empties every text field and unchecks every box after
  confirmation. Read-only fields are left intact.
- `Ctrl`/`Cmd` + `Enter` also triggers print.

No dependencies and no build step. Works offline from disk; Google Fonts is the
only network request.

## Brand

Follows [BRAND.md](../BRAND.md) — Deep Plum `#3B1E3F`, Fresh Green `#22C55E`,
Mint `#E9F7EF`, Slate `#374151`. Inter for English, Hind Siliguri for Bangla.

## Customising

Replace the placeholder inputs (deadline, location, authority, contact) with real
values before issuing. Every label carries Bangla beneath the English line — keep
that pairing if you edit wording, and re-check the print pagination after any
change.

## Deploy

[scripts/build.ps1](../scripts/build.ps1) copies this folder to `dist/rfq/`, so
the live path is:

```text
/rfq/proposal-submission-template.html
```

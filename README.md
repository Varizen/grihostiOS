# GrihostiOS (grihosti.xyz)

> **"আপনার জমি, আপনার নিয়ন্ত্রণ" — "Your Land, Your Control"**
> Institutional operating system for property, tenancy, agricultural land, and productive estate operations in Bangladesh.

---

## 🌟 System Overview
GrihostiOS is a governed document and operational engine for:
1. **Governed Tenancy Agreements**: Legally enforceable, bilingual digital agreements adhering to the Premises Rent Control Act, 1991.
2. **Immutable Rent & Settlement Receipts**: Tamper-proof payment records with QR verification and MFS reconciliation (bKash/Nagad).
3. **Agricultural & Sharecropper Management**: Seasonal parcel accounting, sharecropper (বর্গা) contracts, and harvest verification.
4. **Fisheries & Productive Estates**: Pond leasing, input inventory, and transparent auction and yield settlements.

---

## 🏛️ Brand & Identity
- **Primary Domain**: `grihosti.xyz`
- **Primary Vertical**: Property, Tenancy & Agriculture
- **Tagline**: `Home • Land • Production`
- **Primary Typography**: Hind Siliguri (Bangla) & Inter (English)
- **Palette** (Option 5 "Plum & Green"): Plum `#3B1E3F`, Mauve `#8B5CF6`, Fresh Green `#22C55E`, Mint `#E9F7EF`, Slate `#374151`.

> 📌 **Canonical brand reference (locked):** see [`BRAND.md`](./BRAND.md) and the master key art at `assets/brand/hero-key-art-2026-10-31.jpg`. All future design work must match this reference.

---

## 🚀 Deployment

Live on Cloudflare Pages: **https://grihosti-xyz.pages.dev**

See [`DEPLOY.md`](./DEPLOY.md) for the Pages project details, deploy commands, and the outstanding DNS records needed to serve `grihosti.xyz` itself.

---

## 📁 Repository Structure
```
grihosti.xyz/
├── index.html        # Bilingual landing page (Bangla default)
├── 404.html          # Branded not-found page
├── _headers          # Cloudflare Pages security + cache headers
├── BRAND.md          # Locked brand reference
├── DEPLOY.md         # Deployment guide
├── assets/           # Public assets (logos, favicons)
│   └── brand/        # Internal brand reference set (not published)
├── procurement/      # Sourcing & supply-chain management system
│   ├── index.html    # Internal console
│   ├── vendor-portal.html
│   └── db/schema.sql # PostgreSQL schema
├── rfq/              # Proposal submission template
├── scripts/build.ps1 # Builds dist/ for deployment
├── wrangler.toml     # Cloudflare Pages config
└── .github/workflows/deploy.yml
```

---

## 🧾 Procurement

Internal sourcing and supply-chain system covering vendor registration, staged
RFQ submission, evaluation, normalization, award and contract. See
[`procurement/README.md`](./procurement/README.md).

- Internal console: `/procurement/`
- Vendor portal: `/procurement/vendor-portal`

---

## 🚀 Status
- **Landing page**: live and bilingual (Bangla default, English secondary).
- **Procurement**: live at `/procurement/` and `/procurement/vendor-portal`.
- **Custom domain**: `grihosti.xyz` zone added to Cloudflare; waiting on the
  Spaceship nameserver switch — see [`DEPLOY.md`](./DEPLOY.md).
- **Repository**: [Varizen/grihostiOS](https://github.com/Varizen/grihostiOS)


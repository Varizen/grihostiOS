# Deployment

**Status: live on Cloudflare Pages; custom domain waiting on nameserver change at Spaceship.**

| Item | Value |
|---|---|
| Cloudflare account | `VIC` — `ffdc985581a586cce38fc03d38bd1e61` |
| Pages project | `grihosti-xyz` |
| Production branch | `main` |
| Build output dir | `dist/` (see `scripts/build.ps1`) |
| Pages URL | https://grihosti-xyz.pages.dev |
| Custom domain | `grihosti.xyz`, `www.grihosti.xyz` — **pending nameserver propagation** |

---

## Why the old setup did not work

`grihosti.xyz` was proxied through Cloudflare (A records to `162.159.142.117` /
`172.66.2.113`) but **no origin, Worker or Pages project was ever attached**.
Every request returned **Cloudflare error 1001 (DNS resolution error)**.

The `grihosti.xyz` zone was **not** in this Cloudflare account. Its nameservers
were `launch1.spaceship.net` / `launch2.spaceship.net` (Spaceship registrar),
so DNS was edited at Spaceship, not in the Cloudflare dashboard.

---

## Current state

The `grihosti.xyz` zone has now been added to account `VIC`. Inside it:

- the two bogus proxied apex `A` records were deleted
- `grihosti.xyz` → `CNAME` → `grihosti-xyz.pages.dev` (proxied)
- `www.grihosti.xyz` → `CNAME` → `grihosti-xyz.pages.dev` (proxied)
- existing `MX`, `SRV` and `SPF` records for Spacemail were left untouched

The zone is still **pending** because the registrar nameservers have not been
switched yet.

---

## Deploy

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build.ps1
npx wrangler pages deploy dist --project-name=grihosti-xyz --branch=main
```

Set `CLOUDFLARE_ACCOUNT_ID=ffdc985581a586cce38fc03d38bd1e61` if wrangler asks.

Deploys also run on push to `main` via `.github/workflows/deploy.yml`. The
repository secrets `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID` are
configured, so CI publishes automatically. The token is scoped to
**Cloudflare Pages: Edit** only.

> The Pages project has **no Git integration** (`Git Provider: No`). Cloudflare
> does not build from the repo itself — the GitHub Actions workflow builds
> `dist/` and uploads it with Wrangler.

---

## Required DNS records (Spaceship)

The Pages project is attached to both domains and is waiting on these records.
Pages validates by HTTP, so the records must resolve before the certificate is
issued.

| Type | Name | Value | Proxy |
|---|---|---|---|
| CNAME | `www` | `grihosti-xyz.pages.dev` | DNS only |
| ALIAS (or ANAME) | `@` | `grihosti-xyz.pages.dev` | — |
| TXT | `_cf-custom-hostname` | *(see below)* | — |

`grihosti.xyz` is an apex domain, so a plain CNAME is not valid at most
registrars. Use the provider's ALIAS/ANAME record, or flatten it. Delete the
existing proxied A records — they point at nothing and cause error 1001.

To run `grihosti.xyz` entirely on Cloudflare instead, add the zone to account
`VIC` and switch the registrar nameservers to the pair Cloudflare assigns.

---

## Activate the custom domain

1. Log into Spaceship → **Domains** → `grihosti.xyz` → **Nameservers**.
2. Replace `launch1.spaceship.net` and `launch2.spaceship.net` with:
   - `joel.ns.cloudflare.com`
   - `monika.ns.cloudflare.com`
3. Make sure DNSSEC is **off** at Spaceship before switching.
4. Save, then wait for propagation (usually 1–2 hours, up to 24).
5. In Cloudflare → `grihosti.xyz` → **Overview**, click **Check nameservers now**.
6. Once the zone is **Active**, open Pages → `grihosti-xyz` → **Custom domains**
   and click **Check DNS records** for both hostnames.

Cloudflare then issues the Universal SSL certificate automatically.

---

## Verified live

```text
GET /                       -> 200  text/html      35765 bytes
GET /assets/logo-on-dark.png-> 200  image/png     588132 bytes
GET /assets/favicon-32.png  -> 200  image/png       2874 bytes
GET /nonexistent            -> 404  branded page
GET /assets/brand/*         -> 404  (reference set, not published)
```

`index.html` reports `lang="bn"` and links Hind Siliguri, so Bangla renders as
the default language.

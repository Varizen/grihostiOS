# Deployment

**Status: live on Cloudflare Pages, custom domain pending DNS.**

| Item | Value |
|---|---|
| Cloudflare account | `VIC` — `ffdc985581a586cce38fc03d38bd1e61` |
| Pages project | `grihosti-xyz` |
| Production branch | `main` |
| Build output dir | `dist/` (see `scripts/build.ps1`) |
| Pages URL | https://grihosti-xyz.pages.dev |
| Custom domain | `grihosti.xyz`, `www.grihosti.xyz` — **pending DNS** |

---

## Why the old setup did not work

`grihosti.xyz` was proxied through Cloudflare (A records to `162.159.142.117` /
`172.66.2.113`) but **no origin, Worker or Pages project was ever attached**.
Every request returned **Cloudflare error 1001 (DNS resolution error)**.

The `grihosti.xyz` zone is **not** in this Cloudflare account. Its nameservers
are `launch1.spaceship.net` / `launch2.spaceship.net` (Spaceship registrar),
so DNS is edited at Spaceship, not in the Cloudflare dashboard.

---

## Deploy

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build.ps1
npx wrangler pages deploy dist --project-name=grihosti-xyz --branch=main
```

Set `CLOUDFLARE_ACCOUNT_ID=ffdc985581a586cce38fc03d38bd1e61` if wrangler asks.

Deploys also run on push to `main` via `.github/workflows/deploy.yml`, which
needs two repository secrets:

- `CLOUDFLARE_API_TOKEN`
- `CLOUDFLARE_ACCOUNT_ID`

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

## Verified live

```text
GET /                       -> 200  text/html      13989 bytes
GET /assets/logo-on-dark.png-> 200  image/png     588132 bytes
GET /assets/favicon-32.png  -> 200  image/png       2874 bytes
GET /nonexistent            -> 404  branded page
GET /assets/brand/*         -> 404  (reference set, not published)
```

`index.html` reports `lang="bn"` and links Hind Siliguri, so Bangla renders as
the default language.

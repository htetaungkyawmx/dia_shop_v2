# Deploying

Three pieces go online: the API, the database, and the two Flutter web builds.

## Local / self-hosted (cheapest)

```bash
cd dia_shop_v2
cp .env.example .env     # then edit the secrets
docker compose up -d --build
```

That gives you Postgres and the API on port 8080, with uploads on a named
volume so screenshots survive a restart.

To expose it from a home machine or a small VPS, put Caddy or Nginx in front
for TLS and point it at `localhost:8080`.

## Free / low-cost hosting

| Piece | Good options |
|---|---|
| API | Railway, Render, Fly.io, Koyeb — all read the `Dockerfile` directly |
| Database | The same provider's managed Postgres, or Neon / Supabase free tier |
| Web builds | Netlify, Vercel, Cloudflare Pages, GitHub Pages — static files |

### API

Point the provider at `backend/` (it has a `Dockerfile`) and set:

```
DB_URL=jdbc:postgresql://<host>:5432/<db>
DB_USER=...
DB_PASSWORD=...
JWT_SECRET=<32+ random characters>
ADMIN_EMAIL=you@yourdomain.com
ADMIN_PASSWORD=<a real password>
CORS_ORIGINS=https://shop.yourdomain.com,https://admin.yourdomain.com
STORAGE_PUBLIC_URL=https://api.yourdomain.com/uploads
```

Generate a secret with:

```bash
openssl rand -base64 48
```

Flyway runs the migrations on boot, so a fresh database needs no manual setup.

> **Uploads on ephemeral hosts.** Railway/Render containers have a disk that is
> wiped on redeploy. Attach a persistent volume and set `STORAGE_PATH` to it,
> or implement `StorageService` against S3/R2 — the interface exists for exactly
> this, and nothing else in the app has to change.

### Customer web app

```bash
cd app
flutter build web --release --dart-define=API_BASE_URL=https://api.yourdomain.com
```

Upload `app/build/web/`. On Netlify or Vercel, set the publish directory to
`build/web` and add a rewrite so deep links work:

```
/*  /index.html  200
```

Your customers' link is then `https://shop.yourdomain.com`. On iPhone, Safari →
Share → **Add to Home Screen** installs it like an app. No Apple Developer
account needed.

### Admin panel

```bash
cd admin
flutter build web --release --dart-define=API_BASE_URL=https://api.yourdomain.com
```

Upload `admin/build/web/` to a separate site — for example
`https://admin.yourdomain.com`. Keep it on its own subdomain so you can put an
extra layer in front of it later (IP allowlist, Cloudflare Access) without
touching the shop.

## Android release build

```bash
cd app
flutter build appbundle --release --dart-define=API_BASE_URL=https://api.yourdomain.com
```

Signing config goes in `android/key.properties` — it is gitignored.

## Before you go live

- [ ] `JWT_SECRET` set to a long random value, not the default
- [ ] Admin password changed from `Admin@12345`
- [ ] `CORS_ORIGINS` narrowed to your real domains
- [ ] Real payment accounts entered in the admin panel (the seeded ones are placeholders)
- [ ] Seeded demo products reviewed — prices there are examples, not your prices
- [ ] Database backups scheduled with your provider
- [ ] Uploads on persistent storage

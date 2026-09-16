# Dia Shop v2

Digital goods and game top-up shop — diamonds, UC, gift cards, premium subscriptions.

One backend, three clients:

| Folder | What it is | Runs on |
|---|---|---|
| `backend/` | Java 21 · Spring Boot 3.5 · PostgreSQL | Docker, or any JVM host |
| `app/` | Customer app — Flutter | Android · iOS · **Web (PWA)** |
| `admin/` | Admin panel — Flutter Web | Browser |

The customer app and the website are **the same codebase**. The web build is a
PWA, so on iPhone your customers can open the link in Safari and "Add to Home
Screen" — it behaves like an installed app with no Apple Developer account.

---

## မြန်မာလို အမြန်စတင်နည်း

### ၁။ Database နဲ့ Backend စတင်ရန်

```bash
cd dia_shop_v2 && docker compose up -d
```

ဒါဆိုရင် —
- Postgres က `localhost:5433` မှာ run နေမယ်
- API က `http://localhost:8080` မှာ run နေမယ်
- API စာရွက်စာတမ်း — http://localhost:8080/swagger-ui.html

ပထမဆုံးအကြိမ် run တဲ့အခါ admin account တစ်ခု အလိုအလျောက် ဆောက်ပေးပါတယ် —

```
Email    : admin@diashop.com
Password : Admin@12345
```

> ⚠️ **အရေးကြီး** — ဒီ password ကို ချက်ချင်း ပြောင်းပါ။ Production မှာ
> `ADMIN_PASSWORD` နဲ့ `JWT_SECRET` ကို environment variable နဲ့ သတ်မှတ်ပါ။

### ၂။ Customer app ကို ဖွင့်ရန်

```bash
cd app && flutter run --dart-define=API_BASE_URL=http://localhost:8080
```

Web အဖြစ် ဖွင့်ချင်ရင် —

```bash
cd app && flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8080
```

### ၃။ Admin panel ကို ဖွင့်ရန်

```bash
cd admin && flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8080
```

### ၄။ Web app ကို link နဲ့ ထုတ်ရန်

```bash
cd app && flutter build web --release --dart-define=API_BASE_URL=https://api.yourdomain.com
```

`app/build/web/` ထဲက ဖိုင်တွေကို Netlify, Vercel, Cloudflare Pages စတဲ့
နေရာတွေမှာ တင်လိုက်ရုံပါပဲ (အခမဲ့ tier တွေ ရှိပါတယ်)။ အသေးစိတ်ကို
[`docs/DEPLOY.md`](docs/DEPLOY.md) မှာ ကြည့်ပါ။

---

## What a day in the shop looks like

```
Customer                          Admin
────────                          ─────
browse catalog
      │
      ▼
transfer money in KBZPay/Wave  ──▶  sees the slip in "Top-ups"
upload screenshot + reference       checks it against the bank app
      │                             approves  ──▶ wallet credited
      ▼
order a package (pays from wallet)
      │
      ├── gift card / licence key  ──▶ code delivered instantly, stock decremented
      │
      └── diamonds / UC / premium  ──▶  appears in "Orders" with the Player ID
                                        admin tops up, marks delivered
                                              │
                                              └─ if it can't be done: reject
                                                 → money back, stock back
```

## Why it is built this way

**Money never moves without a ledger row.** `wallet_transactions` is
append-only and every balance change writes one, with the running total in
`balance_after`. The balance column is just a cached sum — you can always
reconstruct and audit it. Balance changes take a `SELECT … FOR UPDATE` row lock
first, so two parallel checkouts can never spend the same money.

**Stock never moves without a movement row.** Every restock, sale, refund and
manual correction writes to `stock_movements` with before/after counts and who
did it. When a number looks wrong, the history tells you exactly why.

Three stock models per package:

| Type | Use it for | Behaviour |
|---|---|---|
| `UNLIMITED` | Diamonds, UC — you top up by hand | Never runs out |
| `LIMITED` | Netflix slots, accounts | Counter, decrements on sale |
| `CODE_POOL` | Gift cards, licence keys | Queue of unique codes, delivered instantly |

**Prices are integers.** MMK has no minor units, so everything is `BIGINT`. The
old app stored `"3,400 Ks"` as a `String` — that is how rounding bugs start.

**Products are data, not code.** Games, packages, prices and the input fields a
buyer must fill (Player ID, Server ID, account email…) all live in the database
and are edited from the admin panel. Adding a new game is a form, not a release.

**Past orders are frozen.** `order_items` snapshots the product name, package
name and price at purchase time, so changing your catalog never rewrites
somebody's receipt.

---

## Project layout

```
dia_shop_v2/
├── backend/
│   └── src/main/java/com/diashop/api/
│       ├── domain/        JPA entities + enums
│       ├── repository/    Spring Data repositories
│       ├── service/       business logic (wallet, stock, orders, top-ups)
│       ├── web/           REST controllers
│       ├── dto/           request/response records
│       ├── security/      JWT, filter, security config
│       └── config/        properties, CORS, OpenAPI
│   └── src/main/resources/db/migration/   Flyway SQL
├── app/
│   └── lib/
│       ├── core/          API client, token storage, formatting
│       ├── models/        JSON models
│       ├── data/          repositories (one per API area)
│       ├── providers/     Riverpod state
│       ├── features/      one folder per screen area
│       ├── widgets/       shared UI
│       └── l10n/          Burmese + English strings
└── admin/
    └── lib/               same shape, admin screens
```

## Configuration

Everything is an environment variable; nothing secret is in the code.

| Variable | Default | Notes |
|---|---|---|
| `DB_URL` | `jdbc:postgresql://localhost:5432/dia_shop` | |
| `DB_USER` / `DB_PASSWORD` | `dia_shop` | |
| `JWT_SECRET` | dev placeholder | **Must** be ≥ 32 chars in production |
| `ADMIN_EMAIL` / `ADMIN_PASSWORD` | `admin@diashop.com` / `Admin@12345` | First boot only |
| `CORS_ORIGINS` | any localhost port | **Must** be your real domains in production |
| `STORAGE_PATH` | `./uploads` | Where payment screenshots land |
| `STORAGE_PUBLIC_URL` | `http://localhost:8080/uploads` | Public base URL for those files |
| `GOOGLE_CLIENT_IDS` | empty | Comma-separated; enables Google Sign-In |

Flutter side, at build time:

```bash
--dart-define=API_BASE_URL=https://api.yourdomain.com
--dart-define=GOOGLE_CLIENT_ID=...apps.googleusercontent.com   # optional
```

## Tests

```bash
cd backend && mvn test              # 38 unit tests: JWT, wallet ledger, stock rules, search
cd app && flutter test              # formatting, validation, order/quote logic
./scripts/smoke-test.sh             # 50 checks against a running API
```

`scripts/smoke-test.sh` walks the whole shop end to end — register, top up,
approve, order, reject, refund — and calls every list endpoint both with and
without filters. Point it at any environment:

```bash
./scripts/smoke-test.sh https://api.yourdomain.com admin@yourdomain.com 'your-password'
```

> On macOS, `flutter test` needs the Xcode licence accepted once:
> `sudo xcodebuild -license accept`

## Payment gateways

Every top-up today is a manual bank transfer that an admin verifies. The seam
for an online gateway is already in place: `payment_methods.gateway` and
`topup_requests.gateway` / `gateway_ref`. When you have a KBZPay or 2C2P
merchant account, a gateway callback can approve a request the same way an
admin does — `TopupService.approve` is the single path that credits a wallet.

## Further reading

- [`docs/API.md`](docs/API.md) — every endpoint, grouped by area
- [`docs/DEPLOY.md`](docs/DEPLOY.md) — putting it online for free or cheap

# API reference

Base URL: `{API_BASE_URL}/api/v1`
Interactive docs: `{API_BASE_URL}/swagger-ui.html`

Authentication is a short-lived JWT access token (30 min) in
`Authorization: Bearer <token>`, refreshed with an opaque, rotating refresh
token (30 days). Only the SHA-256 hash of a refresh token is stored; presenting
a revoked one drops every session for that user.

Errors always come back in the same shape, so clients can branch on `code`:

```json
{
  "code": "INSUFFICIENT_BALANCE",
  "message": "Your balance is not enough. Please top up and try again.",
  "fieldErrors": { "email": "must be a well-formed email address" },
  "path": "/api/v1/orders",
  "timestamp": "2026-09-16T04:06:13.044706Z"
}
```

Paged endpoints return `{ items, page, size, totalItems, totalPages, hasNext }`.

---

## Public — no token required

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/public/config` | Shop name, maintenance flag, top-up limits, support links |
| `GET` | `/public/home` | Banners, categories, featured products |
| `GET` | `/public/categories` | All active categories |
| `GET` | `/public/products?category=&q=` | Product list |
| `GET` | `/public/products/{slug}` | Product detail: input fields + packages |
| `GET` | `/public/payment-methods` | Accounts to transfer to |

Stock is deliberately coarse in public responses: a package reports `inStock`,
and `remaining` only once it drops below 10 — competitors should not be able to
read your full inventory.

## Auth

| Method | Path | Purpose |
|---|---|---|
| `POST` | `/auth/register` | Email + password sign-up |
| `POST` | `/auth/login` | Email + password sign-in |
| `POST` | `/auth/google` | Exchange a Google ID token for a session |
| `POST` | `/auth/refresh` | Rotate the refresh token, get a new access token |
| `POST` | `/auth/logout` | Revoke this device's refresh token |

Unknown email and wrong password return the same message, so the endpoint
cannot be used to discover which emails are registered.

## My account

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/me` | Profile + balance |
| `PATCH` | `/me` | Name, phone, photo, language |
| `POST` | `/me/password` | Change password (signs out every other device) |
| `POST` | `/me/devices` | Register an FCM token |
| `DELETE` | `/me/devices/{token}` | Remove one |
| `POST` | `/me/logout-all` | Sign out everywhere |

## Wallet

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/wallet` | Balance + pending top-up total |
| `GET` | `/wallet/transactions?type=&page=&size=` | Ledger |
| `GET` | `/wallet/payment-methods` | Accounts to transfer to |
| `POST` | `/wallet/topups` | Submit a transfer for review |
| `GET` | `/wallet/topups?status=` | My top-up requests |
| `POST` | `/wallet/topups/{id}/cancel` | Withdraw a pending request |
| `POST` | `/uploads/payment-slip` | Upload the screenshot (multipart `file`) |

A transfer reference can only be claimed once per payment method while a
request is pending or approved, so a screenshot cannot be replayed.

## Orders

| Method | Path | Purpose |
|---|---|---|
| `POST` | `/orders/quote` | Price a basket and check stock without buying |
| `POST` | `/orders` | Place the order, paid from the wallet |
| `GET` | `/orders?status=&page=&size=` | My orders |
| `GET` | `/orders/{id}` | One order, with delivered codes |
| `POST` | `/orders/{id}/cancel` | Cancel while still pending; wallet refunded |

`POST /orders` body:

```json
{
  "items": [
    {
      "variantId": 4,
      "quantity": 2,
      "fieldValues": { "player_id": "123456789", "server_id": "1234" }
    }
  ],
  "customerNote": "Please deliver fast"
}
```

`fieldValues` keys come from the product's `fields`, and each value is checked
against that field's `validationRegex` server-side.

Codes for a `CODE_DELIVERY` product are handed over during checkout and the
order comes back already `COMPLETED`.

## Notifications & support

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/notifications` | In-app inbox (own + broadcasts) |
| `GET` | `/notifications/unread-count` | Badge count |
| `POST` | `/notifications/{id}/read` · `/notifications/read-all` | Mark read |
| `POST` | `/support/tickets` | Ask a question |
| `GET` | `/support/tickets` | My messages and replies |

---

## Admin — requires `ROLE_ADMIN`

### Dashboard & settings

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/admin/dashboard` | Queues, revenue, profit, 30-day series, top sellers, low stock |
| `GET` `PUT` | `/admin/settings` | Key/value shop settings, incl. maintenance mode |
| `POST` | `/admin/notifications` | Notify one customer, or broadcast to all |
| `GET` | `/admin/audit-logs` | Who did what |
| `POST` | `/admin/uploads/image` | Upload a product or banner image |

### Orders

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/admin/orders?q=&status=` | Search every order |
| `GET` | `/admin/orders/{id}` | Detail, incl. the buyer's Player ID |
| `POST` | `/admin/orders/{id}/process` | Claim it so other staff see it's taken |
| `POST` | `/admin/orders/{id}/complete` | Mark delivered; hands over any pending codes |
| `POST` | `/admin/orders/{id}/reject` | Reject → wallet refunded, stock released |
| `POST` | `/admin/orders/{id}/refund` | Reverse an already-completed order |

### Top-ups

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/admin/topups?q=&status=` | Review queue |
| `GET` | `/admin/topups/{id}` | One request |
| `POST` | `/admin/topups/{id}/approve` | Credit the wallet (optionally a corrected amount) |
| `POST` | `/admin/topups/{id}/reject` | Reject with a reason |

### Catalog

| Method | Path | Purpose |
|---|---|---|
| `GET` `POST` | `/admin/categories` · `PUT` `DELETE` `/admin/categories/{id}` | Categories |
| `GET` | `/admin/products?q=&categoryId=&active=` | Products with packages and stock |
| `GET` | `/admin/products/{id}` | One product |
| `POST` | `/admin/products` · `PUT` `/admin/products/{id}` | Create / edit, including input fields |
| `DELETE` | `/admin/products/{id}` | Archive (never hard-deleted — orders point at it) |
| `POST` | `/admin/products/{id}/variants` · `PUT` `/admin/variants/{id}` | Packages |
| `DELETE` | `/admin/variants/{id}` | Archive a package |
| `GET` `POST` `PUT` | `/admin/banners` · `/admin/payment-methods` | Content |

Editing a package cannot change its stock level — that is deliberate, so every
stock change goes through the endpoints below and leaves a trail.

### Stock

| Method | Path | Purpose |
|---|---|---|
| `POST` | `/admin/variants/{id}/stock/adjust` | `+10` restock, `-3` write-off, with a reason |
| `PUT` | `/admin/variants/{id}/stock` | Set the exact count after a recount |
| `GET` | `/admin/variants/{id}/stock/movements` | Full history: delta, before → after, who, why |
| `POST` | `/admin/variants/{id}/stock/codes` | Paste gift-card / licence keys |
| `GET` | `/admin/variants/{id}/stock/codes` | Pool status (values masked) |

### Customers & support

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/admin/users?q=&status=&role=` | Customers with balance and lifetime spend |
| `GET` | `/admin/users/{id}` | One customer |
| `PATCH` | `/admin/users/{id}` | Name, phone, role, suspend/restore |
| `POST` | `/admin/users/{id}/balance` | Manual credit or debit; reason shown to the customer |
| `GET` | `/admin/users/{id}/transactions` | Their ledger |
| `POST` | `/admin/staff` | Create an admin account (super admin only) |
| `GET` | `/admin/tickets?status=` · `POST` `/admin/tickets/{id}/reply` | Support inbox |

Role changes require `SUPER_ADMIN`, and nobody can change their own role or
suspend their own account.

## Error codes worth handling in a client

| Code | HTTP | Meaning |
|---|---|---|
| `INSUFFICIENT_BALANCE` | 402 | Offer a top-up instead of an error |
| `OUT_OF_STOCK` | 409 | Re-quote and show what's left |
| `DUPLICATE_REFERENCE` | 409 | That transfer reference was already submitted |
| `MAINTENANCE` | 503 | Shop is closed; show the message from the body |
| `VALIDATION_FAILED` | 400 | `fieldErrors` maps field → message |
| `CONCURRENT_UPDATE` | 409 | Someone else changed the record; reload |
| `ALREADY_REVIEWED` / `ALREADY_CREDITED` | 409 | Guards against a double-click |

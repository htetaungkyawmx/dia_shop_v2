#!/usr/bin/env bash
#
# End-to-end smoke test against a running API.
#
#   ./scripts/smoke-test.sh [base-url] [admin-email] [admin-password]
#
# Walks the whole shop: catalog -> register -> top-up -> approve -> order ->
# fulfil, and calls every list endpoint both with and without filters, because
# an unfiltered list is a different SQL path from a filtered one.

set -euo pipefail

BASE="${1:-http://localhost:8080}"
ADMIN_EMAIL="${2:-admin@diashop.com}"
ADMIN_PASSWORD="${3:-Admin@12345}"
API="$BASE/api/v1"

pass=0
fail=0

# json <key|index>... — walks into the JSON on stdin and prints the value.
json() {
  python3 -c '
import sys, json
try:
    node = json.load(sys.stdin)
except Exception:
    sys.exit(0)
for step in sys.argv[1:]:
    node = node[int(step)] if step.lstrip("-").isdigit() else node[step]
print(node)
' "$@" 2>/dev/null || true
  # Never fail: under `set -e -o pipefail` a missing key would otherwise end
  # the whole run silently, hiding the very failure we are looking for.
}

check() { # check <name> <expected-status> <curl args...>
  local name="$1" expected="$2"; shift 2
  local status
  status=$(curl -s -o /tmp/smoke-body.json -w '%{http_code}' "$@" || true)
  if [[ "$status" == "$expected" ]]; then
    printf '  \033[32m✓\033[0m %s\n' "$name"
    pass=$((pass + 1))
  else
    printf '  \033[31m✗\033[0m %s — expected %s, got %s\n' "$name" "$expected" "$status"
    head -c 300 /tmp/smoke-body.json; echo
    fail=$((fail + 1))
  fi
}

echo "Smoke testing $BASE"
echo
echo "Public endpoints"
check "config"             200 "$API/public/config"
check "home"               200 "$API/public/home"
check "categories"         200 "$API/public/categories"
check "products (all)"     200 "$API/public/products"
check "products (search)"  200 "$API/public/products?q=diamond"
check "products (category)" 200 "$API/public/products?category=mobile-games"
check "payment methods"    200 "$API/public/payment-methods"

echo
echo "Auth"
STAMP=$(date +%s)
EMAIL="smoke+$STAMP@test.local"
USER_TOKEN=$(curl -s -X POST "$API/auth/register" -H 'Content-Type: application/json' \
  -d "{\"email\":\"$EMAIL\",\"password\":\"Smoke1234\",\"displayName\":\"Smoke Test\"}" | json accessToken)
[[ -n "$USER_TOKEN" ]] && { printf '  \033[32m✓\033[0m register\n'; pass=$((pass+1)); } \
                       || { printf '  \033[31m✗\033[0m register\n'; fail=$((fail+1)); }

ADMIN_TOKEN=$(curl -s -X POST "$API/auth/login" -H 'Content-Type: application/json' \
  -d "{\"email\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASSWORD\"}" | json accessToken)
[[ -n "$ADMIN_TOKEN" ]] && { printf '  \033[32m✓\033[0m admin login\n'; pass=$((pass+1)); } \
                        || { printf '  \033[31m✗\033[0m admin login\n'; fail=$((fail+1)); }

UA=(-H "Authorization: Bearer $USER_TOKEN")
AA=(-H "Authorization: Bearer $ADMIN_TOKEN")

echo
echo "Customer endpoints"
check "me"                 200 "${UA[@]}" "$API/me"
check "wallet"             200 "${UA[@]}" "$API/wallet"
check "transactions"       200 "${UA[@]}" "$API/wallet/transactions"
check "topups (all)"       200 "${UA[@]}" "$API/wallet/topups"
check "topups (filtered)"  200 "${UA[@]}" "$API/wallet/topups?status=PENDING"
check "orders (all)"       200 "${UA[@]}" "$API/orders"
check "orders (filtered)"  200 "${UA[@]}" "$API/orders?status=PENDING"
check "notifications"      200 "${UA[@]}" "$API/notifications"
check "unread count"       200 "${UA[@]}" "$API/notifications/unread-count"
check "tickets"            200 "${UA[@]}" "$API/support/tickets"
check "admin route denied" 403 "${UA[@]}" "$API/admin/dashboard"
check "no token denied"    401 "$API/me"

echo
echo "Admin endpoints (unfiltered and filtered)"
check "dashboard"            200 "${AA[@]}" "$API/admin/dashboard"
check "orders (all)"         200 "${AA[@]}" "$API/admin/orders"
check "orders (status)"      200 "${AA[@]}" "$API/admin/orders?status=PENDING"
check "orders (search)"      200 "${AA[@]}" "$API/admin/orders?q=DS-"
check "topups (all)"         200 "${AA[@]}" "$API/admin/topups"
check "topups (status)"      200 "${AA[@]}" "$API/admin/topups?status=PENDING"
check "topups (search)"      200 "${AA[@]}" "$API/admin/topups?q=TP-"
check "products (all)"       200 "${AA[@]}" "$API/admin/products"
check "products (search)"    200 "${AA[@]}" "$API/admin/products?q=mlbb"
check "products (inactive)"  200 "${AA[@]}" "$API/admin/products?active=false"
check "categories"           200 "${AA[@]}" "$API/admin/categories"
check "users (all)"          200 "${AA[@]}" "$API/admin/users"
check "users (search)"       200 "${AA[@]}" "$API/admin/users?q=smoke"
check "users (status)"       200 "${AA[@]}" "$API/admin/users?status=ACTIVE"
check "users (role)"         200 "${AA[@]}" "$API/admin/users?role=ADMIN"
check "tickets (all)"        200 "${AA[@]}" "$API/admin/tickets"
check "tickets (status)"     200 "${AA[@]}" "$API/admin/tickets?status=OPEN"
check "banners"              200 "${AA[@]}" "$API/admin/banners"
check "payment methods"      200 "${AA[@]}" "$API/admin/payment-methods"
check "settings"             200 "${AA[@]}" "$API/admin/settings"
check "audit logs"           200 "${AA[@]}" "$API/admin/audit-logs"

echo
echo "Purchase flow"
METHOD_ID=$(curl -s "$API/public/payment-methods" | json 0 id)

# Upload the slip the way the Flutter app does: Dio labels in-memory bytes
# application/octet-stream, and web pickers often give a name with no
# extension. The server has to go by the bytes, or every top-up screenshot fails.
SLIP=$(mktemp)
echo 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==' | base64 -d > "$SLIP"
SLIP_URL=$(curl -s "${UA[@]}" -F "file=@$SLIP;filename=image_picker_blob;type=application/octet-stream" \
  "$API/uploads/payment-slip" | json url)
rm -f "$SLIP"
[[ "$SLIP_URL" == http* ]] && { printf '  \033[32m✓\033[0m payment slip upload (as the app sends it)\n'; pass=$((pass+1)); } \
                          || { printf '  \033[31m✗\033[0m payment slip upload (as the app sends it)\n'; fail=$((fail+1)); }
check "uploaded slip is served back" 200 "$SLIP_URL"

TOPUP_ID=$(curl -s -X POST "$API/wallet/topups" "${UA[@]}" -H 'Content-Type: application/json' \
  -d "{\"paymentMethodId\":$METHOD_ID,\"amount\":50000,\"referenceNo\":\"SMOKE$STAMP\",\"screenshotUrl\":\"$SLIP_URL\"}" | json id)
check "approve top-up" 200 -X POST "${AA[@]}" -H 'Content-Type: application/json' -d '{}' \
  "$API/admin/topups/$TOPUP_ID/approve"

BALANCE=$(curl -s "$API/wallet" "${UA[@]}" | json balance)
[[ "$BALANCE" == "50000" ]] && { printf '  \033[32m✓\033[0m wallet credited (%s)\n' "$BALANCE"; pass=$((pass+1)); } \
                            || { printf '  \033[31m✗\033[0m wallet credited — got %s\n' "$BALANCE"; fail=$((fail+1)); }

VARIANT_ID=$(curl -s "$API/public/products/mlbb" | json variants 0 id)
ORDER=$(curl -s -X POST "$API/orders" "${UA[@]}" -H 'Content-Type: application/json' \
  -d "{\"items\":[{\"variantId\":$VARIANT_ID,\"quantity\":1,\"fieldValues\":{\"player_id\":\"123456789\",\"server_id\":\"1234\"}}]}")
ORDER_ID=$(echo "$ORDER" | json id)
[[ -n "$ORDER_ID" ]] && { printf '  \033[32m✓\033[0m order placed (%s)\n' "$(echo "$ORDER" | json orderNo)"; pass=$((pass+1)); } \
                     || { printf '  \033[31m✗\033[0m order placed\n'; fail=$((fail+1)); }

check "reject order (refund)" 200 -X POST "${AA[@]}" -H 'Content-Type: application/json' \
  -d '{"reason":"smoke test"}' "$API/admin/orders/$ORDER_ID/reject"

AFTER=$(curl -s "$API/wallet" "${UA[@]}" | json balance)
[[ "$AFTER" == "50000" ]] && { printf '  \033[32m✓\033[0m refund returned the money (%s)\n' "$AFTER"; pass=$((pass+1)); } \
                          || { printf '  \033[31m✗\033[0m refund returned the money — got %s\n' "$AFTER"; fail=$((fail+1)); }

echo
echo "Validation guards"
check "bad player id rejected" 400 -X POST "${UA[@]}" -H 'Content-Type: application/json' \
  -d "{\"items\":[{\"variantId\":$VARIANT_ID,\"quantity\":1,\"fieldValues\":{\"player_id\":\"abc\",\"server_id\":\"1234\"}}]}" \
  "$API/orders"
check "duplicate reference rejected" 409 -X POST "${UA[@]}" -H 'Content-Type: application/json' \
  -d "{\"paymentMethodId\":$METHOD_ID,\"amount\":50000,\"referenceNo\":\"SMOKE$STAMP\"}" \
  "$API/wallet/topups"
check "double approve rejected" 409 -X POST "${AA[@]}" -H 'Content-Type: application/json' -d '{}' \
  "$API/admin/topups/$TOPUP_ID/approve"

echo
printf 'passed: %d   failed: %d\n' "$pass" "$fail"
[[ "$fail" -eq 0 ]]

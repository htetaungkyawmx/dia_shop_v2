#!/usr/bin/env bash
#
# Deploy to your own VPS. Run this from your Mac, in the repo root.
#
#   ./scripts/deploy.sh
#
# Reads settings from scripts/deploy.env (copy scripts/deploy.env.example).
# What it does:
#   1. builds both Flutter web apps against your production API URL
#   2. copies those builds to the VPS
#   3. pulls the latest code on the VPS and restarts the stack
#
# The backend image is built on the VPS from the code in git, so the server is
# always running exactly what is committed.

set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"

CONFIG="scripts/deploy.env"
if [[ ! -f "$CONFIG" ]]; then
  echo "Missing $CONFIG — copy scripts/deploy.env.example and fill it in." >&2
  exit 1
fi
# shellcheck disable=SC1090
source "$CONFIG"

: "${VPS_HOST:?Set VPS_HOST in $CONFIG (e.g. root@203.0.113.10)}"
: "${DOMAIN:?Set DOMAIN in $CONFIG (e.g. diashop.com)}"
REMOTE_DIR="${REMOTE_DIR:-/opt/dia-shop}"
API_URL="https://api.${DOMAIN}"

step() { printf '\n\033[1;34m==>\033[0m %s\n' "$1"; }

step "Checking the VPS is reachable"
ssh -o BatchMode=yes -o ConnectTimeout=10 "$VPS_HOST" "true" \
  || { echo "Cannot ssh to $VPS_HOST. Set up an SSH key first." >&2; exit 1; }

step "Building the customer web app against $API_URL"
( cd app && flutter build web --release --dart-define=API_BASE_URL="$API_URL" )

step "Building the admin panel against $API_URL"
( cd admin && flutter build web --release --dart-define=API_BASE_URL="$API_URL" )

step "Making sure $REMOTE_DIR exists on the VPS"
ssh "$VPS_HOST" "mkdir -p '$REMOTE_DIR/deploy/web/shop' '$REMOTE_DIR/deploy/web/admin' '$REMOTE_DIR/deploy/backups'"

step "Uploading the web builds"
# --delete so a file removed from a build does not linger and get served.
rsync -az --delete "$ROOT/app/build/web/"   "$VPS_HOST:$REMOTE_DIR/deploy/web/shop/"
rsync -az --delete "$ROOT/admin/build/web/" "$VPS_HOST:$REMOTE_DIR/deploy/web/admin/"

step "Pulling the latest code and restarting the stack"
ssh "$VPS_HOST" bash -s <<REMOTE
set -euo pipefail
cd "$REMOTE_DIR"
git fetch --quiet origin
git reset --hard --quiet origin/main
if [[ ! -f deploy/.env ]]; then
  echo "deploy/.env is missing on the VPS. Copy deploy/env.example to deploy/.env and fill it in." >&2
  exit 1
fi
docker compose --env-file deploy/.env -f deploy/docker-compose.prod.yml up -d --build
docker image prune -f >/dev/null
REMOTE

step "Waiting for the API to report healthy"
for attempt in {1..30}; do
  if curl -fsS "https://api.${DOMAIN}/actuator/health" >/dev/null 2>&1; then
    printf '\033[1;32m✓ live\033[0m\n'
    echo
    echo "  shop   https://${DOMAIN}"
    echo "  admin  https://admin.${DOMAIN}"
    echo "  api    https://api.${DOMAIN}"
    echo
    echo "Verify the whole flow with:"
    echo "  ./scripts/smoke-test.sh https://api.${DOMAIN} <admin-email> '<admin-password>'"
    exit 0
  fi
  sleep 5
done

echo "The API did not come up in time. Check the logs with:" >&2
echo "  ssh $VPS_HOST 'cd $REMOTE_DIR && docker compose -f deploy/docker-compose.prod.yml logs --tail=80 api'" >&2
exit 1

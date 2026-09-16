#!/usr/bin/env bash
#
# Deploy onto a VPS that already hosts other sites behind nginx.
#
#   ./scripts/deploy-shared.sh              # build, upload, start (HTTP)
#   ./scripts/deploy-shared.sh --with-tls   # ...and issue HTTPS certificates
#
# Settings live in scripts/deploy-shared.env (see the .example next to it).
#
# Guarantees for the other sites on the server:
#   - their nginx files are never edited; this site gets its own file
#   - nginx is only reloaded after `nginx -t` passes; on failure our file is
#     removed again so the server is left exactly as it was
#   - the API and database listen on loopback only
#   - nothing is compiled on the server (the jar is built here), so the
#     server's CPU stays free for what is already running on it

set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$(pwd)"

WITH_TLS=false
[[ "${1:-}" == "--with-tls" ]] && WITH_TLS=true

CONFIG="scripts/deploy-shared.env"
[[ -f "$CONFIG" ]] || { echo "Missing $CONFIG — copy $CONFIG.example and fill it in." >&2; exit 1; }
# shellcheck disable=SC1090
source "$CONFIG"
: "${VPS_HOST:?}" "${DOMAIN:?}" "${ADMIN_EMAIL:?}"
APP_DIR="${APP_DIR:-/opt/$(echo "$DOMAIN" | tr '.' '-')}"
WEB_ROOT="${WEB_ROOT:-/var/www/$(echo "$DOMAIN" | tr '.' '-')}"
API_PORT="${API_PORT:-8090}"
SITE_NAME="$(echo "$DOMAIN" | tr '.' '-')"
TLS_EMAIL="${TLS_EMAIL:-$ADMIN_EMAIL}"

step() { printf '\n\033[1;34m==>\033[0m %s\n' "$1"; }
ok()   { printf '    \033[32m✓\033[0m %s\n' "$1"; }
warn() { printf '    \033[33m!\033[0m %s\n' "$1"; }
run()  { ssh -o BatchMode=yes "$VPS_HOST" "$@"; }

step "Connecting to $VPS_HOST"
run true && ok "ssh works"
SERVER_IP=$(run "curl -fsS -4 https://api.ipify.org || hostname -I | awk '{print \$1}'")
ok "server public IP is $SERVER_IP"

# Snapshot what the other sites return now, to prove we did not break them.
OTHER_SITES=$(run "grep -hoE 'server_name[^;]+' /etc/nginx/sites-enabled/* 2>/dev/null | grep -v '$DOMAIN' | awk '{print \$2}' | sort -u" || true)

step "Building the API jar"
( cd backend && mvn -B -q clean package -DskipTests )
JAR=$(ls backend/target/*.jar | grep -v original | head -1)
ok "$(basename "$JAR") ($(du -h "$JAR" | cut -f1))"

step "Building both web apps against https://api.$DOMAIN"
( cd app   && flutter build web --release --dart-define=API_BASE_URL="https://api.$DOMAIN" >/dev/null )
ok "customer app"
( cd admin && flutter build web --release --dart-define=API_BASE_URL="https://api.$DOMAIN" >/dev/null )
ok "admin panel"

step "Preparing the server"
run "command -v docker >/dev/null" && ok "docker already installed" || {
  warn "installing docker (other services keep running)"
  run "curl -fsSL https://get.docker.com | sh >/dev/null 2>&1"
  ok "docker installed"
}
run "mkdir -p '$APP_DIR' '$WEB_ROOT/shop' '$WEB_ROOT/admin'"

# Secrets are generated once on the server and never overwritten: Postgres
# keeps the password it was initialised with, so rotating it here would lock
# the API out of its own database.
if run "test -f '$APP_DIR/.env'"; then
  ok "existing $APP_DIR/.env kept"
else
  # openssl rather than `tr </dev/urandom | head`: under pipefail that pipeline
  # dies of SIGPIPE and silently aborts the whole script.
  ADMIN_PASSWORD="$(openssl rand -base64 24 | tr -dc 'A-Za-z0-9' | cut -c1-18)9a"
  run "umask 077 && cat > '$APP_DIR/.env'" <<ENV
DOMAIN=$DOMAIN
API_PORT=$API_PORT
DB_PASSWORD=$(openssl rand -hex 24)
JWT_SECRET=$(openssl rand -base64 48 | tr -d '\n')
ADMIN_EMAIL=$ADMIN_EMAIL
ADMIN_PASSWORD=$ADMIN_PASSWORD
ENV
  ok "generated $APP_DIR/.env (readable by root only)"
  printf '\n    \033[1;33mAdmin login — save this now, it is shown only once:\033[0m\n'
  printf '      email:    %s\n      password: %s\n' "$ADMIN_EMAIL" "$ADMIN_PASSWORD"
fi

step "Uploading"
rsync -az "$JAR" "$VPS_HOST:$APP_DIR/app.jar"
rsync -az backend/Dockerfile.runtime deploy/shared-nginx/docker-compose.yml "$VPS_HOST:$APP_DIR/"
rsync -az scripts/backup-shared.sh "$VPS_HOST:$APP_DIR/backup.sh"
rsync -az --delete app/build/web/   "$VPS_HOST:$WEB_ROOT/shop/"
rsync -az --delete admin/build/web/ "$VPS_HOST:$WEB_ROOT/admin/"
ok "jar, compose file and web builds uploaded"

step "Starting the database and API"
run "cd '$APP_DIR' && docker compose up -d --build 2>&1 | tail -3"
for i in $(seq 1 60); do
  if run "curl -fsS http://127.0.0.1:$API_PORT/actuator/health" 2>/dev/null | grep -q UP; then
    ok "API healthy on 127.0.0.1:$API_PORT"; break
  fi
  [[ $i -eq 60 ]] && { echo "API did not start. Logs:" >&2; run "cd '$APP_DIR' && docker compose logs --tail=60 api" >&2; exit 1; }
  sleep 3
done

step "Scheduling the nightly backup"
CRON_LINE="30 3 * * * $APP_DIR/backup.sh >> /var/log/$SITE_NAME-backup.log 2>&1"
if run "crontab -l 2>/dev/null | grep -qF '$APP_DIR/backup.sh'"; then
  ok "already scheduled"
else
  # Append to the existing crontab rather than replacing it: other jobs on
  # this server must survive.
  run "(crontab -l 2>/dev/null; echo '$CRON_LINE') | crontab -"
  ok "03:30 daily, 14 days kept in $APP_DIR/backups"
fi

step "Configuring nginx for $DOMAIN"
SITE_FILE="/etc/nginx/sites-available/$SITE_NAME"
if run "grep -q 'managed by Certbot' '$SITE_FILE' 2>/dev/null"; then
  ok "site file already has certificates — left untouched"
else
  sed -e "s|__DOMAIN__|$DOMAIN|g" -e "s|__WEB_ROOT__|$WEB_ROOT|g" -e "s|__API_PORT__|$API_PORT|g" \
      deploy/shared-nginx/site.conf.template | run "cat > '$SITE_FILE'"
  run "ln -sfn '$SITE_FILE' '/etc/nginx/sites-enabled/$SITE_NAME'"
  if run "nginx -t 2>&1"; then
    run "systemctl reload nginx"
    ok "nginx reloaded"
  else
    run "rm -f '/etc/nginx/sites-enabled/$SITE_NAME'"
    echo "nginx rejected the new site; it was removed and nginx was NOT reloaded." >&2
    exit 1
  fi
fi

step "Checking the other sites on this server still answer"
for host in $OTHER_SITES; do
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "https://$host/" || echo 000)
  [[ "$code" =~ ^(2|3|4) ]] && ok "$host → $code" || warn "$host → $code"
done

step "DNS"
ALL_RESOLVE=true
for name in "$DOMAIN" "www.$DOMAIN" "admin.$DOMAIN" "api.$DOMAIN"; do
  got=$(dig +short A "$name" @1.1.1.1 | tail -1)
  if [[ "$got" == "$SERVER_IP" ]]; then ok "$name → $got"
  else warn "$name → ${got:-nothing} (needs an A record to $SERVER_IP)"; ALL_RESOLVE=false; fi
done

if ! $WITH_TLS; then
  echo
  echo "Deployed over HTTP. When all four names above resolve, add HTTPS with:"
  echo "  ./scripts/deploy-shared.sh --with-tls"
  exit 0
fi

step "HTTPS certificates"
if ! $ALL_RESOLVE; then
  echo "Skipping: every name must point at $SERVER_IP first, or Let's Encrypt will refuse." >&2
  exit 1
fi
run "certbot --nginx --non-interactive --agree-tos --redirect -m '$TLS_EMAIL' \
     -d '$DOMAIN' -d 'www.$DOMAIN' -d 'admin.$DOMAIN' -d 'api.$DOMAIN' 2>&1 | tail -4"
run "nginx -t && systemctl reload nginx"

for url in "https://$DOMAIN" "https://admin.$DOMAIN" "https://api.$DOMAIN/actuator/health"; do
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 "$url" || echo 000)
  [[ "$code" == 200 ]] && ok "$url → 200" || warn "$url → $code"
done

echo
echo "  shop   https://$DOMAIN"
echo "  admin  https://admin.$DOMAIN"
echo "  api    https://api.$DOMAIN"

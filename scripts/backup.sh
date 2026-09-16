#!/usr/bin/env bash
#
# Database backup. Run this ON THE VPS.
#
#   /opt/dia-shop/scripts/backup.sh
#
# Writes a compressed dump into deploy/backups and keeps the last 14 days.
# Schedule it with cron:
#   0 3 * * * /opt/dia-shop/scripts/backup.sh >> /var/log/dia-shop-backup.log 2>&1

set -euo pipefail

cd "$(dirname "$0")/.."
COMPOSE="docker compose --env-file deploy/.env -f deploy/docker-compose.prod.yml"
KEEP_DAYS=14

# shellcheck disable=SC1091
source deploy/.env

STAMP=$(date +%Y%m%d-%H%M%S)
OUT="deploy/backups/dia_shop-$STAMP.sql.gz"

$COMPOSE exec -T postgres pg_dump -U "${DB_USER:-dia_shop}" "${DB_NAME:-dia_shop}" | gzip > "$OUT"

# A dump that is suspiciously small means pg_dump failed mid-stream.
SIZE=$(wc -c < "$OUT")
if [[ "$SIZE" -lt 1024 ]]; then
  echo "Backup looks empty ($SIZE bytes) — keeping it for inspection but treating this as a failure." >&2
  exit 1
fi

find deploy/backups -name 'dia_shop-*.sql.gz' -mtime "+$KEEP_DAYS" -delete
echo "$(date -Is)  backed up to $OUT ($(du -h "$OUT" | cut -f1))"

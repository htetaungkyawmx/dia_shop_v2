#!/usr/bin/env bash
#
# Nightly backup for the shared-nginx deployment. Installed on the server as
# <APP_DIR>/backup.sh by deploy-shared.sh, which also schedules it in cron.
#
# Keeps 14 days of:
#   db-<stamp>.sql.gz        full pg_dump
#   uploads-<stamp>.tar.gz   payment screenshots and catalog images
#
# Restore the database:
#   gunzip -c backups/db-<stamp>.sql.gz | docker compose exec -T postgres psql -U dia_shop dia_shop

set -euo pipefail
cd "$(dirname "$0")"
KEEP_DAYS=14
STAMP=$(date +%Y%m%d-%H%M%S)
mkdir -p backups
chmod 700 backups

DB_OUT="backups/db-$STAMP.sql.gz"
# </dev/null: `exec -T` otherwise swallows the caller's stdin, which cuts off
# any script that runs this one from a heredoc.
docker compose exec -T postgres pg_dump -U dia_shop --no-owner dia_shop </dev/null | gzip > "$DB_OUT"

# gzip always writes a header, so a size check alone would pass an empty dump.
# Confirm the dump actually reached the end of the schema.
if ! gunzip -c "$DB_OUT" | tail -n 5 | grep -q "PostgreSQL database dump complete"; then
  echo "$(date -Is) backup FAILED: $DB_OUT is incomplete" >&2
  exit 1
fi
chmod 600 "$DB_OUT"

UP_OUT="backups/uploads-$STAMP.tar.gz"
docker compose exec -T api tar -C /data -czf - uploads </dev/null 2>/dev/null > "$UP_OUT" || true
chmod 600 "$UP_OUT"

find backups -name 'db-*.sql.gz' -mtime "+$KEEP_DAYS" -delete
find backups -name 'uploads-*.tar.gz' -mtime "+$KEEP_DAYS" -delete

echo "$(date -Is) ok  db $(du -h "$DB_OUT" | cut -f1)  uploads $(du -h "$UP_OUT" | cut -f1)"

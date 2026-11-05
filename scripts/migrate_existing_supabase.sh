#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_REF="${PROJECT_REF:-onmzbyltmbdkuodirfow}"
BACKUP_DIR="${BACKUP_DIR:-}"
CONFIRM_MIGRATION="${CONFIRM_MIGRATION:-}"

if [[ -z "${DATABASE_URL:-}" ]]; then
  echo "DATABASE_URL is required." >&2
  exit 2
fi

if [[ -z "$BACKUP_DIR" ]]; then
  echo "BACKUP_DIR is required and must be outside the repository." >&2
  exit 2
fi

if [[ "$CONFIRM_MIGRATION" != "$PROJECT_REF" ]]; then
  echo "Set CONFIRM_MIGRATION=$PROJECT_REF to authorize the cutover." >&2
  exit 2
fi

mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"

schema_backup="$BACKUP_DIR/public_schema.sql"
data_backup="$BACKUP_DIR/public_data.sql"

pg_dump "$DATABASE_URL" --schema=public --schema-only --no-owner --no-privileges \
  --file "$schema_backup"
pg_dump "$DATABASE_URL" --schema=public --data-only --use-set-session-authorization \
  --file "$data_backup"
chmod 600 "$schema_backup" "$data_backup"
shasum -a 256 "$schema_backup" "$data_backup" > "$BACKUP_DIR/SHA256SUMS"
chmod 600 "$BACKUP_DIR/SHA256SUMS"

psql "$DATABASE_URL" -v ON_ERROR_STOP=1 \
  -f "$ROOT_DIR/supabase/production/01_preflight_read_only.sql"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 \
  -f "$ROOT_DIR/supabase/production/02_archive_legacy.sql"

for migration in "$ROOT_DIR"/supabase/migrations/000{1..7}_*.sql; do
  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f "$migration"
done

psql "$DATABASE_URL" -v ON_ERROR_STOP=1 \
  -f "$ROOT_DIR/supabase/production/03_import_legacy.sql"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 \
  -f "$ROOT_DIR/supabase/production/04_validate_import.sql"

echo "Migration completed. Keep legacy_20261105 until post-cutover acceptance."

#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Export every table from one Supabase/Postgres schema as JSON.

Usage:
  DATABASE_URL='postgresql://...' scripts/export_supabase_json.sh OUTPUT_DIR

Environment:
  DATABASE_URL   Required Postgres connection string. Never stored by the script.
  EXPORT_SCHEMA  Schema to export (default: public).

OUTPUT_DIR must be empty and outside this Git repository.
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

if [[ $# -ne 1 ]]; then
  usage >&2
  exit 2
fi

if [[ -z "${DATABASE_URL:-}" ]]; then
  echo "DATABASE_URL is required." >&2
  exit 2
fi

for command in psql jq shasum python3; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "Required command not found: $command" >&2
    exit 2
  fi
done

schema="${EXPORT_SCHEMA:-public}"
if [[ ! "$schema" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
  echo "EXPORT_SCHEMA contains unsupported characters." >&2
  exit 2
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output_parent="$(cd "$(dirname "$1")" && pwd)"
output_dir="$output_parent/$(basename "$1")"
if [[ "$output_dir" == *"'"* || "$output_dir" == *$'\n'* ]]; then
  echo "OUTPUT_DIR cannot contain quotes or newlines." >&2
  exit 2
fi
case "$output_dir/" in
  "$repo_root/"*)
    echo "Refusing to export database contents inside the Git repository." >&2
    exit 2
    ;;
esac

umask 077
mkdir -p "$output_dir"
if find "$output_dir" -mindepth 1 -print -quit | grep -q .; then
  echo "OUTPUT_DIR must be empty: $output_dir" >&2
  exit 2
fi

manifest_rows="$output_dir/.manifest_rows.ndjson"
table_list="$output_dir/.table_list"
export_session="$output_dir/.export.psql"
connection_service="$output_dir/.pg_service.conf"
trap 'rm -f "$manifest_rows" "$table_list" "$export_session" "$connection_service"' EXIT
: >"$manifest_rows"

DATABASE_URL="$DATABASE_URL" SERVICE_FILE="$connection_service" python3 <<'PY'
import os
import re
from urllib.parse import parse_qsl, unquote, urlparse

url = urlparse(os.environ["DATABASE_URL"])
if url.scheme not in {"postgres", "postgresql"} or not url.hostname:
    raise SystemExit("DATABASE_URL must be a PostgreSQL URI")

parameters = {
    "host": url.hostname,
    "port": str(url.port or 5432),
    "dbname": unquote(url.path.lstrip("/")) or "postgres",
}
if url.username:
    parameters["user"] = unquote(url.username)
if url.password:
    parameters["password"] = unquote(url.password)
for key, value in parse_qsl(url.query, keep_blank_values=True):
    if not re.fullmatch(r"[a-z_][a-z0-9_]*", key):
        raise SystemExit(f"Unsupported connection parameter: {key}")
    parameters[key] = value

def quote(value: str) -> str:
    if "\n" in value or "\r" in value:
        raise SystemExit("Connection parameters cannot contain newlines")
    return value.replace("\\", "\\\\").replace("'", "\\'")

with open(os.environ["SERVICE_FILE"], "w", encoding="utf-8") as service:
    service.write("[app_personal_export]\n")
    for key, value in parameters.items():
        service.write(f"{key}={quote(value)}\n")
PY

mapfile_compat() {
  while IFS= read -r line; do
    tables+=("$line")
    table_count=$((table_count + 1))
  done
}

tables=()
table_count=0
PGSERVICEFILE="$connection_service" PGSERVICE=app_personal_export \
  psql --no-psqlrc --no-password --quiet \
  --tuples-only --no-align --set=ON_ERROR_STOP=1 \
  --command="select tablename from pg_catalog.pg_tables where schemaname = '$schema' order by tablename" \
  >"$table_list"
mapfile_compat <"$table_list"

printf '%s\n' '\set ON_ERROR_STOP on' \
  'BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;' \
  '\pset format unaligned' \
  '\pset tuples_only on' >"$export_session"

for ((index = 0; index < table_count; index++)); do
  table="${tables[$index]}"
  if [[ ! "$table" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
    echo "Unsupported table name returned by Postgres: $table" >&2
    exit 1
  fi

  destination="$output_dir/$table.json"
  printf "\\o '%s'\n" "$destination" >>"$export_session"
  printf '%s\n' \
    'SELECT json_line FROM (' \
    "  SELECT 0::bigint AS sequence, '['::text AS json_line" \
    '  UNION ALL' \
    "  SELECT row_number, CASE WHEN row_number = 1 THEN payload ELSE ',' || payload END" \
    '  FROM (' \
    "    SELECT row_number() OVER () AS row_number, row_to_json(t)::text AS payload FROM \"$schema\".\"$table\" t" \
    '  ) AS rows' \
    '  UNION ALL' \
    "  SELECT 9223372036854775807::bigint, ']'::text" \
    ') AS document ORDER BY sequence;' >>"$export_session"
done

printf '%s\n' '\o' 'COMMIT;' >>"$export_session"
PGSERVICEFILE="$connection_service" PGSERVICE=app_personal_export \
  psql --no-psqlrc --no-password --quiet \
  --file="$export_session" >/dev/null

for ((index = 0; index < table_count; index++)); do
  table="${tables[$index]}"
  destination="$output_dir/$table.json"
  rows="$(jq 'length' "$destination")"
  checksum="$(shasum -a 256 "$destination" | awk '{print $1}')"
  jq -nc --arg table "$table" --arg file "$table.json" \
    --argjson rows "$rows" --arg sha256 "$checksum" \
    '{table: $table, file: $file, rows: $rows, sha256: $sha256}' \
    >>"$manifest_rows"
done

jq -s --arg exported_at "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
  --arg schema "$schema" \
  '{exported_at: $exported_at, schema: $schema, tables: .}' \
  "$manifest_rows" >"$output_dir/manifest.json"

echo "Exported $table_count tables to $output_dir."

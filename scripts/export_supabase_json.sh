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

for command in psql jq shasum; do
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
trap 'rm -f "$manifest_rows"' EXIT
: >"$manifest_rows"

mapfile_compat() {
  while IFS= read -r line; do
    tables+=("$line")
    table_count=$((table_count + 1))
  done
}

tables=()
table_count=0
mapfile_compat < <(
  psql "$DATABASE_URL" --no-psqlrc --no-password --quiet --tuples-only \
    --no-align --set=ON_ERROR_STOP=1 \
    --command="select tablename from pg_catalog.pg_tables where schemaname = '$schema' order by tablename"
)

for ((index = 0; index < table_count; index++)); do
  table="${tables[$index]}"
  if [[ ! "$table" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
    echo "Unsupported table name returned by Postgres: $table" >&2
    exit 1
  fi

  destination="$output_dir/$table.json"
  query="select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb) from \"$schema\".\"$table\" t"
  psql "$DATABASE_URL" --no-psqlrc --no-password --quiet --tuples-only \
    --no-align --set=ON_ERROR_STOP=1 --command="$query" >"$destination"

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

#!/usr/bin/env bash
set -euo pipefail

scan_root="${1:-supabase}"

if [[ ! -e "$scan_root" ]]; then
  echo "SQL scan path does not exist: $scan_root" >&2
  exit 2
fi

mapfile_compat() {
  while IFS= read -r line; do
    sql_files+=("$line")
  done
}

sql_files=()
mapfile_compat < <(find "$scan_root" -type f -name '*.sql' -print | sort)
if [[ ${#sql_files[@]} -eq 0 ]]; then
  echo "No executable SQL files found under $scan_root."
  exit 0
fi

unsafe_pattern='using[[:space:]]*\([[:space:]]*true[[:space:]]*\)|with[[:space:]]+check[[:space:]]*\([[:space:]]*true[[:space:]]*\)|(^|[[:space:]])to[[:space:]]+(public|anon)([[:space:];,]|$)|grant[[:space:]].*[[:space:]]to[[:space:]]+(public|anon)([[:space:];,]|$)'

if grep -Ein "$unsafe_pattern" "${sql_files[@]}"; then
  echo "Unsafe SQL detected. Open policies and grants to public/anon are forbidden." >&2
  exit 1
fi

echo "SQL safety scan passed (${#sql_files[@]} files)."

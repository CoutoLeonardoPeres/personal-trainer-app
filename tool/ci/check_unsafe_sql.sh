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

for sql_file in "${sql_files[@]}"; do
  if perl -0777 -e '
    my $sql = do { local $/; <> };
    $sql =~ s{/\*.*?\*/}{}gs;
    $sql =~ s{--[^\r\n]*}{}g;
    $sql =~ s{\x27(?:\x27\x27|[^\x27])*\x27}{\x27\x27}gs;
    exit 0 if $sql =~ /\busing\s*\(\s*true\s*\)/i;
    exit 0 if $sql =~ /\bwith\s+check\s*\(\s*true\s*\)/i;
    exit 0 if $sql =~ /\bto\s+"?(?:public|anon)"?\b/i;
    exit 1;
  ' "$sql_file"; then
    echo "Unsafe SQL detected in $sql_file." >&2
    echo "Open policies and grants to public/anon are forbidden." >&2
    exit 1
  fi
done

echo "SQL safety scan passed (${#sql_files[@]} files)."

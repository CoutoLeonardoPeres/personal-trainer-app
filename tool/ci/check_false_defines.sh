#!/usr/bin/env bash
set -euo pipefail

repository_mode=false
if [[ $# -eq 0 ]]; then
  repository_mode=true
fi
defines_file="${1:-dart_defines.example.json}"

if [[ "$repository_mode" == true ]]; then
  tracked_defines="$(git ls-files -- 'dart_defines*.json')"
  if [[ "$tracked_defines" != "dart_defines.example.json" ]]; then
    echo "Only dart_defines.example.json may be tracked." >&2
    exit 1
  fi
fi

if [[ ! -f "$defines_file" ]]; then
  echo "Defines example not found: $defines_file" >&2
  exit 2
fi

if ! jq -e 'type == "object" and length > 0' "$defines_file" >/dev/null; then
  echo "Defines example must be a non-empty JSON object." >&2
  exit 1
fi

if jq -e 'keys[] | test("SERVICE_ROLE|SECRET"; "i")' "$defines_file" >/dev/null; then
  echo "Backend-only key names are forbidden in client define examples." >&2
  exit 1
fi

if ! jq -e '
  has("SUPABASE_URL") and
  (has("SUPABASE_ANON_KEY") != has("SUPABASE_PUBLISHABLE_KEY")) and
  ((keys - ["SUPABASE_URL", "SUPABASE_ANON_KEY", "SUPABASE_PUBLISHABLE_KEY"]) | length == 0) and
  all(.[]; . == "false")
' "$defines_file" >/dev/null; then
  echo "Defines must contain only the required public Supabase keys set to false." >&2
  exit 1
fi

echo "Defines example contains inert values only."

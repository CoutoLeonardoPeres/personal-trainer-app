#!/usr/bin/env bash
set -euo pipefail

defines_file="${1:-dart_defines.example.json}"

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

if ! jq -e 'all(.[]; . == "false")' "$defines_file" >/dev/null; then
  echo "Every example define value must be the literal string false." >&2
  exit 1
fi

echo "Defines example contains inert values only."

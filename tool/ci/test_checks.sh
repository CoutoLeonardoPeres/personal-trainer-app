#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
sql_check="$repo_root/tool/ci/check_unsafe_sql.sh"
defines_check="$repo_root/tool/ci/check_false_defines.sh"
export_script="$repo_root/scripts/export_supabase_json.sh"
fixture_dir="$(mktemp -d)"
trap 'rm -rf "$fixture_dir"' EXIT

expect_failure() {
  if "$@" >/dev/null 2>&1; then
    echo "Expected command to fail: $*" >&2
    exit 1
  fi
}

mkdir -p "$fixture_dir/safe" "$fixture_dir/unsafe"
cat >"$fixture_dir/safe/policy.sql" <<'SQL'
-- Documentation may mention using (true) without creating an open policy.
create policy owner_only on public.students
  for select to authenticated
  using (auth.uid() = auth_user_id);
SQL
cat >"$fixture_dir/unsafe/using_true.sql" <<'SQL'
create policy open_read on public.students
  for select to authenticated
  using (
    true
  );
SQL
cat >"$fixture_dir/unsafe/check_true.sql" <<'SQL'
create policy open_write on public.students
  for insert to authenticated
  with check (
    true
  );
SQL
cat >"$fixture_dir/unsafe/quoted_anon.sql" <<'SQL'
create policy anonymous_read on public.students
  for select
  to "anon"
  using (auth.uid() = auth_user_id);
SQL

"$sql_check" "$fixture_dir/safe"
for unsafe_sql in "$fixture_dir/unsafe"/*.sql; do
  expect_failure "$sql_check" "$unsafe_sql"
done

cat >"$fixture_dir/safe.json" <<'JSON'
{
  "SUPABASE_URL": "false",
  "SUPABASE_PUBLISHABLE_KEY": "false"
}
JSON
cat >"$fixture_dir/unsafe.json" <<'JSON'
{
  "SUPABASE_URL": "https://project.supabase.co",
  "SUPABASE_ANON_KEY": "eyJhbGciOiJIUzI1NiJ9.real-looking-token"
}
JSON

"$defines_check" "$fixture_dir/safe.json"
expect_failure "$defines_check" "$fixture_dir/unsafe.json"
cat >"$fixture_dir/missing-keys.json" <<'JSON'
{
  "FOO": "false"
}
JSON
expect_failure "$defines_check" "$fixture_dir/missing-keys.json"

"$export_script" --help >/dev/null
expect_failure env -u DATABASE_URL "$export_script" "$fixture_dir/export"

mkdir -p "$fixture_dir/bin"
cat >"$fixture_dir/bin/psql" <<'SH'
#!/usr/bin/env bash
exit 0
SH
chmod +x "$fixture_dir/bin/psql"
PATH="$fixture_dir/bin:$PATH" DATABASE_URL='postgresql://local.invalid/db' \
  "$export_script" "$fixture_dir/empty-export" >/dev/null
jq -e '.schema == "public" and (.tables | length) == 0' \
  "$fixture_dir/empty-export/manifest.json" >/dev/null

cat >"$fixture_dir/bin/psql" <<'SH'
#!/usr/bin/env bash
exit 9
SH
chmod +x "$fixture_dir/bin/psql"
expect_failure env PATH="$fixture_dir/bin:$PATH" \
  DATABASE_URL='postgresql://local.invalid/db' \
  "$export_script" "$fixture_dir/failed-export"

echo "CI guard tests passed."

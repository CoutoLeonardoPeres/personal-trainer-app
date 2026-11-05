-- Archive the complete legacy public schema without deleting data.
-- Prerequisite: 01_preflight_read_only.sql passed and an external backup was verified.
-- After this file, apply migrations 0001-0007 before running 03_import_legacy.sql.

begin;

select pg_advisory_xact_lock(hashtextextended('app_personal:migration:20261105', 0));

do $archive_guard$
begin
  if to_regnamespace('legacy_20261105') is not null then
    raise exception 'ARCHIVE_ALREADY_EXISTS: schema legacy_20261105 already exists';
  end if;
  if to_regnamespace('migration_20261105') is not null then
    raise exception 'MIGRATION_SCHEMA_ALREADY_EXISTS: migration_20261105 already exists';
  end if;
  if to_regclass('public.personals') is null
     or to_regclass('public.day_workouts') is null
     or to_regclass('public.audit_logs') is null then
    raise exception 'ARCHIVE_SOURCE_INVALID: expected legacy public schema';
  end if;
end
$archive_guard$;

alter schema public rename to legacy_20261105;
create schema public authorization postgres;
comment on schema public is 'standard public schema rebuilt by migration 20261105';

-- The archived schema is rollback material, not a Data API surface.
revoke all on schema legacy_20261105 from public, anon, authenticated;
revoke all on all tables in schema legacy_20261105 from public, anon, authenticated;
revoke all on all sequences in schema legacy_20261105 from public, anon, authenticated;
revoke execute on all functions in schema legacy_20261105 from public, anon, authenticated;
grant usage on schema legacy_20261105 to service_role;
grant select on all tables in schema legacy_20261105 to service_role;

create schema migration_20261105 authorization postgres;
revoke all on schema migration_20261105 from public, anon, authenticated;

create table migration_20261105.config (
  key text primary key,
  value text not null,
  recorded_at timestamptz not null default clock_timestamp()
);

insert into migration_20261105.config (key, value)
select 'active_personal_legacy_id', id::text
from legacy_20261105.personals p
where coalesce((to_jsonb(p)->>'is_admin')::boolean, false)
  and nullif(to_jsonb(p)->>'auth_user_id', '') is not null;

insert into migration_20261105.config (key, value) values
  ('archive_schema', 'legacy_20261105'),
  ('migration_version', '20261105'),
  ('archived_at', clock_timestamp()::text);

create table migration_20261105.source_counts (
  source_schema text not null,
  source_table text not null,
  row_count bigint not null,
  recorded_at timestamptz not null default clock_timestamp(),
  primary key (source_schema, source_table)
);

do $capture_counts$
declare
  r record;
  v_count bigint;
begin
  for r in
    select tablename
    from pg_tables
    where schemaname = 'legacy_20261105'
    order by tablename
  loop
    execute format('select count(*) from legacy_20261105.%I', r.tablename)
      into v_count;
    insert into migration_20261105.source_counts
      (source_schema, source_table, row_count)
    values ('legacy_20261105', r.tablename, v_count);
  end loop;
end
$capture_counts$;

create table migration_20261105.id_map (
  source_table text not null,
  source_id text not null,
  target_table text not null,
  target_id uuid not null,
  tenant_id uuid,
  canonical_source_id text,
  primary key (source_table, source_id)
);

create table migration_20261105.row_reconciliation (
  source_table text not null,
  source_pk text not null,
  target_table text,
  target_pk text,
  tenant_id uuid,
  disposition text not null check (disposition in (
    'migrated','merged','preserved_legacy','quarantined'
  )),
  rule_code text not null,
  source_hash text,
  target_hash text,
  details jsonb not null default '{}'::jsonb,
  recorded_at timestamptz not null default clock_timestamp(),
  primary key (source_table, source_pk)
);

create table migration_20261105.table_reconciliation (
  source_table text primary key,
  source_count bigint not null,
  migrated_count bigint not null default 0,
  merged_count bigint not null default 0,
  preserved_count bigint not null default 0,
  quarantined_count bigint not null default 0,
  target_table text,
  target_count bigint,
  checked_at timestamptz not null default clock_timestamp()
);

create table migration_20261105.validation_results (
  check_name text primary key,
  passed boolean not null,
  observed bigint,
  expected bigint,
  details text,
  checked_at timestamptz not null default clock_timestamp()
);

commit;

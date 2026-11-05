begin;

select (to_regnamespace('legacy_20261105') is not null
        and to_regnamespace('migration_20261105') is not null) as migration_ready \gset

\if :migration_ready

select plan(20);

select has_schema('legacy_20261105', 'legacy schema is retained');
select has_schema('migration_20261105', 'migration evidence schema exists');

select is(
  (select count(*)::bigint from migration_20261105.source_counts),
  25::bigint,
  'all 25 legacy tables were inventoried'
);

select ok(
  not exists (select 1 from migration_20261105.validation_results where not passed),
  'all migration invariants passed'
);

select is((select count(*)::bigint from public.personals), 2::bigint, 'personals preserved');
select is((select count(*)::bigint from public.students), 7::bigint, 'students preserved');
select is((select count(*)::bigint from public.week_schedule_items), 2093::bigint, 'schedule duplicates removed');
select is((select count(*)::bigint from public.day_workout_exercises), 777::bigint, 'workout exercise duplicates removed');
select is((select count(*)::bigint from public.performed_set_events), 1257::bigint, 'set sources reconciled');

select is(
  (select count(*)::bigint from (
    select 1 from public.week_schedule_items
    group by block_id,exercise_id,sort_order having count(*) > 1
  ) duplicates),
  0::bigint,
  'schedule has no duplicate slots'
);

select is(
  (select count(*)::bigint from (
    select 1 from public.day_workout_exercises
    group by day_workout_id,exercise_id,sort_order having count(*) > 1
  ) duplicates),
  0::bigint,
  'workouts have no duplicate exercise slots'
);

select ok(
  not exists (
    select 1 from public.day_workouts
    where status not in ('programado','em_andamento','concluido','cancelado')
  ),
  'workout statuses use the new vocabulary'
);

select is(
  (select count(*)::bigint from public.workout_groups where deleted_at is not null),
  4::bigint,
  'deleted workout groups remain tombstoned'
);

select is(
  (select count(*)::bigint from public.workout_group_exercises where deleted_at is not null),
  3::bigint,
  'deleted group exercises remain tombstoned'
);

select is(
  (select count(*)::bigint from legacy_20261105.audit_logs),
  149158::bigint,
  'legacy audit history is intact'
);

select is(
  (select count(*)::bigint from public.tenant_memberships),
  1::bigint,
  'the active authenticated personal has one membership'
);

select is(
  (select count(*)::bigint from public.devices),
  1::bigint,
  'one synthetic import device owns migrated events'
);

select ok(
  not exists (
    select 1 from migration_20261105.id_map m
    left join migration_20261105.row_reconciliation r
      on r.source_table=m.source_table and r.source_pk=m.source_id
    where r.source_pk is null
  ),
  'every mapped source row has a disposition'
);

select ok(
  not exists (
    select 1 from pg_constraint c
    join pg_namespace n on n.oid=c.connamespace
    where n.nspname='public' and c.contype='f' and not c.convalidated
  ),
  'all foreign keys are validated'
);

select is(
  (select count(*)::bigint from migration_20261105.validation_results where passed),
  45::bigint,
  'all 45 production validation checks were recorded'
);

select * from finish();

\else

select plan(1);
select pass('production migration acceptance skipped on clean database');
select * from finish();

\endif

rollback;

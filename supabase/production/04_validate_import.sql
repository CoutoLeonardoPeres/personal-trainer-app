-- Post-import validation. Any failed invariant aborts this transaction.

begin isolation level repeatable read;

select pg_advisory_xact_lock(hashtextextended('app_personal:migration:20261105', 0));
truncate migration_20261105.validation_results;

do $validate$
declare
  r record;
  v_count bigint;
  v_expected bigint;
  v_failures text[] := '{}';
begin
  -- Every tenant-scoped destination row must have a tenant.
  for r in
    select table_name
    from information_schema.columns
    where table_schema='public' and column_name='tenant_id'
    order by table_name
  loop
    execute format('select count(*) from public.%I where tenant_id is null',r.table_name)
      into v_count;
    insert into migration_20261105.validation_results
      (check_name,passed,observed,expected,details)
    values ('tenant_not_null:'||r.table_name,v_count=0,v_count,0,null);
    if v_count <> 0 then v_failures := array_append(v_failures,'tenant_not_null:'||r.table_name); end if;
  end loop;

  -- All target FKs must be validated by PostgreSQL.
  select count(*) into v_count
  from pg_constraint c
  join pg_namespace n on n.oid=c.connamespace
  where n.nspname='public' and c.contype='f' and not c.convalidated;
  insert into migration_20261105.validation_results
    (check_name,passed,observed,expected,details)
  values ('foreign_keys_validated',v_count=0,v_count,0,null);
  if v_count <> 0 then v_failures := array_append(v_failures,'foreign_keys_validated'); end if;

  -- Direct one-to-one imports.
  for r in
    select * from (values
      ('personals','personals'),('students','students'),
      ('muscle_groups','muscle_groups'),('exercises','exercises'),
      ('gyms','gyms'),('training_methods','training_methods'),
      ('workout_groups','workout_groups'),('workout_group_exercises','workout_group_exercises'),
      ('week_schedule_blocks','week_schedule_blocks'),('day_workouts','day_workouts'),
      ('student_gyms','student_gyms')
    ) x(source_table,target_table)
  loop
    execute format('select count(*) from legacy_20261105.%I',r.source_table) into v_expected;
    execute format('select count(*) from public.%I',r.target_table) into v_count;
    insert into migration_20261105.validation_results
      (check_name,passed,observed,expected,details)
    values ('count:'||r.target_table,v_count=v_expected,v_count,v_expected,'direct import');
    if v_count <> v_expected then v_failures := array_append(v_failures,'count:'||r.target_table); end if;
  end loop;

  select count(*) into v_expected from (
    select 1 from legacy_20261105.week_schedule_items
    group by block_id,exercise_id,sort_order
  ) x;
  select count(*) into v_count from public.week_schedule_items;
  insert into migration_20261105.validation_results
    (check_name,passed,observed,expected,details)
  values ('count:week_schedule_items_dedup',v_count=v_expected,v_count,v_expected,
          'one newest row per block/exercise/sort');
  if v_count <> v_expected then v_failures := array_append(v_failures,'count:week_schedule_items_dedup'); end if;

  select count(*) into v_expected from (
    select 1 from legacy_20261105.day_workout_exercises
    group by day_workout_id,exercise_id,sort_order
  ) x;
  select count(*) into v_count from public.day_workout_exercises;
  insert into migration_20261105.validation_results
    (check_name,passed,observed,expected,details)
  values ('count:day_workout_exercises_dedup',v_count=v_expected,v_count,v_expected,
          'one newest row per workout/exercise/sort');
  if v_count <> v_expected then v_failures := array_append(v_failures,'count:day_workout_exercises_dedup'); end if;

  select count(distinct (tenant_id,winner_id)) into v_expected
  from migration_20261105.set_candidates where is_winner;
  select count(*) into v_count from public.performed_set_events;
  insert into migration_20261105.validation_results
    (check_name,passed,observed,expected,details)
  values ('count:performed_set_union',v_count=v_expected,v_count,v_expected,
          'union of JSON/table/event sources after content occurrence dedup');
  if v_count <> v_expected then v_failures := array_append(v_failures,'count:performed_set_union'); end if;

  -- Every imported source row represented by id_map must have one disposition.
  select count(*) into v_count
  from migration_20261105.id_map m
  left join migration_20261105.row_reconciliation rec
    on rec.source_table=m.source_table and rec.source_pk=m.source_id
  where rec.source_pk is null;
  insert into migration_20261105.validation_results
    (check_name,passed,observed,expected,details)
  values ('reconciliation:id_map_complete',v_count=0,v_count,0,null);
  if v_count <> 0 then v_failures := array_append(v_failures,'reconciliation:id_map_complete'); end if;

  select count(*) into v_count
  from migration_20261105.set_candidates c
  left join migration_20261105.row_reconciliation rec
    on rec.source_table=c.source_table and rec.source_pk=c.source_pk
  where rec.source_pk is null;
  insert into migration_20261105.validation_results
    (check_name,passed,observed,expected,details)
  values ('reconciliation:set_sources_complete',v_count=0,v_count,0,null);
  if v_count <> 0 then v_failures := array_append(v_failures,'reconciliation:set_sources_complete'); end if;

  -- No relationship may cross tenant boundaries.
  select count(*) into v_count from (
    select 1 from public.students s join public.personals p on p.id=s.created_by_personal_id
      where s.tenant_id<>p.tenant_id
    union all
    select 1 from public.exercises e join public.muscle_groups m on m.id=e.muscle_group_id
      where e.tenant_id<>m.tenant_id
    union all
    select 1 from public.week_schedule_items i join public.week_schedule_blocks b on b.id=i.block_id
      where i.tenant_id<>b.tenant_id
    union all
    select 1 from public.day_workout_exercises e join public.day_workouts w on w.id=e.day_workout_id
      where e.tenant_id<>w.tenant_id
    union all
    select 1 from public.performed_set_events e join public.day_workout_exercises d on d.id=e.day_workout_exercise_id
      where e.tenant_id<>d.tenant_id
  ) cross_tenant;
  insert into migration_20261105.validation_results
    (check_name,passed,observed,expected,details)
  values ('tenant:no_cross_tenant_relationships',v_count=0,v_count,0,null);
  if v_count <> 0 then v_failures := array_append(v_failures,'tenant:no_cross_tenant_relationships'); end if;

  -- Sensitive legacy stores must remain intact and absent from the new API schema.
  select count(*) into v_count
  from migration_20261105.source_counts sc
  where sc.source_table in (
    'audit_logs','anamnese_sessions','anamnese_answers','student_performance_reports',
    'day_workout_set_event_tombstones','day_workout_set_rest_events',
    'exercises_global','exercises_user','sync_tombstones','workout_start_events'
  )
    and not exists (
      select 1 from migration_20261105.table_reconciliation tr
      where tr.source_table=sc.source_table
        and tr.preserved_count=sc.row_count
        and tr.target_table is null
    );
  insert into migration_20261105.validation_results
    (check_name,passed,observed,expected,details)
  values ('legacy:sensitive_tables_preserved',v_count=0,v_count,0,
          'legacy-only history remains in legacy_20261105');
  if v_count <> 0 then v_failures := array_append(v_failures,'legacy:sensitive_tables_preserved'); end if;

  if array_length(v_failures,1) is not null then
    raise exception 'VALIDATION_FAILED: %',array_to_string(v_failures,', ');
  end if;
end
$validate$;

commit;

select check_name,passed,observed,expected,details
from migration_20261105.validation_results
order by check_name;

-- Production legacy -> multitenant preflight.
-- Read-only by construction. Run before 02_archive_legacy.sql.

begin isolation level repeatable read read only;

do $preflight$
declare
  v_missing text[];
  v_active_count bigint;
  v_orphans bigint;
  v_bad_status bigint;
begin
  select array_agg(required_name order by required_name)
    into v_missing
  from unnest(array[
    'personals','students','muscle_groups','exercises','gyms','student_gyms',
    'training_methods','workout_groups','workout_group_exercises',
    'week_schedule_blocks','week_schedule_items','day_workouts',
    'day_workout_exercises','day_workout_performed_sets','audit_logs'
  ]) required_name
  where to_regclass(format('public.%I', required_name)) is null;

  if v_missing is not null then
    raise exception 'PREFLIGHT_MISSING_TABLES: %', array_to_string(v_missing, ', ');
  end if;

  -- The active personal owns ownerless catalogs/groups. Exactly one admin with
  -- an Auth identity is required so that the choice is never implicit.
  select count(*) into v_active_count
  from public.personals p
  where coalesce((to_jsonb(p)->>'is_admin')::boolean, false)
    and nullif(to_jsonb(p)->>'auth_user_id', '') is not null;

  if v_active_count <> 1 then
    raise exception
      'PREFLIGHT_ACTIVE_PERSONAL: expected exactly one admin personal with auth_user_id, found %',
      v_active_count;
  end if;

  select count(*) into v_orphans
  from public.students s
  left join public.personals p on p.id = s.created_by_personal_id
  where s.created_by_personal_id is null or p.id is null;
  if v_orphans > 0 then
    raise exception 'PREFLIGHT_STUDENT_OWNER: % students have no valid personal', v_orphans;
  end if;

  select count(*) into v_orphans
  from public.exercises e
  left join public.muscle_groups mg on mg.id = e.muscle_group_id
  where mg.id is null;
  if v_orphans > 0 then
    raise exception 'PREFLIGHT_EXERCISE_MUSCLE_GROUP: % orphan exercises', v_orphans;
  end if;

  select count(*) into v_orphans
  from public.week_schedule_blocks b
  left join public.students s on s.id = b.student_id
  where s.id is null;
  if v_orphans > 0 then
    raise exception 'PREFLIGHT_WEEK_BLOCK_STUDENT: % orphan blocks', v_orphans;
  end if;

  select count(*) into v_orphans
  from public.week_schedule_items i
  left join public.week_schedule_blocks b on b.id = i.block_id
  left join public.exercises e on e.id = i.exercise_id
  where b.id is null or e.id is null;
  if v_orphans > 0 then
    raise exception 'PREFLIGHT_WEEK_ITEM_PARENT: % orphan items', v_orphans;
  end if;

  select count(*) into v_orphans
  from public.day_workouts w
  left join public.students s on s.id = w.student_id
  where s.id is null;
  if v_orphans > 0 then
    raise exception 'PREFLIGHT_DAY_WORKOUT_STUDENT: % orphan workouts', v_orphans;
  end if;

  select count(*) into v_orphans
  from public.day_workout_exercises d
  left join public.day_workouts w on w.id = d.day_workout_id
  left join public.exercises e on e.id = d.exercise_id
  where w.id is null or e.id is null;
  if v_orphans > 0 then
    raise exception 'PREFLIGHT_DAY_EXERCISE_PARENT: % orphan workout exercises', v_orphans;
  end if;

  select count(*) into v_orphans
  from public.day_workout_performed_sets s
  left join public.day_workout_exercises d on d.id = s.day_workout_exercise_id
  where d.id is null;
  if v_orphans > 0 then
    raise exception 'PREFLIGHT_PERFORMED_SET_PARENT: % orphan sets', v_orphans;
  end if;

  select count(*) into v_bad_status
  from public.day_workouts
  where lower(status) not in (
    'scheduled','programmed','started','completed','cancelled',
    'programado','em_andamento','concluido','cancelado'
  );
  if v_bad_status > 0 then
    raise exception 'PREFLIGHT_WORKOUT_STATUS: % unsupported statuses', v_bad_status;
  end if;
end
$preflight$;

-- Inventory returned to the operator and suitable for saving with the backup.
select t.table_name,
       (xpath('/row/c/text()', query_to_xml(
          format('select count(*) c from public.%I', t.table_name),
          false, true, ''
       )))[1]::text::bigint as row_count
from information_schema.tables t
where t.table_schema = 'public' and t.table_type = 'BASE TABLE'
order by t.table_name;

select
  (select id from public.personals
   where coalesce((to_jsonb(personals)->>'is_admin')::boolean, false)
     and nullif(to_jsonb(personals)->>'auth_user_id', '') is not null) as active_personal_id,
  (select count(*) from public.personals) as personals,
  (select count(*) from public.students) as students,
  (select count(*) from public.week_schedule_items) as week_items_before_dedup,
  (select count(*) from (
     select row_number() over (
       partition by block_id, exercise_id, sort_order
       order by updated_at desc nulls last, id desc
     ) rn
     from public.week_schedule_items
   ) x where rn > 1) as duplicate_week_items,
  (select count(*) from (
     select row_number() over (
       partition by day_workout_id, exercise_id, sort_order
       order by updated_at desc nulls last, id desc
     ) rn
     from public.day_workout_exercises
   ) x where rn > 1) as duplicate_day_exercises,
  (select count(*) from public.day_workout_performed_sets) as performed_set_rows,
  (select count(*) from public.audit_logs) as legacy_audit_rows;

commit;

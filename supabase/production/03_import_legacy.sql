-- Import legacy_20261105 into the schema created by migrations 0001-0007.
-- This script is atomic: any ambiguity or FK violation rolls the whole import back.

begin;

select pg_advisory_xact_lock(hashtextextended('app_personal:migration:20261105', 0));
set local statement_timeout = '30min';

do $import_guard$
declare v_nonempty bigint;
begin
  if to_regnamespace('legacy_20261105') is null
     or to_regnamespace('migration_20261105') is null then
    raise exception 'IMPORT_ARCHIVE_MISSING';
  end if;
  if to_regclass('public.tenant_memberships') is null
     or to_regclass('public.performed_set_events') is null then
    raise exception 'IMPORT_TARGET_MISSING: apply migrations 0001-0007 first';
  end if;
  select count(*) into v_nonempty from public.personals;
  if v_nonempty <> 0 then
    raise exception 'IMPORT_TARGET_NOT_EMPTY: public.personals contains % rows', v_nonempty;
  end if;
end
$import_guard$;

create or replace function migration_20261105.to_uuid(p_namespace text, p_value text)
returns uuid
language plpgsql immutable strict set search_path = ''
as $fn$
declare h text;
begin
  if lower(p_value) ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' then
    return lower(p_value)::uuid;
  end if;
  h := md5(p_namespace || ':' || p_value);
  return (substr(h,1,8)||'-'||substr(h,9,4)||'-5'||substr(h,14,3)||
          '-8'||substr(h,18,3)||'-'||substr(h,21,12))::uuid;
end
$fn$;

create or replace function migration_20261105.safe_uuid(p_value text)
returns uuid
language plpgsql immutable set search_path = ''
as $fn$
begin
  if nullif(btrim(p_value), '') is null then return null; end if;
  return p_value::uuid;
exception when invalid_text_representation then return null;
end
$fn$;

create or replace function migration_20261105.safe_jsonb(p_value text)
returns jsonb
language plpgsql immutable set search_path = ''
as $fn$
begin
  if nullif(btrim(p_value), '') is null then return null; end if;
  return p_value::jsonb;
exception when others then return null;
end
$fn$;

create or replace function migration_20261105.safe_timestamptz(p_value text)
returns timestamptz
language plpgsql immutable set search_path = ''
as $fn$
begin
  if nullif(btrim(p_value), '') is null then return null; end if;
  return p_value::timestamptz;
exception when others then return null;
end
$fn$;

create or replace function migration_20261105.safe_bigint(p_value text)
returns bigint
language plpgsql immutable set search_path = ''
as $fn$
begin
  if nullif(btrim(p_value), '') is null then return null; end if;
  return p_value::bigint;
exception when others then return null;
end
$fn$;

create or replace function migration_20261105.hlc(p_at timestamptz, p_key text)
returns text
language sql immutable set search_path = ''
as $fn$
  select lpad((extract(epoch from coalesce(p_at, '2000-01-01'::timestamptz))*1000)::bigint::text,15,'0')
         ||'-00000-'||md5(coalesce(p_key,''))
$fn$;

create or replace function migration_20261105.active_personal_id()
returns text
language sql stable set search_path = ''
as $fn$
  select value from migration_20261105.config where key='active_personal_legacy_id'
$fn$;

-- Stable identity and tenant maps.
insert into migration_20261105.id_map
  (source_table,source_id,target_table,target_id,tenant_id,canonical_source_id)
select 'personals', p.id::text, 'personals',
       migration_20261105.to_uuid('personals',p.id::text),
       migration_20261105.to_uuid('personals',p.id::text), p.id::text
from legacy_20261105.personals p;

insert into migration_20261105.id_map
  (source_table,source_id,target_table,target_id,tenant_id,canonical_source_id)
select 'students', s.id::text, 'students',
       migration_20261105.to_uuid('students',s.id::text), pm.target_id, s.id::text
from legacy_20261105.students s
join migration_20261105.id_map pm
  on pm.source_table='personals' and pm.source_id=s.created_by_personal_id::text;

-- A source row with no owner is assigned to the explicitly selected active personal.
insert into migration_20261105.id_map
  (source_table,source_id,target_table,target_id,tenant_id,canonical_source_id)
select src.table_name, src.id, src.table_name,
       migration_20261105.to_uuid(src.table_name,src.id), active.target_id, src.id
from (
  select 'muscle_groups' table_name,id::text id from legacy_20261105.muscle_groups
  union all select 'exercises',id::text from legacy_20261105.exercises
  union all select 'gyms',id::text from legacy_20261105.gyms
  union all select 'training_methods',id::text from legacy_20261105.training_methods
) src
cross join migration_20261105.id_map active
where active.source_table='personals'
  and active.source_id=migration_20261105.active_personal_id();

insert into migration_20261105.id_map
  (source_table,source_id,target_table,target_id,tenant_id,canonical_source_id)
select 'workout_groups',g.id::text,'workout_groups',
       migration_20261105.to_uuid('workout_groups',g.id::text),
       coalesce(owner.target_id,active.target_id),g.id::text
from legacy_20261105.workout_groups g
left join migration_20261105.id_map owner
  on owner.source_table='personals'
 and owner.source_id=nullif(to_jsonb(g)->>'created_by_personal_id','')
cross join migration_20261105.id_map active
where active.source_table='personals'
  and active.source_id=migration_20261105.active_personal_id();

-- Base entities.
insert into public.personals
  (id,tenant_id,name,cpf,professional_registry,street,number,complement,city,state_uf,
   cep,email,phone_commercial,phone_mobile,must_change_password,auth_user_id,is_admin,
   access_tier,max_students_cap,field_hlc,created_hlc)
select m.target_id,m.tenant_id,j->>'name',j->>'cpf',j->>'professional_registry',j->>'street',
       j->>'number',j->>'complement',j->>'city',j->>'state_uf',j->>'cep',j->>'email',
       j->>'phone_commercial',j->>'phone_mobile',coalesce((j->>'must_change_password')::boolean,true),
       migration_20261105.safe_uuid(j->>'auth_user_id'),coalesce((j->>'is_admin')::boolean,false),
       coalesce(j->>'access_tier','legacy'),nullif(j->>'max_students_cap','')::integer,
       '{}'::jsonb,migration_20261105.hlc(
         coalesce(migration_20261105.safe_timestamptz(j->>'created_at'),clock_timestamp()),m.source_id)
from legacy_20261105.personals p
cross join lateral (select to_jsonb(p) j) x
join migration_20261105.id_map m on m.source_table='personals' and m.source_id=p.id::text;

insert into public.tenant_memberships (user_id,tenant_id,role_name,has_full_org_access)
select auth_user_id,tenant_id,
       case when coalesce(is_admin,false) then 'org_admin' else 'personal' end,
       coalesce(is_admin,false)
from public.personals where auth_user_id is not null;

insert into public.tenant_counters (tenant_id,last_seq)
select tenant_id,0 from public.personals on conflict do nothing;

insert into public.students
  (id,tenant_id,name,is_archived,archived_at,email,goal,cpf,birth_date,street,number,
   complement,district,city,state_uf,cep,phone_commercial,phone_mobile,must_change_password,
   auth_user_id,created_by_personal_id,anamnese_completed,access_tier,premium_plan_expires_at,
   field_hlc,created_hlc,deleted_at,deleted_hlc)
select m.target_id,m.tenant_id,j->>'name',coalesce((j->>'is_archived')::boolean,false),
       migration_20261105.safe_timestamptz(j->>'archived_at'),j->>'email',j->>'goal',j->>'cpf',
       (migration_20261105.safe_timestamptz(j->>'birth_date'))::date,j->>'street',j->>'number',
       j->>'complement',j->>'district',j->>'city',j->>'state_uf',j->>'cep',
       j->>'phone_commercial',j->>'phone_mobile',coalesce((j->>'must_change_password')::boolean,true),
       migration_20261105.safe_uuid(j->>'auth_user_id'),owner.target_id,
       coalesce((j->>'anamnese_completed')::boolean,true),coalesce(j->>'access_tier','legacy'),
       migration_20261105.safe_timestamptz(j->>'premium_plan_expires_at'),'{}'::jsonb,
       migration_20261105.hlc(coalesce(migration_20261105.safe_timestamptz(j->>'created_at'),clock_timestamp()),m.source_id),
       migration_20261105.safe_timestamptz(j->>'deleted_at'),
       case when nullif(j->>'deleted_at','') is null then null else
         migration_20261105.hlc(migration_20261105.safe_timestamptz(j->>'deleted_at'),m.source_id||':deleted') end
from legacy_20261105.students s
cross join lateral (select to_jsonb(s) j) x
join migration_20261105.id_map m on m.source_table='students' and m.source_id=s.id::text
join migration_20261105.id_map owner
  on owner.source_table='personals' and owner.source_id=s.created_by_personal_id::text;

insert into public.tenant_memberships (user_id,tenant_id,role_name,student_id)
select auth_user_id,tenant_id,'student',id from public.students where auth_user_id is not null
on conflict (user_id,tenant_id) do update set role_name='student',student_id=excluded.student_id;

insert into public.muscle_groups (id,tenant_id,name,field_hlc,created_hlc)
select m.target_id,m.tenant_id,p.name,'{}',migration_20261105.hlc(
  coalesce(migration_20261105.safe_timestamptz(to_jsonb(p)->>'created_at'),clock_timestamp()),m.source_id)
from legacy_20261105.muscle_groups p join migration_20261105.id_map m
  on m.source_table='muscle_groups' and m.source_id=p.id::text;

insert into public.exercises
  (id,tenant_id,name,muscle_group_id,video_url,alternative_note,alternative_video_url,field_hlc,created_hlc)
select m.target_id,m.tenant_id,p.name,mg.target_id,j->>'video_url',j->>'alternative_note',
       j->>'alternative_video_url','{}',migration_20261105.hlc(
         coalesce(migration_20261105.safe_timestamptz(j->>'created_at'),clock_timestamp()),m.source_id)
from legacy_20261105.exercises p cross join lateral (select to_jsonb(p) j) x
join migration_20261105.id_map m on m.source_table='exercises' and m.source_id=p.id::text
join migration_20261105.id_map mg on mg.source_table='muscle_groups' and mg.source_id=p.muscle_group_id::text;

insert into public.gyms
  (id,tenant_id,name,cnpj,street,number,complement,district,city,state_uf,cep,field_hlc,created_hlc)
select m.target_id,m.tenant_id,j->>'name',j->>'cnpj',j->>'street',j->>'number',j->>'complement',
       j->>'district',j->>'city',j->>'state_uf',j->>'cep','{}',migration_20261105.hlc(
         coalesce(migration_20261105.safe_timestamptz(j->>'created_at'),clock_timestamp()),m.source_id)
from legacy_20261105.gyms p cross join lateral (select to_jsonb(p) j) x
join migration_20261105.id_map m on m.source_table='gyms' and m.source_id=p.id::text;

insert into public.training_methods (id,tenant_id,method,description,field_hlc,created_hlc)
select m.target_id,m.tenant_id,p.method,p.description,'{}',migration_20261105.hlc(
  coalesce(migration_20261105.safe_timestamptz(to_jsonb(p)->>'created_at'),clock_timestamp()),m.source_id)
from legacy_20261105.training_methods p join migration_20261105.id_map m
  on m.source_table='training_methods' and m.source_id=p.id::text;

insert into public.workout_groups
  (id,tenant_id,name,description,created_by_personal_id,is_shared,field_hlc,created_hlc,deleted_at,deleted_hlc)
select m.target_id,m.tenant_id,j->>'name',j->>'description',coalesce(owner.target_id,active.target_id),
       coalesce((j->>'is_shared')::boolean,false),'{}',migration_20261105.hlc(
         coalesce(migration_20261105.safe_timestamptz(j->>'created_at'),clock_timestamp()),m.source_id),
       migration_20261105.safe_timestamptz(j->>'deleted_at'),
       case when nullif(j->>'deleted_at','') is null then null else
         migration_20261105.hlc(migration_20261105.safe_timestamptz(j->>'deleted_at'),m.source_id||':deleted') end
from legacy_20261105.workout_groups p cross join lateral (select to_jsonb(p) j) x
join migration_20261105.id_map m on m.source_table='workout_groups' and m.source_id=p.id::text
left join migration_20261105.id_map owner
  on owner.source_table='personals' and owner.source_id=nullif(j->>'created_by_personal_id','')
cross join migration_20261105.id_map active
where active.source_table='personals' and active.source_id=migration_20261105.active_personal_id();

-- Link tables and workout group contents.
insert into public.student_gyms (id,tenant_id,student_id,gym_id,field_hlc,created_hlc)
select migration_20261105.to_uuid('student_gyms',s.student_id::text||':'||s.gym_id::text),
       sm.tenant_id,sm.target_id,gm.target_id,'{}',migration_20261105.hlc(clock_timestamp(),s.student_id::text||':'||s.gym_id::text)
from legacy_20261105.student_gyms s
join migration_20261105.id_map sm on sm.source_table='students' and sm.source_id=s.student_id::text
join migration_20261105.id_map gm on gm.source_table='gyms' and gm.source_id=s.gym_id::text;

insert into public.workout_group_exercises
  (id,tenant_id,workout_group_id,exercise_id,position,sort_order,last_load_kg,last_reps,
   last_reps_text,last_sets,rest_between_sets_sec,training_method_id,combo_id,field_hlc,created_hlc,
   deleted_at,deleted_hlc)
select migration_20261105.to_uuid('workout_group_exercises',p.id::text),gm.tenant_id,gm.target_id,em.target_id,
       j->>'position',coalesce((j->>'sort_order')::integer,0),nullif(j->>'last_load_kg','')::numeric,
       nullif(j->>'last_reps','')::integer,j->>'last_reps_text',nullif(j->>'last_sets','')::integer,
       coalesce(nullif(j->>'rest_between_sets_sec','')::integer,60),tm.target_id,
       case when nullif(j->>'combo_id','') is null then null else migration_20261105.to_uuid('combo',j->>'combo_id') end,
       '{}',migration_20261105.hlc(
         coalesce(migration_20261105.safe_timestamptz(j->>'updated_at'),clock_timestamp()),p.id::text),
       migration_20261105.safe_timestamptz(j->>'deleted_at'),
       case when nullif(j->>'deleted_at','') is null then null else
         migration_20261105.hlc(
           migration_20261105.safe_timestamptz(j->>'deleted_at'),p.id::text||':deleted')
       end
from legacy_20261105.workout_group_exercises p cross join lateral (select to_jsonb(p) j) x
join migration_20261105.id_map gm on gm.source_table='workout_groups' and gm.source_id=p.workout_group_id::text
join migration_20261105.id_map em on em.source_table='exercises' and em.source_id=p.exercise_id::text
left join migration_20261105.id_map tm on tm.source_table='training_methods' and tm.source_id=nullif(j->>'training_method_id','');

insert into migration_20261105.id_map
  (source_table,source_id,target_table,target_id,tenant_id,canonical_source_id)
select 'week_schedule_blocks',b.id::text,'week_schedule_blocks',
       migration_20261105.to_uuid('week_schedule_blocks',b.id::text),sm.tenant_id,b.id::text
from legacy_20261105.week_schedule_blocks b join migration_20261105.id_map sm
  on sm.source_table='students' and sm.source_id=b.student_id::text;

insert into public.week_schedule_blocks (id,tenant_id,student_id,week_start_monday,field_hlc,created_hlc)
select m.target_id,m.tenant_id,sm.target_id,(b.week_start_monday)::date,'{}',migration_20261105.hlc(
  coalesce(migration_20261105.safe_timestamptz(to_jsonb(b)->>'created_at'),clock_timestamp()),m.source_id)
from legacy_20261105.week_schedule_blocks b
join migration_20261105.id_map m on m.source_table='week_schedule_blocks' and m.source_id=b.id::text
join migration_20261105.id_map sm on sm.source_table='students' and sm.source_id=b.student_id::text;

-- Keep the newest item per block/exercise/sort and map every duplicate to the winner.
with ranked as (
  select i.*,
         first_value(i.id::text) over (
           partition by i.block_id,i.exercise_id,i.sort_order
           order by i.updated_at desc nulls last,i.id desc
         ) winner_id
  from legacy_20261105.week_schedule_items i
)
insert into migration_20261105.id_map
  (source_table,source_id,target_table,target_id,tenant_id,canonical_source_id)
select 'week_schedule_items',r.id::text,'week_schedule_items',
       migration_20261105.to_uuid('week_schedule_items',r.winner_id),bm.tenant_id,r.winner_id
from ranked r join migration_20261105.id_map bm
  on bm.source_table='week_schedule_blocks' and bm.source_id=r.block_id::text;

insert into public.week_schedule_items
  (id,tenant_id,block_id,exercise_id,source_workout_group_id,position,sort_order,sets,reps,
   reps_text,load_kg,needs_detail,rest_between_sets_sec,training_method_id,combo_id,field_hlc,created_hlc)
select distinct on (m.target_id) m.target_id,m.tenant_id,bm.target_id,em.target_id,gm.target_id,j->>'position',
       coalesce((j->>'sort_order')::integer,0),coalesce((j->>'sets')::integer,0),coalesce((j->>'reps')::integer,0),
       j->>'reps_text',nullif(j->>'load_kg','')::numeric,coalesce((j->>'needs_detail')::boolean,false),
       coalesce(nullif(j->>'rest_between_sets_sec','')::integer,60),tm.target_id,
       case when nullif(j->>'combo_id','') is null then null else migration_20261105.to_uuid('combo',j->>'combo_id') end,
       '{}',migration_20261105.hlc(coalesce(migration_20261105.safe_timestamptz(j->>'updated_at'),clock_timestamp()),m.source_id)
from legacy_20261105.week_schedule_items p cross join lateral (select to_jsonb(p) j) x
join migration_20261105.id_map m on m.source_table='week_schedule_items' and m.source_id=p.id::text
join migration_20261105.id_map bm on bm.source_table='week_schedule_blocks' and bm.source_id=p.block_id::text
join migration_20261105.id_map em on em.source_table='exercises' and em.source_id=p.exercise_id::text
left join migration_20261105.id_map gm on gm.source_table='workout_groups' and gm.source_id=nullif(j->>'source_workout_group_id','')
left join migration_20261105.id_map tm on tm.source_table='training_methods' and tm.source_id=nullif(j->>'training_method_id','')
order by m.target_id,migration_20261105.safe_timestamptz(j->>'updated_at') desc nulls last,p.id desc;

-- Workouts and deduplicated workout exercises.
insert into migration_20261105.id_map
  (source_table,source_id,target_table,target_id,tenant_id,canonical_source_id)
select 'day_workouts',w.id::text,'day_workouts',migration_20261105.to_uuid('day_workouts',w.id::text),
       sm.tenant_id,w.id::text
from legacy_20261105.day_workouts w join migration_20261105.id_map sm
  on sm.source_table='students' and sm.source_id=w.student_id::text;

insert into public.day_workouts
  (id,tenant_id,student_id,day_date,status,week_item_id,active_duration_seconds,workout_score,
   started_at,completed_at,timer_resume_at,source_workout_group_id,watch_calories_kcal,
   watch_avg_heart_rate_bpm,field_hlc,created_hlc,deleted_at,deleted_hlc)
select m.target_id,m.tenant_id,sm.target_id,(w.day_date)::date,
       case lower(w.status) when 'scheduled' then 'programado' when 'programmed' then 'programado'
         when 'started' then 'em_andamento' when 'completed' then 'concluido'
         when 'cancelled' then 'cancelado' else lower(w.status) end,
       wi.target_id,coalesce((j->>'active_duration_seconds')::integer,0),nullif(j->>'workout_score','')::numeric,
       migration_20261105.safe_timestamptz(j->>'started_at'),migration_20261105.safe_timestamptz(j->>'completed_at'),
       migration_20261105.safe_timestamptz(j->>'timer_resume_at'),gm.target_id,
       nullif(j->>'watch_calories_kcal','')::numeric,nullif(j->>'watch_avg_heart_rate_bpm','')::integer,
       '{}',migration_20261105.hlc(coalesce(migration_20261105.safe_timestamptz(j->>'created_at'),clock_timestamp()),m.source_id),
       migration_20261105.safe_timestamptz(j->>'deleted_at'),
       case when nullif(j->>'deleted_at','') is null then null else migration_20261105.hlc(
         migration_20261105.safe_timestamptz(j->>'deleted_at'),m.source_id||':deleted') end
from legacy_20261105.day_workouts w cross join lateral (select to_jsonb(w) j) x
join migration_20261105.id_map m on m.source_table='day_workouts' and m.source_id=w.id::text
join migration_20261105.id_map sm on sm.source_table='students' and sm.source_id=w.student_id::text
left join migration_20261105.id_map wi on wi.source_table='week_schedule_items' and wi.source_id=nullif(j->>'week_item_id','')
left join migration_20261105.id_map gm on gm.source_table='workout_groups' and gm.source_id=nullif(j->>'source_workout_group_id','');

with ranked as (
  select d.*,
         first_value(d.id::text) over (
           partition by d.day_workout_id,d.exercise_id,d.sort_order
           order by d.updated_at desc nulls last,d.id desc
         ) winner_id
  from legacy_20261105.day_workout_exercises d
)
insert into migration_20261105.id_map
  (source_table,source_id,target_table,target_id,tenant_id,canonical_source_id)
select 'day_workout_exercises',r.id::text,'day_workout_exercises',
       migration_20261105.to_uuid('day_workout_exercises',r.winner_id),wm.tenant_id,r.winner_id
from ranked r join migration_20261105.id_map wm
  on wm.source_table='day_workouts' and wm.source_id=r.day_workout_id::text;

insert into public.day_workout_exercises
  (id,tenant_id,day_workout_id,exercise_id,position,sort_order,sets,reps,reps_text,load_kg,
   exercise_score,rest_between_sets_sec,training_method_id,combo_id,field_hlc,created_hlc,
   deleted_at,deleted_hlc)
select distinct on (m.target_id) m.target_id,m.tenant_id,wm.target_id,em.target_id,j->>'position',
       coalesce((j->>'sort_order')::integer,0),coalesce((j->>'sets')::integer,0),
       coalesce((j->>'reps')::integer,0),j->>'reps_text',nullif(j->>'load_kg','')::numeric,
       nullif(j->>'exercise_score','')::numeric,coalesce(nullif(j->>'rest_between_sets_sec','')::integer,60),
       tm.target_id,case when nullif(j->>'combo_id','') is null then null else
         migration_20261105.to_uuid('combo',j->>'combo_id') end,'{}',
       migration_20261105.hlc(coalesce(migration_20261105.safe_timestamptz(j->>'updated_at'),clock_timestamp()),m.source_id),
       migration_20261105.safe_timestamptz(j->>'deleted_at'),
       case when nullif(j->>'deleted_at','') is null then null else migration_20261105.hlc(
         migration_20261105.safe_timestamptz(j->>'deleted_at'),m.source_id||':deleted') end
from legacy_20261105.day_workout_exercises p cross join lateral (select to_jsonb(p) j) x
join migration_20261105.id_map m on m.source_table='day_workout_exercises' and m.source_id=p.id::text
join migration_20261105.id_map wm on wm.source_table='day_workouts' and wm.source_id=p.day_workout_id::text
join migration_20261105.id_map em on em.source_table='exercises' and em.source_id=p.exercise_id::text
left join migration_20261105.id_map tm on tm.source_table='training_methods' and tm.source_id=nullif(j->>'training_method_id','')
order by m.target_id,migration_20261105.safe_timestamptz(j->>'updated_at') desc nulls last,p.id desc;

-- A synthetic, non-client device identifies imported append-only events.
insert into public.devices (id,user_id,tenant_id,platform,last_seen_at)
select migration_20261105.to_uuid('migration_device',p.tenant_id::text),p.auth_user_id,p.tenant_id,'ios',clock_timestamp()
from public.personals p
where p.auth_user_id is not null
  and exists (select 1 from public.students s where s.tenant_id=p.tenant_id)
on conflict (id) do nothing;

create table migration_20261105.set_candidates (
  source_table text not null,
  source_pk text not null,
  source_priority integer not null,
  tenant_id uuid not null,
  line_id uuid not null,
  student_id uuid not null,
  candidate_id uuid not null,
  reps integer,
  load_kg numeric,
  logged_at_ms bigint,
  source_hash text not null,
  content_hash text,
  source_occurrence bigint,
  winner_id uuid,
  is_winner boolean,
  primary key (source_table,source_pk)
);

insert into migration_20261105.set_candidates
  (source_table,source_pk,source_priority,tenant_id,line_id,student_id,candidate_id,reps,load_kg,logged_at_ms,source_hash)
select 'day_workout_performed_sets',s.id::text,1,lm.tenant_id,lm.target_id,w.student_id,
       migration_20261105.to_uuid('performed_set_events',s.id::text),
       nullif(j->>'reps','')::integer,nullif(j->>'load_kg','')::numeric,
       migration_20261105.safe_bigint(j->>'logged_at_ms'),md5(j::text)
from legacy_20261105.day_workout_performed_sets s cross join lateral (select to_jsonb(s) j) x
join migration_20261105.id_map lm on lm.source_table='day_workout_exercises' and lm.source_id=s.day_workout_exercise_id::text
join public.day_workout_exercises d on d.id=lm.target_id and d.tenant_id=lm.tenant_id
join public.day_workouts w on w.id=d.day_workout_id and w.tenant_id=d.tenant_id;

insert into migration_20261105.set_candidates
  (source_table,source_pk,source_priority,tenant_id,line_id,student_id,candidate_id,reps,load_kg,logged_at_ms,source_hash)
select 'day_workout_set_events',coalesce(j->>'event_id',j->>'id'),2,lm.tenant_id,lm.target_id,w.student_id,
       migration_20261105.to_uuid('performed_set_events',coalesce(j->>'event_id',j->>'id')),
       nullif(j->>'reps','')::integer,nullif(j->>'load_kg','')::numeric,
       migration_20261105.safe_bigint(j->>'logged_at_ms'),md5(j::text)
from legacy_20261105.day_workout_set_events s cross join lateral (select to_jsonb(s) j) x
join lateral (
  select candidate.*
  from (
    select lm.*,0 priority,null::timestamptz source_updated_at
    from migration_20261105.id_map lm
    where lm.source_table='day_workout_exercises'
      and lm.source_id=nullif(j->>'day_workout_exercise_id','')
    union all
    select lm.*,1 priority,migration_20261105.safe_timestamptz(to_jsonb(d)->>'updated_at') source_updated_at
    from legacy_20261105.day_workout_exercises d
    join migration_20261105.id_map lm
      on lm.source_table='day_workout_exercises' and lm.source_id=d.id::text
    where d.day_workout_id::text=j->>'day_workout_id'
      and d.exercise_id::text=j->>'exercise_id'
  ) candidate
  order by priority,source_updated_at desc nulls last,source_id desc
  limit 1
) lm on true
join public.day_workout_exercises d on d.id=lm.target_id and d.tenant_id=lm.tenant_id
join public.day_workouts w on w.id=d.day_workout_id and w.tenant_id=d.tenant_id;

insert into migration_20261105.set_candidates
  (source_table,source_pk,source_priority,tenant_id,line_id,student_id,candidate_id,reps,load_kg,logged_at_ms,source_hash)
select 'performed_sets_json',d.id::text||':'||a.ordinality,3,lm.tenant_id,lm.target_id,w.student_id,
       migration_20261105.to_uuid('performed_set_events',
         coalesce(nullif(a.value->>'setId',''),d.id::text||':json:'||a.ordinality)),
       nullif(a.value->>'reps','')::integer,nullif(a.value->>'loadKg','')::numeric,
       migration_20261105.safe_bigint(a.value->>'loggedAtMs'),md5(a.value::text)
from legacy_20261105.day_workout_exercises d
join migration_20261105.id_map lm on lm.source_table='day_workout_exercises' and lm.source_id=d.id::text
join public.day_workout_exercises target_d on target_d.id=lm.target_id and target_d.tenant_id=lm.tenant_id
join public.day_workouts w on w.id=target_d.day_workout_id and w.tenant_id=target_d.tenant_id
cross join lateral jsonb_array_elements(
  case when jsonb_typeof(migration_20261105.safe_jsonb(to_jsonb(d)->>'performed_sets_json'))='array'
       then migration_20261105.safe_jsonb(to_jsonb(d)->>'performed_sets_json') else '[]'::jsonb end
) with ordinality a(value,ordinality)
where nullif(a.value->>'reps','') is not null;

with numbered as (
  select ctid,
         md5(line_id::text||':'||coalesce(reps::text,'')||':'||coalesce(load_kg::text,'')||':'||coalesce(logged_at_ms::text,'')) h
  from migration_20261105.set_candidates
), resolved as (
  select ctid,h,1::bigint occurrence,
         first_value(candidate_id) over (
           partition by tenant_id,h order by source_priority,source_table,source_pk
         ) winner,
         row_number() over (
           partition by tenant_id,h order by source_priority,source_table,source_pk
         ) rn
  from migration_20261105.set_candidates c
  join numbered n on n.ctid=c.ctid
)
update migration_20261105.set_candidates c
set content_hash=r.h,source_occurrence=r.occurrence,winner_id=r.winner,is_winner=(r.rn=1)
from resolved r where c.ctid=r.ctid;

with final_winners as (
  select distinct on (tenant_id,winner_id) c.*
  from migration_20261105.set_candidates c
  where c.is_winner
  order by tenant_id,winner_id,source_priority,source_table,source_pk
), sequenced as (
  select c.*,row_number() over (partition by c.tenant_id order by c.logged_at_ms nulls last,c.winner_id) server_seq
  from final_winners c
)
insert into public.performed_set_events
  (id,tenant_id,day_workout_exercise_id,student_id,kind,reps,load_kg,hlc,origin_device,device_seq,server_seq)
select winner_id,tenant_id,line_id,student_id,'logged',reps,load_kg,
       lpad(coalesce(logged_at_ms,0)::text,15,'0')||'-00000-'||replace(
         migration_20261105.to_uuid('migration_device',tenant_id::text)::text,'-',''),
       migration_20261105.to_uuid('migration_device',tenant_id::text),server_seq,server_seq
from sequenced;

update public.tenant_counters tc
set last_seq=coalesce(x.max_seq,0)
from (select tenant_id,max(server_seq) max_seq from public.performed_set_events group by tenant_id) x
where tc.tenant_id=x.tenant_id;

-- Reconciliation: direct entities, deduplicated rows, event sources and retained-only data.
insert into migration_20261105.row_reconciliation
  (source_table,source_pk,target_table,target_pk,tenant_id,disposition,rule_code,source_hash,target_hash)
select m.source_table,m.source_id,m.target_table,m.target_id::text,m.tenant_id,
       case when m.source_id=m.canonical_source_id then 'migrated' else 'merged' end,
       case when m.source_id=m.canonical_source_id then 'DIRECT_OR_CANONICAL' else 'DEDUP_LATEST_UPDATED' end,
       md5(src.payload::text),md5(dst.payload::text)
from migration_20261105.id_map m
join lateral (
  select case m.source_table
    when 'personals' then (select to_jsonb(x) from legacy_20261105.personals x where x.id::text=m.source_id)
    when 'students' then (select to_jsonb(x) from legacy_20261105.students x where x.id::text=m.source_id)
    when 'muscle_groups' then (select to_jsonb(x) from legacy_20261105.muscle_groups x where x.id::text=m.source_id)
    when 'exercises' then (select to_jsonb(x) from legacy_20261105.exercises x where x.id::text=m.source_id)
    when 'gyms' then (select to_jsonb(x) from legacy_20261105.gyms x where x.id::text=m.source_id)
    when 'training_methods' then (select to_jsonb(x) from legacy_20261105.training_methods x where x.id::text=m.source_id)
    when 'workout_groups' then (select to_jsonb(x) from legacy_20261105.workout_groups x where x.id::text=m.source_id)
    when 'week_schedule_blocks' then (select to_jsonb(x) from legacy_20261105.week_schedule_blocks x where x.id::text=m.source_id)
    when 'week_schedule_items' then (select to_jsonb(x) from legacy_20261105.week_schedule_items x where x.id::text=m.source_id)
    when 'day_workouts' then (select to_jsonb(x) from legacy_20261105.day_workouts x where x.id::text=m.source_id)
    when 'day_workout_exercises' then (select to_jsonb(x) from legacy_20261105.day_workout_exercises x where x.id::text=m.source_id)
  end payload
) src on src.payload is not null
join lateral (
  select case m.target_table
    when 'personals' then (select to_jsonb(x) from public.personals x where x.id=m.target_id)
    when 'students' then (select to_jsonb(x) from public.students x where x.id=m.target_id)
    when 'muscle_groups' then (select to_jsonb(x) from public.muscle_groups x where x.id=m.target_id)
    when 'exercises' then (select to_jsonb(x) from public.exercises x where x.id=m.target_id)
    when 'gyms' then (select to_jsonb(x) from public.gyms x where x.id=m.target_id)
    when 'training_methods' then (select to_jsonb(x) from public.training_methods x where x.id=m.target_id)
    when 'workout_groups' then (select to_jsonb(x) from public.workout_groups x where x.id=m.target_id)
    when 'week_schedule_blocks' then (select to_jsonb(x) from public.week_schedule_blocks x where x.id=m.target_id)
    when 'week_schedule_items' then (select to_jsonb(x) from public.week_schedule_items x where x.id=m.target_id)
    when 'day_workouts' then (select to_jsonb(x) from public.day_workouts x where x.id=m.target_id)
    when 'day_workout_exercises' then (select to_jsonb(x) from public.day_workout_exercises x where x.id=m.target_id)
  end payload
) dst on dst.payload is not null;

insert into migration_20261105.row_reconciliation
  (source_table,source_pk,target_table,target_pk,tenant_id,disposition,rule_code,source_hash,target_hash)
select 'workout_group_exercises',p.id::text,'workout_group_exercises',t.id::text,t.tenant_id,
       'migrated','DIRECT',md5(to_jsonb(p)::text),md5(to_jsonb(t)::text)
from legacy_20261105.workout_group_exercises p
join public.workout_group_exercises t
  on t.id=migration_20261105.to_uuid('workout_group_exercises',p.id::text);

insert into migration_20261105.row_reconciliation
  (source_table,source_pk,target_table,target_pk,tenant_id,disposition,rule_code,source_hash,target_hash)
select 'student_gyms',p.student_id::text||':'||p.gym_id::text,'student_gyms',t.id::text,t.tenant_id,
       'migrated','DIRECT',md5(to_jsonb(p)::text),md5(to_jsonb(t)::text)
from legacy_20261105.student_gyms p
join public.student_gyms t
  on t.id=migration_20261105.to_uuid('student_gyms',p.student_id::text||':'||p.gym_id::text);

insert into migration_20261105.row_reconciliation
  (source_table,source_pk,target_table,target_pk,tenant_id,disposition,rule_code,source_hash,target_hash,details)
select source_table,source_pk,'performed_set_events',winner_id::text,tenant_id,
       case when is_winner then 'migrated' else 'merged' end,
       case when is_winner then 'SET_UNION_WINNER' else 'SET_CONTENT_DEDUP' end,
       source_hash,content_hash,jsonb_build_object('occurrence',source_occurrence)
from migration_20261105.set_candidates;

-- Large historical/sensitive stores remain only in the private legacy schema.
insert into migration_20261105.table_reconciliation
  (source_table,source_count,preserved_count,target_table,target_count)
select source_table,row_count,row_count,null,null
from migration_20261105.source_counts
where source_table in ('audit_logs','anamnese_sessions','anamnese_answers','student_performance_reports');

insert into migration_20261105.table_reconciliation
  (source_table,source_count,preserved_count,target_table,target_count)
select source_table,row_count,row_count,null,null
from migration_20261105.source_counts
where source_table in (
  'day_workout_set_event_tombstones',
  'day_workout_set_rest_events',
  'exercises_global',
  'exercises_user',
  'sync_tombstones',
  'workout_start_events'
);

-- Rebuild aggregate reconciliation for all sources represented row by row.
insert into migration_20261105.table_reconciliation
  (source_table,source_count,migrated_count,merged_count,preserved_count,quarantined_count,target_table,target_count)
select r.source_table,coalesce(sc.row_count,count(*)),
       count(*) filter (where r.disposition='migrated'),count(*) filter (where r.disposition='merged'),
       count(*) filter (where r.disposition='preserved_legacy'),count(*) filter (where r.disposition='quarantined'),
       max(r.target_table),count(distinct r.target_pk)
from migration_20261105.row_reconciliation r
left join migration_20261105.source_counts sc on sc.source_table=r.source_table
group by r.source_table,sc.row_count
on conflict (source_table) do update set
  source_count=excluded.source_count,migrated_count=excluded.migrated_count,
  merged_count=excluded.merged_count,preserved_count=excluded.preserved_count,
  quarantined_count=excluded.quarantined_count,target_table=excluded.target_table,
  target_count=excluded.target_count,checked_at=clock_timestamp();

commit;

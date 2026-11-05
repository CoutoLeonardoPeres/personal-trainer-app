create temporary table concurrency_fixture (
  tenant_id uuid, user_id uuid, device_a uuid, device_b uuid,
  op_a uuid, op_b uuid, entity_a uuid, entity_b uuid,
  student_id uuid, workout_id uuid, timer_start uuid, timer_a uuid, timer_b uuid
) on commit preserve rows;

insert into concurrency_fixture
select extensions.gen_random_uuid(),extensions.gen_random_uuid(),extensions.gen_random_uuid(),extensions.gen_random_uuid(),
  extensions.gen_random_uuid(),extensions.gen_random_uuid(),extensions.gen_random_uuid(),extensions.gen_random_uuid(),
  extensions.gen_random_uuid(),extensions.gen_random_uuid(),extensions.gen_random_uuid(),extensions.gen_random_uuid(),
  extensions.gen_random_uuid();

insert into auth.users (instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
select '00000000-0000-0000-0000-000000000000',user_id,'authenticated','authenticated',
  'concurrent-'||user_id||'@example.invalid','',now(),'{}','{}',now(),now() from concurrency_fixture;
insert into public.tenant_memberships (user_id,tenant_id,role_name)
select user_id,tenant_id,'personal' from concurrency_fixture;
insert into public.devices (id,user_id,tenant_id,platform)
select device_a,user_id,tenant_id,'ios' from concurrency_fixture
union all select device_b,user_id,tenant_id,'android' from concurrency_fixture;

select extensions.dblink_connect('sync_a','host=supabase_db_App_Personal port=5432 dbname=postgres user=postgres password=postgres');
select extensions.dblink_connect('sync_b','host=supabase_db_App_Personal port=5432 dbname=postgres user=postgres password=postgres');

select extensions.dblink_send_query('sync_a',format(
  $q$with claims as (select set_config('request.jwt.claims',%L,false))
  select public.sync_push(%L::uuid,jsonb_build_array(jsonb_build_object(
    'op_id',%L,'device_seq',1,'entity','muscle_groups','entity_id',%L,
    'op_type','create','payload',jsonb_build_object('name','Concorrente A'),
    'hlc',%L))) from claims$q$,
  jsonb_build_object('sub',user_id,'role','authenticated','app_metadata',jsonb_build_object('role','personal','tenant_id',tenant_id))::text,
  device_a::text,op_a::text,entity_a::text,'000000000000100-00000-'||replace(device_a::text,'-','')
)) from concurrency_fixture;
select extensions.dblink_send_query('sync_b',format(
  $q$with claims as (select set_config('request.jwt.claims',%L,false))
  select public.sync_push(%L::uuid,jsonb_build_array(jsonb_build_object(
    'op_id',%L,'device_seq',1,'entity','muscle_groups','entity_id',%L,
    'op_type','create','payload',jsonb_build_object('name','Concorrente B'),
    'hlc',%L))) from claims$q$,
  jsonb_build_object('sub',user_id,'role','authenticated','app_metadata',jsonb_build_object('role','personal','tenant_id',tenant_id))::text,
  device_b::text,op_b::text,entity_b::text,'000000000000100-00000-'||replace(device_b::text,'-','')
)) from concurrency_fixture;

create temporary table concurrency_results (result jsonb);
insert into concurrency_results select result from extensions.dblink_get_result('sync_a') as t(result jsonb);
insert into concurrency_results select result from extensions.dblink_get_result('sync_b') as t(result jsonb);
select extensions.dblink_disconnect('sync_a');
select extensions.dblink_disconnect('sync_b');

insert into public.students (id,tenant_id,name,created_hlc)
select student_id,tenant_id,'Aluno concorrente','000000000000100-00000-a' from concurrency_fixture;
insert into public.day_workouts (id,tenant_id,student_id,day_date,status,created_hlc)
select workout_id,tenant_id,student_id,'2026-11-04','programado','000000000000100-00000-a' from concurrency_fixture;
insert into public.workout_timer_events
  (id,tenant_id,day_workout_id,student_id,kind,hlc,origin_device,device_seq,server_seq)
select timer_start,tenant_id,workout_id,student_id,'start',
  '000000000000101-00000-'||replace(device_a::text,'-',''),device_a,0,public._allocate_seq(tenant_id)
from concurrency_fixture;

select extensions.dblink_connect('sync_a','host=supabase_db_App_Personal port=5432 dbname=postgres user=postgres password=postgres');
select extensions.dblink_connect('sync_b','host=supabase_db_App_Personal port=5432 dbname=postgres user=postgres password=postgres');

select extensions.dblink_send_query('sync_a',format(
  $q$with claims as (select set_config('request.jwt.claims',%L,false))
  select public.sync_push(%L::uuid,jsonb_build_array(jsonb_build_object(
    'op_id',%L,'device_seq',2,'entity','workout_timer_events','entity_id',%L,
    'op_type','pause','payload',jsonb_build_object('day_workout_id',%L,'student_id',%L),
    'hlc',%L))) from claims$q$,
  jsonb_build_object('sub',user_id,'role','authenticated','app_metadata',jsonb_build_object('role','personal','tenant_id',tenant_id))::text,
  device_a::text,timer_a::text,timer_a::text,workout_id::text,student_id::text,
  '000000000000102-00000-'||replace(device_a::text,'-','')
)) from concurrency_fixture;
select extensions.dblink_send_query('sync_b',format(
  $q$with claims as (select set_config('request.jwt.claims',%L,false))
  select public.sync_push(%L::uuid,jsonb_build_array(jsonb_build_object(
    'op_id',%L,'device_seq',2,'entity','workout_timer_events','entity_id',%L,
    'op_type','pause','payload',jsonb_build_object('day_workout_id',%L,'student_id',%L),
    'hlc',%L))) from claims$q$,
  jsonb_build_object('sub',user_id,'role','authenticated','app_metadata',jsonb_build_object('role','personal','tenant_id',tenant_id))::text,
  device_b::text,timer_b::text,timer_b::text,workout_id::text,student_id::text,
  '000000000000102-00000-'||replace(device_b::text,'-','')
)) from concurrency_fixture;
create temporary table timer_results (result jsonb);
insert into timer_results select result from extensions.dblink_get_result('sync_a') as t(result jsonb);
insert into timer_results select result from extensions.dblink_get_result('sync_b') as t(result jsonb);
select extensions.dblink_disconnect('sync_a');
select extensions.dblink_disconnect('sync_b');

begin;
select plan(7);
select is((select count(*)::integer from concurrency_results where result #>> '{results,0,status}'='applied'),2,'T9 both concurrent pushes apply');
select is((select count(distinct c.server_seq)::integer from public.change_log c,concurrency_fixture f
  where c.tenant_id=f.tenant_id and c.entity='muscle_groups'),2,'T9 concurrent server sequences are unique');
select is((select max(c.server_seq)-min(c.server_seq) from public.change_log c,concurrency_fixture f
  where c.tenant_id=f.tenant_id and c.entity='muscle_groups'),1::bigint,'T9 concurrent server sequences have no gap');
select is((select count(*)::integer from public.devices d,concurrency_fixture f
  where d.id in (f.device_a,f.device_b) and d.last_acked_seq=2),2,'T9 both device acknowledgements advance through timer race');
select is((select count(*)::integer from timer_results where result #>> '{results,0,status}'='applied'),1,'timer race applies only one pause');
select is((select count(*)::integer from timer_results where result #>> '{results,0,reason}'='invalid_transition'),1,'timer race rejects the second pause');
select is((select count(*)::integer from public.workout_timer_events e,concurrency_fixture f
  where e.tenant_id=f.tenant_id and e.day_workout_id=f.workout_id and e.kind='pause'),1,'timer state contains one pause');
select * from finish();
commit;

delete from public.change_log c using concurrency_fixture f where c.tenant_id=f.tenant_id;
delete from public.ops_applied o using concurrency_fixture f where o.tenant_id=f.tenant_id;
delete from public.muscle_groups m using concurrency_fixture f where m.tenant_id=f.tenant_id;
select set_config('app.account_deletion','on',false);
delete from public.workout_timer_events e using concurrency_fixture f where e.tenant_id=f.tenant_id;
delete from public.day_workouts w using concurrency_fixture f where w.tenant_id=f.tenant_id;
delete from public.students s using concurrency_fixture f where s.tenant_id=f.tenant_id;
delete from public.devices d using concurrency_fixture f where d.tenant_id=f.tenant_id;
delete from public.tenant_memberships m using concurrency_fixture f where m.tenant_id=f.tenant_id;
delete from public.tenant_counters c using concurrency_fixture f where c.tenant_id=f.tenant_id;
delete from public.audit_log a using concurrency_fixture f where a.tenant_id=f.tenant_id;
delete from auth.users u using concurrency_fixture f where u.id=f.user_id;

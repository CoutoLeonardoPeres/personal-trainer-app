begin;
select plan(21);

insert into auth.users (instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at) values
('00000000-0000-0000-0000-000000000000','12000000-0000-0000-0000-000000000001','authenticated','authenticated','owner@example.invalid','',now(),'{}','{}',now(),now()),
('00000000-0000-0000-0000-000000000000','12000000-0000-0000-0000-000000000002','authenticated','authenticated','student-one@example.invalid','',now(),'{}','{}',now(),now());
insert into public.tenant_memberships (user_id,tenant_id,role_name,student_id) values
('12000000-0000-0000-0000-000000000001','22000000-0000-0000-0000-000000000001','personal',null),
('12000000-0000-0000-0000-000000000002','22000000-0000-0000-0000-000000000001','student','32000000-0000-0000-0000-000000000001');
insert into public.personals (id,tenant_id,name,max_students_cap,created_hlc) values
('22000000-0000-0000-0000-000000000001','22000000-0000-0000-0000-000000000001','Personal',2,'000000000000001-00000-a');
insert into public.students (id,tenant_id,name,auth_user_id,created_hlc) values
('32000000-0000-0000-0000-000000000001','22000000-0000-0000-0000-000000000001','Um','12000000-0000-0000-0000-000000000002','000000000000001-00000-a'),
('32000000-0000-0000-0000-000000000002','22000000-0000-0000-0000-000000000001','Dois',null,'000000000000001-00000-b');
insert into public.devices (id,user_id,tenant_id,platform) values
('42000000-0000-0000-0000-000000000001','12000000-0000-0000-0000-000000000001','22000000-0000-0000-0000-000000000001','ios'),
('42000000-0000-0000-0000-000000000002','12000000-0000-0000-0000-000000000002','22000000-0000-0000-0000-000000000001','android');
insert into public.day_workouts (id,tenant_id,student_id,day_date,status,created_hlc)
values ('62000000-0000-0000-0000-000000000010','22000000-0000-0000-0000-000000000001','32000000-0000-0000-0000-000000000001','2026-11-04','programado','000000000000001-00000-a');
insert into public.day_workout_exercises (id,tenant_id,day_workout_id,created_hlc)
values ('62000000-0000-0000-0000-000000000011','22000000-0000-0000-0000-000000000001','62000000-0000-0000-0000-000000000010','000000000000001-00000-a');
insert into public.performed_set_events (id,tenant_id,day_workout_exercise_id,student_id,kind,reps,load_kg,hlc,origin_device,device_seq,server_seq)
values ('62000000-0000-0000-0000-000000000012','22000000-0000-0000-0000-000000000001','62000000-0000-0000-0000-000000000011','32000000-0000-0000-0000-000000000001','logged',10,20,'000000000000001-00000-42000000000000000000000000000001','42000000-0000-0000-0000-000000000001',1,1);

set local role authenticated;
select set_config('request.jwt.claim.sub','12000000-0000-0000-0000-000000000002',true);
select set_config('request.jwt.claims',jsonb_build_object('sub','12000000-0000-0000-0000-000000000002','role','authenticated','iat',extract(epoch from now())::bigint,'app_metadata',jsonb_build_object('role','student','tenant_id','22000000-0000-0000-0000-000000000001','student_id','32000000-0000-0000-0000-000000000001'))::text,true);
select is(public.export_my_data()->'student'->>'id','32000000-0000-0000-0000-000000000001','student export contains only own profile');
select ok(not (public.export_my_data() ? 'students') and not (public.export_my_data() ? 'personals'),'student export omits tenant-wide people');
select ok(public.export_my_data() ?& array['membership','gyms','week_schedule_blocks','week_schedule_items','ai_consents'],'student export includes associated portable data');

create temporary table snapshot_cursor as select public.sync_snapshot('{}'::jsonb,1)->'next_cursor' cursor;
select throws_like(
  $$select public.sync_snapshot((select jsonb_set(cursor,'{snapshot_seq}','999999'::jsonb) from snapshot_cursor),1)$$,
  '%invalid_snapshot_cursor%','tampered snapshot cursor is rejected'
);
select throws_like(
  $$select public.sync_snapshot((select jsonb_set(cursor,'{after_key}',to_jsonb('zzzz'::text)) from snapshot_cursor),1)$$,
  '%invalid_snapshot_cursor%','tampered snapshot position is rejected'
);
select throws_like($$select public.sync_pull('42000000-0000-0000-0000-000000000002',999999,10)$$,
  '%cursor_ahead%','future pull cursor is rejected');

select set_config('request.jwt.claim.sub','12000000-0000-0000-0000-000000000001',true);
select set_config('request.jwt.claims',jsonb_build_object('sub','12000000-0000-0000-0000-000000000001','role','authenticated','iat',extract(epoch from now())::bigint-3600,'app_metadata',jsonb_build_object('role','personal','tenant_id','22000000-0000-0000-0000-000000000001'))::text,true);
select ok(public.export_my_data() ?& array['membership','ai_consents','invitation_requests','account_deletion_request'],'personal export includes auxiliary privacy data');
select is(public.sync_push('42000000-0000-0000-0000-000000000001',jsonb_build_array(jsonb_build_object(
  'op_id','52000000-0000-0000-0000-000000000001','device_seq',1,'entity','day_workouts','entity_id','62000000-0000-0000-0000-000000000001',
  'op_type','create','payload',jsonb_build_object('student_id','32000000-0000-0000-0000-000000000001','day_date','2026-11-04','status','concluido'),
  'hlc','000000000000001-00000-42000000000000000000000000000001'))) #>> '{results,0,reason}','invalid_transition','invalid initial workout state is rejected');
create temporary table malformed_batch as select public.sync_push(
  '42000000-0000-0000-0000-000000000001',jsonb_build_array(
    jsonb_build_object('op_id','52000000-0000-0000-0000-000000000002','device_seq',2,'entity','muscle_groups',
      'entity_id','62000000-0000-0000-0000-000000000002','op_type','create','payload',jsonb_build_object('name','Válido'),
      'hlc','000000000000002-00000-42000000000000000000000000000001'),
    jsonb_build_object('op_id','52000000-0000-0000-0000-000000000003','device_seq',3,'entity','muscle_groups',
      'entity_id','inválido','op_type','create','payload',jsonb_build_object('name','Inválido'),
      'hlc','000000000000003-00000-42000000000000000000000000000001'))) result;
select is((select result #>> '{results,0,status}' from malformed_batch),'applied','valid operation before malformed input is committed');
select is((select result #>> '{results,1,reason}' from malformed_batch),'malformed_operation','malformed operation is rejected without aborting the batch');
select is(public.sync_push('42000000-0000-0000-0000-000000000001',jsonb_build_array(jsonb_build_object(
  'op_id','52000000-0000-0000-0000-000000000004','device_seq',4,'entity','muscle_groups',
  'entity_id','62000000-0000-0000-0000-000000000002','op_type','update','payload',jsonb_build_object('name',null),
  'hlc','000000000000004-00000-42000000000000000000000000000001'))) #>> '{results,0,reason}','missing_required_field','required field cannot be cleared by update');
reset role;
select is((select count(*)::integer from public.day_workouts where id='62000000-0000-0000-0000-000000000001'),0,'rejected create leaves no ghost row');
select is((select name from public.muscle_groups where id='62000000-0000-0000-0000-000000000002'),'Válido','rejected required-field update preserves row');
set local role authenticated;
create temporary table deletion_request as select public.delete_my_account() result;
select is((select result->>'status' from deletion_request),'requested','public deletion RPC only opens a request');
reset role;
select is((select count(*)::integer from public.tenant_memberships where tenant_id='22000000-0000-0000-0000-000000000001'),2,'public deletion RPC does not destroy data');
grant select on deletion_request to service_role;
set local role service_role;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
select is(public.server_create_invited_student(
  '22000000-0000-0000-0000-000000000001','22000000-0000-0000-0000-000000000001',
  '32000000-0000-0000-0000-000000000001','12000000-0000-0000-0000-000000000002','Um','student-one@example.invalid'
)->>'student_id','32000000-0000-0000-0000-000000000001','invitation retry remains idempotent at capacity');
select throws_like($$select public.server_create_invited_student(
  '22000000-0000-0000-0000-000000000001','22000000-0000-0000-0000-000000000001',
  '32000000-0000-0000-0000-000000000099','12000000-0000-0000-0000-000000000001','Excedente','extra@example.invalid')$$,
  '%capacity_reached%','student capacity is enforced atomically');
select public.server_mark_deletion_storage((select (result->>'request_id')::uuid from deletion_request));
reset role;
update public.tenant_memberships set status='suspended' where user_id='12000000-0000-0000-0000-000000000001';
set local role service_role;
select throws_like($$select public.server_finalize_account_deletion((select (result->>'request_id')::uuid from deletion_request))$$,
  '%deletion_authorization_changed%','destructive deletion revalidates current authorization');
reset role;
update public.tenant_memberships set status='active' where user_id='12000000-0000-0000-0000-000000000001';
set local role service_role;
select is(public.server_finalize_account_deletion((select (result->>'request_id')::uuid from deletion_request))->>'status','db_deleted','service finalizer completes database stage');
reset role;
select is((select count(*)::integer from public.performed_set_events where tenant_id='22000000-0000-0000-0000-000000000001'),0,'account deletion removes append-only events through guarded path');
select is((select count(*)::integer from public.tenant_memberships where tenant_id='22000000-0000-0000-0000-000000000001'),0,'account deletion removes tenant memberships');

select * from finish();
rollback;

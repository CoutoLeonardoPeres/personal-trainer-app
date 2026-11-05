begin;

select plan(25);

insert into auth.users (instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
values
('00000000-0000-0000-0000-000000000000','10000000-0000-0000-0000-000000000001','authenticated','authenticated','personal-a@example.invalid','',now(),'{}','{}',now(),now()),
('00000000-0000-0000-0000-000000000000','10000000-0000-0000-0000-000000000002','authenticated','authenticated','student-a@example.invalid','',now(),'{}','{}',now(),now()),
('00000000-0000-0000-0000-000000000000','10000000-0000-0000-0000-000000000003','authenticated','authenticated','personal-b@example.invalid','',now(),'{}','{}',now(),now());

insert into public.tenant_memberships (user_id,tenant_id,role_name,student_id) values
('10000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','personal',null),
('10000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000001','student','30000000-0000-0000-0000-000000000001'),
('10000000-0000-0000-0000-000000000003','20000000-0000-0000-0000-000000000002','personal',null);

insert into public.students (id,tenant_id,name,auth_user_id,created_hlc)
values ('30000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','Aluno A','10000000-0000-0000-0000-000000000002','000000000000001-00000-a');
insert into public.muscle_groups (id,tenant_id,name,created_hlc,updated_seq)
values ('69999999-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000002','Tenant B','000000000000001-00000-b',1);
insert into public.tenant_counters values ('20000000-0000-0000-0000-000000000002',1);
insert into public.change_log (tenant_id,server_seq,entity,entity_id,op_type,payload,hlc,origin_device,origin)
select tenant_id,1,'muscle_groups',id,'create',to_jsonb(m),'000000000000001-00000-bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
  '49999999-0000-0000-0000-000000000099','system' from public.muscle_groups m where id='69999999-0000-0000-0000-000000000001';

insert into public.devices (id,user_id,tenant_id,platform) values
('40000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','ios'),
('40000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000001','android'),
('40000000-0000-0000-0000-000000000003','10000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','ios'),
('40000000-0000-0000-0000-000000000004','10000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','ios'),
('40000000-0000-0000-0000-000000000005','10000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','ios'),
('40000000-0000-0000-0000-000000000006','10000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','ios'),
('40000000-0000-0000-0000-000000000007','10000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','ios'),
('40000000-0000-0000-0000-000000000008','10000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','android');

select ok(not has_function_privilege('anon','public.sync_push(uuid,jsonb)','execute'),'T1 anon cannot execute sync_push');
select ok(not has_function_privilege('anon','public.server_time()','execute'),'T1 anon cannot execute server_time');

set local role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',true);
select set_config('request.jwt.claims','{"sub":"10000000-0000-0000-0000-000000000001","role":"authenticated","app_metadata":{"role":"personal","tenant_id":"20000000-0000-0000-0000-000000000001"},"user_metadata":{"role":"org_admin","tenant_id":"20000000-0000-0000-0000-000000000002"}}',true);

select throws_like(
  $$select public.sync_push('49999999-0000-0000-0000-000000000000','[]'::jsonb)$$,
  '%device_not_registered%', 'T2 unregistered device cannot push'
);

select is(
  public.sync_push('40000000-0000-0000-0000-000000000001',jsonb_build_array(jsonb_build_object(
    'op_id','50000000-0000-0000-0000-000000000001','device_seq',1,'entity','muscle_groups',
    'entity_id','60000000-0000-0000-0000-000000000001','op_type','create',
    'payload',jsonb_build_object('tenant_id','20000000-0000-0000-0000-000000000002','name','Vazamento'),
    'hlc','000000000000001-00000-40000000000000000000000000000001'))) #>> '{results,0,reason}',
  'tenant_mismatch','T3 cross-tenant payload is rejected'
);
reset role;
select is((select count(*)::integer from public.muscle_groups where id='60000000-0000-0000-0000-000000000001'),0,'T3 tenant B remains unchanged');
set local role authenticated;
select ok(not exists (
  select 1 from jsonb_array_elements(public.sync_pull('40000000-0000-0000-0000-000000000001',0,500)->'changes') c
  where c->>'entity_id'='69999999-0000-0000-0000-000000000001'
),'T3 pull cannot read tenant B');
select ok(not exists (
  select 1 from jsonb_array_elements(public.sync_snapshot('{}'::jsonb,500)->'items') i
  where i #>> '{payload,id}'='69999999-0000-0000-0000-000000000001'
),'T3 snapshot cannot read tenant B');

select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000002',true);
select set_config('request.jwt.claims','{"sub":"10000000-0000-0000-0000-000000000002","role":"authenticated","app_metadata":{"role":"student","tenant_id":"20000000-0000-0000-0000-000000000001","student_id":"30000000-0000-0000-0000-000000000001"}}',true);
select is(
  public.sync_push('40000000-0000-0000-0000-000000000002',jsonb_build_array(jsonb_build_object(
    'op_id','50000000-0000-0000-0000-000000000002','device_seq',1,'entity','exercises',
    'entity_id','60000000-0000-0000-0000-000000000002','op_type','create','payload',jsonb_build_object('name','Proibido'),
    'hlc','000000000000002-00000-40000000000000000000000000000002'))) #>> '{results,0,reason}',
  'permission_denied','T4 student cannot write catalogs'
);
reset role;
select is((select last_acked_seq from public.devices where id='40000000-0000-0000-0000-000000000002'),1::bigint,'T4 rejected operation advances ack');
select is((select count(*)::integer from public.exercises where id='60000000-0000-0000-0000-000000000002'),0,'T4 rejected catalog row is not created');
select is((select count(*)::integer from public.change_log where entity_id='60000000-0000-0000-0000-000000000002'),0,'T4 rejected catalog row is not published');
set local role authenticated;

select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',true);
select set_config('request.jwt.claims','{"sub":"10000000-0000-0000-0000-000000000001","role":"authenticated","app_metadata":{"role":"personal","tenant_id":"20000000-0000-0000-0000-000000000001"}}',true);
create temporary table replay_result (result jsonb);
insert into replay_result select public.sync_push('40000000-0000-0000-0000-000000000003',jsonb_build_array(jsonb_build_object(
  'op_id','50000000-0000-0000-0000-000000000003','device_seq',1,'entity','muscle_groups',
  'entity_id','60000000-0000-0000-0000-000000000003','op_type','create','payload',jsonb_build_object('name','Costas'),
  'hlc','000000000000003-00000-40000000000000000000000000000003')));
insert into replay_result select public.sync_push('40000000-0000-0000-0000-000000000003',jsonb_build_array(jsonb_build_object(
  'op_id','50000000-0000-0000-0000-000000000003','device_seq',1,'entity','muscle_groups',
  'entity_id','60000000-0000-0000-0000-000000000003','op_type','create','payload',jsonb_build_object('name','Costas'),
  'hlc','000000000000003-00000-40000000000000000000000000000003')));
reset role;
select is((select count(*)::integer from public.ops_applied where op_id='50000000-0000-0000-0000-000000000003'),1,'T5 replay stores one operation');
select is((select count(*)::integer from public.change_log where entity_id='60000000-0000-0000-0000-000000000003'),1,'T5 replay publishes one change');
select is((select count(distinct result #>> '{results,0,server_seq}')::integer from replay_result),1,'T5 replay returns the original server sequence');
select is((select last_acked_seq from public.devices where id='40000000-0000-0000-0000-000000000003'),1::bigint,'T5 replay does not advance ack twice');
select is((select last_seq from public.tenant_counters where tenant_id='20000000-0000-0000-0000-000000000001'),1::bigint,'T5 replay does not consume another tenant sequence');
set local role authenticated;

select is(
  (public.sync_push('40000000-0000-0000-0000-000000000004',jsonb_build_array(jsonb_build_object(
    'op_id','50000000-0000-0000-0000-000000000004','device_seq',2,'entity','muscle_groups',
    'entity_id','60000000-0000-0000-0000-000000000004','op_type','create','payload',jsonb_build_object('name','Gap'),
    'hlc','000000000000004-00000-40000000000000000000000000000004')))->>'expected_seq')::integer,
  1,'T6 gap reports expected sequence'
);
reset role;
select is((select last_acked_seq from public.devices where id='40000000-0000-0000-0000-000000000004'),0::bigint,'T6 gap does not advance ack');
set local role authenticated;

select is(
  public.sync_push('40000000-0000-0000-0000-000000000005',jsonb_build_array(jsonb_build_object(
    'op_id','50000000-0000-0000-0000-000000000005','device_seq',1,'entity','muscle_groups',
    'entity_id','60000000-0000-0000-0000-000000000005','op_type','create','payload',jsonb_build_object('name','Futuro'),
    'hlc',lpad((public.server_time()+301000)::text,15,'0')||'-00000-40000000000000000000000000000005'))) #>> '{results,0,reason}',
  'clock_drift','T7 future HLC is rejected'
);
reset role;
select is((select count(*)::integer from public.change_log where entity_id='60000000-0000-0000-0000-000000000005'),0,'T7 rejected drift creates no change');
set local role authenticated;

select is(public.sync_push('40000000-0000-0000-0000-000000000006',jsonb_build_array(jsonb_build_object(
  'op_id','50000000-0000-0000-0000-000000000006','device_seq',1,'entity','day_workouts',
  'entity_id','60000000-0000-0000-0000-000000000006','op_type','create',
  'payload',jsonb_build_object('student_id','30000000-0000-0000-0000-000000000001','day_date','2026-11-04','status','programado'),
  'hlc','000000000000006-00000-40000000000000000000000000000006'))) #>> '{results,0,status}','applied','T8 fixture workout is created');
select is(public.sync_push('40000000-0000-0000-0000-000000000006',jsonb_build_array(jsonb_build_object(
  'op_id','50000000-0000-0000-0000-000000000016','device_seq',2,'entity','day_workouts',
  'entity_id','60000000-0000-0000-0000-000000000006','op_type','update','payload',jsonb_build_object('status','concluido'),
  'hlc','000000000000007-00000-40000000000000000000000000000006'))) #>> '{results,0,reason}','invalid_transition','T8 invalid status transition is rejected');
reset role;
select is((select status from public.day_workouts where id='60000000-0000-0000-0000-000000000006'),'programado','T8 terminal skip did not change row');
set local role authenticated;

select public.sync_push('40000000-0000-0000-0000-000000000007',jsonb_build_array(jsonb_build_object(
  'op_id','50000000-0000-0000-0000-000000000007','device_seq',1,'entity','muscle_groups',
  'entity_id','60000000-0000-0000-0000-000000000007','op_type','create','payload',jsonb_build_object('name','A'),
  'hlc','000000000000008-00000-40000000000000000000000000000007')));
select public.sync_push('40000000-0000-0000-0000-000000000008',jsonb_build_array(jsonb_build_object(
  'op_id','50000000-0000-0000-0000-000000000008','device_seq',1,'entity','muscle_groups',
  'entity_id','60000000-0000-0000-0000-000000000008','op_type','create','payload',jsonb_build_object('name','B'),
  'hlc','000000000000009-00000-40000000000000000000000000000008')));
reset role;
select is((select count(distinct server_seq)::integer from public.change_log where entity_id in
  ('60000000-0000-0000-0000-000000000007','60000000-0000-0000-0000-000000000008')),2,'T9 pushes receive unique server sequences');
select is((select max(server_seq)-min(server_seq) from public.change_log where entity_id in
  ('60000000-0000-0000-0000-000000000007','60000000-0000-0000-0000-000000000008')),1::bigint,'T9 server sequences are adjacent');

reset role;
select * from finish();
rollback;

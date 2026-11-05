begin;

select plan(14);

insert into auth.users (instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
values ('00000000-0000-0000-0000-000000000000','11000000-0000-0000-0000-000000000001','authenticated','authenticated','conflict@example.invalid','',now(),'{}','{}',now(),now());
insert into public.tenant_memberships (user_id,tenant_id,role_name)
values ('11000000-0000-0000-0000-000000000001','21000000-0000-0000-0000-000000000001','personal');
insert into public.devices (id,user_id,tenant_id,platform)
values ('41000000-0000-0000-0000-000000000001','11000000-0000-0000-0000-000000000001','21000000-0000-0000-0000-000000000001','ios');

set local role authenticated;
select set_config('request.jwt.claim.sub','11000000-0000-0000-0000-000000000001',true);
select set_config('request.jwt.claims','{"sub":"11000000-0000-0000-0000-000000000001","role":"authenticated","app_metadata":{"role":"personal","tenant_id":"21000000-0000-0000-0000-000000000001"}}',true);

select is(public.sync_push('41000000-0000-0000-0000-000000000001',jsonb_build_array(jsonb_build_object(
  'op_id','51000000-0000-0000-0000-000000000001','device_seq',1,'entity','muscle_groups',
  'entity_id','61000000-0000-0000-0000-000000000001','op_type','create','payload',jsonb_build_object('name','Inicial'),
  'hlc','000000000000010-00000-41000000000000000000000000000001'))) #>> '{results,0,status}','applied','create applies');
select is(public.sync_push('41000000-0000-0000-0000-000000000001',jsonb_build_array(jsonb_build_object(
  'op_id','51000000-0000-0000-0000-000000000002','device_seq',2,'entity','muscle_groups',
  'entity_id','61000000-0000-0000-0000-000000000001','op_type','update','payload',jsonb_build_object('name','Antigo'),
  'hlc','000000000000009-00000-41000000000000000000000000000001'))) #>> '{results,0,status}','noop','older field HLC is noop');
select is(public.sync_push('41000000-0000-0000-0000-000000000001',jsonb_build_array(jsonb_build_object(
  'op_id','51000000-0000-0000-0000-000000000003','device_seq',3,'entity','muscle_groups',
  'entity_id','61000000-0000-0000-0000-000000000001','op_type','update','payload',jsonb_build_object('name','Novo'),
  'hlc','000000000000011-00000-41000000000000000000000000000001'))) #>> '{results,0,status}','applied','newer field HLC applies');
select is(public.sync_push('41000000-0000-0000-0000-000000000001',jsonb_build_array(jsonb_build_object(
  'op_id','51000000-0000-0000-0000-000000000004','device_seq',4,'entity','muscle_groups',
  'entity_id','61000000-0000-0000-0000-000000000001','op_type','delete','payload','{}'::jsonb,
  'hlc','000000000000012-00000-41000000000000000000000000000001'))) #>> '{results,0,status}','applied','delete applies');
select is(public.sync_push('41000000-0000-0000-0000-000000000001',jsonb_build_array(jsonb_build_object(
  'op_id','51000000-0000-0000-0000-000000000005','device_seq',5,'entity','muscle_groups',
  'entity_id','61000000-0000-0000-0000-000000000001','op_type','update','payload',jsonb_build_object('name','Não ressuscita'),
  'hlc','000000000000013-00000-41000000000000000000000000000001'))) #>> '{results,0,status}','noop','edit cannot resurrect tombstone');
select is(public.sync_push('41000000-0000-0000-0000-000000000001',jsonb_build_array(jsonb_build_object(
  'op_id','51000000-0000-0000-0000-000000000006','device_seq',6,'entity','muscle_groups',
  'entity_id','61000000-0000-0000-0000-000000000001','op_type','restore','payload','{}'::jsonb,
  'hlc','000000000000013-00001-41000000000000000000000000000001'))) #>> '{results,0,status}','applied','explicit restore applies');

select is((public.sync_pull('41000000-0000-0000-0000-000000000001',0,2)->'changes'->0->>'server_seq')::bigint,1::bigint,'pull starts at first server sequence');
select ok((public.sync_pull('41000000-0000-0000-0000-000000000001',0,2)->>'has_more')::boolean,'pull reports another page');
select ok(jsonb_array_length(public.sync_snapshot('{}'::jsonb,100)->'items') >= 1,'snapshot contains canonical row');

reset role;
select is((select name from public.muscle_groups where id='61000000-0000-0000-0000-000000000001'),'Novo','tombstone flow preserves latest field');
select is((select count(*)::integer from public.change_log where tenant_id='21000000-0000-0000-0000-000000000001'),4,'noop operations publish no changes');
select is((select last_seq from public.tenant_counters where tenant_id='21000000-0000-0000-0000-000000000001'),4::bigint,'noop operations consume no server sequence');
select is((select count(*)::integer from public.audit_log),(select count(*)::integer from public.change_log),'audit has one row per published change');
select ok(not exists (select 1 from information_schema.columns where table_schema='public' and table_name='audit_log' and column_name in ('payload','anamnese','health_data')),'audit stores no health payload');

select * from finish();
rollback;

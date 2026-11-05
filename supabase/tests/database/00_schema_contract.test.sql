begin;

select plan(28);

select has_table('public', 'devices', 'devices exists');
select has_table('public', 'tenant_counters', 'tenant_counters exists');
select has_table('public', 'ops_applied', 'ops_applied exists');
select has_table('public', 'change_log', 'change_log exists');
select has_table('public', 'performed_set_events', 'set events exist');
select has_table('public', 'workout_timer_events', 'timer events exist');
select has_table('public', 'sync_permissions', 'permission matrix exists');
select has_table('public', 'audit_log', 'audit log exists');

select has_function('public', 'register_device', array['uuid', 'text'], 'register_device exists');
select has_function('public', 'server_time', array[]::text[], 'server_time exists');
select has_function('public', 'sync_push', array['uuid', 'jsonb'], 'sync_push exists');
select has_function('public', 'sync_pull', array['uuid', 'bigint', 'integer'], 'sync_pull exists');
select has_function('public', 'sync_snapshot', array['jsonb', 'integer'], 'sync_snapshot exists');
select has_function('public', 'export_my_data', array[]::text[], 'export_my_data exists');
select has_function('public', 'delete_my_account', array[]::text[], 'delete_my_account exists');

select is(
  (select count(*)::integer from information_schema.role_table_grants
   where table_schema = 'public' and grantee = 'anon'),
  0,
  'anon has no table grants'
);
select is(
  (select count(*)::integer from information_schema.role_table_grants
   where table_schema = 'public' and grantee = 'authenticated'),
  0,
  'authenticated has no direct table grants'
);
select is(
  (select count(*)::integer from information_schema.routine_privileges
   where routine_schema = 'public' and grantee = 'anon'),
  0,
  'anon executes no public function'
);
select is(
  (select count(*)::integer from information_schema.routine_privileges
   where routine_schema = 'public' and grantee = 'authenticated'
     and routine_name not in ('register_device', 'server_time', 'sync_push', 'sync_pull', 'sync_snapshot', 'export_my_data', 'delete_my_account')),
  0,
  'authenticated executes only the public API'
);
select is(
  (select count(*)::integer from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and has_function_privilege('anon',p.oid,'EXECUTE')),
  0,
  'anon inherits no function execution through PUBLIC'
);
select is(
  (select count(*)::integer from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and has_function_privilege('authenticated',p.oid,'EXECUTE')
     and p.proname not in ('register_device','server_time','sync_push','sync_pull','sync_snapshot','export_my_data','delete_my_account')),
  0,
  'authenticated inherits execution only for the public API'
);
select ok(
  has_function_privilege('authenticated','public.register_device(uuid,text)','EXECUTE') and
  has_function_privilege('authenticated','public.server_time()','EXECUTE') and
  has_function_privilege('authenticated','public.sync_push(uuid,jsonb)','EXECUTE') and
  has_function_privilege('authenticated','public.sync_pull(uuid,bigint,integer)','EXECUTE') and
  has_function_privilege('authenticated','public.sync_snapshot(jsonb,integer)','EXECUTE') and
  has_function_privilege('authenticated','public.export_my_data()','EXECUTE') and
  has_function_privilege('authenticated','public.delete_my_account()','EXECUTE'),
  'authenticated can execute every public API function'
);
select is(
  (select count(*)::integer from pg_class c join pg_namespace n on n.oid=c.relnamespace
   where n.nspname='public' and c.relkind in ('r','p') and (
     has_table_privilege('anon',c.oid,'SELECT') or has_table_privilege('anon',c.oid,'INSERT') or
     has_table_privilege('anon',c.oid,'UPDATE') or has_table_privilege('anon',c.oid,'DELETE'))),
  0,
  'anon inherits no public table access'
);
select is(
  (select count(*)::integer from pg_class c join pg_namespace n on n.oid=c.relnamespace
   where n.nspname='public' and c.relkind in ('r','p') and (
     has_table_privilege('authenticated',c.oid,'SELECT') or has_table_privilege('authenticated',c.oid,'INSERT') or
     has_table_privilege('authenticated',c.oid,'UPDATE') or has_table_privilege('authenticated',c.oid,'DELETE'))),
  0,
  'authenticated inherits no direct table access'
);
select is(
  (select count(*)::integer from pg_class c join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public' and c.relkind in ('r', 'p') and not c.relrowsecurity),
  0,
  'RLS is enabled on every public table'
);
select is(
  (select count(*)::integer from pg_policies
   where schemaname = 'public' and (qual = 'true' or with_check = 'true')),
  0,
  'there are no open public policies'
);
select col_is_pk('public', 'change_log', array['tenant_id', 'server_seq'], 'change_log cursor is tenant scoped');
select col_is_pk('public', 'ops_applied', 'op_id', 'op id is the idempotency key');

select * from finish();
rollback;

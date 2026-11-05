begin;

revoke all on schema public from public, anon;
grant usage on schema public to authenticated, service_role;

revoke all on all tables in schema public from anon, authenticated;
revoke all on all sequences in schema public from anon, authenticated;
revoke execute on all functions in schema public from public, anon, authenticated;

alter default privileges for role postgres in schema public revoke all on tables from anon, authenticated;
alter default privileges for role postgres in schema public revoke execute on functions from public, anon, authenticated;
alter default privileges for role postgres in schema public revoke usage, select on sequences from anon, authenticated;

grant execute on function public.register_device(uuid,text) to authenticated;
grant execute on function public.server_time() to authenticated;
grant execute on function public.sync_push(uuid,jsonb) to authenticated;
grant execute on function public.sync_pull(uuid,bigint,integer) to authenticated;
grant execute on function public.sync_snapshot(jsonb,integer) to authenticated;
grant execute on function public.export_my_data() to authenticated;
grant execute on function public.delete_my_account() to authenticated;
grant execute on function public.server_create_invited_student(uuid,uuid,uuid,uuid,text,text) to service_role;
grant execute on function public.server_consume_ai_quota(uuid,integer) to service_role;
grant execute on function public.server_refund_ai_quota(uuid) to service_role;
grant execute on function public.server_mark_deletion_storage(uuid) to service_role;
grant execute on function public.server_finalize_account_deletion(uuid) to service_role;
grant execute on function public.server_complete_account_deletion(uuid) to service_role;

do $$
declare r record;
begin
  for r in select tablename from pg_tables where schemaname='public' loop
    execute format('alter table public.%I enable row level security',r.tablename);
    execute format('alter table public.%I force row level security',r.tablename);
  end loop;
end;
$$;

commit;

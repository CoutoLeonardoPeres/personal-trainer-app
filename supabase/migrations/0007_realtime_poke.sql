begin;

create or replace function public._send_sync_poke()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  begin
    perform realtime.send('{}'::jsonb,'sync_poke','tenant:'||new.tenant_id::text,true);
  exception when others then
    raise warning 'sync poke failed for tenant %: %',new.tenant_id,sqlerrm;
  end;
  return new;
end;
$$;

create trigger change_log_sync_poke_after_insert
after insert on public.change_log
for each row execute function public._send_sync_poke();

revoke execute on function public._send_sync_poke() from public, anon, authenticated;

-- Realtime Authorization policies are owned by the managed Realtime role and
-- are installed in hosted environments by scripts/apply-realtime-policy.sql.

commit;

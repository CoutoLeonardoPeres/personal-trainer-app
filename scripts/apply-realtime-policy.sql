begin;

drop policy if exists tenant_sync_poke_read on realtime.messages;
create policy tenant_sync_poke_read on realtime.messages
for select to authenticated
using (
  extension='broadcast'
  and realtime.topic() = 'tenant:' || ((select auth.jwt()) -> 'app_metadata' ->> 'tenant_id')
  and exists (
    select 1 from public.tenant_memberships m
    where m.user_id=(select auth.uid())
      and m.tenant_id=(((select auth.jwt()) -> 'app_metadata' ->> 'tenant_id')::uuid)
      and m.status='active'
  )
);

commit;

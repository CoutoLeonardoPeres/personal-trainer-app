begin;

create table public.audit_log (
  id bigint generated always as identity primary key,
  tenant_id uuid not null,
  server_seq bigint not null,
  actor_user_id uuid,
  origin_device uuid not null,
  origin text not null,
  entity text not null,
  entity_id uuid not null,
  op_type text not null,
  occurred_at timestamptz not null default clock_timestamp(),
  unique (tenant_id,server_seq)
);

alter table public.audit_log enable row level security;
alter table public.audit_log force row level security;
revoke all on public.audit_log from anon, authenticated;
revoke all on sequence public.audit_log_id_seq from anon, authenticated;

create or replace function public._audit_change()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  insert into public.audit_log
    (tenant_id,server_seq,actor_user_id,origin_device,origin,entity,entity_id,op_type)
  values
    (new.tenant_id,new.server_seq,new.actor_user_id,new.origin_device,new.origin,new.entity,new.entity_id,new.op_type);
  return new;
end;
$$;

create trigger change_log_audit_after_insert
after insert on public.change_log
for each row execute function public._audit_change();

create or replace function public._reject_mutation()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if current_setting('app.account_deletion',true)='on' then return old; end if;
  raise exception 'append_only_table' using errcode='42501';
end;
$$;

create trigger performed_set_events_append_only before update or delete on public.performed_set_events
for each row execute function public._reject_mutation();
create trigger workout_timer_events_append_only before update or delete on public.workout_timer_events
for each row execute function public._reject_mutation();
create trigger audit_log_append_only before update or delete on public.audit_log
for each row execute function public._reject_mutation();

revoke execute on function public._audit_change() from public, anon, authenticated;
revoke execute on function public._reject_mutation() from public, anon, authenticated;

commit;

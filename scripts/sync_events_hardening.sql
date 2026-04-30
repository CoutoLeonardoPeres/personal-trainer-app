begin;

create table if not exists public.day_workout_set_events (
  event_id text primary key,
  day_workout_id text not null,
  day_workout_exercise_id text not null,
  student_id text not null,
  reps int4 not null,
  load_kg float8 null,
  logged_at_ms int8 not null,
  created_by_user_id uuid not null default auth.uid(),
  created_by_role text not null check (created_by_role in ('student','personal')),
  created_at timestamptz not null default now()
);

create table if not exists public.day_workout_set_rest_events (
  rest_event_id text primary key,
  set_event_id text not null references public.day_workout_set_events(event_id) on delete cascade,
  day_workout_id text not null,
  day_workout_exercise_id text not null,
  rest_prescribed_sec int4 null,
  rest_countdown_elapsed_ms int8 null,
  post_rest_modal_ms int8 null,
  recorded_at_ms int8 not null,
  recorded_by_user_id uuid not null default auth.uid(),
  recorded_by_role text not null check (recorded_by_role in ('student','personal')),
  created_at timestamptz not null default now()
);

create table if not exists public.day_workout_set_event_tombstones (
  tombstone_id text primary key,
  event_id text not null references public.day_workout_set_events(event_id) on delete cascade,
  day_workout_id text not null,
  day_workout_exercise_id text not null,
  deleted_at_ms int8 not null,
  deleted_by_user_id uuid not null default auth.uid(),
  deleted_by_role text not null check (deleted_by_role in ('student','personal')),
  deleted_at timestamptz not null default now()
);

create index if not exists idx_set_events_workout_logged
on public.day_workout_set_events(day_workout_id, logged_at_ms);

create index if not exists idx_set_events_line_logged
on public.day_workout_set_events(day_workout_exercise_id, logged_at_ms);

create index if not exists idx_rest_events_workout_recorded
on public.day_workout_set_rest_events(day_workout_id, recorded_at_ms);

create index if not exists idx_rest_events_line_recorded
on public.day_workout_set_rest_events(day_workout_exercise_id, recorded_at_ms);

create index if not exists idx_tomb_events_workout_deleted
on public.day_workout_set_event_tombstones(day_workout_id, deleted_at_ms);

create index if not exists idx_tomb_events_line_deleted
on public.day_workout_set_event_tombstones(day_workout_exercise_id, deleted_at_ms);

create index if not exists idx_tomb_events_by_event
on public.day_workout_set_event_tombstones(event_id);

create or replace function public.validate_rest_event_matches_set()
returns trigger language plpgsql as $$
declare
  s public.day_workout_set_events%rowtype;
begin
  select * into s from public.day_workout_set_events where event_id = new.set_event_id;
  if not found then
    raise exception 'set_event_id % not found', new.set_event_id;
  end if;
  if new.day_workout_id <> s.day_workout_id then
    raise exception 'rest_event day_workout_id mismatch';
  end if;
  if new.day_workout_exercise_id <> s.day_workout_exercise_id then
    raise exception 'rest_event day_workout_exercise_id mismatch';
  end if;
  return new;
end $$;

drop trigger if exists trg_validate_rest_event_matches_set on public.day_workout_set_rest_events;
create trigger trg_validate_rest_event_matches_set
before insert or update on public.day_workout_set_rest_events
for each row execute function public.validate_rest_event_matches_set();

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'day_workout_set_events'
  ) then
    alter publication supabase_realtime add table public.day_workout_set_events;
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'day_workout_set_rest_events'
  ) then
    alter publication supabase_realtime add table public.day_workout_set_rest_events;
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'day_workout_set_event_tombstones'
  ) then
    alter publication supabase_realtime add table public.day_workout_set_event_tombstones;
  end if;
end $$;

alter table public.day_workout_set_events enable row level security;
alter table public.day_workout_set_rest_events enable row level security;
alter table public.day_workout_set_event_tombstones enable row level security;

drop policy if exists p_set_events_select on public.day_workout_set_events;
create policy p_set_events_select
on public.day_workout_set_events
for select
to authenticated
using (
  exists (
    select 1
    from public.day_workouts w
    left join public.students s on s.id::text = w.student_id::text
    where w.id::text = day_workout_id::text
      and (
        s.id::text = auth.uid()::text
        or s.created_by_personal_id::text = auth.uid()::text
      )
  )
);

drop policy if exists p_set_events_insert on public.day_workout_set_events;
create policy p_set_events_insert
on public.day_workout_set_events
for insert
to authenticated
with check (
  exists (
    select 1
    from public.day_workouts w
    left join public.students s on s.id::text = w.student_id::text
    where w.id::text = day_workout_id::text
      and (
        s.id::text = auth.uid()::text
        or s.created_by_personal_id::text = auth.uid()::text
      )
  )
);

drop policy if exists p_rest_events_select on public.day_workout_set_rest_events;
create policy p_rest_events_select
on public.day_workout_set_rest_events
for select
to authenticated
using (
  exists (
    select 1
    from public.day_workouts w
    left join public.students s on s.id::text = w.student_id::text
    where w.id::text = day_workout_id::text
      and (
        s.id::text = auth.uid()::text
        or s.created_by_personal_id::text = auth.uid()::text
      )
  )
);

drop policy if exists p_rest_events_insert on public.day_workout_set_rest_events;
create policy p_rest_events_insert
on public.day_workout_set_rest_events
for insert
to authenticated
with check (
  exists (
    select 1
    from public.day_workouts w
    left join public.students s on s.id::text = w.student_id::text
    where w.id::text = day_workout_id::text
      and (
        s.id::text = auth.uid()::text
        or s.created_by_personal_id::text = auth.uid()::text
      )
  )
);

drop policy if exists p_tomb_events_select on public.day_workout_set_event_tombstones;
create policy p_tomb_events_select
on public.day_workout_set_event_tombstones
for select
to authenticated
using (
  exists (
    select 1
    from public.day_workouts w
    left join public.students s on s.id::text = w.student_id::text
    where w.id::text = day_workout_id::text
      and (
        s.id::text = auth.uid()::text
        or s.created_by_personal_id::text = auth.uid()::text
      )
  )
);

drop policy if exists p_tomb_events_insert on public.day_workout_set_event_tombstones;
create policy p_tomb_events_insert
on public.day_workout_set_event_tombstones
for insert
to authenticated
with check (
  exists (
    select 1
    from public.day_workouts w
    left join public.students s on s.id::text = w.student_id::text
    where w.id::text = day_workout_id::text
      and (
        s.id::text = auth.uid()::text
        or s.created_by_personal_id::text = auth.uid()::text
      )
  )
);

commit;

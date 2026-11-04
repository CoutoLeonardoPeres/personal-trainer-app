-- =============================================================================
-- Sprint 3 — Motor de sync: revision atômico + séries append-only
-- =============================================================================
-- ORDEM: após sprint1 + sprint2. Aplicar no Supabase SQL Editor.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- A) Revision monotônico no servidor (fonte da verdade)
-- ---------------------------------------------------------------------------
create or replace function public.app_bump_row_revision ()
returns trigger
language plpgsql
as $$
begin
  if TG_OP = 'UPDATE' then
    NEW.revision := coalesce(OLD.revision, 0) + 1;
    NEW.updated_at := now();
  elsif TG_OP = 'INSERT' then
    NEW.revision := coalesce(NEW.revision, 0);
    if NEW.revision < 0 then
      NEW.revision := 0;
    end if;
  end if;
  return NEW;
end;
$$;

-- day_workouts
drop trigger if exists trg_day_workouts_bump_revision on public.day_workouts;
create trigger trg_day_workouts_bump_revision
  before insert or update on public.day_workouts
  for each row execute function public.app_bump_row_revision ();

-- day_workout_exercises
drop trigger if exists trg_day_workout_exercises_bump_revision on public.day_workout_exercises;
create trigger trg_day_workout_exercises_bump_revision
  before insert or update on public.day_workout_exercises
  for each row execute function public.app_bump_row_revision ();

-- workout_groups (já possui revision no app)
drop trigger if exists trg_workout_groups_bump_revision on public.workout_groups;
create trigger trg_workout_groups_bump_revision
  before insert or update on public.workout_groups
  for each row execute function public.app_bump_row_revision ();

-- ---------------------------------------------------------------------------
-- B) Séries executadas — append-only (substitui JSON como fonte de verdade)
-- ---------------------------------------------------------------------------
create table if not exists public.day_workout_performed_sets (
  id text primary key,
  day_workout_exercise_id text not null
    references public.day_workout_exercises (id) on delete cascade,
  load_kg double precision null,
  reps integer not null check (reps >= 1),
  logged_at_ms bigint null,
  rest_prescribed_sec integer null,
  rest_countdown_elapsed_ms integer null,
  post_rest_modal_ms integer null,
  device_id text null,
  created_at timestamptz not null default now()
);

create index if not exists idx_dwp_sets_line_created
  on public.day_workout_performed_sets (day_workout_exercise_id, created_at);

create unique index if not exists uq_dwp_sets_line_logged
  on public.day_workout_performed_sets (day_workout_exercise_id, id);

alter table public.day_workout_performed_sets enable row level security;

drop policy if exists dwp_sets_select_auth on public.day_workout_performed_sets;
create policy dwp_sets_select_auth on public.day_workout_performed_sets
  for select to authenticated
  using (
    exists (
      select 1
      from public.day_workout_exercises dwe
      join public.day_workouts dw on dw.id = dwe.day_workout_id
      where dwe.id = day_workout_exercise_id
        and public.app_can_access_student_training (dw.student_id)
    )
  );

drop policy if exists dwp_sets_insert_auth on public.day_workout_performed_sets;
create policy dwp_sets_insert_auth on public.day_workout_performed_sets
  for insert to authenticated
  with check (
    exists (
      select 1
      from public.day_workout_exercises dwe
      join public.day_workouts dw on dw.id = dwe.day_workout_id
      where dwe.id = day_workout_exercise_id
        and public.app_can_access_student_training (dw.student_id)
    )
  );

-- Append-only: sem UPDATE/DELETE para authenticated (correções via admin/service_role).
revoke update, delete on public.day_workout_performed_sets from authenticated;

-- ---------------------------------------------------------------------------
-- C) Backfill opcional: JSON legado → linhas append-only (id estável por índice)
-- ---------------------------------------------------------------------------
insert into public.day_workout_performed_sets (
  id,
  day_workout_exercise_id,
  load_kg,
  reps,
  logged_at_ms,
  rest_prescribed_sec,
  rest_countdown_elapsed_ms,
  post_rest_modal_ms,
  device_id,
  created_at
)
select
  dwe.id || ':set:' || (elem.ordinality - 1)::text,
  dwe.id,
  nullif(elem.value ->> 'loadKg', '')::double precision,
  coalesce((elem.value ->> 'reps')::integer, 1),
  nullif(elem.value ->> 'loggedAtMs', '')::bigint,
  nullif(elem.value ->> 'restPrescribedSec', '')::integer,
  nullif(elem.value ->> 'restCountdownElapsedMs', '')::integer,
  nullif(elem.value ->> 'postRestModalMs', '')::integer,
  dwe.last_modified_by_device_id,
  coalesce(dwe.updated_at, now())
from public.day_workout_exercises dwe
cross join lateral jsonb_array_elements(
  case
    when dwe.performed_sets_json is null
      or trim(dwe.performed_sets_json) = ''
      or dwe.performed_sets_json = '[]' then '[]'::jsonb
    else dwe.performed_sets_json::jsonb
  end
) with ordinality as elem(value, ordinality)
where not exists (
  select 1
  from public.day_workout_performed_sets s
  where s.id = dwe.id || ':set:' || (elem.ordinality - 1)::text
)
on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- D) Realtime (opcional — incluir tabela de séries)
-- ---------------------------------------------------------------------------
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    execute 'alter publication supabase_realtime add table public.day_workout_performed_sets';
  end if;
exception
  when duplicate_object then null;
  when undefined_object then null;
end $$;

-- Schema COMPLETO do app para Supabase (Postgres)
-- Inclui: núcleo do app + anamnese histórica + relatórios por aluno + RLS permissivo (dev)
-- Uso: Supabase Dashboard -> SQL Editor -> Execute

create extension if not exists "pgcrypto";

-- Limpeza opcional (CUIDADO: apaga dados)
-- drop table if exists
--   student_performance_reports,
--   anamnese_answers,
--   anamnese_sessions,
--   audit_logs,
--   day_workout_exercises,
--   day_workouts,
--   week_schedule_items,
--   week_schedule_blocks,
--   workout_group_exercises,
--   workout_groups,
--   training_methods,
--   student_gyms,
--   students,
--   personals,
--   gyms,
--   exercises,
--   muscle_groups
-- cascade;

-- -----------------------------
-- CORE TABLES
-- -----------------------------

create table if not exists public.muscle_groups (
  id text primary key,
  name text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.exercises (
  id text primary key,
  name text not null,
  muscle_group_id text not null references public.muscle_groups(id) on delete restrict,
  video_url text null,
  alternative_note text null,
  alternative_video_url text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.gyms (
  id text primary key,
  name text not null,
  cnpj text not null,
  street text not null,
  number text not null,
  complement text null,
  district text not null,
  city text not null,
  state_uf text not null,
  cep text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.personals (
  id text primary key,
  name text not null,
  cpf text not null,
  professional_registry text not null,
  street text not null,
  number text not null,
  complement text null,
  city text not null,
  state_uf text not null,
  cep text null,
  email text not null,
  must_change_password boolean not null default true,
  password_hash text null,
  is_admin boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.students (
  id text primary key,
  name text not null,
  email text null,
  goal text null,
  cpf text null,
  birth_date timestamptz null,
  street text null,
  number text null,
  complement text null,
  district text null,
  city text null,
  state_uf text null,
  cep text null,
  must_change_password boolean not null default true,
  password_hash text null,
  created_by_personal_id text null references public.personals(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.student_gyms (
  student_id text not null references public.students(id) on delete cascade,
  gym_id text not null references public.gyms(id) on delete cascade,
  primary key (student_id, gym_id)
);

create table if not exists public.training_methods (
  id text primary key,
  method text not null,
  description text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.workout_groups (
  id text primary key,
  name text not null,
  description text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.workout_group_exercises (
  id text primary key,
  workout_group_id text not null references public.workout_groups(id) on delete cascade,
  exercise_id text not null references public.exercises(id) on delete restrict,
  sort_order integer not null default 0,
  last_load_kg double precision null,
  last_reps integer null,
  last_reps_text text null,
  last_sets integer null
);

create table if not exists public.week_schedule_blocks (
  id text primary key,
  student_id text not null references public.students(id) on delete cascade,
  week_start_monday timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.week_schedule_items (
  id text primary key,
  block_id text not null references public.week_schedule_blocks(id) on delete cascade,
  exercise_id text not null references public.exercises(id) on delete restrict,
  source_workout_group_id text null,
  sort_order integer not null default 0,
  sets integer not null default 0,
  reps integer not null default 0,
  load_kg double precision null,
  needs_detail boolean not null default false
);

create table if not exists public.day_workouts (
  id text primary key,
  student_id text not null references public.students(id) on delete cascade,
  day_date timestamptz not null,
  status text not null,
  week_item_id text null,
  active_duration_seconds integer not null default 0,
  workout_score double precision null,
  started_at timestamptz null,
  completed_at timestamptz null,
  timer_resume_at timestamptz null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  source_workout_group_id text null
);

create table if not exists public.day_workout_exercises (
  id text primary key,
  day_workout_id text not null references public.day_workouts(id) on delete cascade,
  exercise_id text not null references public.exercises(id) on delete restrict,
  sort_order integer not null default 0,
  sets integer not null,
  reps integer not null,
  load_kg double precision null,
  exercise_score double precision null,
  performed_sets_json text null
);

create table if not exists public.audit_logs (
  id text primary key,
  at timestamptz not null default now(),
  action text not null,
  entity_type text not null,
  entity_id text null,
  payload_json text null
);

-- -----------------------------
-- NOVAS TABELAS (ANAMNESE + RELATÓRIOS)
-- -----------------------------

create table if not exists public.anamnese_sessions (
  id text primary key default gen_random_uuid()::text,
  student_id text not null references public.students(id) on delete cascade,
  filled_by text null,
  filled_by_name text null,
  notes text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.anamnese_answers (
  id text primary key default gen_random_uuid()::text,
  session_id text not null references public.anamnese_sessions(id) on delete cascade,
  section_name text not null,
  question_order integer not null,
  question_key text not null,
  question_text text not null,
  answer_text text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.student_performance_reports (
  id text primary key default gen_random_uuid()::text,
  student_id text not null references public.students(id) on delete cascade,
  period_label text not null,
  period_start date null,
  period_end date null,
  report_text text not null,
  report_json jsonb null,
  source text not null default 'app', -- app | ai | app+ai
  created_at timestamptz not null default now()
);

-- -----------------------------
-- MIGRAÇÕES COMPATÍVEIS
-- -----------------------------

alter table public.personals add column if not exists cep text;
alter table public.workout_group_exercises add column if not exists last_reps_text text;

-- -----------------------------
-- DEDUP (MUSCLE GROUPS / EXERCISES)
-- -----------------------------

do $$
begin
  create temp table _mg_dedup_map on commit drop as
  with ranked as (
    select
      id,
      lower(trim(name)) as norm_name,
      row_number() over (
        partition by lower(trim(name))
        order by created_at asc, id asc
      ) as rn,
      first_value(id) over (
        partition by lower(trim(name))
        order by created_at asc, id asc
      ) as keeper_id
    from public.muscle_groups
  )
  select id as duplicate_id, keeper_id
  from ranked
  where rn > 1;

  if to_regclass('public.exercises') is not null then
    update public.exercises e
    set muscle_group_id = m.keeper_id
    from _mg_dedup_map m
    where e.muscle_group_id = m.duplicate_id;
  end if;

  delete from public.muscle_groups g
  using _mg_dedup_map m
  where g.id = m.duplicate_id;
end $$;

create unique index if not exists muscle_groups_unique_normalized_name
  on public.muscle_groups (lower(trim(name)));

do $$
begin
  create temp table _ex_dedup_map on commit drop as
  with ranked as (
    select
      id,
      lower(trim(name)) as norm_name,
      row_number() over (
        partition by lower(trim(name))
        order by created_at asc, id asc
      ) as rn,
      first_value(id) over (
        partition by lower(trim(name))
        order by created_at asc, id asc
      ) as keeper_id
    from public.exercises
  )
  select id as duplicate_id, keeper_id
  from ranked
  where rn > 1;

  if to_regclass('public.workout_group_exercises') is not null then
    update public.workout_group_exercises w
    set exercise_id = m.keeper_id
    from _ex_dedup_map m
    where w.exercise_id = m.duplicate_id;
  end if;

  if to_regclass('public.week_schedule_items') is not null then
    update public.week_schedule_items w
    set exercise_id = m.keeper_id
    from _ex_dedup_map m
    where w.exercise_id = m.duplicate_id;
  end if;

  if to_regclass('public.day_workout_exercises') is not null then
    update public.day_workout_exercises d
    set exercise_id = m.keeper_id
    from _ex_dedup_map m
    where d.exercise_id = m.duplicate_id;
  end if;

  delete from public.exercises e
  using _ex_dedup_map m
  where e.id = m.duplicate_id;
end $$;

create unique index if not exists exercises_unique_normalized_name
  on public.exercises (lower(trim(name)));

-- -----------------------------
-- ÍNDICES
-- -----------------------------

create index if not exists idx_exercises_muscle_group_id
  on public.exercises(muscle_group_id);

create index if not exists idx_students_created_by
  on public.students(created_by_personal_id);

create index if not exists idx_wsi_block
  on public.week_schedule_items(block_id);

create index if not exists idx_dw_student_date
  on public.day_workouts(student_id, day_date);

create index if not exists idx_dwe_workout
  on public.day_workout_exercises(day_workout_id);

create index if not exists idx_wge_group_order
  on public.workout_group_exercises(workout_group_id, sort_order);

create index if not exists idx_anamnese_sessions_student_created
  on public.anamnese_sessions(student_id, created_at desc);

create unique index if not exists idx_anamnese_answers_session_key
  on public.anamnese_answers(session_id, question_key);

create index if not exists idx_anamnese_answers_session_order
  on public.anamnese_answers(session_id, question_order);

create index if not exists idx_reports_student_created
  on public.student_performance_reports(student_id, created_at desc);

-- -----------------------------
-- TRIGGERS (updated_at)
-- -----------------------------

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_muscle_groups_updated_at on public.muscle_groups;
create trigger trg_muscle_groups_updated_at
before update on public.muscle_groups
for each row execute function public.set_updated_at();

drop trigger if exists trg_exercises_updated_at on public.exercises;
create trigger trg_exercises_updated_at
before update on public.exercises
for each row execute function public.set_updated_at();

drop trigger if exists trg_gyms_updated_at on public.gyms;
create trigger trg_gyms_updated_at
before update on public.gyms
for each row execute function public.set_updated_at();

drop trigger if exists trg_personals_updated_at on public.personals;
create trigger trg_personals_updated_at
before update on public.personals
for each row execute function public.set_updated_at();

drop trigger if exists trg_students_updated_at on public.students;
create trigger trg_students_updated_at
before update on public.students
for each row execute function public.set_updated_at();

drop trigger if exists trg_training_methods_updated_at on public.training_methods;
create trigger trg_training_methods_updated_at
before update on public.training_methods
for each row execute function public.set_updated_at();

drop trigger if exists trg_workout_groups_updated_at on public.workout_groups;
create trigger trg_workout_groups_updated_at
before update on public.workout_groups
for each row execute function public.set_updated_at();

drop trigger if exists trg_week_schedule_blocks_updated_at on public.week_schedule_blocks;
create trigger trg_week_schedule_blocks_updated_at
before update on public.week_schedule_blocks
for each row execute function public.set_updated_at();

drop trigger if exists trg_day_workouts_updated_at on public.day_workouts;
create trigger trg_day_workouts_updated_at
before update on public.day_workouts
for each row execute function public.set_updated_at();

drop trigger if exists trg_anamnese_sessions_updated_at on public.anamnese_sessions;
create trigger trg_anamnese_sessions_updated_at
before update on public.anamnese_sessions
for each row execute function public.set_updated_at();

-- -----------------------------
-- VIEWS ÚTEIS
-- -----------------------------

create or replace view public.v_student_latest_anamnese as
select distinct on (s.student_id)
  s.student_id,
  s.id as session_id,
  s.created_at as filled_at
from public.anamnese_sessions s
order by s.student_id, s.created_at desc;

-- -----------------------------
-- RLS (DEV) + POLÍTICAS PERMISSIVAS
-- -----------------------------
-- ATENÇÃO: em produção, substitua por políticas restritivas por usuário/tenant.

alter table public.muscle_groups enable row level security;
alter table public.exercises enable row level security;
alter table public.gyms enable row level security;
alter table public.personals enable row level security;
alter table public.students enable row level security;
alter table public.student_gyms enable row level security;
alter table public.training_methods enable row level security;
alter table public.workout_groups enable row level security;
alter table public.workout_group_exercises enable row level security;
alter table public.week_schedule_blocks enable row level security;
alter table public.week_schedule_items enable row level security;
alter table public.day_workouts enable row level security;
alter table public.day_workout_exercises enable row level security;
alter table public.audit_logs enable row level security;
alter table public.anamnese_sessions enable row level security;
alter table public.anamnese_answers enable row level security;
alter table public.student_performance_reports enable row level security;

do $$
declare
  t text;
begin
  for t in
    select unnest(array[
      'muscle_groups',
      'exercises',
      'gyms',
      'personals',
      'students',
      'student_gyms',
      'training_methods',
      'workout_groups',
      'workout_group_exercises',
      'week_schedule_blocks',
      'week_schedule_items',
      'day_workouts',
      'day_workout_exercises',
      'audit_logs',
      'anamnese_sessions',
      'anamnese_answers',
      'student_performance_reports'
    ])
  loop
    execute format('drop policy if exists app_sync_anon_all on public.%I', t);
    execute format('drop policy if exists app_sync_authenticated_all on public.%I', t);
    execute format(
      'create policy app_sync_anon_all on public.%I for all to anon using (true) with check (true)',
      t
    );
    execute format(
      'create policy app_sync_authenticated_all on public.%I for all to authenticated using (true) with check (true)',
      t
    );
  end loop;
end $$;

grant usage on schema public to anon;
grant usage on schema public to authenticated;
grant select, insert, update, delete on all tables in schema public to anon;
grant select, insert, update, delete on all tables in schema public to authenticated;


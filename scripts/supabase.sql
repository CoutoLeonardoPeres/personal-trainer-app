-- =============================================================================
-- Supabase / Postgres — único script SQL do projeto (schema + migrações + reparo)
-- =============================================================================
-- Execute no Supabase Dashboard → SQL Editor. Idempotente: pode rodar várias vezes.
--
-- Colunas: usa ADD IF NOT EXISTS onde basta; para `rest_between_sets_sec` também
-- corrige tipo (→ integer), preenche NULLs, alinha DEFAULT 60 e NOT NULL.
--
-- RLS permissivo (anon/authenticated) é para desenvolvimento/sync; em produção,
-- substitua por políticas restritivas.
--
-- Paridade SQLite (Drift) ↔ nuvem (envio completo + sync incremental):
--   muscle_groups, exercises, gyms, personals, students, student_gyms,
--   training_methods, workout_groups, workout_group_exercises,
--   week_schedule_blocks, week_schedule_items, day_workouts,
--   day_workout_exercises, audit_logs
-- Reconciliação de id por nome normalizado (evita 23505): ver no app
--   supabase_muscle_group_cloud_reconcile.dart, supabase_exercise_cloud_reconcile.dart,
--   supabase_catalog_cloud_reconcile.dart.
-- Se a nuvem já ficou inconsistente (23505 em exercises / 23503 nas filhas), rode no
--   SQL Editor: scripts/supabase_repair_exercises_dedupe.sql
--
-- Só Postgres hoje (app não envia ainda): anamnese_sessions, anamnese_answers,
-- student_performance_reports. Anamnese no app fica em audit_logs (JSON).
-- =============================================================================

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
  phone_commercial text null,
  phone_mobile text null,
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
  phone_commercial text null,
  phone_mobile text null,
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
  updated_at timestamptz not null default now(),
  deleted_at timestamptz null
);

alter table public.workout_groups
  add column if not exists deleted_at timestamptz null;

create table if not exists public.workout_group_exercises (
  id text primary key,
  workout_group_id text not null references public.workout_groups(id) on delete cascade,
  exercise_id text not null references public.exercises(id) on delete restrict,
  sort_order integer not null default 0,
  last_load_kg double precision null,
  last_reps integer null,
  last_reps_text text null,
  last_sets integer null,
  rest_between_sets_sec integer not null default 60,
  training_method_id text null references public.training_methods(id) on delete set null,
  updated_at timestamptz not null default now()
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
  reps_text text null,
  load_kg double precision null,
  needs_detail boolean not null default false,
  rest_between_sets_sec integer not null default 60,
  training_method_id text null references public.training_methods(id) on delete set null,
  updated_at timestamptz not null default now()
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
  source_workout_group_id text null,
  watch_calories_kcal double precision null,
  watch_avg_heart_rate_bpm integer null
);

create table if not exists public.day_workout_exercises (
  id text primary key,
  day_workout_id text not null references public.day_workouts(id) on delete cascade,
  exercise_id text not null references public.exercises(id) on delete restrict,
  sort_order integer not null default 0,
  sets integer not null,
  reps integer not null,
  reps_text text null,
  load_kg double precision null,
  exercise_score double precision null,
  performed_sets_json text null,
  rest_between_sets_sec integer not null default 60,
  training_method_id text null references public.training_methods(id) on delete set null,
  updated_at timestamptz not null default now()
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
-- (cópia só destas linhas para projetos antigos: scripts/supabase_migrate_planning_tables.sql)
-- -----------------------------

alter table public.personals add column if not exists cep text;
alter table public.personals add column if not exists phone_commercial text;
alter table public.personals add column if not exists phone_mobile text;
alter table public.students add column if not exists phone_commercial text;
alter table public.students add column if not exists phone_mobile text;
alter table public.workout_group_exercises add column if not exists last_reps_text text;

alter table public.workout_group_exercises
  add column if not exists training_method_id text null
  references public.training_methods(id) on delete set null;

alter table public.week_schedule_items
  add column if not exists reps_text text null;

alter table public.week_schedule_items
  add column if not exists training_method_id text null
  references public.training_methods(id) on delete set null;

alter table public.day_workout_exercises
  add column if not exists reps_text text null;

alter table public.day_workout_exercises
  add column if not exists training_method_id text null
  references public.training_methods(id) on delete set null;

alter table public.workout_group_exercises add column if not exists combo_id text null;
alter table public.week_schedule_items add column if not exists combo_id text null;
alter table public.day_workout_exercises add column if not exists combo_id text null;

-- RBAC + ligação Supabase Auth (paridade scripts/supabase_rbac_columns_rls.sql e supabase_rls_strict_auth_uid.sql)
alter table public.personals
  add column if not exists access_tier text not null default 'legacy';
alter table public.personals
  add column if not exists max_students_cap integer null;
alter table public.students
  add column if not exists anamnese_completed boolean not null default true;
alter table public.students
  add column if not exists access_tier text not null default 'legacy';
alter table public.personals
  add column if not exists auth_user_id uuid unique references auth.users (id) on delete set null;
alter table public.students
  add column if not exists auth_user_id uuid unique references auth.users (id) on delete set null;
alter table public.students
  add column if not exists premium_plan_expires_at timestamptz null;
-- Paridade com o app (aluno «inativo» / arquivado — listas ativas filtram por is_archived).
alter table public.students
  add column if not exists is_archived boolean not null default false;
alter table public.students
  add column if not exists archived_at timestamptz null;
-- Opcional (uma vez): corrigir linhas antigas em que o nome tem prefixo de inativo mas is_archived ficou false.
update public.students s
set
  is_archived = true,
  archived_at = coalesce(s.archived_at, s.updated_at)
where s.is_archived = false
  and (s.name like '(Inativo)%' or s.name like '(Excluído)%');
create index if not exists idx_personals_auth_user_id on public.personals (auth_user_id);
create index if not exists idx_students_auth_user_id on public.students (auth_user_id);

-- Descanso entre séries (segundos): cria se faltar; se existir com tipo/default errados, alinha.
do $$
declare
  t text;
  dt text;
begin
  foreach t in array array[
    'workout_group_exercises',
    'week_schedule_items',
    'day_workout_exercises'
  ]::text[]
  loop
    if to_regclass('public.' || t) is null then
      continue;
    end if;
    if not exists (
      select 1
      from information_schema.columns c
      where c.table_schema = 'public'
        and c.table_name = t
        and c.column_name = 'rest_between_sets_sec'
    ) then
      execute format(
        'alter table public.%I add column rest_between_sets_sec integer not null default 60',
        t
      );
    else
      select c.data_type into dt
      from information_schema.columns c
      where c.table_schema = 'public'
        and c.table_name = t
        and c.column_name = 'rest_between_sets_sec';
      if dt is distinct from 'integer' then
        execute format(
          $s$
          alter table public.%I
            alter column rest_between_sets_sec type integer
            using (trim(both from rest_between_sets_sec::text))::integer
          $s$,
          t
        );
      end if;
      execute format(
        'update public.%I set rest_between_sets_sec = 60 where rest_between_sets_sec is null',
        t
      );
      execute format(
        'alter table public.%I alter column rest_between_sets_sec set default 60',
        t
      );
      execute format(
        'alter table public.%I alter column rest_between_sets_sec set not null',
        t
      );
    end if;
  end loop;
end $$;

comment on column public.workout_group_exercises.rest_between_sets_sec is
  'Intervalo prescrito entre séries neste exercício do modelo de grupo (segundos).';
comment on column public.week_schedule_items.rest_between_sets_sec is
  'Intervalo entre séries no planejamento semanal (segundos); pode divergir do grupo.';
comment on column public.day_workout_exercises.rest_between_sets_sec is
  'Intervalo entre séries no treino agendado (segundos); cópia do planejamento na programação.';

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

-- Colunas updated_at em tabelas criadas antes desta revisão (idempotente).
alter table public.workout_group_exercises
  add column if not exists updated_at timestamptz not null default now();
alter table public.week_schedule_items
  add column if not exists updated_at timestamptz not null default now();
alter table public.day_workout_exercises
  add column if not exists updated_at timestamptz not null default now();

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

drop trigger if exists trg_week_schedule_items_updated_at on public.week_schedule_items;
create trigger trg_week_schedule_items_updated_at
before update on public.week_schedule_items
for each row execute function public.set_updated_at();

drop trigger if exists trg_workout_group_exercises_updated_at on public.workout_group_exercises;
create trigger trg_workout_group_exercises_updated_at
before update on public.workout_group_exercises
for each row execute function public.set_updated_at();

drop trigger if exists trg_day_workout_exercises_updated_at on public.day_workout_exercises;
create trigger trg_day_workout_exercises_updated_at
before update on public.day_workout_exercises
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
-- Políticas com auth.uid() + anamnese: scripts/supabase_rls_strict_auth_uid.sql

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

-- =============================================================================
-- Reparo de integridade referencial (23503 / sync / linhas órfãs)
-- Idempotente. Remove ou corrige linhas que violam FK; o app pode reenviar do SQLite.
-- =============================================================================

update public.students s
set created_by_personal_id = null
where s.created_by_personal_id is not null
  and not exists (
    select 1 from public.personals p where p.id = s.created_by_personal_id
  );

insert into public.muscle_groups (id, name, created_at, updated_at)
values (
  '__sync_orphan_muscle_group__',
  '(Correção sync) Grupo indeterminado',
  now(),
  now()
)
on conflict (id) do nothing;

update public.exercises e
set muscle_group_id = '__sync_orphan_muscle_group__',
    updated_at = now()
where not exists (
  select 1 from public.muscle_groups mg where mg.id = e.muscle_group_id
);

update public.week_schedule_items i
set source_workout_group_id = null
where i.source_workout_group_id is not null
  and not exists (
    select 1 from public.workout_groups g where g.id = i.source_workout_group_id
  );

update public.day_workouts dw
set source_workout_group_id = null
where dw.source_workout_group_id is not null
  and not exists (
    select 1 from public.workout_groups g where g.id = dw.source_workout_group_id
  );

update public.day_workouts dw
set week_item_id = null
where dw.week_item_id is not null
  and not exists (
    select 1 from public.week_schedule_items wsi where wsi.id = dw.week_item_id
  );

delete from public.workout_group_exercises w
where not exists (select 1 from public.workout_groups g where g.id = w.workout_group_id)
   or not exists (select 1 from public.exercises x where x.id = w.exercise_id);

delete from public.week_schedule_items i
where not exists (select 1 from public.week_schedule_blocks b where b.id = i.block_id)
   or not exists (select 1 from public.exercises x where x.id = i.exercise_id);

delete from public.week_schedule_blocks b
where not exists (select 1 from public.students s where s.id = b.student_id);

delete from public.day_workout_exercises d
where not exists (select 1 from public.day_workouts w where w.id = d.day_workout_id)
   or not exists (select 1 from public.exercises x where x.id = d.exercise_id);

delete from public.day_workouts dw
where not exists (select 1 from public.students s where s.id = dw.student_id);

delete from public.student_gyms sg
where not exists (select 1 from public.students s where s.id = sg.student_id)
   or not exists (select 1 from public.gyms g where g.id = sg.gym_id);

do $$
begin
  if to_regclass('public.anamnese_answers') is not null then
    delete from public.anamnese_answers a
    where not exists (
      select 1 from public.anamnese_sessions sess where sess.id = a.session_id
    );
  end if;

  if to_regclass('public.anamnese_sessions') is not null then
    delete from public.anamnese_sessions sess
    where not exists (
      select 1 from public.students s where s.id = sess.student_id
    );
  end if;

  if to_regclass('public.student_performance_reports') is not null then
    delete from public.student_performance_reports r
    where not exists (
      select 1 from public.students s where s.id = r.student_id
    );
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- Migração: colunas opcionais do relógio em treinos concluídos (aluno).
-- Executar no SQL Editor do Supabase em projetos criados antes desta alteração.
-- Idempotente: pode voltar a correr sem erro se as colunas já existirem.
-- ---------------------------------------------------------------------------
alter table public.day_workouts
  add column if not exists watch_calories_kcal double precision null;
alter table public.day_workouts
  add column if not exists watch_avg_heart_rate_bpm integer null;

-- ---------------------------------------------------------------------------
-- Nota (app: resumo ao concluir séries de um exercício no calendário)
-- A comparação «último treino concluído vs atual» usa apenas dados já existentes:
--   day_workout_exercises.performed_sets_json (carga, reps, logged_at_ms,
--   rest_prescribed_sec, rest_countdown_elapsed_ms, post_rest_modal_ms),
--   day_workout_exercises.exercise_score,
--   day_workouts.watch_calories_kcal (estimativa proporcional por exercício).
-- Não é obrigatória nenhuma migração adicional no Supabase para esta funcionalidade.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- Migração robusta de sync offline-first (treino/séries).
-- Garante versionamento por revisão + metadados de dispositivo/sync para merge LWW.
-- Idempotente.
-- ---------------------------------------------------------------------------
alter table public.day_workouts
  add column if not exists revision integer not null default 0;
alter table public.day_workouts
  add column if not exists last_modified_by_device_id text null;
alter table public.day_workouts
  add column if not exists sync_status text not null default 'synced';
alter table public.day_workouts
  add column if not exists deleted_at timestamptz null;

alter table public.day_workout_exercises
  add column if not exists revision integer not null default 0;
alter table public.day_workout_exercises
  add column if not exists last_modified_by_device_id text null;
alter table public.day_workout_exercises
  add column if not exists sync_status text not null default 'synced';
alter table public.day_workout_exercises
  add column if not exists deleted_at timestamptz null;

create index if not exists day_workouts_sync_merge_idx
  on public.day_workouts (id, revision, updated_at);

create index if not exists day_workout_exercises_sync_merge_idx
  on public.day_workout_exercises (id, revision, updated_at);

create index if not exists day_workouts_student_updated_idx
  on public.day_workouts (student_id, updated_at desc);

create index if not exists day_workout_exercises_workout_updated_idx
  on public.day_workout_exercises (day_workout_id, updated_at desc);

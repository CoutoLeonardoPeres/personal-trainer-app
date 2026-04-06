-- Schema espelho do app (Drift/SQLite) para Supabase Postgres.
-- Projeto Supabase: PersonalTreiner
-- Project ref: onmzbyltmbdkuodirfow → URL: https://onmzbyltmbdkuodirfow.supabase.co
--
-- Uso: Supabase Dashboard → SQL Editor → colar e executar.
-- Depois configure RLS conforme sua política de auth (abaixo há políticas de desenvolvimento para role anon).

-- Limpar se quiser reinstalar (cuidado: apaga dados remotos)
-- DROP TABLE IF EXISTS audit_logs, day_workout_exercises, day_workouts, week_schedule_items,
--   week_schedule_blocks, workout_group_exercises, workout_groups, training_methods,
--   student_gyms, students, personals, gyms, exercises, muscle_groups CASCADE;

CREATE TABLE IF NOT EXISTS muscle_groups (
  id text PRIMARY KEY,
  name text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Índice único de nomes normalizados será criado após deduplicação automática
-- (para bases já populadas).

CREATE TABLE IF NOT EXISTS exercises (
  id text PRIMARY KEY,
  name text NOT NULL,
  muscle_group_id text NOT NULL REFERENCES muscle_groups (id) ON DELETE RESTRICT,
  video_url text,
  alternative_note text,
  alternative_video_url text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Deduplica grupos musculares por nome normalizado e reaponta FKs de exercises
-- antes de criar o índice único.
DO $$
BEGIN
  CREATE TEMP TABLE _mg_dedup_map ON COMMIT DROP AS
  WITH ranked AS (
    SELECT
      id,
      lower(trim(name)) AS norm_name,
      row_number() OVER (
        PARTITION BY lower(trim(name))
        ORDER BY created_at ASC, id ASC
      ) AS rn,
      first_value(id) OVER (
        PARTITION BY lower(trim(name))
        ORDER BY created_at ASC, id ASC
      ) AS keeper_id
    FROM public.muscle_groups
  )
  SELECT id AS duplicate_id, keeper_id
  FROM ranked
  WHERE rn > 1;

  IF to_regclass('public.exercises') IS NOT NULL THEN
    UPDATE public.exercises e
    SET muscle_group_id = m.keeper_id
    FROM _mg_dedup_map m
    WHERE e.muscle_group_id = m.duplicate_id;
  END IF;

  DELETE FROM public.muscle_groups g
  USING _mg_dedup_map m
  WHERE g.id = m.duplicate_id;
END $$;

-- Evita duplicar o mesmo grupo (ex.: "Peitoral" e "peitoral").
CREATE UNIQUE INDEX IF NOT EXISTS muscle_groups_unique_normalized_name
  ON muscle_groups (lower(trim(name)));

-- Deduplica exercícios por nome normalizado e reaponta FKs nas tabelas que referenciam exercises.
DO $$
BEGIN
  CREATE TEMP TABLE _ex_dedup_map ON COMMIT DROP AS
  WITH ranked AS (
    SELECT
      id,
      lower(trim(name)) AS norm_name,
      row_number() OVER (
        PARTITION BY lower(trim(name))
        ORDER BY created_at ASC, id ASC
      ) AS rn,
      first_value(id) OVER (
        PARTITION BY lower(trim(name))
        ORDER BY created_at ASC, id ASC
      ) AS keeper_id
    FROM public.exercises
  )
  SELECT id AS duplicate_id, keeper_id
  FROM ranked
  WHERE rn > 1;

  IF to_regclass('public.workout_group_exercises') IS NOT NULL THEN
    UPDATE public.workout_group_exercises w
    SET exercise_id = m.keeper_id
    FROM _ex_dedup_map m
    WHERE w.exercise_id = m.duplicate_id;
  END IF;

  IF to_regclass('public.week_schedule_items') IS NOT NULL THEN
    UPDATE public.week_schedule_items w
    SET exercise_id = m.keeper_id
    FROM _ex_dedup_map m
    WHERE w.exercise_id = m.duplicate_id;
  END IF;

  IF to_regclass('public.day_workout_exercises') IS NOT NULL THEN
    UPDATE public.day_workout_exercises d
    SET exercise_id = m.keeper_id
    FROM _ex_dedup_map m
    WHERE d.exercise_id = m.duplicate_id;
  END IF;

  DELETE FROM public.exercises e
  USING _ex_dedup_map m
  WHERE e.id = m.duplicate_id;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS exercises_unique_normalized_name
  ON exercises (lower(trim(name)));

CREATE TABLE IF NOT EXISTS gyms (
  id text PRIMARY KEY,
  name text NOT NULL,
  cnpj text NOT NULL,
  street text NOT NULL,
  number text NOT NULL,
  complement text,
  district text NOT NULL,
  city text NOT NULL,
  state_uf text NOT NULL,
  cep text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS personals (
  id text PRIMARY KEY,
  name text NOT NULL,
  cpf text NOT NULL,
  professional_registry text NOT NULL,
  street text NOT NULL,
  number text NOT NULL,
  complement text,
  city text NOT NULL,
  state_uf text NOT NULL,
  cep text,
  email text NOT NULL,
  must_change_password boolean NOT NULL DEFAULT true,
  password_hash text,
  is_admin boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS students (
  id text PRIMARY KEY,
  name text NOT NULL,
  email text,
  goal text,
  cpf text,
  birth_date timestamptz,
  street text,
  number text,
  complement text,
  district text,
  city text,
  state_uf text,
  cep text,
  must_change_password boolean NOT NULL DEFAULT true,
  password_hash text,
  created_by_personal_id text REFERENCES personals (id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS student_gyms (
  student_id text NOT NULL REFERENCES students (id) ON DELETE CASCADE,
  gym_id text NOT NULL REFERENCES gyms (id) ON DELETE CASCADE,
  PRIMARY KEY (student_id, gym_id)
);

CREATE TABLE IF NOT EXISTS training_methods (
  id text PRIMARY KEY,
  method text NOT NULL,
  description text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS workout_groups (
  id text PRIMARY KEY,
  name text NOT NULL,
  description text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS workout_group_exercises (
  id text PRIMARY KEY,
  workout_group_id text NOT NULL REFERENCES workout_groups (id) ON DELETE CASCADE,
  exercise_id text NOT NULL REFERENCES exercises (id) ON DELETE RESTRICT,
  sort_order integer NOT NULL DEFAULT 0,
  last_load_kg double precision,
  last_reps integer,
  last_reps_text text,
  last_sets integer
);

CREATE TABLE IF NOT EXISTS week_schedule_blocks (
  id text PRIMARY KEY,
  student_id text NOT NULL REFERENCES students (id) ON DELETE CASCADE,
  week_start_monday timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS week_schedule_items (
  id text PRIMARY KEY,
  block_id text NOT NULL REFERENCES week_schedule_blocks (id) ON DELETE CASCADE,
  exercise_id text NOT NULL REFERENCES exercises (id) ON DELETE RESTRICT,
  source_workout_group_id text,
  sort_order integer NOT NULL DEFAULT 0,
  sets integer NOT NULL DEFAULT 0,
  reps integer NOT NULL DEFAULT 0,
  load_kg double precision,
  needs_detail boolean NOT NULL DEFAULT false
);

CREATE TABLE IF NOT EXISTS day_workouts (
  id text PRIMARY KEY,
  student_id text NOT NULL REFERENCES students (id) ON DELETE CASCADE,
  day_date timestamptz NOT NULL,
  status text NOT NULL,
  week_item_id text,
  active_duration_seconds integer NOT NULL DEFAULT 0,
  workout_score double precision,
  started_at timestamptz,
  completed_at timestamptz,
  timer_resume_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  source_workout_group_id text
);

CREATE TABLE IF NOT EXISTS day_workout_exercises (
  id text PRIMARY KEY,
  day_workout_id text NOT NULL REFERENCES day_workouts (id) ON DELETE CASCADE,
  exercise_id text NOT NULL REFERENCES exercises (id) ON DELETE RESTRICT,
  sort_order integer NOT NULL DEFAULT 0,
  sets integer NOT NULL,
  reps integer NOT NULL,
  load_kg double precision,
  exercise_score double precision,
  performed_sets_json text
);

CREATE TABLE IF NOT EXISTS audit_logs (
  id text PRIMARY KEY,
  at timestamptz NOT NULL DEFAULT now(),
  action text NOT NULL,
  entity_type text NOT NULL,
  entity_id text,
  payload_json text
);

CREATE INDEX IF NOT EXISTS idx_exercises_muscle_group_id ON exercises (muscle_group_id);
CREATE INDEX IF NOT EXISTS idx_students_created_by ON students (created_by_personal_id);
CREATE INDEX IF NOT EXISTS idx_week_schedule_items_block ON week_schedule_items (block_id);
CREATE INDEX IF NOT EXISTS idx_day_workouts_student_date ON day_workouts (student_id, day_date);
CREATE INDEX IF NOT EXISTS idx_day_workout_exercises_workout ON day_workout_exercises (day_workout_id);

-- ——— RLS (desenvolvimento / sync com chave anon no app) ———
--
-- O Security Advisor do Supabase pode listar WARN `rls_policy_always_true`
-- (lint 0024 permissive_rls_policy): políticas FOR ALL com USING (true) e
-- WITH CHECK (true) para `anon` (e abaixo para `authenticated`) são de propósito —
-- permitem que o app Flutter sincronize via PostgREST sem Supabase Auth ainda.
-- Isso NÃO é um erro de runtime; em produção você deve substituir por políticas
-- restritivas (ex.: auth.uid(), tenant_id, ou sync só via Edge Function + service_role).
--
-- No painel: Advisors → Security → você pode marcar como revisado / snooze se
-- aceitar esse risco apenas em ambiente de testes.
--
-- Documentação: https://supabase.com/docs/guides/database/database-linter?lint=0024_permissive_rls_policy
-- ———
ALTER TABLE muscle_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE exercises ENABLE ROW LEVEL SECURITY;
ALTER TABLE gyms ENABLE ROW LEVEL SECURITY;
ALTER TABLE personals ENABLE ROW LEVEL SECURITY;
ALTER TABLE students ENABLE ROW LEVEL SECURITY;
ALTER TABLE student_gyms ENABLE ROW LEVEL SECURITY;
ALTER TABLE training_methods ENABLE ROW LEVEL SECURITY;
ALTER TABLE workout_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE workout_group_exercises ENABLE ROW LEVEL SECURITY;
ALTER TABLE week_schedule_blocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE week_schedule_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE day_workouts ENABLE ROW LEVEL SECURITY;
ALTER TABLE day_workout_exercises ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

DO $$
DECLARE
  t text;
BEGIN
  FOR t IN SELECT unnest(ARRAY[
    'muscle_groups', 'exercises', 'gyms', 'personals', 'students', 'student_gyms',
    'training_methods', 'workout_groups', 'workout_group_exercises',
    'week_schedule_blocks', 'week_schedule_items', 'day_workouts', 'day_workout_exercises',
    'audit_logs'
  ])
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS app_sync_anon_all ON public.%I', t);
    EXECUTE format('DROP POLICY IF EXISTS app_sync_authenticated_all ON public.%I', t);
    EXECUTE format(
      'CREATE POLICY app_sync_anon_all ON public.%I FOR ALL TO anon USING (true) WITH CHECK (true)',
      t
    );
    EXECUTE format(
      'CREATE POLICY app_sync_authenticated_all ON public.%I FOR ALL TO authenticated USING (true) WITH CHECK (true)',
      t
    );
  END LOOP;
END $$;

GRANT USAGE ON SCHEMA public TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO authenticated;

-- ——— Migração: CEP em personals (projetos que criaram `personals` antes desta coluna) ———
ALTER TABLE public.personals ADD COLUMN IF NOT EXISTS cep text;

-- ——— Migração: repetições como texto (ex.: 12-15) em linhas de grupo ———
ALTER TABLE public.workout_group_exercises ADD COLUMN IF NOT EXISTS last_reps_text text;

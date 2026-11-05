begin;

create table public.personals (
  id uuid primary key,
  tenant_id uuid not null,
  name text,
  cpf text,
  professional_registry text,
  street text,
  number text,
  complement text,
  city text,
  state_uf text,
  cep text,
  email text,
  phone_commercial text,
  phone_mobile text,
  must_change_password boolean,
  auth_user_id uuid unique references auth.users(id) on delete set null,
  is_admin boolean,
  access_tier text,
  max_students_cap integer,
  field_hlc jsonb not null default '{}'::jsonb,
  created_hlc text not null,
  deleted_at timestamptz,
  deleted_hlc text,
  updated_seq bigint
);

create table public.muscle_groups (
  id uuid primary key, tenant_id uuid not null, name text,
  field_hlc jsonb not null default '{}'::jsonb, created_hlc text not null,
  deleted_at timestamptz, deleted_hlc text, updated_seq bigint
);

create table public.exercises (
  id uuid primary key, tenant_id uuid not null, name text, muscle_group_id uuid,
  video_url text, alternative_note text, alternative_video_url text,
  field_hlc jsonb not null default '{}'::jsonb, created_hlc text not null,
  deleted_at timestamptz, deleted_hlc text, updated_seq bigint
);

create table public.gyms (
  id uuid primary key, tenant_id uuid not null, name text, cnpj text, street text,
  number text, complement text, district text, city text, state_uf text, cep text,
  field_hlc jsonb not null default '{}'::jsonb, created_hlc text not null,
  deleted_at timestamptz, deleted_hlc text, updated_seq bigint
);

create table public.students (
  id uuid primary key, tenant_id uuid not null, name text, is_archived boolean,
  archived_at timestamptz, email text, goal text, cpf text, birth_date date,
  street text, number text, complement text, district text, city text,
  state_uf text, cep text, phone_commercial text, phone_mobile text,
  must_change_password boolean, auth_user_id uuid unique references auth.users(id) on delete set null,
  created_by_personal_id uuid, anamnese_completed boolean, access_tier text,
  premium_plan_expires_at timestamptz,
  field_hlc jsonb not null default '{}'::jsonb, created_hlc text not null,
  deleted_at timestamptz, deleted_hlc text, updated_seq bigint
);

create table public.student_gyms (
  id uuid primary key, tenant_id uuid not null, student_id uuid, gym_id uuid,
  field_hlc jsonb not null default '{}'::jsonb, created_hlc text not null,
  deleted_at timestamptz, deleted_hlc text, updated_seq bigint,
  unique (tenant_id, student_id, gym_id)
);

create table public.training_methods (
  id uuid primary key, tenant_id uuid not null, method text, description text,
  field_hlc jsonb not null default '{}'::jsonb, created_hlc text not null,
  deleted_at timestamptz, deleted_hlc text, updated_seq bigint
);

create table public.workout_groups (
  id uuid primary key, tenant_id uuid not null, name text, description text,
  created_by_personal_id uuid, is_shared boolean,
  field_hlc jsonb not null default '{}'::jsonb, created_hlc text not null,
  deleted_at timestamptz, deleted_hlc text, updated_seq bigint
);

create table public.workout_group_exercises (
  id uuid primary key, tenant_id uuid not null, workout_group_id uuid, exercise_id uuid,
  position text, sort_order integer, last_load_kg numeric, last_reps integer,
  last_reps_text text, last_sets integer, rest_between_sets_sec integer,
  training_method_id uuid, combo_id uuid,
  field_hlc jsonb not null default '{}'::jsonb, created_hlc text not null,
  deleted_at timestamptz, deleted_hlc text, updated_seq bigint
);

create table public.week_schedule_blocks (
  id uuid primary key, tenant_id uuid not null, student_id uuid, week_start_monday date,
  field_hlc jsonb not null default '{}'::jsonb, created_hlc text not null,
  deleted_at timestamptz, deleted_hlc text, updated_seq bigint
);

create table public.week_schedule_items (
  id uuid primary key, tenant_id uuid not null, block_id uuid, exercise_id uuid,
  source_workout_group_id uuid, position text, sort_order integer, sets integer,
  reps integer, reps_text text, load_kg numeric, needs_detail boolean,
  rest_between_sets_sec integer, training_method_id uuid, combo_id uuid,
  field_hlc jsonb not null default '{}'::jsonb, created_hlc text not null,
  deleted_at timestamptz, deleted_hlc text, updated_seq bigint
);

create table public.day_workouts (
  id uuid primary key, tenant_id uuid not null, student_id uuid, day_date date,
  status text check (status is null or status in ('programado','em_andamento','concluido','cancelado')),
  week_item_id uuid, active_duration_seconds integer, workout_score numeric,
  started_at timestamptz, completed_at timestamptz, timer_resume_at timestamptz,
  source_workout_group_id uuid, watch_calories_kcal numeric,
  watch_avg_heart_rate_bpm integer,
  field_hlc jsonb not null default '{}'::jsonb, created_hlc text not null,
  deleted_at timestamptz, deleted_hlc text, updated_seq bigint
);

create table public.day_workout_exercises (
  id uuid primary key, tenant_id uuid not null, day_workout_id uuid, exercise_id uuid,
  position text, sort_order integer, sets integer, reps integer, reps_text text,
  load_kg numeric, exercise_score numeric, rest_between_sets_sec integer,
  training_method_id uuid, combo_id uuid,
  field_hlc jsonb not null default '{}'::jsonb, created_hlc text not null,
  deleted_at timestamptz, deleted_hlc text, updated_seq bigint
);

create table public.performed_set_events (
  id uuid primary key,
  tenant_id uuid not null,
  day_workout_exercise_id uuid not null,
  student_id uuid not null,
  kind text not null check (kind in ('logged','amended','voided')),
  target_set_id uuid,
  reps integer,
  load_kg numeric,
  rpe numeric,
  note text,
  hlc text not null,
  origin_device uuid not null,
  device_seq bigint not null,
  server_seq bigint not null,
  check ((kind = 'logged' and target_set_id is null) or (kind in ('amended','voided') and target_set_id is not null)),
  unique (tenant_id, server_seq)
);

create table public.workout_timer_events (
  id uuid primary key,
  tenant_id uuid not null,
  day_workout_id uuid not null,
  student_id uuid not null,
  kind text not null check (kind in ('start','pause','resume','finish')),
  hlc text not null,
  origin_device uuid not null,
  device_seq bigint not null,
  server_seq bigint not null,
  unique (tenant_id, server_seq)
);

create table public.ai_consents (
  id uuid primary key default extensions.gen_random_uuid(),
  tenant_id uuid not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  policy_version text not null,
  purpose text not null,
  provider text not null,
  granted_at timestamptz not null default now(),
  revoked_at timestamptz
);

create index students_tenant_auth_idx on public.students (tenant_id, auth_user_id);
create index day_workouts_tenant_student_idx on public.day_workouts (tenant_id, student_id);
create index set_events_exercise_order_idx on public.performed_set_events
  (tenant_id, day_workout_exercise_id, hlc, origin_device, device_seq);
create index timer_events_workout_order_idx on public.workout_timer_events
  (tenant_id, day_workout_id, hlc, origin_device, device_seq);

commit;

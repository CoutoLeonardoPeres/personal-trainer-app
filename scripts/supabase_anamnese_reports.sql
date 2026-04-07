-- Anamnese + relatórios por aluno (Supabase/Postgres)
-- Execute no SQL Editor do Supabase.

create extension if not exists "pgcrypto";

create table if not exists public.anamnese_sessions (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.students(id) on delete cascade,
  filled_by uuid null,
  filled_by_name text null,
  notes text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists anamnese_sessions_student_created_idx
  on public.anamnese_sessions(student_id, created_at desc);

create table if not exists public.anamnese_answers (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.anamnese_sessions(id) on delete cascade,
  section_name text not null,
  question_order int not null,
  question_key text not null,
  question_text text not null,
  answer_text text not null,
  created_at timestamptz not null default now()
);

create unique index if not exists anamnese_answers_unique_question_per_session
  on public.anamnese_answers(session_id, question_key);

create index if not exists anamnese_answers_session_order_idx
  on public.anamnese_answers(session_id, question_order);

create table if not exists public.student_performance_reports (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.students(id) on delete cascade,
  period_label text not null,
  period_start date null,
  period_end date null,
  report_text text not null,
  report_json jsonb null,
  source text not null default 'app', -- app | ai | app+ai
  created_at timestamptz not null default now()
);

create index if not exists student_performance_reports_student_created_idx
  on public.student_performance_reports(student_id, created_at desc);

-- Trigger de updated_at para sessões de anamnese
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_anamnese_sessions_updated_at on public.anamnese_sessions;
create trigger trg_anamnese_sessions_updated_at
before update on public.anamnese_sessions
for each row
execute function public.set_updated_at();

-- View útil: última anamnese por aluno
create or replace view public.v_student_latest_anamnese as
select distinct on (s.student_id)
  s.student_id,
  s.id as session_id,
  s.created_at as filled_at
from public.anamnese_sessions s
order by s.student_id, s.created_at desc;

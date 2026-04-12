-- =============================================================================
-- Migração: colunas que o app envia em workout_group_exercises, week_schedule_items
-- e day_workout_exercises mas que faltam em projetos Supabase criados antes.
--
-- Corrige PGRST204 (schema cache), ex.:
--   training_method_id em workout_group_exercises
--   reps_text em week_schedule_items / day_workout_exercises
--   combo_id, last_reps_text, etc.
--
-- Execute no Supabase → SQL Editor → Run (uma vez).
-- Depois: Settings → Data API → «Reload schema».
-- Paridade com scripts/supabase.sql (secção MIGRAÇÕES COMPATÍVEIS ~280–302).
-- =============================================================================

-- workout_group_exercises
alter table public.workout_group_exercises
  add column if not exists last_reps_text text null;

alter table public.workout_group_exercises
  add column if not exists training_method_id text null
  references public.training_methods(id) on delete set null;

alter table public.workout_group_exercises
  add column if not exists combo_id text null;

-- week_schedule_items
alter table public.week_schedule_items
  add column if not exists reps_text text null;

alter table public.week_schedule_items
  add column if not exists training_method_id text null
  references public.training_methods(id) on delete set null;

alter table public.week_schedule_items
  add column if not exists combo_id text null;

-- day_workout_exercises
alter table public.day_workout_exercises
  add column if not exists reps_text text null;

alter table public.day_workout_exercises
  add column if not exists training_method_id text null
  references public.training_methods(id) on delete set null;

alter table public.day_workout_exercises
  add column if not exists combo_id text null;

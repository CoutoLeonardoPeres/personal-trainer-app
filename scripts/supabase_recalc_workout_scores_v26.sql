-- Recalcula day_workouts.workout_score (treinos concluídos) com a fórmula v26:
-- (Σ score só exercícios concluídos) × 10 ÷ minutos_ativos × (nº concluídos).
--
-- Exercício concluído: sets > 0 e jsonb_array_length(performed_sets_json) >= sets.
-- Score da linha: Σ (load_kg × reps / 10) por entrada em performed_sets_json com reps >= 1.
--
-- Executar no SQL Editor do Supabase (service role ou utilizador com UPDATE em day_workouts).
-- Se algum performed_sets_json for JSON inválido, o cast falha — corrija essas linhas antes.

begin;

with per_line as (
  select
    dwe.day_workout_id,
    dwe.sets,
    case
      when dwe.performed_sets_json is null or btrim(dwe.performed_sets_json) = ''
        then '[]'::jsonb
      else dwe.performed_sets_json::jsonb
    end as j
  from public.day_workout_exercises dwe
),
scored as (
  select
    day_workout_id,
    sets,
    j,
    coalesce(jsonb_array_length(j), 0) as n_performed,
    coalesce(
      (
        select sum(
          (coalesce((elem->>'loadKg')::double precision, 0) *
           greatest(coalesce((elem->>'reps')::integer, 0), 0)) / 10.0
        )
        from jsonb_array_elements(j) as elem
        where coalesce((elem->>'reps')::integer, 0) >= 1
      ),
      0
    ) as line_score
  from per_line
),
agg as (
  select
    day_workout_id,
    coalesce(
      sum(line_score) filter (
        where sets > 0 and n_performed >= sets
      ),
      0
    ) as sum_done,
    count(*) filter (
      where sets > 0 and n_performed >= sets
    )::double precision as n_done
  from scored
  group by day_workout_id
)
update public.day_workouts dw
set
  workout_score = case
    when coalesce(agg.n_done, 0) <= 0 then 0
    else (
      agg.sum_done * 10.0
      / greatest(dw.active_duration_seconds::double precision / 60.0, 1.0 / 60.0)
    ) * agg.n_done
  end,
  updated_at = now()
from agg
where dw.id = agg.day_workout_id
  and dw.status = 'completed';

commit;

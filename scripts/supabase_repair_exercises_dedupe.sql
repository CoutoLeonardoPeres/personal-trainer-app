-- =============================================================================
-- Reparo Supabase: exercises_unique_normalized_name (23505) e FKs (23503)
--
-- Contexto do log:
--   - exercises: falha por duplicata em lower(trim(name)) — vários UUIDs para
--     o mesmo nome (dispositivos diferentes ou sync antigo).
--   - workout_group_exercises / week_schedule_items / day_workout_exercises:
--     FK para exercise_id que não existe em exercises (push de exercises falhou
--     ou IDs órfãos após inconsistência).
--
-- O que este script faz (idempotente, seguro repetir):
--   1) Garante grupo muscular placeholder para exercícios com FK quebrada.
--   2) Consolida exercícios duplicados por nome normalizado (mantém o mais
--      antigo: created_at, depois id) e reponta todas as FKs conhecidas.
--   3) Remove linhas filhas que ainda referenciam exercise_id inexistente
--      (o app pode reenviar do SQLite após sync bem-sucedido).
--
-- O que NÃO corrige só no banco: se o cliente envia num único batch dois
-- exercícios com o mesmo nome e IDs diferentes, o PostgREST ainda pode
-- retornar 23505 até o app reconciliar IDs (já tratado no código:
-- supabase_exercise_cloud_reconcile). Este script deixa a nuvem consistente
-- para o próximo push/pull.
--
-- Execução: SQL Editor do Supabase → colar → Run (recomendado em transação).
-- =============================================================================

begin;

-- Placeholder já usado em scripts/supabase.sql (integridade).
insert into public.muscle_groups (id, name, created_at, updated_at)
values (
  '__sync_orphan_muscle_group__',
  '(Correção sync) Grupo indeterminado',
  now(),
  now()
)
on conflict (id) do nothing;

update public.exercises e
set
  muscle_group_id = '__sync_orphan_muscle_group__',
  updated_at = now()
where not exists (
  select 1 from public.muscle_groups mg where mg.id = e.muscle_group_id
);

-- Mapa: duplicate_id → keeper_id (um keeper por lower(trim(name))).
create temp table _ex_dedup_map on commit drop as
with ranked as (
  select
    id,
    row_number() over (
      partition by lower(trim(name))
      order by created_at asc nulls last, id asc
    ) as rn,
    first_value(id) over (
      partition by lower(trim(name))
      order by created_at asc nulls last, id asc
    ) as keeper_id
  from public.exercises
)
select id as duplicate_id, keeper_id
from ranked
where rn > 1;

update public.workout_group_exercises w
set
  exercise_id = m.keeper_id,
  updated_at = now()
from _ex_dedup_map m
where w.exercise_id = m.duplicate_id;

update public.week_schedule_items w
set
  exercise_id = m.keeper_id,
  updated_at = now()
from _ex_dedup_map m
where w.exercise_id = m.duplicate_id;

update public.day_workout_exercises d
set
  exercise_id = m.keeper_id,
  updated_at = now()
from _ex_dedup_map m
where d.exercise_id = m.duplicate_id;

delete from public.exercises e
using _ex_dedup_map m
where e.id = m.duplicate_id;

-- Filhos que ainda apontam para exercise inexistente (após falhas de sync).
delete from public.workout_group_exercises w
where not exists (select 1 from public.exercises x where x.id = w.exercise_id);

delete from public.week_schedule_items i
where not exists (select 1 from public.exercises x where x.id = i.exercise_id);

delete from public.day_workout_exercises d
where not exists (select 1 from public.exercises x where x.id = d.exercise_id);

commit;

-- -----------------------------------------------------------------------------
-- Verificações manuais (opcional, após o commit):
--
-- Duplicatas por nome normalizado (deve retornar 0 linhas):
--   select lower(trim(name)) as n, count(*) c
--   from public.exercises
--   group by 1 having count(*) > 1;
--
-- Contagem rápida:
--   select
--     (select count(*) from public.exercises) as exercises,
--     (select count(*) from public.workout_group_exercises) as wge,
--     (select count(*) from public.week_schedule_items) as wsi,
--     (select count(*) from public.day_workout_exercises) as dwe;
-- -----------------------------------------------------------------------------

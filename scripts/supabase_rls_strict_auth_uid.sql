-- =============================================================================
-- RLS restritivo com auth.uid() — Personal Gym
-- =============================================================================
-- Pré-requisitos:
--   1) Utilizadores em auth.users (Supabase Auth) com e-mail/senha ou OAuth.
--   2) Ligar cada conta: UPDATE personals SET auth_user_id = '<uuid>' WHERE id = '...';
--      e/ou UPDATE students SET auth_user_id = '<uuid>' WHERE id = '...';
--   3) No app Flutter: após Supabase.initialize, chamar signInWithPassword (ou sessão
--      já persistida). A anon key sozinha deixa de conseguir SELECT/INSERT nas tabelas
--      quando a fase "revogar anon" estiver aplicada.
--
-- ALERTA CRÍTICO:
--   O app atual usa autenticação própria com password_hash local + AppSession.
--   Enquanto o login não chamar Supabase Auth, auth.uid() será null e estas
--   políticas bloquearão o acesso do app às tabelas. Use este script só depois
--   de migrar para Supabase Auth e preencher auth_user_id em personals/students.
--   Para MVP com login local, mantenha a service_role key fora do cliente final
--   ou faça as escritas/leitura via Edge Functions que validem a sessão local.
--
-- Modo de execução sugerido:
--   A) Correr secção 1 (colunas + funções) — seguro, não remove políticas antigas.
--   B) Testar login com JWT e queries manuais no SQL Editor (role authenticated).
--   C) Correr secção 2 (substituir políticas + revogar anon) em janela de manutenção.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1) Colunas e funções auxiliares (idempotente)
-- ---------------------------------------------------------------------------
-- RBAC + anamnese em students/personals: criar ANTES das funções (evita 42703).

alter table public.personals
  add column if not exists access_tier text not null default 'legacy';

alter table public.personals
  add column if not exists max_students_cap integer null;

alter table public.students
  add column if not exists anamnese_completed boolean not null default true;

alter table public.students
  add column if not exists access_tier text not null default 'legacy';

update public.students
set access_tier = 'legacy'
where access_tier is null or trim(access_tier) = '';

update public.personals
set access_tier = 'legacy'
where access_tier is null or trim(access_tier) = '';

alter table public.personals
  add column if not exists auth_user_id uuid unique references auth.users (id) on delete set null;

alter table public.students
  add column if not exists auth_user_id uuid unique references auth.users (id) on delete set null;

alter table public.students
  add column if not exists premium_plan_expires_at timestamptz null;

alter table public.workout_groups
  add column if not exists created_by_personal_id text null references public.personals(id) on delete set null;

alter table public.workout_groups
  add column if not exists is_shared boolean not null default false;

alter table public.workout_groups
  add column if not exists revision integer not null default 0;

alter table public.workout_groups
  add column if not exists last_modified_by_device_id text null;

alter table public.audit_logs
  add column if not exists device_id text null;

alter table public.audit_logs
  add column if not exists personal_id text null references public.personals(id) on delete set null;

alter table public.audit_logs
  add column if not exists student_id text null references public.students(id) on delete set null;

create index if not exists idx_personals_auth_user_id on public.personals (auth_user_id);
create index if not exists idx_students_auth_user_id on public.students (auth_user_id);
create index if not exists idx_workout_groups_created_by_personal
  on public.workout_groups (created_by_personal_id)
  where created_by_personal_id is not null;

create or replace function public.app_is_admin_personal () returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.personals p
    where p.auth_user_id = auth.uid()
      and p.is_admin is true
  );
$$;

create or replace function public.app_my_personal_id () returns text
language sql
stable
security definer
set search_path = public
as $$
  select p.id
  from public.personals p
  where p.auth_user_id = auth.uid()
  limit 1;
$$;

create or replace function public.app_my_student_id () returns text
language sql
stable
security definer
set search_path = public
as $$
  select s.id
  from public.students s
  where s.auth_user_id = auth.uid()
  limit 1;
$$;

create or replace function public.app_is_linked_user () returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.app_is_admin_personal()
    or public.app_my_personal_id () is not null
    or public.app_my_student_id () is not null;
$$;

-- Anamnese: aluno comercial só usa dados de treino após concluir (exceto legacy).
create or replace function public.app_student_anamnese_ok (sid text) returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (
      select st.access_tier = 'legacy'
        or coalesce(st.anamnese_completed, true)
      from public.students st
      where st.id = sid
    ),
    false
  );
$$;

create or replace function public.app_can_access_student_row (sid text) returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.app_is_admin_personal()
    or public.app_my_student_id () is not distinct from sid
    or exists (
      select 1
      from public.students st
      where st.id = sid
        and st.created_by_personal_id is not distinct from public.app_my_personal_id ()
    );
$$;

-- Personal/admin vê dados dos seus alunos mesmo com anamnese pendente; o próprio aluno não.
create or replace function public.app_can_access_student_training (sid text) returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.app_is_admin_personal()
    or exists (
      select 1
      from public.students st
      where st.id = sid
        and st.created_by_personal_id is not distinct from public.app_my_personal_id ()
    )
    or (
      public.app_my_student_id () is not distinct from sid
      and public.app_student_anamnese_ok (sid)
    );
$$;

-- Aluno free: sem escrita em catálogo; basic/premium/standard/legacy podem (conforme app).
create or replace function public.app_may_mutate_catalog () returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.app_is_admin_personal()
    or public.app_my_personal_id () is not null
    or (
      public.app_my_student_id () is not null
      and exists (
        select 1
        from public.students s
        where s.auth_user_id = auth.uid()
          and s.access_tier in (
            'legacy',
            'aluno_basic',
            'aluno_premium',
            'aluno_standard'
          )
      )
    );
$$;

create or replace function public.app_can_read_personal_row (pid text) returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.app_is_admin_personal()
    or public.app_my_personal_id () is not distinct from pid
    or exists (
      select 1
      from public.students s
      where s.auth_user_id = auth.uid()
        and s.created_by_personal_id is not distinct from pid
    );
$$;

create or replace function public.app_can_access_workout_group (gid text) returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.app_is_admin_personal()
    or exists (
      select 1
      from public.workout_groups g
      where g.id = gid
        and (
          coalesce(g.is_shared, false)
          or g.created_by_personal_id is not distinct from public.app_my_personal_id ()
        )
    );
$$;

create or replace function public.app_can_mutate_workout_group (gid text) returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.app_is_admin_personal()
    or exists (
      select 1
      from public.workout_groups g
      where g.id = gid
        and g.created_by_personal_id is not distinct from public.app_my_personal_id ()
    );
$$;

-- ---------------------------------------------------------------------------
-- 2) Substituir políticas permissivas e restringir anon (manutenção)
-- ---------------------------------------------------------------------------
-- Comentário: descomente o bloco abaixo quando estiver pronto para produção.
/*
do $$
declare
  t text;
  tables text[] := array[
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
  ];
begin
  foreach t in array tables
  loop
    execute format('drop policy if exists app_sync_anon_all on public.%I', t);
    execute format('drop policy if exists app_sync_authenticated_all on public.%I', t);
  end loop;
end $$;

revoke all on all tables in schema public from anon;

-- muscle_groups: leitura para utilizador ligado; escrita só quem pode mutar catálogo
create policy muscle_groups_select_auth on public.muscle_groups
  for select to authenticated
  using (public.app_is_linked_user ());

create policy muscle_groups_ins_auth on public.muscle_groups
  for insert to authenticated
  with check (public.app_may_mutate_catalog ());

create policy muscle_groups_upd_auth on public.muscle_groups
  for update to authenticated
  using (public.app_may_mutate_catalog ())
  with check (public.app_may_mutate_catalog ());

create policy muscle_groups_del_auth on public.muscle_groups
  for delete to authenticated
  using (public.app_may_mutate_catalog ());

-- exercises
create policy exercises_select_auth on public.exercises
  for select to authenticated
  using (public.app_is_linked_user ());

create policy exercises_ins_auth on public.exercises
  for insert to authenticated
  with check (public.app_may_mutate_catalog ());

create policy exercises_upd_auth on public.exercises
  for update to authenticated
  using (public.app_may_mutate_catalog ())
  with check (public.app_may_mutate_catalog ());

create policy exercises_del_auth on public.exercises
  for delete to authenticated
  using (public.app_may_mutate_catalog ());

-- gyms
create policy gyms_select_auth on public.gyms
  for select to authenticated
  using (public.app_is_linked_user ());

create policy gyms_ins_auth on public.gyms
  for insert to authenticated
  with check (public.app_may_mutate_catalog ());

create policy gyms_upd_auth on public.gyms
  for update to authenticated
  using (public.app_may_mutate_catalog ())
  with check (public.app_may_mutate_catalog ());

create policy gyms_del_auth on public.gyms
  for delete to authenticated
  using (public.app_may_mutate_catalog ());

-- personals
create policy personals_select_auth on public.personals
  for select to authenticated
  using (public.app_can_read_personal_row (id));

create policy personals_insert_auth on public.personals
  for insert to authenticated
  with check (
    public.app_is_admin_personal ()
    or auth_user_id = auth.uid ()
  );

create policy personals_update_auth on public.personals
  for update to authenticated
  using (
    public.app_is_admin_personal ()
    or public.app_my_personal_id () is not distinct from id
  )
  with check (
    public.app_is_admin_personal ()
    or public.app_my_personal_id () is not distinct from id
  );

create policy personals_delete_auth on public.personals
  for delete to authenticated
  using (public.app_is_admin_personal ());

-- students
create policy students_select_auth on public.students
  for select to authenticated
  using (public.app_can_access_student_row (id));

create policy students_insert_auth on public.students
  for insert to authenticated
  with check (
    public.app_is_admin_personal ()
    or (
      public.app_my_personal_id () is not null
      and created_by_personal_id is not distinct from public.app_my_personal_id ()
    )
  );

create policy students_update_auth on public.students
  for update to authenticated
  using (public.app_can_access_student_row (id))
  with check (public.app_can_access_student_row (id));

create policy students_delete_auth on public.students
  for delete to authenticated
  using (
    public.app_is_admin_personal ()
    or (
      public.app_my_personal_id () is not null
      and created_by_personal_id is not distinct from public.app_my_personal_id ()
    )
  );

-- student_gyms
create policy student_gyms_all_auth on public.student_gyms
  for all to authenticated
  using (public.app_can_access_student_training (student_id))
  with check (public.app_can_access_student_training (student_id));

-- training_methods, workout_groups (catálogo)
create policy training_methods_select_auth on public.training_methods
  for select to authenticated
  using (public.app_is_linked_user ());

create policy training_methods_ins_auth on public.training_methods
  for insert to authenticated
  with check (public.app_may_mutate_catalog ());

create policy training_methods_upd_auth on public.training_methods
  for update to authenticated
  using (public.app_may_mutate_catalog ())
  with check (public.app_may_mutate_catalog ());

create policy training_methods_del_auth on public.training_methods
  for delete to authenticated
  using (public.app_may_mutate_catalog ());

create policy workout_groups_select_auth on public.workout_groups
  for select to authenticated
  using (public.app_can_access_workout_group (id));

create policy workout_groups_ins_auth on public.workout_groups
  for insert to authenticated
  with check (
    public.app_is_admin_personal ()
    or created_by_personal_id is not distinct from public.app_my_personal_id ()
  );

create policy workout_groups_upd_auth on public.workout_groups
  for update to authenticated
  using (
    public.app_is_admin_personal ()
    or created_by_personal_id is not distinct from public.app_my_personal_id ()
  )
  with check (
    public.app_is_admin_personal ()
    or created_by_personal_id is not distinct from public.app_my_personal_id ()
  );

create policy workout_groups_del_auth on public.workout_groups
  for delete to authenticated
  using (
    public.app_is_admin_personal ()
    or created_by_personal_id is not distinct from public.app_my_personal_id ()
  );

-- workout_group_exercises
create policy wge_select_auth on public.workout_group_exercises
  for select to authenticated
  using (public.app_can_access_workout_group (workout_group_id));

create policy wge_ins_auth on public.workout_group_exercises
  for insert to authenticated
  with check (public.app_can_mutate_workout_group (workout_group_id));

create policy wge_upd_auth on public.workout_group_exercises
  for update to authenticated
  using (public.app_can_mutate_workout_group (workout_group_id))
  with check (public.app_can_mutate_workout_group (workout_group_id));

create policy wge_del_auth on public.workout_group_exercises
  for delete to authenticated
  using (public.app_can_mutate_workout_group (workout_group_id));

-- week_schedule_blocks
create policy wsb_all_auth on public.week_schedule_blocks
  for all to authenticated
  using (public.app_can_access_student_training (student_id))
  with check (public.app_can_access_student_training (student_id));

-- week_schedule_items
create policy wsi_all_auth on public.week_schedule_items
  for all to authenticated
  using (
    exists (
      select 1
      from public.week_schedule_blocks b
      where b.id = week_schedule_items.block_id
        and public.app_can_access_student_training (b.student_id)
    )
  )
  with check (
    exists (
      select 1
      from public.week_schedule_blocks b
      where b.id = week_schedule_items.block_id
        and public.app_can_access_student_training (b.student_id)
    )
  );

-- day_workouts
create policy dw_all_auth on public.day_workouts
  for all to authenticated
  using (public.app_can_access_student_training (student_id))
  with check (public.app_can_access_student_training (student_id));

-- day_workout_exercises
create policy dwe_all_auth on public.day_workout_exercises
  for all to authenticated
  using (
    exists (
      select 1
      from public.day_workouts w
      where w.id = day_workout_exercises.day_workout_id
        and public.app_can_access_student_training (w.student_id)
    )
  )
  with check (
    exists (
      select 1
      from public.day_workouts w
      where w.id = day_workout_exercises.day_workout_id
        and public.app_can_access_student_training (w.student_id)
    )
  );

-- audit_logs: escrita para sync; leitura só admin
create policy audit_insert_auth on public.audit_logs
  for insert to authenticated
  with check (public.app_is_linked_user ());

create policy audit_select_auth on public.audit_logs
  for select to authenticated
  using (public.app_is_admin_personal ());

create policy audit_update_auth on public.audit_logs
  for update to authenticated
  using (public.app_is_admin_personal ());

create policy audit_delete_auth on public.audit_logs
  for delete to authenticated
  using (public.app_is_admin_personal ());

-- anamnese
create policy anam_sess_all_auth on public.anamnese_sessions
  for all to authenticated
  using (public.app_can_access_student_row (student_id))
  with check (public.app_can_access_student_row (student_id));

create policy anam_ans_all_auth on public.anamnese_answers
  for all to authenticated
  using (
    exists (
      select 1
      from public.anamnese_sessions s
      where s.id = anamnese_answers.session_id
        and public.app_can_access_student_row (s.student_id)
    )
  )
  with check (
    exists (
      select 1
      from public.anamnese_sessions s
      where s.id = anamnese_answers.session_id
        and public.app_can_access_student_row (s.student_id)
    )
  );

create policy reports_all_auth on public.student_performance_reports
  for all to authenticated
  using (public.app_can_access_student_training (student_id))
  with check (public.app_can_access_student_training (student_id));

grant usage on schema public to authenticated;
grant select, insert, update, delete on all tables in schema public to authenticated;
*/

comment on function public.app_is_admin_personal () is
  'RLS helper: personal com is_admin ligado ao auth.uid().';

comment on function public.app_can_access_student_training (text) is
  'Aluno só acede a dados de treino com anamnese ok; personal vê os seus alunos sempre.';

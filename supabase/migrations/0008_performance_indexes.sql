begin;

create index if not exists ai_consents_user_idx
  on public.ai_consents (user_id);
create index if not exists devices_user_idx
  on public.devices (user_id);
create index if not exists invitation_requests_requested_by_idx
  on public.invitation_requests (requested_by);
create index if not exists sync_snapshot_sessions_user_idx
  on public.sync_snapshot_sessions (user_id);

create index if not exists exercises_tenant_muscle_group_idx
  on public.exercises (tenant_id, muscle_group_id);
create index if not exists students_tenant_personal_idx
  on public.students (tenant_id, created_by_personal_id);
create index if not exists student_gyms_tenant_gym_idx
  on public.student_gyms (tenant_id, gym_id);
create index if not exists workout_groups_tenant_personal_idx
  on public.workout_groups (tenant_id, created_by_personal_id);

create index if not exists wge_tenant_group_idx
  on public.workout_group_exercises (tenant_id, workout_group_id);
create index if not exists wge_tenant_exercise_idx
  on public.workout_group_exercises (tenant_id, exercise_id);
create index if not exists wge_tenant_method_idx
  on public.workout_group_exercises (tenant_id, training_method_id)
  where training_method_id is not null;

create index if not exists wsb_tenant_student_idx
  on public.week_schedule_blocks (tenant_id, student_id);
create index if not exists wsi_tenant_block_idx
  on public.week_schedule_items (tenant_id, block_id);
create index if not exists wsi_tenant_exercise_idx
  on public.week_schedule_items (tenant_id, exercise_id);
create index if not exists wsi_tenant_group_idx
  on public.week_schedule_items (tenant_id, source_workout_group_id)
  where source_workout_group_id is not null;
create index if not exists wsi_tenant_method_idx
  on public.week_schedule_items (tenant_id, training_method_id)
  where training_method_id is not null;

create index if not exists day_workouts_tenant_week_item_idx
  on public.day_workouts (tenant_id, week_item_id)
  where week_item_id is not null;
create index if not exists day_workouts_tenant_group_idx
  on public.day_workouts (tenant_id, source_workout_group_id)
  where source_workout_group_id is not null;
create index if not exists dwe_tenant_workout_idx
  on public.day_workout_exercises (tenant_id, day_workout_id);
create index if not exists dwe_tenant_exercise_idx
  on public.day_workout_exercises (tenant_id, exercise_id);
create index if not exists dwe_tenant_method_idx
  on public.day_workout_exercises (tenant_id, training_method_id)
  where training_method_id is not null;

create index if not exists performed_set_events_origin_device_idx
  on public.performed_set_events (origin_device);
create index if not exists performed_set_events_tenant_student_idx
  on public.performed_set_events (tenant_id, student_id);
create index if not exists workout_timer_events_origin_device_idx
  on public.workout_timer_events (origin_device);
create index if not exists workout_timer_events_tenant_student_idx
  on public.workout_timer_events (tenant_id, student_id);

commit;

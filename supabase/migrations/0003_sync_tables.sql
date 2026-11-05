begin;

create table public.devices (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  tenant_id uuid not null,
  platform text not null check (platform in ('ios','android')),
  created_at timestamptz not null default now(),
  last_seen_at timestamptz,
  last_acked_seq bigint not null default 0
);

create table public.tenant_memberships (
  user_id uuid not null references auth.users(id) on delete cascade,
  tenant_id uuid not null,
  role_name text not null check (role_name in ('personal','student','org_admin')),
  student_id uuid,
  has_full_org_access boolean not null default false,
  status text not null default 'active' check (status in ('active','suspended','revoked')),
  created_at timestamptz not null default now(),
  primary key (user_id, tenant_id)
);

create table public.tenant_counters (
  tenant_id uuid primary key,
  last_seq bigint not null default 0
);

create table public.ops_applied (
  op_id uuid primary key,
  tenant_id uuid not null,
  device_id uuid not null references public.devices(id),
  device_seq bigint not null,
  status text not null check (status in ('applied','noop','rejected')),
  reject_reason text,
  op_hash text not null,
  server_seq bigint,
  applied_at timestamptz not null default now(),
  unique (device_id, device_seq)
);

create table public.change_log (
  tenant_id uuid not null,
  server_seq bigint not null,
  entity text not null,
  entity_id uuid not null,
  op_type text not null,
  payload jsonb not null,
  hlc text not null,
  origin_device uuid not null,
  actor_user_id uuid,
  origin text not null default 'device' check (origin in ('device','edge','system')),
  primary key (tenant_id, server_seq)
);

create table public.sync_retention (
  tenant_id uuid primary key,
  min_available_seq bigint not null default 0
);

create table public.sync_snapshot_sessions (
  token uuid primary key default extensions.gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  tenant_id uuid not null,
  snapshot_seq bigint not null,
  after_key text not null default '',
  expires_at timestamptz not null default (now() + interval '15 minutes')
);

create table public.sync_permissions (
  role_name text not null check (role_name in ('personal','student','org_admin')),
  entity text not null,
  op_type text not null,
  own_rows_only boolean not null default false,
  primary key (role_name, entity, op_type)
);

create table public.sync_entity_fields (
  entity text not null,
  field_name text not null,
  sql_type text not null,
  primary key (entity, field_name)
);

create table public.sync_entity_required_fields (
  entity text not null,
  field_name text not null,
  primary key (entity,field_name),
  foreign key (entity,field_name) references public.sync_entity_fields(entity,field_name)
);

create table public.invitation_requests (
  id uuid primary key default extensions.gen_random_uuid(),
  tenant_id uuid not null,
  requested_by uuid not null references auth.users(id) on delete cascade,
  student_id uuid not null,
  email text not null,
  name text not null,
  status text not null check (status in ('pending','invited','completed','failed')),
  auth_user_id uuid,
  error_code text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id,email)
);

create table public.account_deletion_requests (
  id uuid primary key default extensions.gen_random_uuid(),
  user_id uuid not null unique,
  tenant_id uuid not null,
  role_name text not null check (role_name in ('personal','student','org_admin')),
  student_id uuid,
  status text not null check (status in ('requested','storage_deleted','db_deleted','completed','failed')),
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.ai_report_usage (
  user_id uuid not null references auth.users(id) on delete cascade,
  window_started_at timestamptz not null,
  request_count integer not null default 0,
  primary key (user_id,window_started_at)
);

insert into public.sync_entity_fields (entity, field_name, sql_type) values
  ('personals','name','text'),('personals','cpf','text'),('personals','professional_registry','text'),('personals','street','text'),('personals','number','text'),('personals','complement','text'),('personals','city','text'),('personals','state_uf','text'),('personals','cep','text'),('personals','email','text'),('personals','phone_commercial','text'),('personals','phone_mobile','text'),('personals','must_change_password','boolean'),('personals','auth_user_id','uuid'),('personals','is_admin','boolean'),('personals','access_tier','text'),('personals','max_students_cap','integer'),
  ('muscle_groups','name','text'),
  ('exercises','name','text'),('exercises','muscle_group_id','uuid'),('exercises','video_url','text'),('exercises','alternative_note','text'),('exercises','alternative_video_url','text'),
  ('gyms','name','text'),('gyms','cnpj','text'),('gyms','street','text'),('gyms','number','text'),('gyms','complement','text'),('gyms','district','text'),('gyms','city','text'),('gyms','state_uf','text'),('gyms','cep','text'),
  ('students','name','text'),('students','is_archived','boolean'),('students','archived_at','timestamptz'),('students','email','text'),('students','goal','text'),('students','cpf','text'),('students','birth_date','date'),('students','street','text'),('students','number','text'),('students','complement','text'),('students','district','text'),('students','city','text'),('students','state_uf','text'),('students','cep','text'),('students','phone_commercial','text'),('students','phone_mobile','text'),('students','must_change_password','boolean'),('students','auth_user_id','uuid'),('students','created_by_personal_id','uuid'),('students','anamnese_completed','boolean'),('students','access_tier','text'),('students','premium_plan_expires_at','timestamptz'),
  ('student_gyms','student_id','uuid'),('student_gyms','gym_id','uuid'),
  ('training_methods','method','text'),('training_methods','description','text'),
  ('workout_groups','name','text'),('workout_groups','description','text'),('workout_groups','created_by_personal_id','uuid'),('workout_groups','is_shared','boolean'),
  ('workout_group_exercises','workout_group_id','uuid'),('workout_group_exercises','exercise_id','uuid'),('workout_group_exercises','position','text'),('workout_group_exercises','sort_order','integer'),('workout_group_exercises','last_load_kg','numeric'),('workout_group_exercises','last_reps','integer'),('workout_group_exercises','last_reps_text','text'),('workout_group_exercises','last_sets','integer'),('workout_group_exercises','rest_between_sets_sec','integer'),('workout_group_exercises','training_method_id','uuid'),('workout_group_exercises','combo_id','uuid'),
  ('week_schedule_blocks','student_id','uuid'),('week_schedule_blocks','week_start_monday','date'),
  ('week_schedule_items','block_id','uuid'),('week_schedule_items','exercise_id','uuid'),('week_schedule_items','source_workout_group_id','uuid'),('week_schedule_items','position','text'),('week_schedule_items','sort_order','integer'),('week_schedule_items','sets','integer'),('week_schedule_items','reps','integer'),('week_schedule_items','reps_text','text'),('week_schedule_items','load_kg','numeric'),('week_schedule_items','needs_detail','boolean'),('week_schedule_items','rest_between_sets_sec','integer'),('week_schedule_items','training_method_id','uuid'),('week_schedule_items','combo_id','uuid'),
  ('day_workouts','student_id','uuid'),('day_workouts','day_date','date'),('day_workouts','status','text'),('day_workouts','week_item_id','uuid'),('day_workouts','active_duration_seconds','integer'),('day_workouts','workout_score','numeric'),('day_workouts','started_at','timestamptz'),('day_workouts','completed_at','timestamptz'),('day_workouts','timer_resume_at','timestamptz'),('day_workouts','source_workout_group_id','uuid'),('day_workouts','watch_calories_kcal','numeric'),('day_workouts','watch_avg_heart_rate_bpm','integer'),
  ('day_workout_exercises','day_workout_id','uuid'),('day_workout_exercises','exercise_id','uuid'),('day_workout_exercises','position','text'),('day_workout_exercises','sort_order','integer'),('day_workout_exercises','sets','integer'),('day_workout_exercises','reps','integer'),('day_workout_exercises','reps_text','text'),('day_workout_exercises','load_kg','numeric'),('day_workout_exercises','exercise_score','numeric'),('day_workout_exercises','rest_between_sets_sec','integer'),('day_workout_exercises','training_method_id','uuid'),('day_workout_exercises','combo_id','uuid');

insert into public.sync_entity_required_fields (entity,field_name) values
  ('personals','name'),('muscle_groups','name'),('exercises','name'),('exercises','muscle_group_id'),
  ('gyms','name'),('gyms','cnpj'),('gyms','street'),('gyms','number'),('gyms','district'),('gyms','city'),('gyms','state_uf'),('gyms','cep'),
  ('students','name'),('student_gyms','student_id'),('student_gyms','gym_id'),
  ('training_methods','method'),('training_methods','description'),
  ('workout_groups','name'),('workout_groups','description'),
  ('workout_group_exercises','workout_group_id'),('workout_group_exercises','exercise_id'),
  ('week_schedule_blocks','student_id'),('week_schedule_blocks','week_start_monday'),
  ('week_schedule_items','block_id'),('week_schedule_items','exercise_id'),
  ('day_workouts','student_id'),('day_workouts','day_date'),('day_workouts','status'),
  ('day_workout_exercises','day_workout_id'),('day_workout_exercises','exercise_id'),('day_workout_exercises','sets'),('day_workout_exercises','reps');

insert into public.sync_permissions (role_name, entity, op_type, own_rows_only)
select r.role_name, e.entity, o.op_type, false
from (values ('personal'), ('org_admin')) as r(role_name)
cross join (values ('personals'),('muscle_groups'),('exercises'),('gyms'),('students'),('student_gyms'),('training_methods'),('workout_groups'),('workout_group_exercises'),('week_schedule_blocks'),('week_schedule_items'),('day_workouts'),('day_workout_exercises')) as e(entity)
cross join (values ('create'),('update'),('delete'),('restore')) as o(op_type);

insert into public.sync_permissions (role_name, entity, op_type, own_rows_only) values
  ('personal','performed_set_events','logged',false),
  ('personal','performed_set_events','amended',false),
  ('personal','performed_set_events','voided',false),
  ('personal','workout_timer_events','start',false),
  ('personal','workout_timer_events','pause',false),
  ('personal','workout_timer_events','resume',false),
  ('personal','workout_timer_events','finish',false),
  ('org_admin','performed_set_events','logged',false),
  ('org_admin','performed_set_events','amended',false),
  ('org_admin','performed_set_events','voided',false),
  ('org_admin','workout_timer_events','start',false),
  ('org_admin','workout_timer_events','pause',false),
  ('org_admin','workout_timer_events','resume',false),
  ('org_admin','workout_timer_events','finish',false),
  ('student','performed_set_events','logged',true),
  ('student','performed_set_events','amended',true),
  ('student','performed_set_events','voided',true),
  ('student','workout_timer_events','start',true),
  ('student','workout_timer_events','pause',true),
  ('student','workout_timer_events','resume',true),
  ('student','workout_timer_events','finish',true);

alter table public.performed_set_events
  add constraint performed_set_events_origin_device_fkey foreign key (origin_device) references public.devices(id);
alter table public.workout_timer_events
  add constraint workout_timer_events_origin_device_fkey foreign key (origin_device) references public.devices(id);

alter table public.muscle_groups add constraint muscle_groups_tenant_id_key unique (tenant_id,id);
alter table public.personals add constraint personals_tenant_id_key unique (tenant_id,id);
alter table public.exercises add constraint exercises_muscle_group_tenant_fkey foreign key (tenant_id,muscle_group_id) references public.muscle_groups(tenant_id,id);
alter table public.gyms add constraint gyms_tenant_id_key unique (tenant_id,id);
alter table public.students add constraint students_tenant_id_key unique (tenant_id,id);
alter table public.exercises add constraint exercises_tenant_id_key unique (tenant_id,id);
alter table public.training_methods add constraint training_methods_tenant_id_key unique (tenant_id,id);
alter table public.workout_groups add constraint workout_groups_tenant_id_key unique (tenant_id,id);
alter table public.week_schedule_blocks add constraint week_schedule_blocks_tenant_id_key unique (tenant_id,id);
alter table public.day_workouts add constraint day_workouts_tenant_id_key unique (tenant_id,id);
alter table public.workout_group_exercises add constraint workout_group_exercises_tenant_id_key unique (tenant_id,id);
alter table public.week_schedule_items add constraint week_schedule_items_tenant_id_key unique (tenant_id,id);
alter table public.day_workout_exercises add constraint day_workout_exercises_tenant_id_key unique (tenant_id,id);
alter table public.students add constraint students_personal_tenant_fkey foreign key (tenant_id,created_by_personal_id) references public.personals(tenant_id,id);
alter table public.week_schedule_blocks add constraint wsb_student_tenant_fkey foreign key (tenant_id,student_id) references public.students(tenant_id,id);
alter table public.workout_groups add constraint workout_groups_personal_tenant_fkey foreign key (tenant_id,created_by_personal_id) references public.personals(tenant_id,id);
alter table public.student_gyms add constraint student_gyms_student_tenant_fkey foreign key (tenant_id,student_id) references public.students(tenant_id,id);
alter table public.student_gyms add constraint student_gyms_gym_tenant_fkey foreign key (tenant_id,gym_id) references public.gyms(tenant_id,id);
alter table public.workout_group_exercises add constraint wge_group_tenant_fkey foreign key (tenant_id,workout_group_id) references public.workout_groups(tenant_id,id);
alter table public.workout_group_exercises add constraint wge_exercise_tenant_fkey foreign key (tenant_id,exercise_id) references public.exercises(tenant_id,id);
alter table public.workout_group_exercises add constraint wge_method_tenant_fkey foreign key (tenant_id,training_method_id) references public.training_methods(tenant_id,id);
alter table public.week_schedule_items add constraint wsi_block_tenant_fkey foreign key (tenant_id,block_id) references public.week_schedule_blocks(tenant_id,id);
alter table public.week_schedule_items add constraint wsi_exercise_tenant_fkey foreign key (tenant_id,exercise_id) references public.exercises(tenant_id,id);
alter table public.week_schedule_items add constraint wsi_group_tenant_fkey foreign key (tenant_id,source_workout_group_id) references public.workout_groups(tenant_id,id);
alter table public.week_schedule_items add constraint wsi_method_tenant_fkey foreign key (tenant_id,training_method_id) references public.training_methods(tenant_id,id);
alter table public.day_workouts add constraint day_workouts_student_tenant_fkey foreign key (tenant_id,student_id) references public.students(tenant_id,id);
alter table public.day_workouts add constraint day_workouts_week_item_tenant_fkey foreign key (tenant_id,week_item_id) references public.week_schedule_items(tenant_id,id);
alter table public.day_workouts add constraint day_workouts_group_tenant_fkey foreign key (tenant_id,source_workout_group_id) references public.workout_groups(tenant_id,id);
alter table public.day_workout_exercises add constraint dwe_workout_tenant_fkey foreign key (tenant_id,day_workout_id) references public.day_workouts(tenant_id,id);
alter table public.day_workout_exercises add constraint dwe_exercise_tenant_fkey foreign key (tenant_id,exercise_id) references public.exercises(tenant_id,id);
alter table public.day_workout_exercises add constraint dwe_method_tenant_fkey foreign key (tenant_id,training_method_id) references public.training_methods(tenant_id,id);
alter table public.performed_set_events add constraint set_events_exercise_tenant_fkey foreign key (tenant_id,day_workout_exercise_id) references public.day_workout_exercises(tenant_id,id);
alter table public.performed_set_events add constraint set_events_student_tenant_fkey foreign key (tenant_id,student_id) references public.students(tenant_id,id);
alter table public.workout_timer_events add constraint timer_events_workout_tenant_fkey foreign key (tenant_id,day_workout_id) references public.day_workouts(tenant_id,id);
alter table public.workout_timer_events add constraint timer_events_student_tenant_fkey foreign key (tenant_id,student_id) references public.students(tenant_id,id);

create index change_log_pull_idx on public.change_log (tenant_id, server_seq);
create index ops_applied_device_seq_idx on public.ops_applied (device_id, device_seq);

commit;

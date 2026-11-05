begin;

update auth.users u
set raw_app_meta_data = coalesce(u.raw_app_meta_data, '{}'::jsonb)
  || jsonb_build_object(
    'role', case when coalesce(p.is_admin,false) then 'org_admin' else 'personal' end,
    'tenant_id', p.tenant_id,
    'profile_id', p.id,
    'has_full_org_access', coalesce(p.is_admin,false)
  ),
  updated_at = clock_timestamp()
from public.personals p
where p.auth_user_id=u.id;

update auth.users u
set raw_app_meta_data = coalesce(u.raw_app_meta_data, '{}'::jsonb)
  || jsonb_build_object(
    'role', 'student',
    'tenant_id', s.tenant_id,
    'profile_id', s.id,
    'student_id', s.id,
    'has_full_org_access', false
  ),
  updated_at = clock_timestamp()
from public.students s
where s.auth_user_id=u.id;

commit;

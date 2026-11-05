begin;

create or replace function public._claim_text(p_key text)
returns text
language sql stable security definer set search_path = ''
as $$ select auth.jwt() -> 'app_metadata' ->> p_key $$;

create or replace function public._tenant_id()
returns uuid
language plpgsql stable security definer set search_path = ''
as $$
declare v text;
begin
  v := public._claim_text('tenant_id');
  if v is null then raise exception 'missing_tenant_claim' using errcode = '42501'; end if;
  if auth.uid() is not null and not exists (
    select 1 from public.tenant_memberships
    where user_id=auth.uid() and tenant_id=v::uuid and status='active'
  ) then raise exception 'inactive_membership' using errcode = '42501'; end if;
  return v::uuid;
end;
$$;

create or replace function public._allocate_seq(p_tenant uuid)
returns bigint
language sql security definer set search_path = ''
as $$
  insert into public.tenant_counters (tenant_id, last_seq) values (p_tenant, 1)
  on conflict (tenant_id) do update set last_seq = public.tenant_counters.last_seq + 1
  returning last_seq
$$;

create or replace function public._current_role(p_tenant uuid)
returns text
language sql stable security definer set search_path = ''
as $$
  select role_name from public.tenant_memberships
  where user_id=auth.uid() and tenant_id=p_tenant and status='active'
$$;

create or replace function public.server_time()
returns bigint
language sql stable security definer set search_path = ''
as $$ select (extract(epoch from clock_timestamp()) * 1000)::bigint $$;

create or replace function public.register_device(p_device_id uuid, p_platform text)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare v_tenant uuid; v_row public.devices;
begin
  if auth.uid() is null then raise exception 'authentication_required' using errcode = '42501'; end if;
  if p_platform not in ('ios','android') then raise exception 'invalid_platform' using errcode = '22023'; end if;
  v_tenant := public._tenant_id();
  insert into public.devices (id, user_id, tenant_id, platform, last_seen_at)
  values (p_device_id, auth.uid(), v_tenant, p_platform, clock_timestamp())
  on conflict (id) do update set
    platform = excluded.platform,
    last_seen_at = excluded.last_seen_at
  where public.devices.user_id = auth.uid() and public.devices.tenant_id = v_tenant
  returning * into v_row;
  if v_row.id is null then raise exception 'device_owned_by_another_user' using errcode = '42501'; end if;
  return jsonb_build_object('device_id', v_row.id, 'acked_through_seq', v_row.last_acked_seq);
end;
$$;

create or replace function public._state_row_json(p_entity text, p_id uuid, p_tenant uuid)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare v jsonb;
begin
  execute format('select to_jsonb(t) from public.%I t where id = $1 and tenant_id = $2', p_entity)
    into v using p_id, p_tenant;
  return v;
end;
$$;

create or replace function public._apply_state(
  p_entity text, p_entity_id uuid, p_op_type text, p_payload jsonb, p_hlc text,
  p_tenant uuid, p_device uuid
) returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  v_exists boolean; v_deleted_hlc text; v_deleted_at timestamptz; v_changed boolean := false;
  v_key text; v_type text; v_old_hlc text; v_old_status text; v_new_status text;
  v_seq bigint; v_row jsonb;
begin
  if not exists (select 1 from public.sync_entity_fields where entity = p_entity) then
    return jsonb_build_object('status','rejected','reason','unknown_entity');
  end if;
  if exists (
    select 1 from jsonb_object_keys(coalesce(p_payload,'{}'::jsonb)) k
    where k <> 'tenant_id' and not exists (
      select 1 from public.sync_entity_fields f where f.entity=p_entity and f.field_name=k
    )
  ) then return jsonb_build_object('status','rejected','reason','unknown_field'); end if;
  if p_entity='day_workouts' and p_op_type='create'
     and (p_payload->>'status') is distinct from 'programado' then
    return jsonb_build_object('status','rejected','reason','invalid_transition');
  end if;
  if p_op_type='create' and exists (
    select 1 from public.sync_entity_required_fields r
    where r.entity=p_entity and (not (p_payload ? r.field_name) or jsonb_typeof(p_payload->r.field_name)='null')
  ) then return jsonb_build_object('status','rejected','reason','missing_required_field'); end if;
  if p_op_type='update' and exists (
    select 1 from public.sync_entity_required_fields r
    where r.entity=p_entity and p_payload ? r.field_name and jsonb_typeof(p_payload->r.field_name)='null'
  ) then return jsonb_build_object('status','rejected','reason','missing_required_field'); end if;

  execute format('select true, deleted_hlc, deleted_at from public.%I where id=$1 and tenant_id=$2 for update', p_entity)
    into v_exists, v_deleted_hlc, v_deleted_at using p_entity_id, p_tenant;

  if p_op_type = 'create' and not coalesce(v_exists,false) then
    execute format('insert into public.%I (id, tenant_id, created_hlc) values ($1,$2,$3)', p_entity)
      using p_entity_id, p_tenant, p_hlc;
    v_exists := true;
    v_changed := true;
  elsif p_op_type in ('update','delete','restore') and not coalesce(v_exists,false) then
    return jsonb_build_object('status','rejected','reason','not_found');
  end if;

  if p_op_type in ('create','update') then
    if v_deleted_at is not null then
      return jsonb_build_object('status','noop');
    end if;
    if p_entity = 'day_workouts' and p_payload ? 'status' then
      execute 'select status from public.day_workouts where id=$1 and tenant_id=$2'
        into v_old_status using p_entity_id, p_tenant;
      v_new_status := p_payload ->> 'status';
      if p_op_type='create' and v_new_status <> 'programado' then
        return jsonb_build_object('status','rejected','reason','invalid_transition');
      end if;
      if v_old_status is not null and v_new_status is distinct from v_old_status and not (
        (v_old_status = 'programado' and v_new_status in ('em_andamento','cancelado')) or
        (v_old_status = 'em_andamento' and v_new_status in ('concluido','cancelado'))
      ) then
        return jsonb_build_object('status','rejected','reason','invalid_transition');
      end if;
    end if;

    for v_key in select jsonb_object_keys(coalesce(p_payload, '{}'::jsonb)) loop
      select sql_type into v_type from public.sync_entity_fields
      where entity = p_entity and field_name = v_key;
      if v_type is null then continue; end if;
      execute format('select field_hlc ->> $1 from public.%I where id=$2 and tenant_id=$3', p_entity)
        into v_old_hlc using v_key, p_entity_id, p_tenant;
      if v_old_hlc is null or (p_hlc collate "C") > (v_old_hlc collate "C") then
        execute format(
          'update public.%I set %I = case when jsonb_typeof($1->$2) = ''null'' then null else ($1->>$2)::%s end, field_hlc = jsonb_set(field_hlc, array[$2], to_jsonb($3::text), true) where id=$4 and tenant_id=$5',
          p_entity, v_key, v_type
        ) using p_payload, v_key, p_hlc, p_entity_id, p_tenant;
        v_changed := true;
      end if;
    end loop;
  elsif p_op_type = 'delete' then
    if v_deleted_hlc is null or (p_hlc collate "C") > (v_deleted_hlc collate "C") then
      execute format('update public.%I set deleted_at=clock_timestamp(), deleted_hlc=$1 where id=$2 and tenant_id=$3', p_entity)
        using p_hlc, p_entity_id, p_tenant;
      v_changed := true;
    end if;
  elsif p_op_type = 'restore' then
    if v_deleted_at is not null and (v_deleted_hlc is null or (p_hlc collate "C") > (v_deleted_hlc collate "C")) then
      execute format('update public.%I set deleted_at=null, deleted_hlc=$1 where id=$2 and tenant_id=$3', p_entity)
        using p_hlc, p_entity_id, p_tenant;
      v_changed := true;
    end if;
  else
    return jsonb_build_object('status','rejected','reason','invalid_op_type');
  end if;

  if not v_changed then return jsonb_build_object('status','noop'); end if;
  v_seq := public._allocate_seq(p_tenant);
  execute format('update public.%I set updated_seq=$1 where id=$2 and tenant_id=$3', p_entity)
    using v_seq, p_entity_id, p_tenant;
  v_row := public._state_row_json(p_entity, p_entity_id, p_tenant);
  insert into public.change_log
    (tenant_id,server_seq,entity,entity_id,op_type,payload,hlc,origin_device,actor_user_id,origin)
  values (p_tenant, v_seq, p_entity, p_entity_id, p_op_type, v_row, p_hlc, p_device,auth.uid(),'device');
  return jsonb_build_object('status','applied','server_seq',v_seq);
exception when check_violation or invalid_text_representation or not_null_violation or foreign_key_violation or unique_violation then
  return jsonb_build_object('status','rejected','reason','invalid_payload');
end;
$$;

create or replace function public._student_owns_event(p_entity text, p_payload jsonb, p_tenant uuid)
returns boolean
language plpgsql stable security definer set search_path = ''
as $$
declare v_student uuid; v_claim uuid;
begin
  v_claim := coalesce(nullif(public._claim_text('student_id'), '')::uuid, nullif(public._claim_text('profile_id'), '')::uuid);
  v_student := nullif(p_payload ->> 'student_id','')::uuid;
  if v_claim is null or v_student is distinct from v_claim then return false; end if;
  if p_entity = 'performed_set_events' then
    return exists (
      select 1 from public.day_workout_exercises dwe
      join public.day_workouts dw on dw.id=dwe.day_workout_id and dw.tenant_id=dwe.tenant_id
      where dwe.id=(p_payload->>'day_workout_exercise_id')::uuid
        and dw.student_id=v_claim and dw.tenant_id=p_tenant and dw.deleted_at is null
    );
  end if;
  return exists (select 1 from public.day_workouts where id=(p_payload->>'day_workout_id')::uuid
    and student_id=v_claim and tenant_id=p_tenant and deleted_at is null);
exception when others then return false;
end;
$$;

create or replace function public._apply_event(
  p_entity text, p_entity_id uuid, p_op_type text, p_payload jsonb, p_hlc text,
  p_tenant uuid, p_device uuid, p_device_seq bigint
) returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare v_seq bigint; v_target uuid; v_row jsonb; v_last_kind text; v_workout uuid;
begin
  perform pg_advisory_xact_lock(hashtextextended(p_entity_id::text, 0));
  if p_entity = 'performed_set_events' then
    if p_op_type not in ('logged','amended','voided') then
      return jsonb_build_object('status','rejected','reason','invalid_op_type');
    end if;
    if exists (select 1 from public.performed_set_events where id=p_entity_id) then
      return jsonb_build_object('status','rejected','reason','entity_id_collision');
    end if;
    v_target := nullif(p_payload->>'target_set_id','')::uuid;
    if p_op_type in ('amended','voided') and not exists (
      select 1 from public.performed_set_events where id=v_target and tenant_id=p_tenant
        and kind='logged'
        and student_id=(p_payload->>'student_id')::uuid
        and day_workout_exercise_id=(p_payload->>'day_workout_exercise_id')::uuid
    ) then return jsonb_build_object('status','rejected','reason','target_not_found'); end if;
    v_seq := public._allocate_seq(p_tenant);
    insert into public.performed_set_events
      (id,tenant_id,day_workout_exercise_id,student_id,kind,target_set_id,reps,load_kg,rpe,note,hlc,origin_device,device_seq,server_seq)
    values (p_entity_id,p_tenant,(p_payload->>'day_workout_exercise_id')::uuid,(p_payload->>'student_id')::uuid,
      p_op_type,v_target,nullif(p_payload->>'reps','')::integer,nullif(p_payload->>'load_kg','')::numeric,
      nullif(p_payload->>'rpe','')::numeric,p_payload->>'note',p_hlc,p_device,p_device_seq,v_seq)
    returning to_jsonb(performed_set_events.*) into v_row;
  elsif p_entity = 'workout_timer_events' then
    if p_op_type not in ('start','pause','resume','finish') then
      return jsonb_build_object('status','rejected','reason','invalid_op_type');
    end if;
    if exists (select 1 from public.workout_timer_events where id=p_entity_id) then
      return jsonb_build_object('status','rejected','reason','entity_id_collision');
    end if;
    v_workout := (p_payload->>'day_workout_id')::uuid;
    perform pg_advisory_xact_lock(hashtextextended(p_tenant::text||':'||v_workout::text,3));
    select kind into v_last_kind from public.workout_timer_events
      where tenant_id=p_tenant and day_workout_id=v_workout order by server_seq desc limit 1;
    if (v_last_kind is null and p_op_type<>'start')
       or (v_last_kind in ('start','resume') and p_op_type not in ('pause','finish'))
       or (v_last_kind='pause' and p_op_type not in ('resume','finish'))
       or v_last_kind='finish' then
      return jsonb_build_object('status','rejected','reason','invalid_transition');
    end if;
    v_seq := public._allocate_seq(p_tenant);
    insert into public.workout_timer_events
      (id,tenant_id,day_workout_id,student_id,kind,hlc,origin_device,device_seq,server_seq)
    values (p_entity_id,p_tenant,v_workout,(p_payload->>'student_id')::uuid,
      p_op_type,p_hlc,p_device,p_device_seq,v_seq)
    returning to_jsonb(workout_timer_events.*) into v_row;
  else
    return jsonb_build_object('status','rejected','reason','unknown_entity');
  end if;
  insert into public.change_log
    (tenant_id,server_seq,entity,entity_id,op_type,payload,hlc,origin_device,actor_user_id,origin)
  values (p_tenant,v_seq,p_entity,p_entity_id,p_op_type,v_row,p_hlc,p_device,auth.uid(),'device');
  return jsonb_build_object('status','applied','server_seq',v_seq);
exception when check_violation or invalid_text_representation or not_null_violation or foreign_key_violation then
  return jsonb_build_object('status','rejected','reason','invalid_payload');
end;
$$;

create or replace function public.sync_push(p_device_id uuid, p_ops jsonb)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  v_device public.devices; v_tenant uuid; v_role text; v_op jsonb; v_existing public.ops_applied;
  v_op_id uuid; v_device_seq bigint; v_entity text; v_entity_id uuid; v_op_type text;
  v_payload jsonb; v_hlc text; v_wall bigint; v_result jsonb; v_status text; v_reason text;
  v_server_seq bigint; v_results jsonb := '[]'::jsonb; v_expected bigint; v_op_hash text; v_malformed boolean;
begin
  if auth.uid() is null then raise exception 'authentication_required' using errcode='42501'; end if;
  select * into v_device from public.devices where id=p_device_id for update;
  if v_device.id is null or v_device.user_id <> auth.uid() then
    raise exception 'device_not_registered' using errcode='42501';
  end if;
  v_tenant := public._tenant_id();
  if v_device.tenant_id <> v_tenant then raise exception 'tenant_mismatch' using errcode='42501'; end if;
  v_role := public._current_role(v_tenant);
  if v_role is null or v_role is distinct from public._claim_text('role') then
    raise exception 'role_claim_mismatch' using errcode='42501';
  end if;
  if jsonb_typeof(p_ops) <> 'array' then raise exception 'ops_must_be_array' using errcode='22023'; end if;
  if jsonb_array_length(p_ops) > 100 or octet_length(p_ops::text) > 1048576 then
    raise exception 'batch_limit_exceeded' using errcode='22023';
  end if;

  for v_op in select value from jsonb_array_elements(p_ops) loop
    v_malformed := false;
    begin
      v_op_id := (v_op->>'op_id')::uuid;
      v_device_seq := (v_op->>'device_seq')::bigint;
    exception when others then
      return jsonb_build_object('results',v_results || jsonb_build_array(jsonb_build_object(
        'status','rejected','reason','malformed_operation')),
        'gap',false,'acked_through_seq',v_device.last_acked_seq);
    end;
    if v_op_id is null or v_device_seq is null then
      return jsonb_build_object('results',v_results || jsonb_build_array(jsonb_build_object(
        'status','rejected','reason','malformed_operation')),
        'gap',false,'acked_through_seq',v_device.last_acked_seq);
    end if;
    begin
      v_entity := v_op->>'entity'; v_entity_id := (v_op->>'entity_id')::uuid;
      v_op_type := v_op->>'op_type'; v_payload := coalesce(v_op->'payload','{}'::jsonb); v_hlc := v_op->>'hlc';
      if v_entity is null or v_entity_id is null or v_op_type is null or jsonb_typeof(v_payload)<>'object' then
        v_malformed := true;
      end if;
    exception when others then
      v_malformed := true;
    end;

    perform pg_advisory_xact_lock(hashtextextended(v_op_id::text, 1));
    select * into v_existing from public.ops_applied where op_id=v_op_id;
    if v_existing.op_id is not null then
      v_op_hash := encode(extensions.digest(convert_to(v_op::text,'UTF8'),'sha256'),'hex');
      if v_existing.tenant_id<>v_tenant or v_existing.device_id<>p_device_id or
         v_existing.device_seq<>v_device_seq or v_existing.op_hash<>v_op_hash then
        return jsonb_build_object('results',v_results || jsonb_build_array(jsonb_build_object(
          'op_id',v_op_id,'status','rejected','reason','op_id_collision')),
          'gap',false,'acked_through_seq',v_device.last_acked_seq);
      end if;
      v_results := v_results || jsonb_build_array(jsonb_build_object(
        'op_id',v_op_id,'status',v_existing.status,'reason',v_existing.reject_reason,'server_seq',v_existing.server_seq));
      continue;
    end if;

    v_expected := v_device.last_acked_seq + 1;
    if v_device_seq <> v_expected then
      return jsonb_build_object('results',v_results,'gap',true,'expected_seq',v_expected,
        'acked_through_seq',v_device.last_acked_seq);
    end if;

    begin
      v_result := null;
      if v_malformed then
        v_result := jsonb_build_object('status','rejected','reason','malformed_operation');
      elsif v_payload ? 'tenant_id' and v_payload->>'tenant_id' <> v_tenant::text then
        v_result := jsonb_build_object('status','rejected','reason','tenant_mismatch');
      elsif v_hlc is null or v_hlc !~ '^[0-9]{15}-[0-9a-f]{5}-[0-9a-f]{32}$' then
        v_result := jsonb_build_object('status','rejected','reason','invalid_hlc');
      elsif split_part(v_hlc,'-',3) <> replace(p_device_id::text,'-','') then
        v_result := jsonb_build_object('status','rejected','reason','hlc_node_mismatch');
      else
        v_wall := split_part(v_hlc,'-',1)::bigint;
        if v_wall > public.server_time() + 300000 then
          v_result := jsonb_build_object('status','rejected','reason','clock_drift');
        elsif not exists (select 1 from public.sync_permissions where role_name=v_role and entity=v_entity and op_type=v_op_type) then
          v_result := jsonb_build_object('status','rejected','reason','permission_denied');
        elsif v_role='student' and not public._student_owns_event(v_entity,v_payload,v_tenant) then
          v_result := jsonb_build_object('status','rejected','reason','permission_denied');
        elsif v_entity in ('performed_set_events','workout_timer_events') then
          v_result := public._apply_event(v_entity,v_entity_id,v_op_type,v_payload,v_hlc,v_tenant,p_device_id,v_device_seq);
        else
          v_result := public._apply_state(v_entity,v_entity_id,v_op_type,v_payload,v_hlc,v_tenant,p_device_id);
        end if;
      end if;
    exception when others then
      v_result := jsonb_build_object('status','rejected','reason','invalid_payload');
    end;

    v_status := v_result->>'status'; v_reason := v_result->>'reason';
    v_server_seq := nullif(v_result->>'server_seq','')::bigint;
    v_op_hash := encode(extensions.digest(convert_to(v_op::text,'UTF8'),'sha256'),'hex');
    insert into public.ops_applied (op_id,tenant_id,device_id,device_seq,status,reject_reason,op_hash,server_seq)
      values (v_op_id,v_tenant,p_device_id,v_device_seq,v_status,v_reason,v_op_hash,v_server_seq);
    update public.devices set last_acked_seq=v_device_seq,last_seen_at=clock_timestamp() where id=p_device_id;
    v_device.last_acked_seq := v_device_seq;
    v_results := v_results || jsonb_build_array(jsonb_build_object(
      'op_id',v_op_id,'status',v_status,'reason',v_reason,'server_seq',v_server_seq));
  end loop;
  return jsonb_build_object('results',v_results,'gap',false,'acked_through_seq',v_device.last_acked_seq);
end;
$$;

create or replace function public.sync_pull(p_device_id uuid, p_since bigint, p_limit integer default 500)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare v_device public.devices; v_tenant uuid; v_min bigint; v_rows jsonb; v_next bigint; v_last bigint;
begin
  select * into v_device from public.devices where id=p_device_id and user_id=auth.uid();
  if v_device.id is null then raise exception 'device_not_registered' using errcode='42501'; end if;
  v_tenant := public._tenant_id();
  if v_device.tenant_id <> v_tenant then raise exception 'tenant_mismatch' using errcode='42501'; end if;
  v_last := coalesce((select last_seq from public.tenant_counters where tenant_id=v_tenant),0);
  if p_since > v_last then raise exception 'cursor_ahead' using errcode='22023'; end if;
  select coalesce(min_available_seq,0) into v_min from public.sync_retention where tenant_id=v_tenant;
  if p_since < coalesce(v_min,0) then
    return jsonb_build_object('reset',true,'changes','[]'::jsonb,'next_cursor',p_since,'has_more',false,
      'acked_through_seq',v_device.last_acked_seq);
  end if;
  select coalesce(jsonb_agg(to_jsonb(x) order by x.server_seq),'[]'::jsonb), coalesce(max(x.server_seq),p_since)
    into v_rows,v_next from (select * from public.change_log where tenant_id=v_tenant and server_seq>p_since
      order by server_seq limit greatest(1,least(coalesce(p_limit,500),1000))) x;
  return jsonb_build_object('reset',false,'changes',v_rows,'next_cursor',v_next,'has_more',v_next<v_last,
    'acked_through_seq',v_device.last_acked_seq);
end;
$$;

create or replace function public.sync_snapshot(p_cursor jsonb default '{}'::jsonb, p_limit integer default 500)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  v_tenant uuid; v_snapshot bigint; v_after text; v_rows jsonb; v_next text; v_token uuid;
  v_session public.sync_snapshot_sessions;
  v_limit integer := greatest(1,least(coalesce(p_limit,500),1000));
begin
  v_tenant := public._tenant_id();
  if p_cursor ? 'token' then
    v_token := (p_cursor->>'token')::uuid;
    select * into v_session from public.sync_snapshot_sessions
      where token=v_token and user_id=auth.uid() and tenant_id=v_tenant and expires_at>clock_timestamp();
    if v_session.token is null then raise exception 'invalid_snapshot_cursor' using errcode='22023'; end if;
    if p_cursor ? 'snapshot_seq' and (p_cursor->>'snapshot_seq')::bigint<>v_session.snapshot_seq then
      raise exception 'invalid_snapshot_cursor' using errcode='22023';
    end if;
    if p_cursor ? 'after_key' and p_cursor->>'after_key' is distinct from v_session.after_key then
      raise exception 'invalid_snapshot_cursor' using errcode='22023';
    end if;
    v_snapshot := v_session.snapshot_seq;
    v_after := v_session.after_key;
  else
    v_snapshot := coalesce((select last_seq from public.tenant_counters where tenant_id=v_tenant),0);
    v_after := '';
  end if;
  with all_rows as (
    select 'personals' entity,id,updated_seq,to_jsonb(t) payload from public.personals t where tenant_id=v_tenant and coalesce(updated_seq,0)<=v_snapshot
    union all select 'muscle_groups',id,updated_seq,to_jsonb(t) from public.muscle_groups t where tenant_id=v_tenant and coalesce(updated_seq,0)<=v_snapshot
    union all select 'exercises',id,updated_seq,to_jsonb(t) from public.exercises t where tenant_id=v_tenant and coalesce(updated_seq,0)<=v_snapshot
    union all select 'gyms',id,updated_seq,to_jsonb(t) from public.gyms t where tenant_id=v_tenant and coalesce(updated_seq,0)<=v_snapshot
    union all select 'students',id,updated_seq,to_jsonb(t) from public.students t where tenant_id=v_tenant and coalesce(updated_seq,0)<=v_snapshot
    union all select 'student_gyms',id,updated_seq,to_jsonb(t) from public.student_gyms t where tenant_id=v_tenant and coalesce(updated_seq,0)<=v_snapshot
    union all select 'training_methods',id,updated_seq,to_jsonb(t) from public.training_methods t where tenant_id=v_tenant and coalesce(updated_seq,0)<=v_snapshot
    union all select 'workout_groups',id,updated_seq,to_jsonb(t) from public.workout_groups t where tenant_id=v_tenant and coalesce(updated_seq,0)<=v_snapshot
    union all select 'workout_group_exercises',id,updated_seq,to_jsonb(t) from public.workout_group_exercises t where tenant_id=v_tenant and coalesce(updated_seq,0)<=v_snapshot
    union all select 'week_schedule_blocks',id,updated_seq,to_jsonb(t) from public.week_schedule_blocks t where tenant_id=v_tenant and coalesce(updated_seq,0)<=v_snapshot
    union all select 'week_schedule_items',id,updated_seq,to_jsonb(t) from public.week_schedule_items t where tenant_id=v_tenant and coalesce(updated_seq,0)<=v_snapshot
    union all select 'day_workouts',id,updated_seq,to_jsonb(t) from public.day_workouts t where tenant_id=v_tenant and coalesce(updated_seq,0)<=v_snapshot
    union all select 'day_workout_exercises',id,updated_seq,to_jsonb(t) from public.day_workout_exercises t where tenant_id=v_tenant and coalesce(updated_seq,0)<=v_snapshot
    union all select 'performed_set_events',id,server_seq,to_jsonb(t) from public.performed_set_events t where tenant_id=v_tenant and server_seq<=v_snapshot
    union all select 'workout_timer_events',id,server_seq,to_jsonb(t) from public.workout_timer_events t where tenant_id=v_tenant and server_seq<=v_snapshot
  ), page as (
    select *, entity||':'||id::text as row_key from all_rows where entity||':'||id::text>v_after order by entity,id limit v_limit
  ) select coalesce(jsonb_agg(jsonb_build_object('entity',entity,'payload',payload) order by row_key),'[]'::jsonb), max(row_key)
    into v_rows,v_next from page;
  if v_next is not null then
    insert into public.sync_snapshot_sessions (user_id,tenant_id,snapshot_seq,after_key)
      values (auth.uid(),v_tenant,v_snapshot,v_next) returning token into v_token;
  end if;
  return jsonb_build_object('items',v_rows,'snapshot_seq',v_snapshot,
    'next_cursor',case when v_next is null then null else jsonb_build_object('token',v_token,'snapshot_seq',v_snapshot,'after_key',v_next) end,
    'has_more',jsonb_array_length(v_rows)=v_limit);
end;
$$;

create or replace function public.export_my_data()
returns jsonb
language plpgsql stable security definer set search_path = ''
as $$
declare v_tenant uuid; v_role text; v_student uuid;
begin
  v_tenant := public._tenant_id();
  v_role := public._current_role(v_tenant);
  if v_role is null or v_role is distinct from public._claim_text('role') then
    raise exception 'role_claim_mismatch' using errcode='42501';
  end if;
  if v_role='student' then
    select student_id into v_student from public.tenant_memberships
      where user_id=auth.uid() and tenant_id=v_tenant and status='active';
    return jsonb_build_object(
      'exported_at',clock_timestamp(),'tenant_id',v_tenant,
      'student',(select to_jsonb(t) from public.students t where tenant_id=v_tenant and id=v_student),
      'membership',(select to_jsonb(t) from public.tenant_memberships t where tenant_id=v_tenant and user_id=auth.uid()),
      'student_gyms',(select coalesce(jsonb_agg(to_jsonb(t)),'[]'::jsonb) from public.student_gyms t where tenant_id=v_tenant and student_id=v_student),
      'gyms',(select coalesce(jsonb_agg(to_jsonb(t)),'[]'::jsonb) from public.gyms t where tenant_id=v_tenant and id in
        (select gym_id from public.student_gyms where tenant_id=v_tenant and student_id=v_student)),
      'week_schedule_blocks',(select coalesce(jsonb_agg(to_jsonb(t)),'[]'::jsonb) from public.week_schedule_blocks t where tenant_id=v_tenant and student_id=v_student),
      'week_schedule_items',(select coalesce(jsonb_agg(to_jsonb(t)),'[]'::jsonb) from public.week_schedule_items t where tenant_id=v_tenant and block_id in
        (select id from public.week_schedule_blocks where tenant_id=v_tenant and student_id=v_student)),
      'workouts',(select coalesce(jsonb_agg(to_jsonb(t)),'[]'::jsonb) from public.day_workouts t where tenant_id=v_tenant and student_id=v_student),
      'workout_exercises',(select coalesce(jsonb_agg(to_jsonb(t)),'[]'::jsonb) from public.day_workout_exercises t where tenant_id=v_tenant and day_workout_id in (select id from public.day_workouts where tenant_id=v_tenant and student_id=v_student)),
      'set_events',(select coalesce(jsonb_agg(to_jsonb(t)),'[]'::jsonb) from public.performed_set_events t where tenant_id=v_tenant and student_id=v_student),
      'timer_events',(select coalesce(jsonb_agg(to_jsonb(t)),'[]'::jsonb) from public.workout_timer_events t where tenant_id=v_tenant and student_id=v_student),
      'ai_consents',(select coalesce(jsonb_agg(to_jsonb(t)),'[]'::jsonb) from public.ai_consents t where tenant_id=v_tenant and user_id=auth.uid())
    );
  end if;
  return jsonb_build_object(
    'exported_at',clock_timestamp(),
    'tenant_id',v_tenant,
    'personals',(select coalesce(jsonb_agg(to_jsonb(t)),'[]'::jsonb) from public.personals t where tenant_id=v_tenant),
    'muscle_groups',(select coalesce(jsonb_agg(to_jsonb(t)),'[]'::jsonb) from public.muscle_groups t where tenant_id=v_tenant),
    'exercises',(select coalesce(jsonb_agg(to_jsonb(t)),'[]'::jsonb) from public.exercises t where tenant_id=v_tenant),
    'gyms',(select coalesce(jsonb_agg(to_jsonb(t)),'[]'::jsonb) from public.gyms t where tenant_id=v_tenant),
    'students',(select coalesce(jsonb_agg(to_jsonb(t)),'[]'::jsonb) from public.students t where tenant_id=v_tenant),
    'student_gyms',(select coalesce(jsonb_agg(to_jsonb(t)),'[]'::jsonb) from public.student_gyms t where tenant_id=v_tenant),
    'training_methods',(select coalesce(jsonb_agg(to_jsonb(t)),'[]'::jsonb) from public.training_methods t where tenant_id=v_tenant),
    'workout_groups',(select coalesce(jsonb_agg(to_jsonb(t)),'[]'::jsonb) from public.workout_groups t where tenant_id=v_tenant),
    'workout_group_exercises',(select coalesce(jsonb_agg(to_jsonb(t)),'[]'::jsonb) from public.workout_group_exercises t where tenant_id=v_tenant),
    'week_schedule_blocks',(select coalesce(jsonb_agg(to_jsonb(t)),'[]'::jsonb) from public.week_schedule_blocks t where tenant_id=v_tenant),
    'week_schedule_items',(select coalesce(jsonb_agg(to_jsonb(t)),'[]'::jsonb) from public.week_schedule_items t where tenant_id=v_tenant),
    'workouts',(select coalesce(jsonb_agg(to_jsonb(t)),'[]'::jsonb) from public.day_workouts t where tenant_id=v_tenant),
    'workout_exercises',(select coalesce(jsonb_agg(to_jsonb(t)),'[]'::jsonb) from public.day_workout_exercises t where tenant_id=v_tenant),
    'set_events',(select coalesce(jsonb_agg(to_jsonb(t)),'[]'::jsonb) from public.performed_set_events t where tenant_id=v_tenant),
    'timer_events',(select coalesce(jsonb_agg(to_jsonb(t)),'[]'::jsonb) from public.workout_timer_events t where tenant_id=v_tenant),
    'membership',(select to_jsonb(t) from public.tenant_memberships t where tenant_id=v_tenant and user_id=auth.uid()),
    'ai_consents',(select coalesce(jsonb_agg(to_jsonb(t)),'[]'::jsonb) from public.ai_consents t where tenant_id=v_tenant and user_id=auth.uid()),
    'invitation_requests',(select coalesce(jsonb_agg(to_jsonb(t)),'[]'::jsonb) from public.invitation_requests t where tenant_id=v_tenant and requested_by=auth.uid()),
    'account_deletion_request',(select to_jsonb(t) from public.account_deletion_requests t where user_id=auth.uid())
  );
end;
$$;

create or replace function public.delete_my_account()
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare v_tenant uuid; v_role text; v_student uuid; v_request public.account_deletion_requests;
begin
  v_tenant := public._tenant_id(); v_role := public._current_role(v_tenant);
  if v_role is null or v_role is distinct from public._claim_text('role') then
    raise exception 'role_claim_mismatch' using errcode='42501';
  end if;
  if v_role='student' then
    select student_id into v_student from public.tenant_memberships
      where user_id=auth.uid() and tenant_id=v_tenant and status='active';
  end if;
  insert into public.account_deletion_requests (user_id,tenant_id,role_name,student_id,status)
  values (auth.uid(),v_tenant,v_role,v_student,'requested')
  on conflict (user_id) do update set updated_at=clock_timestamp()
  returning * into v_request;
  return jsonb_build_object('request_id',v_request.id,'status',v_request.status);
end;
$$;

create or replace function public.server_mark_deletion_storage(p_request_id uuid)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare v_request public.account_deletion_requests;
begin
  if auth.role()<>'service_role' then raise exception 'service_role_required' using errcode='42501'; end if;
  update public.account_deletion_requests set status='storage_deleted',last_error=null,updated_at=clock_timestamp()
    where id=p_request_id and status in ('requested','failed','storage_deleted') returning * into v_request;
  if v_request.id is null then
    select * into v_request from public.account_deletion_requests where id=p_request_id;
  end if;
  if v_request.id is null then raise exception 'deletion_request_not_found' using errcode='22023'; end if;
  return jsonb_build_object('request_id',v_request.id,'status',v_request.status);
end;
$$;

create or replace function public.server_finalize_account_deletion(p_request_id uuid)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare v public.account_deletion_requests;
begin
  if auth.role()<>'service_role' then raise exception 'service_role_required' using errcode='42501'; end if;
  select * into v from public.account_deletion_requests where id=p_request_id for update;
  if v.id is null then raise exception 'deletion_request_not_found' using errcode='22023'; end if;
  if v.status in ('db_deleted','completed') then return jsonb_build_object('request_id',v.id,'status',v.status); end if;
  if v.status<>'storage_deleted' then raise exception 'storage_deletion_required' using errcode='22023'; end if;
  if not exists (
    select 1 from public.tenant_memberships
    where user_id=v.user_id and tenant_id=v.tenant_id and status='active' and role_name=v.role_name
      and (v.role_name<>'student' or student_id is not distinct from v.student_id)
  ) then raise exception 'deletion_authorization_changed' using errcode='42501'; end if;
  perform set_config('app.account_deletion','on',true);
  if v.role_name in ('personal','org_admin') then
    delete from public.invitation_requests where tenant_id=v.tenant_id;
    delete from public.ai_consents where tenant_id=v.tenant_id;
    delete from public.ai_report_usage where user_id in (select user_id from public.tenant_memberships where tenant_id=v.tenant_id);
    delete from public.change_log where tenant_id=v.tenant_id;
    delete from public.sync_snapshot_sessions where tenant_id=v.tenant_id;
    delete from public.ops_applied where tenant_id=v.tenant_id;
    delete from public.performed_set_events where tenant_id=v.tenant_id;
    delete from public.workout_timer_events where tenant_id=v.tenant_id;
    delete from public.day_workout_exercises where tenant_id=v.tenant_id;
    delete from public.day_workouts where tenant_id=v.tenant_id;
    delete from public.week_schedule_items where tenant_id=v.tenant_id;
    delete from public.week_schedule_blocks where tenant_id=v.tenant_id;
    delete from public.workout_group_exercises where tenant_id=v.tenant_id;
    delete from public.workout_groups where tenant_id=v.tenant_id;
    delete from public.student_gyms where tenant_id=v.tenant_id;
    delete from public.students where tenant_id=v.tenant_id;
    delete from public.exercises where tenant_id=v.tenant_id;
    delete from public.muscle_groups where tenant_id=v.tenant_id;
    delete from public.training_methods where tenant_id=v.tenant_id;
    delete from public.gyms where tenant_id=v.tenant_id;
    delete from public.personals where tenant_id=v.tenant_id;
    delete from public.devices where tenant_id=v.tenant_id;
    delete from public.tenant_memberships where tenant_id=v.tenant_id;
    delete from public.tenant_counters where tenant_id=v.tenant_id;
    delete from public.sync_retention where tenant_id=v.tenant_id;
  else
    delete from public.performed_set_events where tenant_id=v.tenant_id and student_id=v.student_id;
    delete from public.workout_timer_events where tenant_id=v.tenant_id and student_id=v.student_id;
    delete from public.day_workout_exercises where tenant_id=v.tenant_id and day_workout_id in
      (select id from public.day_workouts where tenant_id=v.tenant_id and student_id=v.student_id);
    delete from public.day_workouts where tenant_id=v.tenant_id and student_id=v.student_id;
    delete from public.week_schedule_items where tenant_id=v.tenant_id and block_id in
      (select id from public.week_schedule_blocks where tenant_id=v.tenant_id and student_id=v.student_id);
    delete from public.week_schedule_blocks where tenant_id=v.tenant_id and student_id=v.student_id;
    delete from public.student_gyms where tenant_id=v.tenant_id and student_id=v.student_id;
    delete from public.students where tenant_id=v.tenant_id and id=v.student_id;
    delete from public.devices where user_id=v.user_id;
    delete from public.sync_snapshot_sessions where user_id=v.user_id;
    delete from public.tenant_memberships where user_id=v.user_id and tenant_id=v.tenant_id;
  end if;
  update public.account_deletion_requests set status='db_deleted',updated_at=clock_timestamp() where id=v.id;
  return jsonb_build_object('request_id',v.id,'status','db_deleted');
end;
$$;

create or replace function public.server_complete_account_deletion(p_request_id uuid)
returns void
language plpgsql security definer set search_path = ''
as $$
begin
  if auth.role()<>'service_role' then raise exception 'service_role_required' using errcode='42501'; end if;
  update public.account_deletion_requests set status='completed',updated_at=clock_timestamp()
    where id=p_request_id and status in ('db_deleted','completed');
end;
$$;

create or replace function public.server_create_invited_student(
  p_tenant uuid, p_personal_id uuid, p_student_id uuid, p_auth_user_id uuid, p_name text, p_email text
) returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare v_seq bigint; v_hlc text; v_row jsonb; v_cap integer; v_count integer;
begin
  if auth.role() <> 'service_role' then raise exception 'service_role_required' using errcode='42501'; end if;
  perform pg_advisory_xact_lock(hashtextextended(p_tenant::text,2));
  if exists (select 1 from public.students where id=p_student_id and tenant_id=p_tenant and auth_user_id=p_auth_user_id) then
    return jsonb_build_object('student_id',p_student_id,'server_seq',
      (select updated_seq from public.students where id=p_student_id and tenant_id=p_tenant));
  elsif exists (select 1 from public.students where id=p_student_id) then
    raise exception 'student_id_collision' using errcode='23505';
  end if;
  select max_students_cap into v_cap from public.personals
    where id=p_personal_id and tenant_id=p_tenant and deleted_at is null for update;
  if not found then raise exception 'personal_not_found' using errcode='22023'; end if;
  if v_cap is not null then
    select count(*) into v_count from public.students where tenant_id=p_tenant and deleted_at is null;
    if v_count>=v_cap then raise exception 'capacity_reached' using errcode='P0001'; end if;
  end if;
  v_hlc := lpad(public.server_time()::text,15,'0')||'-00000-00000000000000000000000000000000';
  v_seq := public._allocate_seq(p_tenant);
  insert into public.students (id,tenant_id,name,email,auth_user_id,created_by_personal_id,field_hlc,created_hlc,updated_seq)
  values (p_student_id,p_tenant,p_name,p_email,p_auth_user_id,p_personal_id,
    jsonb_build_object('name',v_hlc,'email',v_hlc,'auth_user_id',v_hlc,'created_by_personal_id',v_hlc),v_hlc,v_seq)
  returning to_jsonb(students.*) into v_row;
  insert into public.tenant_memberships (user_id,tenant_id,role_name,student_id)
  values (p_auth_user_id,p_tenant,'student',p_student_id)
  on conflict (user_id,tenant_id) do update set role_name='student',student_id=p_student_id,status='active';
  insert into public.change_log
    (tenant_id,server_seq,entity,entity_id,op_type,payload,hlc,origin_device,actor_user_id,origin)
  values (p_tenant,v_seq,'students',p_student_id,'create',v_row,v_hlc,
    '00000000-0000-0000-0000-000000000000',null,'edge');
  return jsonb_build_object('student_id',p_student_id,'server_seq',v_seq);
end;
$$;

create or replace function public.server_consume_ai_quota(p_user_id uuid, p_limit integer default 10)
returns boolean
language plpgsql security definer set search_path = ''
as $$
declare v_allowed boolean;
begin
  if auth.role()<>'service_role' then raise exception 'service_role_required' using errcode='42501'; end if;
  if p_limit<1 or p_limit>100 then raise exception 'invalid_limit' using errcode='22023'; end if;
  insert into public.ai_report_usage (user_id,window_started_at,request_count)
  values (p_user_id,date_trunc('hour',clock_timestamp()),1)
  on conflict (user_id,window_started_at) do update
    set request_count=public.ai_report_usage.request_count+1
    where public.ai_report_usage.request_count<p_limit
  returning true into v_allowed;
  return coalesce(v_allowed,false);
end;
$$;

create or replace function public.server_refund_ai_quota(p_user_id uuid)
returns void
language plpgsql security definer set search_path = ''
as $$
begin
  if auth.role()<>'service_role' then raise exception 'service_role_required' using errcode='42501'; end if;
  update public.ai_report_usage set request_count=greatest(0,request_count-1)
    where user_id=p_user_id and window_started_at=date_trunc('hour',clock_timestamp());
end;
$$;

commit;

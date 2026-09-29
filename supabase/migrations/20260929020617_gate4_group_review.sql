create or replace function public.list_group_review_queue(
  after_created_at timestamptz,
  after_id uuid,
  page_size integer
)
returns table (
  id uuid,
  slug text,
  name text,
  city_id uuid,
  city_name text,
  state_code text,
  group_type text,
  join_policy text,
  group_status text,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not private.current_account_is_active()
    or not private.current_user_has_platform_role('platform_admin') then
    raise exception using errcode = '42501', message = 'platform admin required';
  end if;

  return query
  select
    g.id,
    g.slug,
    g.name,
    g.city_id,
    c.name,
    c.state_code,
    g.type,
    g.join_policy,
    g.status,
    g.created_at,
    g.updated_at
  from public.groups as g
  join public.cities as c on c.id = g.city_id
  where g.status = 'pending'
    and (
      (after_created_at is null and after_id is null)
      or (
        after_created_at is not null
        and after_id is not null
        and (g.created_at, g.id) > (after_created_at, after_id)
      )
    )
  order by g.created_at, g.id
  limit greatest(1, least(50, coalesce(page_size, 20)));
end;
$$;

create or replace function public.get_group_review(target_group_id uuid)
returns table (
  id uuid,
  slug text,
  name text,
  description text,
  city_id uuid,
  city_name text,
  state_code text,
  group_type text,
  join_policy text,
  group_status text,
  created_by uuid,
  owner_user_id uuid,
  created_at timestamptz,
  updated_at timestamptz,
  approved_by uuid,
  approved_at timestamptz,
  rejection_reason text,
  suspended_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not private.current_account_is_active()
    or not private.current_user_has_platform_role('platform_admin') then
    raise exception using errcode = '42501', message = 'platform admin required';
  end if;

  return query
  select
    g.id,
    g.slug,
    g.name,
    g.description,
    g.city_id,
    c.name,
    c.state_code,
    g.type,
    g.join_policy,
    g.status,
    g.created_by,
    g.owner_user_id,
    g.created_at,
    g.updated_at,
    g.approved_by,
    g.approved_at,
    g.rejection_reason,
    g.suspended_at
  from public.groups as g
  join public.cities as c on c.id = g.city_id
  where g.id = target_group_id;
end;
$$;

create or replace function public.approve_group_request(target_group_id uuid)
returns uuid
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  actor_user_id uuid;
  group_status text;
  group_creator_id uuid;
  group_owner_id uuid;
  group_city_id uuid;
  owner_membership_status text;
  decision_at timestamptz;
  audit_id uuid;
  receipt_id uuid;
  receipt_business_key text;
begin
  actor_user_id := auth.uid();
  if actor_user_id is null
    or not private.current_account_is_active()
    or not private.current_user_has_platform_role('platform_admin') then
    raise exception using errcode = '42501', message = 'platform admin required';
  end if;

  select g.status, g.created_by, g.owner_user_id, g.city_id
  into group_status, group_creator_id, group_owner_id, group_city_id
  from public.groups as g
  where g.id = target_group_id
  for update of g;

  if not found then
    raise exception using errcode = 'P0002', message = 'group not found';
  end if;
  if group_status <> 'pending' then
    raise exception using errcode = 'P0001', message = 'group_state_changed';
  end if;
  if group_creator_id = actor_user_id or group_owner_id = actor_user_id then
    raise exception using errcode = '42501', message = 'independent platform admin required';
  end if;

  select gm.status
  into owner_membership_status
  from public.group_members as gm
  where gm.group_id = target_group_id
    and gm.user_id = group_owner_id
    and gm.role = 'owner'
  for update of gm;

  if not found or owner_membership_status <> 'pending' then
    raise exception using errcode = 'P0001', message = 'group_state_changed';
  end if;

  decision_at := pg_catalog.now();
  update public.groups as g
  set status = 'approved',
      approved_by = actor_user_id,
      approved_at = decision_at,
      rejection_reason = null,
      suspended_at = null
  where g.id = target_group_id;

  update public.group_members as gm
  set status = 'active',
      joined_at = coalesce(gm.joined_at, decision_at)
  where gm.group_id = target_group_id
    and gm.user_id = group_owner_id
    and gm.role = 'owner';

  insert into private.admin_audit_logs (
    actor_user_id, action, target_type, target_id, metadata
  ) values (
    actor_user_id,
    'group.request_approved',
    'group',
    target_group_id,
    pg_catalog.jsonb_build_object('previous_status', 'pending', 'new_status', 'approved')
  ) returning id into audit_id;

  insert into public.notifications (
    recipient_user_id, actor_user_id, type, target_type, target_id, dedupe_key
  ) values (
    group_owner_id,
    actor_user_id,
    'group_request_approved',
    'group',
    target_group_id,
    'group_request_approved:' || audit_id::text
  ) on conflict (recipient_user_id, dedupe_key) do nothing;

  insert into private.analytics_events (
    event_name, user_id, city_id, entity_type, entity_id, properties, event_key
  ) values (
    'group_approved',
    actor_user_id,
    group_city_id,
    'group',
    target_group_id,
    '{}'::jsonb,
    'group_approved:' || audit_id::text
  );

  receipt_business_key := 'group:' || target_group_id::text || ':' || group_owner_id::text;
  insert into private.domain_event_receipts (
    event_type, business_key, entity_type, entity_id
  ) values (
    'group_joined', receipt_business_key, 'group', target_group_id
  ) on conflict (event_type, business_key) do nothing
  returning id into receipt_id;

  if receipt_id is not null then
    insert into public.activity_events (
      actor_user_id, group_id, event_type, entity_type, entity_id, metadata, dedupe_key
    ) values (
      group_owner_id,
      target_group_id,
      'group_joined',
      'group',
      target_group_id,
      '{}'::jsonb,
      'group_joined:' || target_group_id::text || ':' || group_owner_id::text
    ) on conflict (dedupe_key) do nothing;
  end if;

  return target_group_id;
end;
$$;

create or replace function public.reject_group_request(
  target_group_id uuid,
  requested_reason text
)
returns uuid
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  actor_user_id uuid;
  group_status text;
  group_creator_id uuid;
  group_owner_id uuid;
  owner_membership_status text;
  normalized_reason text;
  audit_id uuid;
begin
  actor_user_id := auth.uid();
  if actor_user_id is null
    or not private.current_account_is_active()
    or not private.current_user_has_platform_role('platform_admin') then
    raise exception using errcode = '42501', message = 'platform admin required';
  end if;

  normalized_reason := pg_catalog.btrim(coalesce(requested_reason, ''));
  if pg_catalog.char_length(normalized_reason) not between 3 and 1000 then
    raise exception using errcode = '22023', message = 'group reason is invalid';
  end if;

  select g.status, g.created_by, g.owner_user_id
  into group_status, group_creator_id, group_owner_id
  from public.groups as g
  where g.id = target_group_id
  for update of g;

  if not found then
    raise exception using errcode = 'P0002', message = 'group not found';
  end if;
  if group_status <> 'pending' then
    raise exception using errcode = 'P0001', message = 'group_state_changed';
  end if;
  if group_creator_id = actor_user_id or group_owner_id = actor_user_id then
    raise exception using errcode = '42501', message = 'independent platform admin required';
  end if;

  select gm.status
  into owner_membership_status
  from public.group_members as gm
  where gm.group_id = target_group_id
    and gm.user_id = group_owner_id
    and gm.role = 'owner'
  for update of gm;

  if not found or owner_membership_status <> 'pending' then
    raise exception using errcode = 'P0001', message = 'group_state_changed';
  end if;

  update public.groups as g
  set status = 'rejected',
      approved_by = null,
      approved_at = null,
      rejection_reason = normalized_reason,
      suspended_at = null
  where g.id = target_group_id;

  insert into private.admin_audit_logs (
    actor_user_id, action, target_type, target_id, metadata
  ) values (
    actor_user_id,
    'group.request_rejected',
    'group',
    target_group_id,
    pg_catalog.jsonb_build_object(
      'previous_status', 'pending',
      'new_status', 'rejected',
      'reason', normalized_reason
    )
  ) returning id into audit_id;

  insert into public.notifications (
    recipient_user_id, actor_user_id, type, target_type, target_id, dedupe_key
  ) values (
    group_owner_id,
    actor_user_id,
    'group_request_rejected',
    'group',
    target_group_id,
    'group_request_rejected:' || audit_id::text
  ) on conflict (recipient_user_id, dedupe_key) do nothing;

  return target_group_id;
end;
$$;

create or replace function public.suspend_group(
  target_group_id uuid,
  requested_reason text
)
returns uuid
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  actor_user_id uuid;
  group_status text;
  normalized_reason text;
  decision_at timestamptz;
  audit_id uuid;
begin
  actor_user_id := auth.uid();
  if actor_user_id is null
    or not private.current_account_is_active()
    or not (
      private.current_user_has_platform_role('moderator')
      or private.current_user_has_platform_role('platform_admin')
    ) then
    raise exception using errcode = '42501', message = 'moderator or platform admin required';
  end if;

  normalized_reason := pg_catalog.btrim(coalesce(requested_reason, ''));
  if pg_catalog.char_length(normalized_reason) not between 3 and 1000 then
    raise exception using errcode = '22023', message = 'group reason is invalid';
  end if;

  select g.status
  into group_status
  from public.groups as g
  where g.id = target_group_id
  for update of g;

  if not found then
    raise exception using errcode = 'P0002', message = 'group not found';
  end if;
  if group_status <> 'approved' then
    raise exception using errcode = 'P0001', message = 'group_state_changed';
  end if;

  decision_at := pg_catalog.now();
  update public.groups as g
  set status = 'suspended',
      suspended_at = decision_at
  where g.id = target_group_id;

  update public.run_series as rs
  set status = 'paused'
  where rs.group_id = target_group_id
    and rs.status = 'active';

  update public.runs as r
  set status = 'cancelled',
      cancelled_at = decision_at,
      cancellation_reason = normalized_reason
  where r.group_id = target_group_id
    and r.status = 'scheduled'
    and r.starts_at > decision_at;

  insert into private.admin_audit_logs (
    actor_user_id, action, target_type, target_id, metadata
  ) values (
    actor_user_id,
    'group.suspended',
    'group',
    target_group_id,
    pg_catalog.jsonb_build_object(
      'previous_status', 'approved',
      'new_status', 'suspended',
      'reason', normalized_reason
    )
  ) returning id into audit_id;

  -- The audit row is the immutable source for each suspension, including re-suspension after restoration.
  insert into private.notification_jobs (
    event_type, source_entity_type, source_entity_id
  ) values (
    'group_suspended', 'admin_audit_log', audit_id
  );

  return target_group_id;
end;
$$;

create or replace function public.restore_group(
  target_group_id uuid,
  requested_reason text
)
returns uuid
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  actor_user_id uuid;
  group_status text;
  normalized_reason text;
  audit_id uuid;
begin
  actor_user_id := auth.uid();
  if actor_user_id is null
    or not private.current_account_is_active()
    or not private.current_user_has_platform_role('platform_admin') then
    raise exception using errcode = '42501', message = 'platform admin required';
  end if;

  normalized_reason := pg_catalog.btrim(coalesce(requested_reason, ''));
  if pg_catalog.char_length(normalized_reason) not between 3 and 1000 then
    raise exception using errcode = '22023', message = 'group reason is invalid';
  end if;

  select g.status
  into group_status
  from public.groups as g
  where g.id = target_group_id
  for update of g;

  if not found then
    raise exception using errcode = 'P0002', message = 'group not found';
  end if;
  if group_status <> 'suspended' then
    raise exception using errcode = 'P0001', message = 'group_state_changed';
  end if;

  update public.groups as g
  set status = 'approved',
      suspended_at = null
  where g.id = target_group_id;

  insert into private.admin_audit_logs (
    actor_user_id, action, target_type, target_id, metadata
  ) values (
    actor_user_id,
    'group.restored',
    'group',
    target_group_id,
    pg_catalog.jsonb_build_object(
      'previous_status', 'suspended',
      'new_status', 'approved',
      'reason', normalized_reason
    )
  ) returning id into audit_id;

  return target_group_id;
end;
$$;

revoke all on function public.list_group_review_queue(timestamptz, uuid, integer) from public, anon, authenticated;
revoke all on function public.get_group_review(uuid) from public, anon, authenticated;
revoke all on function public.approve_group_request(uuid) from public, anon, authenticated;
revoke all on function public.reject_group_request(uuid, text) from public, anon, authenticated;
revoke all on function public.suspend_group(uuid, text) from public, anon, authenticated;
revoke all on function public.restore_group(uuid, text) from public, anon, authenticated;

grant execute on function public.list_group_review_queue(timestamptz, uuid, integer) to authenticated;
grant execute on function public.get_group_review(uuid) to authenticated;
grant execute on function public.approve_group_request(uuid) to authenticated;
grant execute on function public.reject_group_request(uuid, text) to authenticated;
grant execute on function public.suspend_group(uuid, text) to authenticated;
grant execute on function public.restore_group(uuid, text) to authenticated;

alter function public.list_group_review_queue(timestamptz, uuid, integer) owner to postgres;
alter function public.get_group_review(uuid) owner to postgres;
alter function public.approve_group_request(uuid) owner to postgres;
alter function public.reject_group_request(uuid, text) owner to postgres;
alter function public.suspend_group(uuid, text) owner to postgres;
alter function public.restore_group(uuid, text) owner to postgres;

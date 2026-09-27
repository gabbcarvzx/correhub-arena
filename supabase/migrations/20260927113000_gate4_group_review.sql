create or replace function private.current_user_can_review_groups()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.current_account_is_group_ready()
    and private.current_user_has_platform_role('platform_admin');
$$;

create or replace function private.current_user_can_suspend_groups()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.current_account_is_group_ready()
    and (
      private.current_user_has_platform_role('platform_admin')
      or private.current_user_has_platform_role('moderator')
    );
$$;

alter function private.current_user_can_review_groups() owner to postgres;
alter function private.current_user_can_suspend_groups() owner to postgres;
revoke all on function private.current_user_can_review_groups() from public,anon,authenticated;
revoke all on function private.current_user_can_suspend_groups() from public,anon,authenticated;
grant execute on function private.current_user_can_review_groups() to authenticated;
grant execute on function private.current_user_can_suspend_groups() to authenticated;

create policy groups_read_platform_admin_review
on public.groups for select
to authenticated
using (private.current_user_can_review_groups());

create or replace function public.list_group_review_queue(
  after_created_at timestamptz default null,
  after_id uuid default null,
  page_size integer default 20
)
returns table(
  id uuid, slug text, name text, description text, city_id uuid, city_name text,
  group_type text, join_policy text, status text, created_by uuid,
  owner_user_id uuid, created_at timestamptz, updated_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select g.id,g.slug,g.name,g.description,g.city_id,c.name,g.type,g.join_policy,
    g.status,g.created_by,g.owner_user_id,g.created_at,g.updated_at
  from public.groups g
  join public.cities c on c.id=g.city_id
  where private.current_user_can_review_groups()
    and g.status='pending'
    and (
      after_created_at is null or after_id is null
      or (g.created_at,g.id) > (after_created_at,after_id)
    )
  order by g.created_at,g.id
  limit case when page_size < 1 then 1 when page_size > 21 then 21 else page_size end;
$$;

create or replace function public.get_group_review(target_group_id uuid)
returns table(
  id uuid, slug text, name text, description text, city_id uuid, city_name text,
  group_type text, join_policy text, status text, rejection_reason text,
  created_by uuid, owner_user_id uuid, avatar_url text, cover_url text,
  created_at timestamptz, updated_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select g.id,g.slug,g.name,g.description,g.city_id,c.name,g.type,g.join_policy,
    g.status,g.rejection_reason,g.created_by,g.owner_user_id,g.avatar_url,g.cover_url,
    g.created_at,g.updated_at
  from public.groups g
  join public.cities c on c.id=g.city_id
  where private.current_user_can_review_groups()
    and g.id=target_group_id
    and g.status in ('pending','rejected','approved','suspended');
$$;

create or replace function public.approve_group_request(target_group_id uuid)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  actor uuid := (select auth.uid());
  target public.groups%rowtype;
begin
  if actor is null or not private.current_user_can_review_groups() then
    raise exception using errcode='42501', message='forbidden';
  end if;
  select * into target from public.groups g where g.id=target_group_id for update;
  if not found then raise exception using errcode='P0002', message='group_not_found'; end if;
  if target.status <> 'pending' then raise exception using errcode='P0001', message='state_changed'; end if;
  if target.created_by=actor or target.owner_user_id=actor then
    raise exception using errcode='42501', message='self_approval_forbidden';
  end if;
  perform 1 from public.group_members gm
    where gm.group_id=target_group_id and gm.user_id=target.owner_user_id
      and gm.role='owner' and gm.status='pending'
    for update;
  if not found then raise exception using errcode='23514', message='owner_membership_inconsistent'; end if;

  update public.group_members
  set status='active', joined_at=coalesce(joined_at,pg_catalog.now())
  where group_id=target_group_id and user_id=target.owner_user_id and role='owner' and status='pending';
  update public.groups
  set status='approved',approved_by=actor,approved_at=pg_catalog.now(),rejection_reason=null,suspended_at=null
  where id=target_group_id;

  insert into private.admin_audit_logs(actor_user_id,action,target_type,target_id,metadata)
  values(actor,'group_approved','group',target_group_id,pg_catalog.jsonb_build_object('from','pending','to','approved'));
  insert into public.notifications(recipient_user_id,actor_user_id,type,target_type,target_id,dedupe_key)
  values(target.owner_user_id,actor,'group_approved','group',target_group_id,'group_approved:'||target_group_id::text)
  on conflict(recipient_user_id,dedupe_key) do nothing;
  insert into private.analytics_events(event_name,user_id,city_id,entity_type,entity_id,properties,event_key)
  values('group_approved',actor,target.city_id,'group',target_group_id,'{}'::jsonb,'group_approved:'||target_group_id::text)
  on conflict(event_key) do nothing;
  insert into public.activity_events(actor_user_id,group_id,event_type,entity_type,entity_id,metadata,dedupe_key)
  values(target.owner_user_id,target_group_id,'group_joined','group',target_group_id,'{}'::jsonb,'group_joined:'||target_group_id::text||':'||target.owner_user_id::text)
  on conflict(dedupe_key) do nothing;
end;
$$;

create or replace function public.reject_group_request(target_group_id uuid, reason text)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  actor uuid := (select auth.uid());
  target public.groups%rowtype;
  normalized_reason text := pg_catalog.btrim(reason);
begin
  if actor is null or not private.current_user_can_review_groups() then
    raise exception using errcode='42501', message='forbidden';
  end if;
  if normalized_reason is null or pg_catalog.char_length(normalized_reason) not between 3 and 1000 then
    raise exception using errcode='22023', message='invalid_rejection_reason';
  end if;
  select * into target from public.groups g where g.id=target_group_id for update;
  if not found then raise exception using errcode='P0002', message='group_not_found'; end if;
  if target.status <> 'pending' then raise exception using errcode='P0001', message='state_changed'; end if;
  if target.created_by=actor or target.owner_user_id=actor then
    raise exception using errcode='42501', message='self_approval_forbidden';
  end if;
  update public.groups set status='rejected',rejection_reason=normalized_reason,
    approved_by=null,approved_at=null,suspended_at=null where id=target_group_id;
  insert into private.admin_audit_logs(actor_user_id,action,target_type,target_id,metadata)
  values(actor,'group_rejected','group',target_group_id,pg_catalog.jsonb_build_object('reason',normalized_reason));
  insert into public.notifications(recipient_user_id,actor_user_id,type,target_type,target_id,dedupe_key)
  values(target.owner_user_id,actor,'group_rejected','group',target_group_id,'group_rejected:'||target_group_id::text||':'||target.updated_at::text)
  on conflict(recipient_user_id,dedupe_key) do nothing;
  insert into private.analytics_events(event_name,user_id,city_id,entity_type,entity_id,properties,event_key)
  values('group_rejected',actor,target.city_id,'group',target_group_id,'{}'::jsonb,'group_rejected:'||target_group_id::text||':'||target.updated_at::text)
  on conflict(event_key) do nothing;
end;
$$;

create or replace function public.suspend_group(target_group_id uuid, reason text)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  actor uuid := (select auth.uid());
  normalized_reason text := pg_catalog.btrim(reason);
begin
  if actor is null or not private.current_user_can_suspend_groups() then
    raise exception using errcode='42501', message='forbidden';
  end if;
  if normalized_reason is null or pg_catalog.char_length(normalized_reason) not between 3 and 1000 then
    raise exception using errcode='22023', message='invalid_suspension_reason';
  end if;
  perform 1 from public.groups g where g.id=target_group_id and g.status='approved' for update;
  if not found then raise exception using errcode='P0001', message='state_changed'; end if;
  update public.groups set status='suspended',suspended_at=pg_catalog.now() where id=target_group_id;
  update public.run_series set status='paused'
    where group_id=target_group_id and status='active';
  update public.runs set status='cancelled',cancelled_at=pg_catalog.now(),cancellation_reason='Grupo suspenso'
    where group_id=target_group_id and status='scheduled' and starts_at>pg_catalog.now();
  insert into private.admin_audit_logs(actor_user_id,action,target_type,target_id,metadata)
  values(actor,'group_suspended','group',target_group_id,pg_catalog.jsonb_build_object('reason',normalized_reason));
end;
$$;

create or replace function public.restore_group(target_group_id uuid, reason text)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  actor uuid := (select auth.uid());
  normalized_reason text := pg_catalog.btrim(reason);
begin
  if actor is null or not private.current_user_can_review_groups() then
    raise exception using errcode='42501', message='forbidden';
  end if;
  if normalized_reason is null or pg_catalog.char_length(normalized_reason) not between 3 and 1000 then
    raise exception using errcode='22023', message='invalid_restore_reason';
  end if;
  perform 1 from public.groups g where g.id=target_group_id and g.status='suspended' for update;
  if not found then raise exception using errcode='P0001', message='state_changed'; end if;
  update public.groups set status='approved',suspended_at=null where id=target_group_id;
  insert into private.admin_audit_logs(actor_user_id,action,target_type,target_id,metadata)
  values(actor,'group_restored','group',target_group_id,pg_catalog.jsonb_build_object('reason',normalized_reason));
end;
$$;

alter function public.list_group_review_queue(timestamptz,uuid,integer) owner to postgres;
alter function public.get_group_review(uuid) owner to postgres;
alter function public.approve_group_request(uuid) owner to postgres;
alter function public.reject_group_request(uuid,text) owner to postgres;
alter function public.suspend_group(uuid,text) owner to postgres;
alter function public.restore_group(uuid,text) owner to postgres;
revoke all on function public.list_group_review_queue(timestamptz,uuid,integer) from public,anon,authenticated;
revoke all on function public.get_group_review(uuid) from public,anon,authenticated;
revoke all on function public.approve_group_request(uuid) from public,anon,authenticated;
revoke all on function public.reject_group_request(uuid,text) from public,anon,authenticated;
revoke all on function public.suspend_group(uuid,text) from public,anon,authenticated;
revoke all on function public.restore_group(uuid,text) from public,anon,authenticated;
grant execute on function public.list_group_review_queue(timestamptz,uuid,integer) to authenticated;
grant execute on function public.get_group_review(uuid) to authenticated;
grant execute on function public.approve_group_request(uuid) to authenticated;
grant execute on function public.reject_group_request(uuid,text) to authenticated;
grant execute on function public.suspend_group(uuid,text) to authenticated;
grant execute on function public.restore_group(uuid,text) to authenticated;

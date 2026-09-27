create or replace function private.current_group_role(target_group_id uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select gm.role
  from public.group_members gm
  join public.groups g on g.id=gm.group_id
  where gm.group_id=target_group_id
    and gm.user_id=(select auth.uid())
    and gm.status='active'
    and g.status='approved';
$$;

create or replace function private.current_user_manages_group(target_group_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    private.current_account_is_group_ready()
      and private.current_group_role(target_group_id) in ('owner','admin'),
    false
  );
$$;

alter function private.current_group_role(uuid) owner to postgres;
alter function private.current_user_manages_group(uuid) owner to postgres;
revoke all on function private.current_group_role(uuid) from public,anon,authenticated;
revoke all on function private.current_user_manages_group(uuid) from public,anon,authenticated;
grant execute on function private.current_group_role(uuid) to authenticated;
grant execute on function private.current_user_manages_group(uuid) to authenticated;

create or replace function public.join_group(target_group_id uuid)
returns text
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  actor uuid := (select auth.uid());
  target_group public.groups%rowtype;
  existing public.group_members%rowtype;
  resulting_status text;
begin
  if actor is null or not private.current_account_is_group_ready() then
    raise exception using errcode='42501', message='forbidden';
  end if;
  select * into target_group from public.groups g where g.id=target_group_id for update;
  if not found or target_group.status <> 'approved' then
    raise exception using errcode='P0001', message='state_changed';
  end if;
  select * into existing from public.group_members gm
    where gm.group_id=target_group_id and gm.user_id=actor for update;
  if found then
    if existing.status='blocked' then
      raise exception using errcode='42501', message='membership_blocked';
    end if;
    return existing.status;
  end if;

  resulting_status := case when target_group.join_policy='open' then 'active' else 'pending' end;
  insert into public.group_members(group_id,user_id,role,status,joined_at)
  values(target_group_id,actor,'member',resulting_status,
    case when resulting_status='active' then pg_catalog.now() end);

  if resulting_status='active' then
    insert into public.activity_events(actor_user_id,group_id,event_type,entity_type,entity_id,metadata,dedupe_key)
    values(actor,target_group_id,'group_joined','group',target_group_id,'{}'::jsonb,
      'group_joined:'||target_group_id::text||':'||actor::text)
    on conflict(dedupe_key) do nothing;
  else
    insert into public.notifications(recipient_user_id,actor_user_id,type,target_type,target_id,dedupe_key)
    values(target_group.owner_user_id,actor,'group_join_requested','group',target_group_id,
      'group_join_requested:'||target_group_id::text||':'||actor::text)
    on conflict(recipient_user_id,dedupe_key) do nothing;
  end if;
  return resulting_status;
end;
$$;

create or replace function public.approve_group_member(target_group_id uuid, target_user_id uuid)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare actor uuid := (select auth.uid());
begin
  if actor is null or not private.current_user_manages_group(target_group_id) then
    raise exception using errcode='42501', message='forbidden';
  end if;
  perform 1 from public.groups g where g.id=target_group_id and g.status='approved' for update;
  if not found then raise exception using errcode='P0001', message='state_changed'; end if;
  perform 1 from public.group_members gm where gm.group_id=target_group_id and gm.user_id=target_user_id
    and gm.role='member' and gm.status='pending' for update;
  if not found then raise exception using errcode='P0001', message='state_changed'; end if;
  if not private.account_is_active_for_visibility(target_user_id) then
    raise exception using errcode='42501', message='target_ineligible';
  end if;
  update public.group_members set status='active',joined_at=coalesce(joined_at,pg_catalog.now())
    where group_id=target_group_id and user_id=target_user_id;
  insert into public.activity_events(actor_user_id,group_id,event_type,entity_type,entity_id,metadata,dedupe_key)
  values(target_user_id,target_group_id,'group_joined','group',target_group_id,'{}'::jsonb,
    'group_joined:'||target_group_id::text||':'||target_user_id::text)
  on conflict(dedupe_key) do nothing;
  insert into public.notifications(recipient_user_id,actor_user_id,type,target_type,target_id,dedupe_key)
  values(target_user_id,actor,'group_membership_approved','group',target_group_id,
    'group_membership_approved:'||target_group_id::text||':'||target_user_id::text)
  on conflict(recipient_user_id,dedupe_key) do nothing;
end;
$$;

create or replace function public.reject_group_member_request(target_group_id uuid, target_user_id uuid)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null or not private.current_user_manages_group(target_group_id) then
    raise exception using errcode='42501', message='forbidden';
  end if;
  perform 1 from public.groups g where g.id=target_group_id and g.status='approved' for update;
  if not found then raise exception using errcode='P0001', message='state_changed'; end if;
  delete from public.group_members
    where group_id=target_group_id and user_id=target_user_id and role='member' and status='pending';
  if not found then raise exception using errcode='P0001', message='state_changed'; end if;
end;
$$;

create or replace function public.block_group_member(target_group_id uuid, target_user_id uuid)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null or not private.current_user_manages_group(target_group_id) then
    raise exception using errcode='42501', message='forbidden';
  end if;
  perform 1 from public.groups g where g.id=target_group_id and g.status='approved' for update;
  if not found then raise exception using errcode='P0001', message='state_changed'; end if;
  update public.group_members set status='blocked'
    where group_id=target_group_id and user_id=target_user_id and role='member' and status in ('active','pending');
  if not found then raise exception using errcode='42501', message='target_not_manageable'; end if;
end;
$$;

create or replace function public.leave_group(target_group_id uuid)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare actor uuid := (select auth.uid()); actor_role text;
begin
  if actor is null or not private.current_account_is_group_ready() then
    raise exception using errcode='42501', message='forbidden';
  end if;
  perform 1 from public.groups g where g.id=target_group_id and g.status='approved' for update;
  if not found then raise exception using errcode='P0001', message='state_changed'; end if;
  select gm.role into actor_role from public.group_members gm
    where gm.group_id=target_group_id and gm.user_id=actor and gm.status='active' for update;
  if not found then return; end if;
  if actor_role='owner' then raise exception using errcode='42501', message='owner_must_transfer'; end if;
  delete from public.group_members where group_id=target_group_id and user_id=actor;
end;
$$;

create or replace function public.promote_group_admin(target_group_id uuid, target_user_id uuid)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null or private.current_group_role(target_group_id) <> 'owner'
    or not private.current_account_is_group_ready() then
    raise exception using errcode='42501', message='forbidden';
  end if;
  perform 1 from public.groups g where g.id=target_group_id and g.status='approved' for update;
  update public.group_members set role='admin'
    where group_id=target_group_id and user_id=target_user_id and role='member' and status='active';
  if not found then raise exception using errcode='P0001', message='state_changed'; end if;
end;
$$;

create or replace function public.demote_group_admin(target_group_id uuid, target_user_id uuid)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null or private.current_group_role(target_group_id) <> 'owner'
    or not private.current_account_is_group_ready() then
    raise exception using errcode='42501', message='forbidden';
  end if;
  perform 1 from public.groups g where g.id=target_group_id and g.status='approved' for update;
  update public.group_members set role='member'
    where group_id=target_group_id and user_id=target_user_id and role='admin' and status='active';
  if not found then raise exception using errcode='P0001', message='state_changed'; end if;
end;
$$;

create or replace function public.list_group_members(
  target_group_id uuid,
  requested_status text default 'active',
  after_username text default null,
  after_user_id uuid default null,
  page_size integer default 20
)
returns table(
  user_id uuid, username text, full_name text, avatar_url text, visibility text,
  member_role text, member_status text, joined_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select p.id,p.username,p.full_name,
    case when p.is_private then null else p.avatar_url end,
    case when p.is_private then 'private' else 'public' end,
    gm.role,gm.status,gm.joined_at
  from public.group_members gm
  join public.profiles p on p.id=gm.user_id
  where gm.group_id=target_group_id
    and p.onboarding_completed
    and private.current_account_is_group_ready()
    and private.current_group_role(target_group_id) in ('member','admin','owner')
    and requested_status in ('active','pending','blocked')
    and gm.status=requested_status
    and (
      requested_status='active'
      or private.current_group_role(target_group_id) in ('admin','owner')
    )
    and (
      after_username is null or after_user_id is null
      or (p.username,p.id) > (after_username,after_user_id)
    )
  order by p.username,p.id
  limit case when page_size < 1 then 1 when page_size > 21 then 21 else page_size end;
$$;

alter function public.join_group(uuid) owner to postgres;
alter function public.approve_group_member(uuid,uuid) owner to postgres;
alter function public.reject_group_member_request(uuid,uuid) owner to postgres;
alter function public.block_group_member(uuid,uuid) owner to postgres;
alter function public.leave_group(uuid) owner to postgres;
alter function public.promote_group_admin(uuid,uuid) owner to postgres;
alter function public.demote_group_admin(uuid,uuid) owner to postgres;
alter function public.list_group_members(uuid,text,text,uuid,integer) owner to postgres;
revoke all on function public.join_group(uuid) from public,anon,authenticated;
revoke all on function public.approve_group_member(uuid,uuid) from public,anon,authenticated;
revoke all on function public.reject_group_member_request(uuid,uuid) from public,anon,authenticated;
revoke all on function public.block_group_member(uuid,uuid) from public,anon,authenticated;
revoke all on function public.leave_group(uuid) from public,anon,authenticated;
revoke all on function public.promote_group_admin(uuid,uuid) from public,anon,authenticated;
revoke all on function public.demote_group_admin(uuid,uuid) from public,anon,authenticated;
revoke all on function public.list_group_members(uuid,text,text,uuid,integer) from public,anon,authenticated;
grant execute on function public.join_group(uuid) to authenticated;
grant execute on function public.approve_group_member(uuid,uuid) to authenticated;
grant execute on function public.reject_group_member_request(uuid,uuid) to authenticated;
grant execute on function public.block_group_member(uuid,uuid) to authenticated;
grant execute on function public.leave_group(uuid) to authenticated;
grant execute on function public.promote_group_admin(uuid,uuid) to authenticated;
grant execute on function public.demote_group_admin(uuid,uuid) to authenticated;
grant execute on function public.list_group_members(uuid,text,text,uuid,integer) to authenticated;

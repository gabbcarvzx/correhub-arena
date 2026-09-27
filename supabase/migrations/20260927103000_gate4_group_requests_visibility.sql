create or replace function private.current_account_is_group_ready()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.current_account_is_social_ready();
$$;

create or replace function private.group_slug_is_reserved(candidate text)
returns boolean
language sql
immutable
security invoker
set search_path = ''
as $$
  select candidate = any (array[
    'admin','api','auth','grupos','login','logout','me','meus','onboarding',
    'people','settings','solicitar','u'
  ]::text[]);
$$;

create or replace function private.consume_group_request_rate_limit()
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  actor uuid := (select auth.uid());
  bucket_start timestamptz := pg_catalog.date_trunc('day', pg_catalog.now());
  current_consumed integer;
begin
  if actor is null then
    raise exception using errcode = '42501', message = 'unauthenticated';
  end if;

  insert into private.rate_limit_buckets(user_id, action, window_started_at, consumed, expires_at)
  values (actor, 'group_request', bucket_start, 1, bucket_start + interval '1 day')
  on conflict (user_id, action, window_started_at)
  do update set consumed = private.rate_limit_buckets.consumed + 1
  returning consumed into current_consumed;

  if current_consumed > 5 then
    raise exception using errcode = 'P0001', message = 'rate_limited';
  end if;
end;
$$;

alter function private.current_account_is_group_ready() owner to postgres;
alter function private.group_slug_is_reserved(text) owner to postgres;
alter function private.consume_group_request_rate_limit() owner to postgres;
revoke all on function private.current_account_is_group_ready() from public, anon, authenticated;
revoke all on function private.group_slug_is_reserved(text) from public, anon, authenticated;
revoke all on function private.consume_group_request_rate_limit() from public, anon, authenticated;
grant execute on function private.current_account_is_group_ready() to authenticated;

create index groups_status_created_id_idx on public.groups(status, created_at, id);

create policy groups_read_approved
on public.groups for select
to anon, authenticated
using (status = 'approved');

create policy groups_read_own_request
on public.groups for select
to authenticated
using (
  owner_user_id = (select auth.uid())
  and status in ('pending','rejected','suspended')
  and private.current_account_is_group_ready()
);

create policy group_members_read_own_relation
on public.group_members for select
to authenticated
using (
  user_id = (select auth.uid())
  and private.current_account_is_active()
);

grant select (
  id, slug, name, description, city_id, type, join_policy, status,
  created_by, owner_user_id, avatar_url, cover_url, approved_at,
  suspended_at, created_at, updated_at
) on public.groups to anon, authenticated;

grant select (group_id, user_id, role, status, joined_at, updated_at)
on public.group_members to authenticated;

create or replace function public.request_group(
  requested_name text,
  requested_slug text,
  requested_description text,
  requested_city_id uuid,
  requested_type text,
  requested_join_policy text
)
returns uuid
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  actor uuid := (select auth.uid());
  created_group_id uuid;
  normalized_name text := pg_catalog.btrim(requested_name);
  normalized_description text := pg_catalog.btrim(requested_description);
begin
  if actor is null or not private.current_account_is_group_ready() then
    raise exception using errcode = '42501', message = 'forbidden';
  end if;
  if requested_slug is null
    or requested_slug <> pg_catalog.lower(requested_slug)
    or requested_slug !~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'
    or pg_catalog.char_length(requested_slug) not between 3 and 100
    or private.group_slug_is_reserved(requested_slug) then
    raise exception using errcode = '22023', message = 'invalid_group_slug';
  end if;
  if requested_type not in ('community','professional') then
    raise exception using errcode = '22023', message = 'invalid_group_type';
  end if;
  if requested_join_policy not in ('open','approval_required') then
    raise exception using errcode = '22023', message = 'invalid_join_policy';
  end if;
  if not exists (select 1 from public.cities c where c.id=requested_city_id and c.is_active) then
    raise exception using errcode = '23514', message = 'inactive_city';
  end if;

  perform private.consume_group_request_rate_limit();

  insert into public.groups(
    slug,name,description,city_id,type,join_policy,status,created_by,owner_user_id
  ) values (
    requested_slug,normalized_name,normalized_description,requested_city_id,
    requested_type,requested_join_policy,'pending',actor,actor
  ) returning id into created_group_id;

  insert into public.group_members(group_id,user_id,role,status)
  values (created_group_id,actor,'owner','pending');

  insert into private.analytics_events(
    event_name,user_id,city_id,entity_type,entity_id,properties,event_key
  ) values (
    'group_requested',actor,requested_city_id,'group',created_group_id,
    pg_catalog.jsonb_build_object('group_type',requested_type,'join_policy',requested_join_policy),
    'group_requested:' || created_group_id::text
  );

  return created_group_id;
end;
$$;

create or replace function public.update_group_profile(
  target_group_id uuid,
  requested_name text,
  requested_slug text,
  requested_description text,
  requested_city_id uuid,
  requested_type text,
  requested_join_policy text
)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  actor uuid := (select auth.uid());
  current_status text;
begin
  if actor is null or not private.current_account_is_group_ready() then
    raise exception using errcode='42501', message='forbidden';
  end if;
  select g.status into current_status
  from public.groups g
  where g.id=target_group_id and g.owner_user_id=actor
  for update;
  if not found then raise exception using errcode='P0002', message='group_not_found'; end if;
  if current_status not in ('pending','rejected') then
    raise exception using errcode='42501', message='group_not_editable';
  end if;
  if requested_slug is null
    or requested_slug <> pg_catalog.lower(requested_slug)
    or requested_slug !~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'
    or pg_catalog.char_length(requested_slug) not between 3 and 100
    or private.group_slug_is_reserved(requested_slug) then
    raise exception using errcode='22023', message='invalid_group_slug';
  end if;
  if requested_type not in ('community','professional') or requested_join_policy not in ('open','approval_required') then
    raise exception using errcode='22023', message='invalid_group_configuration';
  end if;
  if not exists (select 1 from public.cities c where c.id=requested_city_id and c.is_active) then
    raise exception using errcode='23514', message='inactive_city';
  end if;
  update public.groups set
    name=pg_catalog.btrim(requested_name), slug=requested_slug,
    description=pg_catalog.btrim(requested_description), city_id=requested_city_id,
    type=requested_type, join_policy=requested_join_policy
  where id=target_group_id;
end;
$$;

create or replace function public.resubmit_group(target_group_id uuid)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  actor uuid := (select auth.uid());
begin
  if actor is null or not private.current_account_is_group_ready() then
    raise exception using errcode='42501', message='forbidden';
  end if;
  update public.groups
  set status='pending', rejection_reason=null, approved_by=null, approved_at=null, suspended_at=null
  where id=target_group_id and owner_user_id=actor and status='rejected';
  if not found then raise exception using errcode='P0002', message='group_not_resubmittable'; end if;
end;
$$;

create or replace function public.get_group_by_slug(target_slug text)
returns table(
  id uuid, slug text, name text, description text, city_id uuid, city_name text,
  group_type text, join_policy text, status text, owner_user_id uuid,
  avatar_url text, cover_url text, approved_at timestamptz, created_at timestamptz,
  updated_at timestamptz, is_owner boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  select g.id,g.slug,g.name,g.description,g.city_id,c.name,g.type,g.join_policy,g.status,
    g.owner_user_id,g.avatar_url,g.cover_url,g.approved_at,g.created_at,g.updated_at,
    g.owner_user_id=(select auth.uid())
  from public.groups g
  join public.cities c on c.id=g.city_id
  where g.slug=target_slug
    and (
      g.status='approved'
      or (
        (select auth.uid()) is not null
        and g.owner_user_id=(select auth.uid())
        and g.status in ('pending','rejected','suspended')
        and private.current_account_is_group_ready()
      )
    );
$$;

create or replace function public.list_my_groups(
  after_updated_at timestamptz default null,
  after_id uuid default null,
  page_size integer default 20
)
returns table(
  id uuid, slug text, name text, group_type text, join_policy text, status text,
  rejection_reason text, avatar_url text, updated_at timestamptz,
  relation_role text, relation_status text
)
language sql
stable
security definer
set search_path = ''
as $$
  select g.id,g.slug,g.name,g.type,g.join_policy,g.status,g.rejection_reason,g.avatar_url,g.updated_at,
    gm.role,gm.status
  from public.groups g
  join public.group_members gm on gm.group_id=g.id
  where (select auth.uid()) is not null
    and private.current_account_is_group_ready()
    and gm.user_id=(select auth.uid())
    and (
      after_updated_at is null or after_id is null
      or (g.updated_at,g.id) < (after_updated_at,after_id)
    )
  order by g.updated_at desc,g.id desc
  limit case
    when page_size < 1 then 1
    when page_size > 21 then 21
    else page_size
  end;
$$;

create or replace function public.get_current_group_relation(target_group_id uuid)
returns table(relation_role text, relation_status text, joined_at timestamptz)
language sql
stable
security definer
set search_path = ''
as $$
  select gm.role,gm.status,gm.joined_at
  from public.group_members gm
  where gm.group_id=target_group_id
    and gm.user_id=(select auth.uid())
    and private.current_account_is_group_ready();
$$;

alter function public.request_group(text,text,text,uuid,text,text) owner to postgres;
alter function public.update_group_profile(uuid,text,text,text,uuid,text,text) owner to postgres;
alter function public.resubmit_group(uuid) owner to postgres;
alter function public.get_group_by_slug(text) owner to postgres;
alter function public.list_my_groups(timestamptz,uuid,integer) owner to postgres;
alter function public.get_current_group_relation(uuid) owner to postgres;

revoke all on function public.request_group(text,text,text,uuid,text,text) from public,anon,authenticated;
revoke all on function public.update_group_profile(uuid,text,text,text,uuid,text,text) from public,anon,authenticated;
revoke all on function public.resubmit_group(uuid) from public,anon,authenticated;
revoke all on function public.get_group_by_slug(text) from public,anon,authenticated;
revoke all on function public.list_my_groups(timestamptz,uuid,integer) from public,anon,authenticated;
revoke all on function public.get_current_group_relation(uuid) from public,anon,authenticated;

grant execute on function public.request_group(text,text,text,uuid,text,text) to authenticated;
grant execute on function public.update_group_profile(uuid,text,text,text,uuid,text,text) to authenticated;
grant execute on function public.resubmit_group(uuid) to authenticated;
grant execute on function public.get_group_by_slug(text) to anon,authenticated;
grant execute on function public.list_my_groups(timestamptz,uuid,integer) to authenticated;
grant execute on function public.get_current_group_relation(uuid) to authenticated;

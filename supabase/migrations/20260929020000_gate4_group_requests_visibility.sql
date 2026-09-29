create or replace function private.current_account_is_group_ready()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from private.account_controls ac
    join public.profiles p on p.id = ac.user_id
    where ac.user_id = (select auth.uid())
      and ac.status = 'active'
      and p.onboarding_completed
  );
$$;

create or replace function private.group_slug_is_reserved(requested_slug text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select pg_catalog.lower(pg_catalog.btrim(coalesce(requested_slug, ''))) in ('solicitar', 'meus');
$$;

alter function private.current_account_is_group_ready() owner to postgres;
alter function private.group_slug_is_reserved(text) owner to postgres;

revoke all on function private.current_account_is_group_ready() from public, anon, authenticated;
revoke all on function private.group_slug_is_reserved(text) from public, anon, authenticated;
grant execute on function private.current_account_is_group_ready() to authenticated;
grant execute on function private.group_slug_is_reserved(text) to authenticated;

create policy groups_read_approved_anon
on public.groups for select
to anon
using (status = 'approved');

create policy groups_read_approved_authenticated
on public.groups for select
to authenticated
using (status = 'approved');

create policy groups_read_requester
on public.groups for select
to authenticated
using (
  owner_user_id = (select auth.uid())
  and private.current_account_is_group_ready()
);

create policy groups_read_platform_admin
on public.groups for select
to authenticated
using (
  private.current_account_is_group_ready()
  and private.current_user_has_platform_role('platform_admin')
);

create policy groups_read_moderator_suspended
on public.groups for select
to authenticated
using (
  status = 'suspended'
  and private.current_account_is_group_ready()
  and private.current_user_has_platform_role('moderator')
);

revoke all on public.groups from public, anon, authenticated;
grant select (
  id, slug, name, description, city_id, type, join_policy, status, created_at, updated_at
) on public.groups to anon, authenticated;

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
  actor_id uuid := (select auth.uid());
  normalized_name text := pg_catalog.btrim(coalesce(requested_name, ''));
  normalized_slug text;
  normalized_description text := pg_catalog.btrim(coalesce(requested_description, ''));
  window_start timestamptz;
  request_count integer;
  group_id uuid;
begin
  if actor_id is null then
    raise exception using errcode = '42501', message = 'authentication required';
  end if;

  perform 1
  from private.account_controls ac
  join public.profiles p on p.id = ac.user_id
  where ac.user_id = actor_id
    and ac.status = 'active'
    and p.onboarding_completed
  for share of ac, p;
  if not found then
    raise exception using errcode = '42501', message = 'account is not eligible to request groups';
  end if;

  if pg_catalog.char_length(normalized_name) not between 3 and 100 then
    raise exception using errcode = '22023', message = 'group name is invalid';
  end if;
  if pg_catalog.char_length(normalized_description) not between 1 and 2000 then
    raise exception using errcode = '22023', message = 'group description is invalid';
  end if;

  normalized_slug := pg_catalog.lower(pg_catalog.btrim(coalesce(requested_slug, '')));
  normalized_slug := pg_catalog.regexp_replace(normalized_slug, '[^a-z0-9]+', '-', 'g');
  normalized_slug := pg_catalog.regexp_replace(normalized_slug, '(^-+|-+$)', '', 'g');
  if pg_catalog.char_length(normalized_slug) not between 3 and 100
    or normalized_slug !~ '^[a-z0-9]+(-[a-z0-9]+)*$' then
    raise exception using errcode = '22023', message = 'group slug is invalid';
  end if;
  if private.group_slug_is_reserved(normalized_slug) then
    raise exception using errcode = '22023', message = 'group slug is reserved';
  end if;
  if requested_type not in ('community', 'professional') then
    raise exception using errcode = '22023', message = 'group type is invalid';
  end if;
  if requested_join_policy not in ('open', 'approval_required') then
    raise exception using errcode = '22023', message = 'group join policy is invalid';
  end if;
  if requested_city_id is null then
    raise exception using errcode = '22023', message = 'group city is required';
  end if;

  perform 1
  from public.cities c
  where c.id = requested_city_id and c.is_active
  for share;
  if not found then
    raise exception using errcode = '23514', message = 'city must be active';
  end if;

  window_start := pg_catalog.date_trunc('day', (pg_catalog.now() at time zone 'UTC')) at time zone 'UTC';
  insert into private.rate_limit_buckets as bucket (
    user_id, action, window_started_at, consumed, expires_at
  ) values (
    actor_id, 'group_request', window_start, 1, window_start + interval '1 day'
  )
  on conflict (user_id, action, window_started_at) do update
  set consumed = bucket.consumed + 1
  where bucket.consumed < 5
  returning consumed into request_count;

  if not found then
    raise exception using errcode = 'P0001', message = 'group_request_rate_limited';
  end if;

  insert into public.groups (
    slug, name, description, city_id, type, join_policy, status, created_by, owner_user_id
  ) values (
    normalized_slug, normalized_name, normalized_description, requested_city_id,
    requested_type, requested_join_policy, 'pending', actor_id, actor_id
  ) returning id into group_id;

  insert into public.group_members (group_id, user_id, role, status)
  values (group_id, actor_id, 'owner', 'pending');

  insert into private.analytics_events (
    event_name, user_id, city_id, entity_type, entity_id, properties, event_key
  ) values (
    'group_requested', actor_id, requested_city_id, 'group', group_id, '{}'::jsonb,
    'group_requested:' || group_id::text
  );

  return group_id;
end;
$$;

alter function public.request_group(text, text, text, uuid, text, text) owner to postgres;
revoke all on function public.request_group(text, text, text, uuid, text, text) from public, anon, authenticated;
grant execute on function public.request_group(text, text, text, uuid, text, text) to authenticated;

create or replace function public.update_group_profile(
  target_group_id uuid,
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
  actor_id uuid := (select auth.uid());
  group_status text;
  designated_owner uuid;
  current_slug text;
  normalized_name text := pg_catalog.btrim(coalesce(requested_name, ''));
  normalized_slug text;
  normalized_description text := pg_catalog.btrim(coalesce(requested_description, ''));
begin
  if actor_id is null then
    raise exception using errcode = '42501', message = 'authentication required';
  end if;

  perform 1
  from private.account_controls ac
  join public.profiles p on p.id = ac.user_id
  where ac.user_id = actor_id
    and ac.status = 'active'
    and p.onboarding_completed
  for share of ac, p;
  if not found then
    raise exception using errcode = '42501', message = 'account is not eligible to manage groups';
  end if;

  select g.status, g.owner_user_id, g.slug
  into group_status, designated_owner, current_slug
  from public.groups g
  where g.id = target_group_id
  for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'group not found';
  end if;

  if group_status in ('pending', 'rejected') then
    if designated_owner is distinct from actor_id
      or not exists (
        select 1 from public.group_members gm
        where gm.group_id = target_group_id
          and gm.user_id = actor_id
          and gm.role = 'owner'
          and gm.status = 'pending'
      ) then
      raise exception using errcode = '42501', message = 'group management is not allowed';
    end if;
  elsif group_status = 'approved' then
    if not exists (
      select 1 from public.group_members gm
      where gm.group_id = target_group_id
        and gm.user_id = actor_id
        and gm.role in ('admin', 'owner')
        and gm.status = 'active'
    ) then
      raise exception using errcode = '42501', message = 'group management is not allowed';
    end if;
  else
    raise exception using errcode = 'P0001', message = 'group_state_changed';
  end if;

  if pg_catalog.char_length(normalized_name) not between 3 and 100 then
    raise exception using errcode = '22023', message = 'group name is invalid';
  end if;
  if pg_catalog.char_length(normalized_description) not between 1 and 2000 then
    raise exception using errcode = '22023', message = 'group description is invalid';
  end if;
  normalized_slug := pg_catalog.lower(pg_catalog.btrim(coalesce(requested_slug, '')));
  normalized_slug := pg_catalog.regexp_replace(normalized_slug, '[^a-z0-9]+', '-', 'g');
  normalized_slug := pg_catalog.regexp_replace(normalized_slug, '(^-+|-+$)', '', 'g');
  if pg_catalog.char_length(normalized_slug) not between 3 and 100
    or normalized_slug !~ '^[a-z0-9]+(-[a-z0-9]+)*$' then
    raise exception using errcode = '22023', message = 'group slug is invalid';
  end if;
  if private.group_slug_is_reserved(normalized_slug) then
    raise exception using errcode = '22023', message = 'group slug is reserved';
  end if;
  if requested_type not in ('community', 'professional') then
    raise exception using errcode = '22023', message = 'group type is invalid';
  end if;
  if requested_join_policy not in ('open', 'approval_required') then
    raise exception using errcode = '22023', message = 'group join policy is invalid';
  end if;
  if requested_city_id is null then
    raise exception using errcode = '22023', message = 'group city is required';
  end if;
  if group_status = 'approved' and normalized_slug is distinct from current_slug then
    raise exception using errcode = '22023', message = 'approved group slug is immutable';
  end if;

  perform 1 from public.cities c
  where c.id = requested_city_id and c.is_active
  for share;
  if not found then
    raise exception using errcode = '23514', message = 'city must be active';
  end if;

  update public.groups g
  set name = normalized_name,
      slug = normalized_slug,
      description = normalized_description,
      city_id = requested_city_id,
      type = requested_type,
      join_policy = requested_join_policy
  where g.id = target_group_id;

  return target_group_id;
end;
$$;

alter function public.update_group_profile(uuid, text, text, text, uuid, text, text) owner to postgres;
revoke all on function public.update_group_profile(uuid, text, text, text, uuid, text, text) from public, anon, authenticated;
grant execute on function public.update_group_profile(uuid, text, text, text, uuid, text, text) to authenticated;

create or replace function public.resubmit_group(target_group_id uuid)
returns uuid
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  actor_id uuid := (select auth.uid());
  group_status text;
  designated_owner uuid;
begin
  if actor_id is null then
    raise exception using errcode = '42501', message = 'authentication required';
  end if;

  perform 1
  from private.account_controls ac
  join public.profiles p on p.id = ac.user_id
  where ac.user_id = actor_id
    and ac.status = 'active'
    and p.onboarding_completed
  for share of ac, p;
  if not found then
    raise exception using errcode = '42501', message = 'account is not eligible to manage groups';
  end if;

  select g.status, g.owner_user_id
  into group_status, designated_owner
  from public.groups g
  where g.id = target_group_id
  for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'group not found';
  end if;
  if designated_owner is distinct from actor_id
    or not exists (
      select 1 from public.group_members gm
      where gm.group_id = target_group_id
        and gm.user_id = actor_id
        and gm.role = 'owner'
        and gm.status = 'pending'
    ) then
    raise exception using errcode = '42501', message = 'group management is not allowed';
  end if;
  if group_status <> 'rejected' then
    raise exception using errcode = 'P0001', message = 'group_state_changed';
  end if;

  update public.groups g
  set status = 'pending',
      rejection_reason = null,
      approved_by = null,
      approved_at = null,
      suspended_at = null
  where g.id = target_group_id;

  return target_group_id;
end;
$$;

alter function public.resubmit_group(uuid) owner to postgres;
revoke all on function public.resubmit_group(uuid) from public, anon, authenticated;
grant execute on function public.resubmit_group(uuid) to authenticated;

create or replace function public.get_group_by_slug(target_slug text)
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
  group_view text,
  created_at timestamptz,
  updated_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    g.id,
    g.slug,
    g.name,
    g.description,
    g.city_id,
    c.name as city_name,
    c.state_code,
    g.type as group_type,
    g.join_policy,
    g.status as group_status,
    case
      when g.status = 'approved' then 'public'
      when g.status = 'suspended' then 'suspended'
      when g.owner_user_id = (select auth.uid()) then 'requester'
      else 'reviewer'
    end as group_view,
    g.created_at,
    g.updated_at
  from public.groups g
  join public.cities c on c.id = g.city_id
  where g.slug = pg_catalog.lower(pg_catalog.btrim(coalesce(target_slug, '')))
    and (
      g.status = 'approved'
      or (
        g.status in ('pending', 'rejected', 'suspended')
        and private.current_account_is_group_ready()
        and g.owner_user_id = (select auth.uid())
      )
      or (
        g.status in ('pending', 'rejected', 'suspended')
        and private.current_account_is_group_ready()
        and private.current_user_has_platform_role('platform_admin')
      )
      or (
        g.status = 'suspended'
        and private.current_account_is_group_ready()
        and private.current_user_has_platform_role('moderator')
      )
    );
$$;

alter function public.get_group_by_slug(text) owner to postgres;
revoke all on function public.get_group_by_slug(text) from public, anon, authenticated;
grant execute on function public.get_group_by_slug(text) to anon, authenticated;

create or replace function public.list_my_groups(
  after_updated_at timestamptz default null,
  after_id uuid default null,
  page_size integer default 20
)
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
  membership_role text,
  membership_status text,
  rejection_reason text,
  created_at timestamptz,
  updated_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    g.id,
    g.slug,
    g.name,
    g.description,
    g.city_id,
    c.name as city_name,
    c.state_code,
    g.type as group_type,
    g.join_policy,
    g.status as group_status,
    gm.role as membership_role,
    gm.status as membership_status,
    case when g.owner_user_id = (select auth.uid()) then g.rejection_reason else null end,
    g.created_at,
    g.updated_at
  from public.group_members gm
  join public.groups g on g.id = gm.group_id
  join public.cities c on c.id = g.city_id
  where (select auth.uid()) is not null
    and private.current_account_is_group_ready()
    and gm.user_id = (select auth.uid())
    and (
      after_updated_at is null
      or after_id is null
      or (g.updated_at, g.id) < (after_updated_at, after_id)
    )
  order by g.updated_at desc, g.id desc
  limit least(greatest(coalesce(page_size, 20), 1), 50);
$$;

alter function public.list_my_groups(timestamptz, uuid, integer) owner to postgres;
revoke all on function public.list_my_groups(timestamptz, uuid, integer) from public, anon, authenticated;
grant execute on function public.list_my_groups(timestamptz, uuid, integer) to authenticated;

create or replace function public.get_current_group_relation(target_group_id uuid)
returns table (
  group_id uuid,
  group_status text,
  membership_role text,
  membership_status text
)
language sql
stable
security definer
set search_path = ''
as $$
  select g.id, g.status, gm.role, gm.status
  from public.groups g
  left join public.group_members gm
    on gm.group_id = g.id and gm.user_id = (select auth.uid())
  where g.id = target_group_id
    and (select auth.uid()) is not null
    and private.current_account_is_group_ready()
    and (g.status = 'approved' or g.owner_user_id = (select auth.uid()));
$$;

alter function public.get_current_group_relation(uuid) owner to postgres;
revoke all on function public.get_current_group_relation(uuid) from public, anon, authenticated;
grant execute on function public.get_current_group_relation(uuid) to authenticated;

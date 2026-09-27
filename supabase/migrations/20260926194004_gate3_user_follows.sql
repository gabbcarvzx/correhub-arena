create or replace function private.current_account_is_social_ready()
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

create or replace function private.profile_is_socially_eligible(target_user_id uuid)
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
    where ac.user_id = target_user_id
      and ac.status = 'active'
      and p.onboarding_completed
  );
$$;

alter function private.current_account_is_social_ready() owner to postgres;
alter function private.profile_is_socially_eligible(uuid) owner to postgres;

revoke all on function private.current_account_is_social_ready() from public, anon, authenticated;
revoke all on function private.profile_is_socially_eligible(uuid) from public, anon, authenticated;
grant execute on function private.current_account_is_social_ready() to authenticated;
grant execute on function private.profile_is_socially_eligible(uuid) to authenticated;

grant select, delete on public.user_follows to authenticated;
grant insert (follower_id, followed_id) on public.user_follows to authenticated;

create policy user_follows_select_own
on public.user_follows for select
to authenticated
using (
  private.current_account_is_social_ready()
  and (
    follower_id = (select auth.uid())
    or followed_id = (select auth.uid())
  )
);

create policy user_follows_insert_own
on public.user_follows for insert
to authenticated
with check (
  follower_id = (select auth.uid())
  and follower_id <> followed_id
  and private.current_account_is_social_ready()
  and private.profile_is_socially_eligible(followed_id)
);

create policy user_follows_delete_own
on public.user_follows for delete
to authenticated
using (
  follower_id = (select auth.uid())
  and private.current_account_is_social_ready()
);

create or replace function public.list_profile_connections(
  target_username text,
  connection_direction text,
  after_username text default null,
  after_id uuid default null,
  page_size integer default 20
)
returns table (
  id uuid,
  username text,
  full_name text,
  avatar_url text,
  bio text,
  city_id uuid,
  city_name text,
  city_slug text,
  country_code text,
  state_code text,
  running_level text,
  preferred_distance text,
  pace_seconds_per_km integer,
  visibility text,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  with target as (
    select p.id, p.is_private
    from public.profiles p
    join private.account_controls ac on ac.user_id = p.id
    where p.username = target_username
      and p.onboarding_completed
      and ac.status = 'active'
  ),
  relationships as (
    select
      case
        when connection_direction = 'followers' then uf.follower_id
        when connection_direction = 'following' then uf.followed_id
      end as counterpart_id
    from public.user_follows uf
    join target t on (
      (connection_direction = 'followers' and uf.followed_id = t.id)
      or (connection_direction = 'following' and uf.follower_id = t.id)
    )
    where connection_direction in ('followers', 'following')
  )
  select
    cp.id,
    cp.username,
    cp.full_name,
    case when not cp.is_private then cp.avatar_url end,
    case when not cp.is_private then cp.bio end,
    case when not cp.is_private then cp.city_id end,
    case when not cp.is_private then c.name end,
    case when not cp.is_private then c.slug end,
    case when not cp.is_private then c.country_code end,
    case when not cp.is_private then c.state_code end,
    case when not cp.is_private then cp.running_level end,
    case when not cp.is_private then cp.preferred_distance end,
    case when not cp.is_private then cp.pace_seconds_per_km end,
    case when cp.is_private then 'private' else 'public' end,
    cp.created_at
  from target t
  join relationships r on true
  join public.profiles cp on cp.id = r.counterpart_id
  join private.account_controls cac on cac.user_id = cp.id
  join public.cities c on c.id = cp.city_id
  where (select auth.uid()) is not null
    and private.current_account_is_social_ready()
    and (not t.is_private or t.id = (select auth.uid()))
    and cp.onboarding_completed
    and cac.status = 'active'
    and (t.id = (select auth.uid()) or not cp.is_private)
    and (
      after_username is null
      or after_id is null
      or (cp.username, cp.id) > (after_username, after_id)
    )
  order by cp.username, cp.id
  limit case
    when page_size is null then 20
    when page_size < 1 then 1
    when page_size > 20 then 20
    else page_size
  end;
$$;

alter function public.list_profile_connections(text, text, text, uuid, integer) owner to postgres;
revoke all on function public.list_profile_connections(text, text, text, uuid, integer) from public, anon, authenticated;
grant execute on function public.list_profile_connections(text, text, text, uuid, integer) to authenticated;

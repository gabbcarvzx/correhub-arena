revoke update (avatar_url) on public.profiles from authenticated;

create or replace function private.prevent_profile_onboarding_regression()
returns trigger
language plpgsql
volatile
security definer
set search_path = ''
as $$
begin
  if old.onboarding_completed and not new.onboarding_completed then
    raise exception using
      errcode = '23514',
      message = 'onboarding completion cannot be reversed';
  end if;

  return new;
end;
$$;

create or replace function private.protect_profile_personal_posts()
returns trigger
language plpgsql
volatile
security definer
set search_path = ''
as $$
begin
  if not old.is_private and new.is_private then
    update public.posts
    set visibility = 'private'
    where author_user_id = new.id
      and group_id is null
      and visibility = 'public';
  end if;

  return new;
end;
$$;

alter function private.prevent_profile_onboarding_regression() owner to postgres;
alter function private.protect_profile_personal_posts() owner to postgres;

revoke all on function private.prevent_profile_onboarding_regression() from public, anon, authenticated;
revoke all on function private.protect_profile_personal_posts() from public, anon, authenticated;

create trigger profiles_prevent_onboarding_regression
before update of onboarding_completed on public.profiles
for each row execute function private.prevent_profile_onboarding_regression();

create trigger profiles_protect_personal_posts
after update of is_private on public.profiles
for each row
when (old.is_private is distinct from new.is_private)
execute function private.protect_profile_personal_posts();

create or replace function private.profile_is_publicly_visible(target_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.profiles p
    join private.account_controls ac on ac.user_id = p.id
    where p.id = target_user_id
      and p.onboarding_completed
      and not p.is_private
      and ac.status = 'active'
  );
$$;

alter function private.profile_is_publicly_visible(uuid) owner to postgres;
revoke all on function private.profile_is_publicly_visible(uuid) from public, anon, authenticated;
grant execute on function private.profile_is_publicly_visible(uuid) to anon, authenticated;

create or replace view public.profile_directory
with (security_invoker = true)
as
select
  p.id,
  p.username,
  p.full_name,
  p.avatar_url,
  p.bio,
  p.city_id,
  p.running_level,
  p.preferred_distance,
  p.pace_seconds_per_km,
  p.created_at,
  c.name as city_name,
  c.slug as city_slug,
  c.country_code,
  c.state_code
from public.profiles p
join public.cities c on c.id = p.city_id
where private.profile_is_publicly_visible(p.id);

revoke all on public.profile_directory from public, anon, authenticated;
grant select on public.profile_directory to anon, authenticated;

create or replace function public.get_profile_by_username(target_username text)
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
  select
    p.id,
    p.username,
    p.full_name,
    case when p.id = (select auth.uid()) or not p.is_private then p.avatar_url end,
    case when p.id = (select auth.uid()) or not p.is_private then p.bio end,
    case when p.id = (select auth.uid()) or not p.is_private then p.city_id end,
    case when p.id = (select auth.uid()) or not p.is_private then c.name end,
    case when p.id = (select auth.uid()) or not p.is_private then c.slug end,
    case when p.id = (select auth.uid()) or not p.is_private then c.country_code end,
    case when p.id = (select auth.uid()) or not p.is_private then c.state_code end,
    case when p.id = (select auth.uid()) or not p.is_private then p.running_level end,
    case when p.id = (select auth.uid()) or not p.is_private then p.preferred_distance end,
    case when p.id = (select auth.uid()) or not p.is_private then p.pace_seconds_per_km end,
    case
      when p.id = (select auth.uid()) then 'self'
      when p.is_private then 'private'
      else 'public'
    end,
    p.created_at
  from public.profiles p
  join public.cities c on c.id = p.city_id
  where p.username = target_username
    and p.onboarding_completed
    and private.account_is_active_for_visibility(p.id)
  limit 1;
$$;

alter function public.get_profile_by_username(text) owner to postgres;
revoke all on function public.get_profile_by_username(text) from public, anon, authenticated;
grant execute on function public.get_profile_by_username(text) to anon, authenticated;

create or replace function public.discover_profiles(
  search_query text default null,
  filter_city_id uuid default null,
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
security invoker
set search_path = ''
as $$
  select
    p.id,
    p.username,
    p.full_name,
    p.avatar_url,
    p.bio,
    p.city_id,
    p.city_name,
    p.city_slug,
    p.country_code,
    p.state_code,
    p.running_level,
    p.preferred_distance,
    p.pace_seconds_per_km,
    'public'::text,
    p.created_at
  from public.profile_directory p
  where (filter_city_id is null or p.city_id = filter_city_id)
    and (
      search_query is null
      or pg_catalog.btrim(search_query) = ''
      or (
        pg_catalog.char_length(pg_catalog.btrim(search_query)) <= 80
        and (
          p.username ilike '%' || pg_catalog.btrim(search_query) || '%'
          or p.full_name ilike '%' || pg_catalog.btrim(search_query) || '%'
        )
      )
    )
    and (
      after_username is null
      or after_id is null
      or (p.username, p.id) > (after_username, after_id)
    )
  order by p.username, p.id
  limit case
    when page_size is null then 20
    when page_size < 1 then 1
    when page_size > 20 then 20
    else page_size
  end;
$$;

alter function public.discover_profiles(text, uuid, text, uuid, integer) owner to postgres;
revoke all on function public.discover_profiles(text, uuid, text, uuid, integer) from public, anon, authenticated;
grant execute on function public.discover_profiles(text, uuid, text, uuid, integer) to anon, authenticated;

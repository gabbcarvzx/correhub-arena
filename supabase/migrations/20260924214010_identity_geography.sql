create table public.cities (
  id uuid primary key default extensions.gen_random_uuid(),
  name text not null,
  country_code text not null,
  state_code text not null,
  slug text not null,
  timezone text not null,
  is_active boolean not null default false,
  created_at timestamptz not null default pg_catalog.now(),
  updated_at timestamptz not null default pg_catalog.now(),
  constraint cities_name_check check (
    name = pg_catalog.btrim(name) and pg_catalog.char_length(name) between 2 and 100
  ),
  constraint cities_country_code_check check (country_code ~ '^[A-Z]{2}$'),
  constraint cities_state_code_check check (state_code ~ '^[A-Z]{2}$'),
  constraint cities_slug_check check (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  constraint cities_timezone_check check (
    timezone = pg_catalog.btrim(timezone)
    and pg_catalog.char_length(timezone) > 0
    and private.assert_valid_timezone(timezone)
  ),
  constraint cities_country_state_slug_key unique (country_code, state_code, slug)
);

create table public.app_settings (
  id uuid primary key,
  launch_city_id uuid not null references public.cities(id) on delete restrict,
  created_at timestamptz not null default pg_catalog.now(),
  updated_at timestamptz not null default pg_catalog.now(),
  constraint app_settings_singleton_check check (
    id = '10000000-0000-4000-8000-000000000002'::uuid
  )
);

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique,
  full_name text,
  avatar_url text,
  bio text,
  city_id uuid references public.cities(id) on delete restrict,
  running_level text,
  preferred_distance text,
  pace_seconds_per_km integer,
  is_private boolean not null default false,
  onboarding_completed boolean not null default false,
  created_at timestamptz not null default pg_catalog.now(),
  updated_at timestamptz not null default pg_catalog.now(),
  constraint profiles_username_check check (
    username is null or username ~ '^[a-z0-9_]{3,30}$'
  ),
  constraint profiles_full_name_check check (
    full_name is null or (
      full_name = pg_catalog.btrim(full_name)
      and pg_catalog.char_length(full_name) between 2 and 80
    )
  ),
  constraint profiles_avatar_url_check check (
    avatar_url is null or (
      avatar_url = pg_catalog.btrim(avatar_url)
      and pg_catalog.char_length(avatar_url) between 1 and 2048
    )
  ),
  constraint profiles_bio_check check (
    bio is null or (
      bio = pg_catalog.btrim(bio)
      and pg_catalog.char_length(bio) between 1 and 300
    )
  ),
  constraint profiles_running_level_check check (
    running_level is null or running_level in ('beginner', 'intermediate', 'advanced')
  ),
  constraint profiles_preferred_distance_check check (
    preferred_distance is null or preferred_distance in (
      'up_to_5k', '5k_to_10k', '10k_to_21k', 'over_21k', 'flexible'
    )
  ),
  constraint profiles_pace_check check (
    pace_seconds_per_km is null or pace_seconds_per_km between 120 and 1800
  ),
  constraint profiles_onboarding_check check (
    not onboarding_completed or (
      username is not null
      and full_name is not null
      and city_id is not null
      and running_level is not null
      and preferred_distance is not null
    )
  )
);

create index profiles_city_id_idx on public.profiles(city_id);
create index profiles_username_present_idx on public.profiles(username) where username is not null;

create table private.account_controls (
  user_id uuid primary key references auth.users(id) on delete cascade,
  status text not null default 'active',
  reason text,
  status_changed_at timestamptz not null default pg_catalog.now(),
  created_at timestamptz not null default pg_catalog.now(),
  updated_at timestamptz not null default pg_catalog.now(),
  constraint account_controls_status_check check (status in ('active', 'suspended', 'deleted')),
  constraint account_controls_reason_check check (
    reason is null or (
      reason = pg_catalog.btrim(reason)
      and pg_catalog.char_length(reason) between 1 and 1000
    )
  )
);

create table private.platform_roles (
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null,
  granted_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default pg_catalog.now(),
  primary key (user_id, role),
  constraint platform_roles_role_check check (role in ('platform_admin', 'moderator'))
);

create table private.reserved_usernames (
  username text primary key,
  created_at timestamptz not null default pg_catalog.now(),
  constraint reserved_usernames_username_check check (username ~ '^[a-z0-9_]{3,30}$')
);

insert into private.reserved_usernames (username)
values
  ('admin'), ('administrator'), ('correhub'), ('login'), ('signup'),
  ('register'), ('api'), ('settings'), ('support'), ('help'), ('auth'),
  ('account'), ('onboarding'), ('groups'), ('runs'), ('people'),
  ('notifications'), ('privacy'), ('terms')
on conflict (username) do nothing;

create or replace function private.enforce_profile_username()
returns trigger
language plpgsql
volatile
security definer
set search_path = ''
as $$
begin
  if new.username is not null and exists (
    select 1
    from private.reserved_usernames r
    where r.username = new.username
  ) then
    raise exception using
      errcode = '23514',
      message = 'username is reserved';
  end if;

  return new;
end;
$$;

create or replace function private.assert_active_city_reference()
returns trigger
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  must_validate boolean;
begin
  if tg_table_schema = 'public' and tg_table_name = 'profiles' then
    must_validate := new.onboarding_completed and (
      tg_op = 'INSERT'
      or not coalesce(old.onboarding_completed, false)
      or new.city_id is distinct from old.city_id
    );
  else
    must_validate := tg_op = 'INSERT' or new.city_id is distinct from old.city_id;
  end if;

  if must_validate and not exists (
    select 1
    from public.cities c
    where c.id = new.city_id and c.is_active
  ) then
    raise exception using
      errcode = '23514',
      message = 'city must be active';
  end if;

  return new;
end;
$$;

revoke all on function private.enforce_profile_username() from public, anon, authenticated;
revoke all on function private.assert_active_city_reference() from public, anon, authenticated;

create trigger profiles_enforce_username
before insert or update of username on public.profiles
for each row execute function private.enforce_profile_username();

create trigger profiles_assert_active_city
before insert or update of city_id, onboarding_completed on public.profiles
for each row execute function private.assert_active_city_reference();

create trigger cities_set_updated_at
before update on public.cities
for each row execute function private.set_updated_at();

create trigger app_settings_set_updated_at
before update on public.app_settings
for each row execute function private.set_updated_at();

create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function private.set_updated_at();

create trigger account_controls_set_updated_at
before update on private.account_controls
for each row execute function private.set_updated_at();

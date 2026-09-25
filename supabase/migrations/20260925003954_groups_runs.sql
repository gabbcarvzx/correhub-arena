create table public.groups (
  id uuid primary key default extensions.gen_random_uuid(),
  slug text not null unique,
  name text not null,
  description text not null,
  city_id uuid not null references public.cities(id) on delete restrict,
  type text not null,
  join_policy text not null,
  status text not null default 'pending',
  created_by uuid references auth.users(id) on delete set null,
  owner_user_id uuid not null references auth.users(id) on delete restrict,
  avatar_url text,
  cover_url text,
  approved_by uuid references auth.users(id) on delete set null,
  approved_at timestamptz,
  rejection_reason text,
  suspended_at timestamptz,
  created_at timestamptz not null default pg_catalog.now(),
  updated_at timestamptz not null default pg_catalog.now(),
  constraint groups_slug_check check (
    pg_catalog.char_length(slug) between 3 and 100
    and slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'
  ),
  constraint groups_name_check check (
    name = pg_catalog.btrim(name) and pg_catalog.char_length(name) between 3 and 100
  ),
  constraint groups_description_check check (
    description = pg_catalog.btrim(description) and pg_catalog.char_length(description) between 1 and 2000
  ),
  constraint groups_type_check check (type in ('community', 'professional')),
  constraint groups_join_policy_check check (join_policy in ('open', 'approval_required')),
  constraint groups_status_check check (status in ('pending', 'approved', 'rejected', 'suspended')),
  constraint groups_avatar_url_check check (
    avatar_url is null or (
      avatar_url = pg_catalog.btrim(avatar_url) and pg_catalog.char_length(avatar_url) between 1 and 2048
    )
  ),
  constraint groups_cover_url_check check (
    cover_url is null or (
      cover_url = pg_catalog.btrim(cover_url) and pg_catalog.char_length(cover_url) between 1 and 2048
    )
  ),
  constraint groups_rejection_reason_check check (
    rejection_reason is null or (
      rejection_reason = pg_catalog.btrim(rejection_reason)
      and pg_catalog.char_length(rejection_reason) between 1 and 1000
    )
  ),
  constraint groups_decision_state_check check (
    (status = 'pending' and approved_by is null and approved_at is null and rejection_reason is null and suspended_at is null)
    or (status = 'approved' and approved_by is not null and approved_at is not null and rejection_reason is null and suspended_at is null)
    or (status = 'rejected' and approved_by is null and approved_at is null and rejection_reason is not null and suspended_at is null)
    or (status = 'suspended' and approved_by is not null and approved_at is not null and rejection_reason is null and suspended_at is not null)
  )
);

create table public.group_members (
  group_id uuid not null references public.groups(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null,
  status text not null,
  joined_at timestamptz,
  updated_at timestamptz not null default pg_catalog.now(),
  primary key (group_id, user_id),
  constraint group_members_role_check check (role in ('member', 'admin', 'owner')),
  constraint group_members_status_check check (status in ('active', 'pending', 'blocked')),
  constraint group_members_joined_at_check check (status <> 'active' or joined_at is not null)
);

create unique index group_members_one_active_owner_idx
on public.group_members(group_id)
where role = 'owner' and status = 'active';

create table public.group_follows (
  user_id uuid not null references auth.users(id) on delete cascade,
  group_id uuid not null references public.groups(id) on delete cascade,
  created_at timestamptz not null default pg_catalog.now(),
  primary key (user_id, group_id)
);

create table public.run_series (
  id uuid primary key default extensions.gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete restrict,
  city_id uuid not null references public.cities(id) on delete restrict,
  title text not null,
  description text not null,
  weekday smallint not null,
  local_start_time time not null,
  meeting_offset_minutes smallint not null default 0,
  timezone text not null,
  starts_on date not null,
  ends_on date,
  location_text text not null,
  distance_meters integer not null,
  level text not null,
  visibility text not null,
  max_participants integer,
  status text not null default 'active',
  created_by uuid references auth.users(id) on delete set null,
  generated_through date,
  created_at timestamptz not null default pg_catalog.now(),
  updated_at timestamptz not null default pg_catalog.now(),
  constraint run_series_id_group_id_city_id_key unique (id, group_id, city_id),
  constraint run_series_title_check check (
    title = pg_catalog.btrim(title) and pg_catalog.char_length(title) between 3 and 120
  ),
  constraint run_series_description_check check (
    description = pg_catalog.btrim(description) and pg_catalog.char_length(description) between 1 and 5000
  ),
  constraint run_series_weekday_check check (weekday between 1 and 7),
  constraint run_series_meeting_offset_check check (meeting_offset_minutes between 0 and 120),
  constraint run_series_timezone_check check (
    timezone = pg_catalog.btrim(timezone)
    and pg_catalog.char_length(timezone) > 0
    and private.assert_valid_timezone(timezone)
  ),
  constraint run_series_dates_check check (ends_on is null or ends_on >= starts_on),
  constraint run_series_generated_through_check check (generated_through is null or generated_through >= starts_on),
  constraint run_series_location_check check (
    location_text = pg_catalog.btrim(location_text) and pg_catalog.char_length(location_text) between 3 and 300
  ),
  constraint run_series_distance_check check (distance_meters between 100 and 100000),
  constraint run_series_level_check check (level in ('beginner', 'intermediate', 'advanced', 'all_levels')),
  constraint run_series_visibility_check check (visibility in ('public', 'members_only')),
  constraint run_series_capacity_check check (max_participants is null or max_participants between 1 and 10000),
  constraint run_series_status_check check (status in ('active', 'paused', 'ended'))
);

create table public.runs (
  id uuid primary key default extensions.gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete restrict,
  city_id uuid not null references public.cities(id) on delete restrict,
  series_id uuid,
  occurrence_date date,
  title text not null,
  description text not null,
  starts_at timestamptz not null,
  meeting_time timestamptz,
  location_text text not null,
  distance_meters integer not null,
  level text not null,
  visibility text not null,
  max_participants integer,
  status text not null default 'scheduled',
  created_by uuid references auth.users(id) on delete set null,
  cancelled_at timestamptz,
  cancellation_reason text,
  created_at timestamptz not null default pg_catalog.now(),
  updated_at timestamptz not null default pg_catalog.now(),
  constraint runs_series_group_city_fkey foreign key (series_id, group_id, city_id)
    references public.run_series(id, group_id, city_id) on delete restrict,
  constraint runs_series_occurrence_key unique (series_id, occurrence_date),
  constraint runs_series_pair_check check ((series_id is null) = (occurrence_date is null)),
  constraint runs_title_check check (
    title = pg_catalog.btrim(title) and pg_catalog.char_length(title) between 3 and 120
  ),
  constraint runs_description_check check (
    description = pg_catalog.btrim(description) and pg_catalog.char_length(description) between 1 and 5000
  ),
  constraint runs_meeting_time_check check (
    meeting_time is null or meeting_time between starts_at - interval '2 hours' and starts_at
  ),
  constraint runs_location_check check (
    location_text = pg_catalog.btrim(location_text) and pg_catalog.char_length(location_text) between 3 and 300
  ),
  constraint runs_distance_check check (distance_meters between 100 and 100000),
  constraint runs_level_check check (level in ('beginner', 'intermediate', 'advanced', 'all_levels')),
  constraint runs_visibility_check check (visibility in ('public', 'members_only')),
  constraint runs_capacity_check check (max_participants is null or max_participants between 1 and 10000),
  constraint runs_status_check check (status in ('scheduled', 'cancelled', 'completed')),
  constraint runs_cancellation_check check (
    (status = 'cancelled' and cancelled_at is not null and cancellation_reason is not null
      and cancellation_reason = pg_catalog.btrim(cancellation_reason)
      and pg_catalog.char_length(cancellation_reason) between 1 and 1000)
    or (status <> 'cancelled' and cancelled_at is null and cancellation_reason is null)
  )
);

create table public.run_participations (
  id uuid primary key default extensions.gen_random_uuid(),
  run_id uuid not null references public.runs(id) on delete restrict,
  user_id uuid references auth.users(id) on delete set null,
  status text not null default 'going',
  joined_at timestamptz not null default pg_catalog.now(),
  updated_at timestamptz not null default pg_catalog.now(),
  constraint run_participations_run_id_user_id_key unique (run_id, user_id),
  constraint run_participations_status_check check (status in ('going', 'attended', 'no_show', 'cancelled'))
);

create index groups_city_status_idx on public.groups(city_id, status);
create index group_members_user_status_idx on public.group_members(user_id, status);
create index group_members_group_role_status_idx on public.group_members(group_id, role, status);
create index group_follows_group_id_idx on public.group_follows(group_id);
create index run_series_status_generated_idx on public.run_series(status, generated_through);
create index run_series_city_status_idx on public.run_series(city_id, status);
create index runs_city_visibility_status_starts_idx on public.runs(city_id, visibility, status, starts_at);
create index runs_group_starts_idx on public.runs(group_id, starts_at);
create index run_participations_user_status_idx on public.run_participations(user_id, status);
create index run_participations_run_status_idx on public.run_participations(run_id, status);

create or replace function private.assert_group_owner_consistency()
returns trigger
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  target_group_id uuid;
  group_status text;
  designated_owner uuid;
  matching_owner_count integer;
  total_owner_count integer;
  required_member_status text;
begin
  if tg_table_name = 'groups' then
    target_group_id := coalesce(new.id, old.id);
  else
    target_group_id := coalesce(new.group_id, old.group_id);
  end if;

  select g.status, g.owner_user_id
  into group_status, designated_owner
  from public.groups g
  where g.id = target_group_id;

  if not found then
    return null;
  end if;

  required_member_status := case
    when group_status in ('approved', 'suspended') then 'active'
    else 'pending'
  end;

  select
    count(*) filter (where gm.role = 'owner' and gm.status = required_member_status),
    count(*) filter (
      where gm.role = 'owner'
        and gm.status = required_member_status
        and gm.user_id = designated_owner
    )
  into total_owner_count, matching_owner_count
  from public.group_members gm
  where gm.group_id = target_group_id;

  if total_owner_count <> 1 or matching_owner_count <> 1 then
    raise exception using
      errcode = '23514',
      message = 'group owner membership is inconsistent';
  end if;

  return null;
end;
$$;

revoke all on function private.assert_group_owner_consistency() from public, anon, authenticated;

create constraint trigger groups_owner_consistency
after insert or update of status, owner_user_id on public.groups
deferrable initially deferred
for each row execute function private.assert_group_owner_consistency();

create constraint trigger group_members_owner_consistency
after insert or update or delete on public.group_members
deferrable initially deferred
for each row execute function private.assert_group_owner_consistency();

create trigger groups_assert_active_city
before insert or update of city_id on public.groups
for each row execute function private.assert_active_city_reference();
create trigger run_series_assert_active_city
before insert or update of city_id on public.run_series
for each row execute function private.assert_active_city_reference();
create trigger runs_assert_active_city
before insert or update of city_id on public.runs
for each row execute function private.assert_active_city_reference();

create trigger groups_set_updated_at before update on public.groups
for each row execute function private.set_updated_at();
create trigger group_members_set_updated_at before update on public.group_members
for each row execute function private.set_updated_at();
create trigger run_series_set_updated_at before update on public.run_series
for each row execute function private.set_updated_at();
create trigger runs_set_updated_at before update on public.runs
for each row execute function private.set_updated_at();
create trigger run_participations_set_updated_at before update on public.run_participations
for each row execute function private.set_updated_at();

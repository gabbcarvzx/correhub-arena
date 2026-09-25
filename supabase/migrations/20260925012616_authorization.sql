alter table public.cities enable row level security;
alter table public.app_settings enable row level security;
alter table public.profiles enable row level security;
alter table public.groups enable row level security;
alter table public.group_members enable row level security;
alter table public.group_follows enable row level security;
alter table public.run_series enable row level security;
alter table public.runs enable row level security;
alter table public.run_participations enable row level security;
alter table public.user_follows enable row level security;
alter table public.posts enable row level security;
alter table public.post_likes enable row level security;
alter table public.comments enable row level security;
alter table public.activity_events enable row level security;
alter table public.notifications enable row level security;

alter table private.account_controls enable row level security;
alter table private.platform_roles enable row level security;
alter table private.reserved_usernames enable row level security;
alter table private.reports enable row level security;
alter table private.admin_audit_logs enable row level security;
alter table private.analytics_events enable row level security;
alter table private.notification_jobs enable row level security;
alter table private.media_uploads enable row level security;
alter table private.rate_limit_buckets enable row level security;
alter table private.group_owner_transfers enable row level security;
alter table private.domain_event_receipts enable row level security;

revoke all privileges on all tables in schema public from anon, authenticated;
revoke all privileges on all sequences in schema public from anon, authenticated;
revoke all privileges on schema private from public, anon, authenticated;
revoke all privileges on all tables in schema private from public, anon, authenticated;
revoke all privileges on all sequences in schema private from public, anon, authenticated;
revoke execute on all functions in schema private from public, anon, authenticated;

create or replace function private.current_account_is_active()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from private.account_controls ac
    where ac.user_id = (select auth.uid())
      and ac.status = 'active'
  );
$$;

create or replace function private.account_is_active_for_visibility(target_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from private.account_controls ac
    where ac.user_id = target_user_id
      and ac.status = 'active'
  );
$$;

create or replace function private.current_user_has_platform_role(requested_role text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select requested_role in ('platform_admin', 'moderator')
    and exists (
      select 1
      from private.platform_roles pr
      where pr.user_id = (select auth.uid())
        and pr.role = requested_role
    );
$$;

alter function private.current_account_is_active() owner to postgres;
alter function private.account_is_active_for_visibility(uuid) owner to postgres;
alter function private.current_user_has_platform_role(text) owner to postgres;

revoke all on function private.current_account_is_active() from public, anon, authenticated;
revoke all on function private.account_is_active_for_visibility(uuid) from public, anon, authenticated;
revoke all on function private.current_user_has_platform_role(text) from public, anon, authenticated;

grant usage on schema private to anon, authenticated;
grant execute on function private.account_is_active_for_visibility(uuid) to anon, authenticated;
grant execute on function private.current_account_is_active() to authenticated;
grant execute on function private.current_user_has_platform_role(text) to authenticated;

grant select on public.cities to anon, authenticated;
grant select on public.app_settings to anon, authenticated;

grant select (
  id, username, full_name, avatar_url, bio, city_id, running_level,
  preferred_distance, pace_seconds_per_km, created_at
) on public.profiles to anon;

grant select on public.profiles to authenticated;
grant update (
  username, full_name, avatar_url, bio, city_id, running_level,
  preferred_distance, pace_seconds_per_km, is_private, onboarding_completed
) on public.profiles to authenticated;

create policy cities_read_public
on public.cities for select
to anon, authenticated
using (true);

create policy app_settings_read
on public.app_settings for select
to anon, authenticated
using (id = '10000000-0000-4000-8000-000000000002'::uuid);

create policy profiles_read_public_anon
on public.profiles for select
to anon
using (
  onboarding_completed
  and not is_private
  and private.account_is_active_for_visibility(id)
);

create policy profiles_read_authenticated
on public.profiles for select
to authenticated
using (
  id = (select auth.uid())
  or (
    onboarding_completed
    and not is_private
    and private.account_is_active_for_visibility(id)
  )
);

create policy profiles_update_own
on public.profiles for update
to authenticated
using (
  id = (select auth.uid())
  and private.current_account_is_active()
)
with check (
  id = (select auth.uid())
  and private.current_account_is_active()
);

create view public.profile_directory
with (security_invoker = true)
as
select
  id,
  username,
  full_name,
  avatar_url,
  bio,
  city_id,
  running_level,
  preferred_distance,
  pace_seconds_per_km,
  created_at
from public.profiles;

revoke all on public.profile_directory from public, anon, authenticated;
grant select on public.profile_directory to anon, authenticated;

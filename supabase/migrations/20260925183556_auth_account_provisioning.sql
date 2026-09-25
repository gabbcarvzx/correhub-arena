create or replace function private.provision_auth_user()
returns trigger
language plpgsql
volatile
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id)
  values (new.id)
  on conflict (id) do nothing;

  insert into private.account_controls (user_id, status)
  values (new.id, 'active')
  on conflict (user_id) do nothing;

  return new;
end;
$$;

alter function private.provision_auth_user() owner to postgres;
revoke all on function private.provision_auth_user() from public, anon, authenticated;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function private.provision_auth_user();

create or replace function public.ensure_current_account_foundation()
returns table (
  account_status text,
  onboarding_completed boolean
)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := (select auth.uid());
begin
  if current_user_id is null or not exists (
    select 1 from auth.users u where u.id = current_user_id
  ) then
    raise insufficient_privilege using message = 'authenticated identity required';
  end if;

  insert into public.profiles (id)
  values (current_user_id)
  on conflict (id) do nothing;

  insert into private.account_controls (user_id, status)
  values (current_user_id, 'active')
  on conflict (user_id) do nothing;

  return query
  select ac.status, p.onboarding_completed
  from private.account_controls ac
  join public.profiles p on p.id = ac.user_id
  where ac.user_id = current_user_id;
end;
$$;

create or replace function public.get_current_account_state()
returns table (
  account_status text,
  onboarding_completed boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  select ac.status, p.onboarding_completed
  from auth.users u
  join private.account_controls ac on ac.user_id = u.id
  join public.profiles p on p.id = u.id
  where u.id = (select auth.uid());
$$;

alter function public.ensure_current_account_foundation() owner to postgres;
alter function public.get_current_account_state() owner to postgres;

revoke all on function public.ensure_current_account_foundation() from public, anon, authenticated;
revoke all on function public.get_current_account_state() from public, anon, authenticated;
grant execute on function public.ensure_current_account_foundation() to authenticated;
grant execute on function public.get_current_account_state() to authenticated;

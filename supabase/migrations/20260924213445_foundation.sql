create schema if not exists private;

revoke all on schema private from public, anon, authenticated;

create extension if not exists pgcrypto with schema extensions;

create or replace function private.set_updated_at()
returns trigger
language plpgsql
volatile
security invoker
set search_path = ''
as $$
begin
  new.updated_at := pg_catalog.now();
  return new;
end;
$$;

create or replace function private.assert_valid_timezone(candidate text)
returns boolean
language sql
stable
security invoker
set search_path = ''
as $$
  select exists (
    select 1
    from pg_catalog.pg_timezone_names
    where name = candidate
  );
$$;

revoke all on function private.set_updated_at() from public, anon, authenticated;
revoke all on function private.assert_valid_timezone(text) from public, anon, authenticated;

alter default privileges for role postgres in schema public
  revoke all privileges on tables from anon, authenticated;
alter default privileges for role postgres in schema public
  revoke all privileges on sequences from anon, authenticated;
alter default privileges for role postgres in schema public
  revoke execute on functions from public, anon, authenticated;
alter default privileges for role postgres in schema private
  revoke all on tables from public, anon, authenticated;
alter default privileges for role postgres in schema private
  revoke execute on functions from public, anon, authenticated;

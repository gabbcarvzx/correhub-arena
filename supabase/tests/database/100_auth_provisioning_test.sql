begin;

create extension if not exists pgtap with schema extensions;

select plan(51);

select has_function('private', 'provision_auth_user', array[]::text[], 'Auth provisioning trigger function exists');
select has_function('public', 'ensure_current_account_foundation', array[]::text[], 'account recovery RPC exists');
select has_function('public', 'get_current_account_state', array[]::text[], 'account state RPC exists');

select is(
  (
    select count(*)
    from pg_catalog.pg_trigger t
    join pg_catalog.pg_class c on c.oid = t.tgrelid
    join pg_catalog.pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'auth'
      and c.relname = 'users'
      and t.tgname = 'on_auth_user_created'
      and not t.tgisinternal
  ),
  1::bigint,
  'auth.users has exactly one provisioning trigger'
);

select is(
  (select pg_catalog.pg_get_userbyid(p.proowner) from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid = p.pronamespace where n.nspname = 'private' and p.proname = 'provision_auth_user'),
  'postgres',
  'provisioning trigger function is owned by postgres'
);
select is(
  (select pg_catalog.pg_get_userbyid(p.proowner) from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'ensure_current_account_foundation'),
  'postgres',
  'recovery RPC is owned by postgres'
);
select is(
  (select pg_catalog.pg_get_userbyid(p.proowner) from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'get_current_account_state'),
  'postgres',
  'account state RPC is owned by postgres'
);

select ok((select p.proconfig @> array['search_path=""'] from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid = p.pronamespace where n.nspname = 'private' and p.proname = 'provision_auth_user'), 'provisioning function fixes an empty search_path');
select ok((select p.proconfig @> array['search_path=""'] from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'ensure_current_account_foundation'), 'recovery RPC fixes an empty search_path');
select ok((select p.proconfig @> array['search_path=""'] from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'get_current_account_state'), 'account state RPC fixes an empty search_path');

select ok((select p.prosecdef from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid = p.pronamespace where n.nspname = 'private' and p.proname = 'provision_auth_user'), 'provisioning function is security definer');
select ok((select p.prosecdef from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'ensure_current_account_foundation'), 'recovery RPC is security definer');
select ok((select p.prosecdef from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'get_current_account_state'), 'account state RPC is security definer');

select is(
  (select count(*) from pg_catalog.aclexplode(p.proacl) a where a.grantee = 0 and a.privilege_type = 'EXECUTE')::bigint,
  0::bigint,
  'PUBLIC cannot execute the trigger helper'
) from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid = p.pronamespace where n.nspname = 'private' and p.proname = 'provision_auth_user';
select isnt(has_function_privilege('anon', 'private.provision_auth_user()', 'EXECUTE'), true, 'anon cannot execute the trigger helper');
select isnt(has_function_privilege('authenticated', 'private.provision_auth_user()', 'EXECUTE'), true, 'authenticated cannot execute the trigger helper');
select is(
  (select count(*) from pg_catalog.aclexplode(p.proacl) a where a.grantee = 0 and a.privilege_type = 'EXECUTE')::bigint,
  0::bigint,
  'PUBLIC cannot execute recovery'
) from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'ensure_current_account_foundation';
select isnt(has_function_privilege('anon', 'public.ensure_current_account_foundation()', 'EXECUTE'), true, 'anon cannot execute recovery');
select ok(has_function_privilege('authenticated', 'public.ensure_current_account_foundation()', 'EXECUTE'), 'authenticated can execute recovery');
select is(
  (select count(*) from pg_catalog.aclexplode(p.proacl) a where a.grantee = 0 and a.privilege_type = 'EXECUTE')::bigint,
  0::bigint,
  'PUBLIC cannot read account state'
) from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'get_current_account_state';
select isnt(has_function_privilege('anon', 'public.get_current_account_state()', 'EXECUTE'), true, 'anon cannot read account state');
select ok(has_function_privilege('authenticated', 'public.get_current_account_state()', 'EXECUTE'), 'authenticated can read account state');
select is((select count(*) from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'ensure_current_account_foundation' and p.pronargs > 0), 0::bigint, 'recovery accepts no impersonation argument');

insert into auth.users (id, email, raw_user_meta_data)
values (
  '21000000-0000-4000-8000-000000000001',
  'provisioned@example.test',
  '{"username":"admin","full_name":"Metadata Admin","avatar_url":"https://evil.example/avatar.png","role":"platform_admin","onboarding_completed":true}'::jsonb
);

select is((select count(*) from public.profiles where id = '21000000-0000-4000-8000-000000000001'), 1::bigint, 'new Auth user gets exactly one profile');
select is((select count(*) from private.account_controls where user_id = '21000000-0000-4000-8000-000000000001'), 1::bigint, 'new Auth user gets exactly one account control');
select is((select count(*) from private.platform_roles where user_id = '21000000-0000-4000-8000-000000000001'), 0::bigint, 'new Auth user gets no platform role');
select is((select username from public.profiles where id = '21000000-0000-4000-8000-000000000001'), null::text, 'metadata does not set username');
select is((select full_name from public.profiles where id = '21000000-0000-4000-8000-000000000001'), null::text, 'metadata does not set full name');
select is((select avatar_url from public.profiles where id = '21000000-0000-4000-8000-000000000001'), null::text, 'metadata does not persist provider avatar');
select isnt((select onboarding_completed from public.profiles where id = '21000000-0000-4000-8000-000000000001'), true, 'metadata cannot complete onboarding');
select is((select status from private.account_controls where user_id = '21000000-0000-4000-8000-000000000001'), 'active', 'new account control is active');

set local role authenticated;
set local request.jwt.claims = '{"sub":"21000000-0000-4000-8000-000000000001","role":"authenticated"}';
select lives_ok('select * from public.ensure_current_account_foundation()', 'recovery is safe for an already provisioned account');
reset role;
select is((select count(*) from public.profiles where id = '21000000-0000-4000-8000-000000000001'), 1::bigint, 'recovery does not duplicate profile');
select is((select count(*) from private.account_controls where user_id = '21000000-0000-4000-8000-000000000001'), 1::bigint, 'recovery does not duplicate account control');

delete from public.profiles where id = '21000000-0000-4000-8000-000000000001';
set local role authenticated;
select lives_ok('select * from public.ensure_current_account_foundation()', 'recovery repairs a missing profile');
reset role;
select is((select count(*) from public.profiles where id = '21000000-0000-4000-8000-000000000001'), 1::bigint, 'missing profile is restored');

delete from private.account_controls where user_id = '21000000-0000-4000-8000-000000000001';
set local role authenticated;
select lives_ok('select * from public.ensure_current_account_foundation()', 'recovery repairs a missing account control');
reset role;
select is((select count(*) from private.account_controls where user_id = '21000000-0000-4000-8000-000000000001'), 1::bigint, 'missing account control is restored');

update private.account_controls set status = 'suspended' where user_id = '21000000-0000-4000-8000-000000000001';
insert into private.platform_roles (user_id, role) values ('21000000-0000-4000-8000-000000000001', 'moderator');
delete from public.profiles where id = '21000000-0000-4000-8000-000000000001';
set local role authenticated;
select lives_ok('select * from public.ensure_current_account_foundation()', 'recovery runs for a suspended account without changing control state');
reset role;
select is((select status from private.account_controls where user_id = '21000000-0000-4000-8000-000000000001'), 'suspended', 'recovery does not reactivate a suspended account');
select is((select count(*) from private.platform_roles where user_id = '21000000-0000-4000-8000-000000000001' and role = 'moderator'), 1::bigint, 'recovery preserves an existing platform role');

insert into auth.users (id, email) values ('21000000-0000-4000-8000-000000000002', 'both-missing@example.test');
delete from public.profiles where id = '21000000-0000-4000-8000-000000000002';
delete from private.account_controls where user_id = '21000000-0000-4000-8000-000000000002';
set local role authenticated;
set local request.jwt.claims = '{"sub":"21000000-0000-4000-8000-000000000002","role":"authenticated"}';
select lives_ok('select * from public.ensure_current_account_foundation()', 'recovery repairs both missing rows');
reset role;
select is(
  (select count(*) from public.profiles where id = '21000000-0000-4000-8000-000000000002')
  + (select count(*) from private.account_controls where user_id = '21000000-0000-4000-8000-000000000002'),
  2::bigint,
  'both account foundation rows are restored exactly once'
);

update private.account_controls set status = 'deleted' where user_id = '21000000-0000-4000-8000-000000000002';
delete from public.profiles where id = '21000000-0000-4000-8000-000000000002';
set local role authenticated;
select lives_ok('select * from public.ensure_current_account_foundation()', 'recovery can restore a profile without changing deleted status');
reset role;
select is((select status from private.account_controls where user_id = '21000000-0000-4000-8000-000000000002'), 'deleted', 'recovery does not reactivate a deleted account');

delete from public.profiles where id = '21000000-0000-4000-8000-000000000002';
set local role authenticated;
set local request.jwt.claims = '{"sub":"21000000-0000-4000-8000-000000000001","role":"authenticated"}';
select lives_ok('select * from public.ensure_current_account_foundation()', 'user A can only repair the identity in its claims');
reset role;
select is((select count(*) from public.profiles where id = '21000000-0000-4000-8000-000000000002'), 0::bigint, 'user A cannot repair user B');

set local role anon;
set local request.jwt.claims = '{}';
select throws_ok('select * from public.ensure_current_account_foundation()', '42501', null, 'anon cannot invoke recovery');
reset role;

set local role authenticated;
set local request.jwt.claims = '{"sub":"21000000-0000-4000-8000-000000000001","role":"authenticated"}';
select results_eq(
  'select account_status, onboarding_completed from public.get_current_account_state()',
  $$values ('suspended'::text, false)$$,
  'account state returns current status and onboarding state'
);
reset role;

create function private.test_reject_profile_insert()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception using errcode = '23514', message = 'controlled profile failure';
end;
$$;
create trigger aaa_test_reject_profile_insert
before insert on public.profiles
for each row execute function private.test_reject_profile_insert();

select throws_ok(
  $$insert into auth.users (id, email) values ('21000000-0000-4000-8000-000000000099', 'rollback@example.test')$$,
  '23514',
  'controlled profile failure',
  'provisioning failure aborts Auth user creation transactionally'
);
select is((select count(*) from auth.users where id = '21000000-0000-4000-8000-000000000099'), 0::bigint, 'failed provisioning leaves no orphan Auth user');

drop trigger aaa_test_reject_profile_insert on public.profiles;
drop function private.test_reject_profile_insert();

select * from finish();
rollback;

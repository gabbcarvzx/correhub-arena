begin;
create extension if not exists pgtap with schema extensions;
select plan(49);

insert into auth.users (id, email) values
  ('31000000-0000-4000-8000-000000000001', 'gate3-a@example.test'),
  ('31000000-0000-4000-8000-000000000002', 'gate3-b@example.test'),
  ('31000000-0000-4000-8000-000000000003', 'gate3-c@example.test'),
  ('31000000-0000-4000-8000-000000000004', 'gate3-d@example.test'),
  ('31000000-0000-4000-8000-000000000005', 'gate3-e@example.test'),
  ('31000000-0000-4000-8000-000000000006', 'gate3-f@example.test'),
  ('31000000-0000-4000-8000-000000000007', 'gate3-g@example.test');

update private.account_controls
set status = 'suspended'
where user_id = '31000000-0000-4000-8000-000000000004';

update public.profiles set
  username = 'gate3_a', full_name = 'Gate Three A',
  avatar_url = 'https://images.example/a.png', bio = 'Private bio A',
  city_id = '10000000-0000-4000-8000-000000000001',
  running_level = 'beginner', preferred_distance = 'up_to_5k',
  pace_seconds_per_km = 420, is_private = true, onboarding_completed = true
where id = '31000000-0000-4000-8000-000000000001';

update public.profiles set
  username = 'gate3_b', full_name = 'Gate Three B',
  avatar_url = 'https://images.example/b.png', bio = 'Public bio B',
  city_id = '10000000-0000-4000-8000-000000000001',
  running_level = 'intermediate', preferred_distance = '5k_to_10k',
  pace_seconds_per_km = 360, is_private = false, onboarding_completed = true
where id = '31000000-0000-4000-8000-000000000002';

update public.profiles set
  username = 'gate3_c', full_name = 'Gate Three C',
  avatar_url = 'https://images.example/private-c.png', bio = 'Private bio C',
  city_id = '10000000-0000-4000-8000-000000000001',
  running_level = 'advanced', preferred_distance = '10k_to_21k',
  pace_seconds_per_km = 330, is_private = true, onboarding_completed = true
where id = '31000000-0000-4000-8000-000000000003';

update public.profiles set
  username = 'gate3_d', full_name = 'Gate Three D',
  city_id = '10000000-0000-4000-8000-000000000001',
  running_level = 'beginner', preferred_distance = 'flexible',
  is_private = false, onboarding_completed = true
where id = '31000000-0000-4000-8000-000000000004';

update public.profiles set
  username = 'gate3_e', full_name = 'Gate Three E'
where id = '31000000-0000-4000-8000-000000000005';

update public.profiles set
  username = 'gate3_f', full_name = 'Gate Three F',
  city_id = '10000000-0000-4000-8000-000000000001',
  running_level = 'intermediate', preferred_distance = 'flexible',
  is_private = false, onboarding_completed = true
where id = '31000000-0000-4000-8000-000000000006';

update public.profiles set
  username = 'gate3_g', full_name = 'Gate Three G',
  city_id = '10000000-0000-4000-8000-000000000001',
  running_level = 'intermediate', preferred_distance = 'flexible',
  is_private = false, onboarding_completed = true
where id = '31000000-0000-4000-8000-000000000007';

select has_function('public', 'get_profile_by_username', array['text'], 'profile read RPC exists');
select has_function('public', 'discover_profiles', array['text','uuid','text','uuid','integer'], 'discovery RPC exists');
select has_function('private', 'profile_is_publicly_visible', array['uuid'], 'public visibility helper exists');
select has_function('private', 'prevent_profile_onboarding_regression', array[]::text[], 'onboarding regression trigger helper exists');
select has_function('private', 'protect_profile_personal_posts', array[]::text[], 'privacy transition trigger helper exists');
select has_view('public', 'profile_directory', 'profile directory view exists');
select ok(
  coalesce((select 'security_invoker=true' = any(c.reloptions) from pg_catalog.pg_class c join pg_catalog.pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname='profile_directory'), false),
  'profile directory remains security invoker'
);
select isnt(has_column_privilege('authenticated', 'public.profiles', 'avatar_url', 'UPDATE'), true, 'authenticated cannot update avatar_url');
select is(
  (select array_agg(column_name::text order by ordinal_position) from information_schema.columns where table_schema='public' and table_name='profile_directory'),
  array['id','username','full_name','avatar_url','bio','city_id','running_level','preferred_distance','pace_seconds_per_km','created_at','city_name','city_slug','country_code','state_code']::text[],
  'directory contains only approved public profile and city columns'
);
select is(
  (select count(*) from information_schema.columns where table_schema='public' and table_name='profile_directory' and column_name in ('email','is_private','onboarding_completed','status','role')),
  0::bigint,
  'directory exposes no auth, privacy, control or role columns'
);
select ok(has_function_privilege('anon', 'public.get_profile_by_username(text)', 'EXECUTE'), 'anon can execute narrow profile read');
select ok(has_function_privilege('authenticated', 'public.get_profile_by_username(text)', 'EXECUTE'), 'authenticated can execute narrow profile read');
select is(
  (select count(*) from pg_catalog.aclexplode(p.proacl) a where a.grantee=0 and a.privilege_type='EXECUTE')::bigint,
  0::bigint,
  'PUBLIC cannot execute profile read'
) from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='get_profile_by_username';
select ok((select p.prosecdef and p.proconfig @> array['search_path=""'] from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='get_profile_by_username'), 'profile RPC is definer with empty search_path');
select is(
  (select count(*) from pg_catalog.pg_trigger t join pg_catalog.pg_class c on c.oid=t.tgrelid join pg_catalog.pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname='profiles' and t.tgname in ('profiles_prevent_onboarding_regression','profiles_protect_personal_posts') and not t.tgisinternal),
  2::bigint,
  'profiles has both Gate 3 protection triggers'
);
select ok((select p.prosecdef and p.proconfig @> array['search_path=""'] from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid=p.pronamespace where n.nspname='private' and p.proname='profile_is_publicly_visible'), 'visibility helper is definer with empty search_path');
select is((select count(*) from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid=p.pronamespace where n.nspname='private' and p.proname in ('prevent_profile_onboarding_regression','protect_profile_personal_posts') and p.prosecdef and p.proconfig @> array['search_path=""']), 2::bigint, 'trigger helpers are definer with empty search_path');
select ok(has_function_privilege('anon', 'private.profile_is_publicly_visible(uuid)', 'EXECUTE'), 'anon can execute only the boolean visibility helper');
select ok(has_function_privilege('authenticated', 'private.profile_is_publicly_visible(uuid)', 'EXECUTE'), 'authenticated can execute the boolean visibility helper');
select is((select count(*) from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid=p.pronamespace where n.nspname='private' and p.proname in ('prevent_profile_onboarding_regression','protect_profile_personal_posts') and has_function_privilege('authenticated', p.oid, 'EXECUTE')), 0::bigint, 'authenticated cannot execute trigger helpers');

set local role anon;
set local request.jwt.claims = '{"role":"anon"}';
select is((select count(*) from public.profile_directory), 3::bigint, 'anon directory contains only active complete public fixtures');
select results_eq(
  $$select username from public.profile_directory order by username$$,
  $$values ('gate3_b'::text), ('gate3_f'::text), ('gate3_g'::text)$$,
  'directory excludes private, suspended and incomplete profiles'
);
select is((select city_name from public.profile_directory where username='gate3_b'), 'São Lourenço da Mata', 'directory resolves city from database');
select is((select count(*) from public.discover_profiles(null, null, null, null, 20)), 3::bigint, 'discovery returns only eligible public profiles');
select is((select visibility from public.get_profile_by_username('gate3_b')), 'public', 'anon reads public profile');
select is((select bio from public.get_profile_by_username('gate3_b')), 'Public bio B', 'anon receives allowed public bio');
select is((select visibility from public.get_profile_by_username('gate3_c')), 'private', 'anon receives private identity projection');
select is((select bio from public.get_profile_by_username('gate3_c')), null::text, 'private projection hides bio');
select is((select city_id from public.get_profile_by_username('gate3_c')), null::uuid, 'private projection hides city');
select is((select avatar_url from public.get_profile_by_username('gate3_c')), null::text, 'private projection hides real avatar');
select is((select count(*) from public.get_profile_by_username('gate3_d')), 0::bigint, 'suspended profile is absent');
select is((select count(*) from public.get_profile_by_username('gate3_e')), 0::bigint, 'incomplete profile is absent');
select is((select count(*) from public.get_profile_by_username('missing_runner')), 0::bigint, 'unknown profile is absent');
reset role;

set local role authenticated;
set local request.jwt.claims = '{"sub":"31000000-0000-4000-8000-000000000001","role":"authenticated"}';
select is((select visibility from public.get_profile_by_username('gate3_a')), 'self', 'owner reads own private profile as self');
select is((select bio from public.get_profile_by_username('gate3_a')), 'Private bio A', 'owner reads own complete bio');
select is((select bio from public.get_profile_by_username('gate3_b')), 'Public bio B', 'authenticated A reads public B');
select is(
  (select jsonb_strip_nulls(to_jsonb(p) - 'created_at') from public.get_profile_by_username('gate3_c') p),
  '{"id":"31000000-0000-4000-8000-000000000003","username":"gate3_c","full_name":"Gate Three C","visibility":"private"}'::jsonb,
  'private C projection is minimal before follow'
);
reset role;

insert into public.user_follows(follower_id, followed_id)
values ('31000000-0000-4000-8000-000000000001','31000000-0000-4000-8000-000000000003');

set local role authenticated;
set local request.jwt.claims = '{"sub":"31000000-0000-4000-8000-000000000001","role":"authenticated"}';
select is(
  (select jsonb_strip_nulls(to_jsonb(p) - 'created_at') from public.get_profile_by_username('gate3_c') p),
  '{"id":"31000000-0000-4000-8000-000000000003","username":"gate3_c","full_name":"Gate Three C","visibility":"private"}'::jsonb,
  'following private C does not change any visible field'
);
select results_eq(
  $$update public.profiles set bio='Cross-user write' where id='31000000-0000-4000-8000-000000000002' returning id$$,
  array[]::uuid[],
  'A cannot update B'
);
select throws_ok(
  $$update public.profiles set onboarding_completed=false where id='31000000-0000-4000-8000-000000000001'$$,
  '23514', 'onboarding completion cannot be reversed',
  'completed onboarding cannot regress'
);
reset role;

update public.profiles
set is_private = false
where id = '31000000-0000-4000-8000-000000000003';

insert into public.groups(id,slug,name,description,city_id,type,join_policy,status,created_by,owner_user_id)
values ('31000000-0000-4000-8000-000000000100','gate3-test-group','Gate Three Group','Group fixture','10000000-0000-4000-8000-000000000001','community','open','pending','31000000-0000-4000-8000-000000000003','31000000-0000-4000-8000-000000000003');
insert into public.group_members(group_id,user_id,role,status)
values ('31000000-0000-4000-8000-000000000100','31000000-0000-4000-8000-000000000003','owner','pending');
insert into public.posts(id,author_user_id,group_id,body,visibility) values
  ('31000000-0000-4000-8000-000000000201','31000000-0000-4000-8000-000000000003',null,'Public personal post','public'),
  ('31000000-0000-4000-8000-000000000202','31000000-0000-4000-8000-000000000003',null,'Private personal post','private'),
  ('31000000-0000-4000-8000-000000000203','31000000-0000-4000-8000-000000000003','31000000-0000-4000-8000-000000000100','Public group post','public');

set local role authenticated;
set local request.jwt.claims = '{"sub":"31000000-0000-4000-8000-000000000003","role":"authenticated"}';
select lives_ok($$update public.profiles set is_private=true where id='31000000-0000-4000-8000-000000000003'$$, 'public to private transition succeeds');
reset role;
select is((select visibility from public.posts where id='31000000-0000-4000-8000-000000000201'), 'private', 'public personal post becomes private');
select is((select visibility from public.posts where id='31000000-0000-4000-8000-000000000202'), 'private', 'existing private personal post remains private');
select is((select visibility from public.posts where id='31000000-0000-4000-8000-000000000203'), 'public', 'group post remains public');

set local role authenticated;
set local request.jwt.claims = '{"sub":"31000000-0000-4000-8000-000000000003","role":"authenticated"}';
select lives_ok($$update public.profiles set is_private=false where id='31000000-0000-4000-8000-000000000003'$$, 'private to public transition succeeds');
reset role;
select is((select visibility from public.posts where id='31000000-0000-4000-8000-000000000201'), 'private', 'private to public does not republish old post');

insert into public.posts(id,author_user_id,body,visibility)
values ('31000000-0000-4000-8000-000000000204','31000000-0000-4000-8000-000000000007','Rollback personal post','public');
create function private.gate3_test_reject_post_privacy_update()
returns trigger language plpgsql set search_path='' as $$
begin
  if old.author_user_id='31000000-0000-4000-8000-000000000007'::uuid and old.visibility='public' and new.visibility='private' then
    raise exception using errcode='23514', message='controlled privacy failure';
  end if;
  return new;
end;
$$;
create trigger gate3_test_reject_post_privacy_update
before update on public.posts for each row execute function private.gate3_test_reject_post_privacy_update();

set local role authenticated;
set local request.jwt.claims = '{"sub":"31000000-0000-4000-8000-000000000007","role":"authenticated"}';
select throws_ok(
  $$update public.profiles set is_private=true where id='31000000-0000-4000-8000-000000000007'$$,
  '23514', 'controlled privacy failure',
  'post privacy failure aborts profile privacy transition'
);
reset role;
select isnt((select is_private from public.profiles where id='31000000-0000-4000-8000-000000000007'), true, 'failed transition rolls profile back');
select is((select visibility from public.posts where id='31000000-0000-4000-8000-000000000204'), 'public', 'failed transition rolls post back');

select * from finish();
rollback;

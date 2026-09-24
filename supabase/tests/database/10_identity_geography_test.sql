begin;

create extension if not exists pgtap with schema extensions;

select plan(66);

select has_table(schema_name, table_name, format('%s.%s exists', schema_name, table_name))
from (values
  ('public', 'cities'),
  ('public', 'app_settings'),
  ('public', 'profiles'),
  ('private', 'account_controls'),
  ('private', 'platform_roles'),
  ('private', 'reserved_usernames')
) as expected(schema_name, table_name);

select has_column(schema_name, table_name, column_name, format('%s.%s.%s exists', schema_name, table_name, column_name))
from (values
  ('public', 'cities', 'timezone'),
  ('public', 'app_settings', 'launch_city_id'),
  ('public', 'profiles', 'username'),
  ('private', 'account_controls', 'status'),
  ('private', 'platform_roles', 'role'),
  ('private', 'reserved_usernames', 'username')
) as expected(schema_name, table_name, column_name);

select fk_ok('public', 'app_settings', 'launch_city_id', 'public', 'cities', 'id', 'launch city references cities');
select fk_ok('public', 'profiles', 'id', 'auth', 'users', 'id', 'profile identity references auth.users');
select fk_ok('public', 'profiles', 'city_id', 'public', 'cities', 'id', 'profile city references cities');
select fk_ok('private', 'account_controls', 'user_id', 'auth', 'users', 'id', 'account control references auth.users');
select fk_ok('private', 'platform_roles', 'user_id', 'auth', 'users', 'id', 'platform role identity references auth.users');
select fk_ok('private', 'platform_roles', 'granted_by', 'auth', 'users', 'id', 'role grantor references auth.users');

select is(
  (select count(*) from public.cities where id = '10000000-0000-4000-8000-000000000001'),
  1::bigint,
  'launch city exists exactly once'
);
select is(
  (select row(name, country_code, state_code, slug, timezone, is_active)::text
   from public.cities where id = '10000000-0000-4000-8000-000000000001'),
  '("São Lourenço da Mata",BR,PE,sao-lourenco-da-mata,America/Recife,t)'::text,
  'launch city has the approved values'
);
select is(
  (select launch_city_id from public.app_settings where id = '10000000-0000-4000-8000-000000000002'),
  '10000000-0000-4000-8000-000000000001'::uuid,
  'application settings point to the launch city'
);

select results_eq(
  'select username from private.reserved_usernames order by username',
  $$values
    ('account'::text), ('admin'), ('administrator'), ('api'), ('auth'),
    ('correhub'), ('groups'), ('help'), ('login'), ('notifications'),
    ('onboarding'), ('people'), ('privacy'), ('register'), ('runs'),
    ('settings'), ('signup'), ('support'), ('terms')$$,
  'reserved username catalog is exact'
);

insert into auth.users (id, email)
select
  format('20000000-0000-4000-8000-%s', lpad(i::text, 12, '0'))::uuid,
  format('gate1-user-%s@example.test', i)
from generate_series(1, 8) as fixture(i);

select is(
  (select count(*) from public.profiles where id::text like '20000000-0000-4000-8000-%'),
  0::bigint,
  'auth.users insert does not provision profiles in Gate 1'
);
select is(
  (select count(*) from private.account_controls where user_id::text like '20000000-0000-4000-8000-%'),
  0::bigint,
  'auth.users insert does not provision account controls in Gate 1'
);

select lives_ok(
  $$insert into public.profiles
    (id, username, full_name, city_id, running_level, preferred_distance, pace_seconds_per_km, onboarding_completed)
    values
    ('20000000-0000-4000-8000-000000000002', 'valid_runner', 'Valid Runner',
     '10000000-0000-4000-8000-000000000001', 'beginner', 'up_to_5k', 360, true)$$,
  'valid_runner is accepted'
);

select throws_ok(
  $$insert into public.profiles (id, username) values ('20000000-0000-4000-8000-000000000006', 'ValidRunner')$$,
  '23514', null, 'uppercase username is rejected'
);
select throws_ok(
  $$insert into public.profiles (id, username) values ('20000000-0000-4000-8000-000000000006', 'ab')$$,
  '23514', null, 'username shorter than three characters is rejected'
);
select throws_ok(
  $$insert into public.profiles (id, username) values ('20000000-0000-4000-8000-000000000006', 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa')$$,
  '23514', null, 'username longer than thirty characters is rejected'
);
select throws_ok(
  $$insert into public.profiles (id, username) values ('20000000-0000-4000-8000-000000000006', 'invalid-runner')$$,
  '23514', null, 'username containing a hyphen is rejected'
);

select throws_ok(
  format(
    'insert into public.profiles (id, username) values (%L::uuid, %L)',
    '20000000-0000-4000-8000-000000000006',
    username
  ),
  '23514',
  null,
  format('reserved username %s is rejected', username)
)
from unnest(array[
  'admin', 'administrator', 'correhub', 'login', 'signup', 'register', 'api',
  'settings', 'support', 'help', 'auth', 'account', 'onboarding', 'groups',
  'runs', 'people', 'notifications', 'privacy', 'terms'
]) as reserved(username);

insert into public.profiles (id, username)
values ('20000000-0000-4000-8000-000000000003', 'unique_runner');
select throws_ok(
  $$insert into public.profiles (id, username) values ('20000000-0000-4000-8000-000000000004', 'unique_runner')$$,
  '23505', null, 'duplicate username is rejected atomically'
);

select throws_ok(
  $$insert into public.profiles (id, full_name) values ('20000000-0000-4000-8000-000000000006', ' ')$$,
  '23514', null, 'blank full name is rejected'
);
select throws_ok(
  $$insert into public.profiles (id, full_name) values ('20000000-0000-4000-8000-000000000006', 'A')$$,
  '23514', null, 'one-character full name is rejected'
);
select throws_ok(
  $$insert into public.profiles (id, bio) values ('20000000-0000-4000-8000-000000000006', ' ')$$,
  '23514', null, 'blank bio is rejected'
);
select throws_ok(
  $$insert into public.profiles (id, bio) values ('20000000-0000-4000-8000-000000000006', repeat('a', 301))$$,
  '23514', null, 'bio longer than 300 characters is rejected'
);
select throws_ok(
  $$insert into public.profiles (id, pace_seconds_per_km) values ('20000000-0000-4000-8000-000000000006', 119)$$,
  '23514', null, 'pace below 120 seconds per km is rejected'
);
select throws_ok(
  $$insert into public.profiles (id, pace_seconds_per_km) values ('20000000-0000-4000-8000-000000000006', 1801)$$,
  '23514', null, 'pace above 1800 seconds per km is rejected'
);

select lives_ok(
  $$insert into public.profiles (id) values ('20000000-0000-4000-8000-000000000005')$$,
  'an incomplete profile accepts the approved nullable fields'
);

select throws_ok(
  $$insert into public.profiles (id, full_name, city_id, running_level, preferred_distance, onboarding_completed)
    values ('20000000-0000-4000-8000-000000000006', 'Runner Six', '10000000-0000-4000-8000-000000000001', 'beginner', 'up_to_5k', true)$$,
  '23514', null, 'completed onboarding requires username'
);
select throws_ok(
  $$insert into public.profiles (id, username, city_id, running_level, preferred_distance, onboarding_completed)
    values ('20000000-0000-4000-8000-000000000006', 'runner_six', '10000000-0000-4000-8000-000000000001', 'beginner', 'up_to_5k', true)$$,
  '23514', null, 'completed onboarding requires full name'
);
select throws_ok(
  $$insert into public.profiles (id, username, full_name, running_level, preferred_distance, onboarding_completed)
    values ('20000000-0000-4000-8000-000000000006', 'runner_six', 'Runner Six', 'beginner', 'up_to_5k', true)$$,
  '23514', null, 'completed onboarding requires city'
);
select throws_ok(
  $$insert into public.profiles (id, username, full_name, city_id, preferred_distance, onboarding_completed)
    values ('20000000-0000-4000-8000-000000000006', 'runner_six', 'Runner Six', '10000000-0000-4000-8000-000000000001', 'up_to_5k', true)$$,
  '23514', null, 'completed onboarding requires running level'
);
select throws_ok(
  $$insert into public.profiles (id, username, full_name, city_id, running_level, onboarding_completed)
    values ('20000000-0000-4000-8000-000000000006', 'runner_six', 'Runner Six', '10000000-0000-4000-8000-000000000001', 'beginner', true)$$,
  '23514', null, 'completed onboarding requires preferred distance'
);

insert into public.cities
  (id, name, country_code, state_code, slug, timezone, is_active)
values
  ('10000000-0000-4000-8000-000000000003', 'Cidade Inativa', 'BR', 'PE', 'cidade-inativa', 'America/Recife', false);
select throws_ok(
  $$insert into public.profiles
    (id, username, full_name, city_id, running_level, preferred_distance, onboarding_completed)
    values
    ('20000000-0000-4000-8000-000000000006', 'runner_six', 'Runner Six',
     '10000000-0000-4000-8000-000000000003', 'beginner', 'up_to_5k', true)$$,
  '23514', null, 'completed onboarding rejects an inactive city'
);

select throws_ok(
  $$insert into public.app_settings (id, launch_city_id)
    values ('10000000-0000-4000-8000-000000000099', '10000000-0000-4000-8000-000000000001')$$,
  '23514', null, 'app settings rejects a second singleton identity'
);
select throws_ok(
  $$insert into public.cities (name, country_code, state_code, slug, timezone)
    values ('Timezone Inválida', 'BR', 'PE', 'timezone-invalida', 'Mars/Olympus')$$,
  '23514', null, 'city rejects an invalid IANA timezone'
);
select throws_ok(
  $$insert into private.account_controls (user_id, status)
    values ('20000000-0000-4000-8000-000000000006', 'unknown')$$,
  '23514', null, 'account control rejects an invalid status'
);
select throws_ok(
  $$insert into private.platform_roles (user_id, role)
    values ('20000000-0000-4000-8000-000000000006', 'owner')$$,
  '23514', null, 'platform role rejects an invalid role'
);

select * from finish();
rollback;

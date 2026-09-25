begin;
create extension if not exists pgtap with schema extensions;
select plan(7);

insert into auth.users(id,email) values
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','public-a@example.test'),
 ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','private-b@example.test'),
 ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','suspended@example.test');
insert into private.account_controls(user_id,status) values
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','active'),
 ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','active'),
 ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','suspended')
on conflict (user_id) do update set status = excluded.status;
insert into public.profiles(id,username,full_name,city_id,running_level,preferred_distance,is_private,onboarding_completed) values
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','public_a','Public A','10000000-0000-4000-8000-000000000001','beginner','up_to_5k',false,true),
 ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','private_b','Private B','10000000-0000-4000-8000-000000000001','intermediate','5k_to_10k',true,true),
 ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','suspended_e','Suspended E','10000000-0000-4000-8000-000000000001','advanced','flexible',false,true)
on conflict (id) do update set
 username = excluded.username,
 full_name = excluded.full_name,
 city_id = excluded.city_id,
 running_level = excluded.running_level,
 preferred_distance = excluded.preferred_distance,
 is_private = excluded.is_private,
 onboarding_completed = excluded.onboarding_completed;
insert into public.cities(id,name,country_code,state_code,slug,timezone,is_active)
values ('10000000-0000-4000-8000-000000000020','Cidade Histórica','BR','PE','cidade-historica','America/Recife',false);

set local role anon;
set local request.jwt.claims = '{}';
select is((select count(*) from public.cities),2::bigint,'anon reads active and inactive cities');
select is((select count(*) from public.app_settings),1::bigint,'anon reads launch settings');
select throws_ok($$insert into public.cities(name,country_code,state_code,slug,timezone)
 values ('Cidade Indevida','BR','PE','cidade-indevida','America/Recife')$$,'42501',null,'anon cannot write cities');
select is((select count(*) from public.profile_directory where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),1::bigint,'anon sees public active profile');
select is((select count(*) from public.profile_directory where id='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'),0::bigint,'anon cannot see private profile');
select is((select count(*) from public.profile_directory where id='eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee'),0::bigint,'anon cannot see suspended profile');
select throws_ok('select is_private from public.profiles','42501',null,'anon cannot select operational profile columns');
reset role;

select * from finish();
rollback;

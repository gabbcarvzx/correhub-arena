begin;
create extension if not exists pgtap with schema extensions;
select plan(8);

insert into auth.users(id,email) values
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','a@example.test'),
 ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','b@example.test'),
 ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','e@example.test');
insert into private.account_controls(user_id,status) values
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','active'),
 ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','active'),
 ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','suspended')
on conflict (user_id) do update set status = excluded.status;
insert into public.profiles(id,username,full_name,city_id,running_level,preferred_distance,is_private,onboarding_completed) values
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','runner_a','Runner A','10000000-0000-4000-8000-000000000001','beginner','up_to_5k',true,true),
 ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','runner_b','Runner B','10000000-0000-4000-8000-000000000001','intermediate','5k_to_10k',true,true),
 ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','runner_e','Runner E','10000000-0000-4000-8000-000000000001','advanced','flexible',true,true)
on conflict (id) do update set
 username = excluded.username,
 full_name = excluded.full_name,
 city_id = excluded.city_id,
 running_level = excluded.running_level,
 preferred_distance = excluded.preferred_distance,
 is_private = excluded.is_private,
 onboarding_completed = excluded.onboarding_completed;
insert into public.user_follows(follower_id,followed_id)
values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb');

set local role authenticated;
set local request.jwt.claims = '{"sub":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","role":"authenticated"}';
select is((select count(*) from public.profiles where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),1::bigint,'user A reads own private profile');
select is((select count(*) from public.profiles where id='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'),0::bigint,'user A cannot read private B');
select lives_ok($$update public.profiles set bio='Bio A' where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'$$,'user A updates own profile');
select is((select bio from public.profiles where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),'Bio A','own update persists');
select results_eq($$update public.profiles set bio='Inválida' where id='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb' returning id$$,array[]::uuid[],'user A cannot update B');
select is((select count(*) from public.profile_directory where id='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'),0::bigint,'follow does not reveal private B');
reset role;

set local role authenticated;
set local request.jwt.claims = '{"sub":"bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb","role":"authenticated"}';
select is((select count(*) from public.profiles where id='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'),1::bigint,'private B reads own profile');
reset role;

set local role authenticated;
set local request.jwt.claims = '{"sub":"eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee","role":"authenticated"}';
select results_eq($$update public.profiles set bio='Suspensa' where id='eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee' returning id$$,array[]::uuid[],'suspended user cannot mutate profile');
reset role;

select * from finish();
rollback;

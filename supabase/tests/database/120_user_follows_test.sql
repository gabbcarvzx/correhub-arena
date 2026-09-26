begin;
create extension if not exists pgtap with schema extensions;
select plan(51);

insert into auth.users (id, email) values
  ('32000000-0000-4000-8000-000000000001', 'follow-a@example.test'),
  ('32000000-0000-4000-8000-000000000002', 'follow-b@example.test'),
  ('32000000-0000-4000-8000-000000000003', 'follow-c@example.test'),
  ('32000000-0000-4000-8000-000000000004', 'follow-d@example.test'),
  ('32000000-0000-4000-8000-000000000005', 'follow-e@example.test'),
  ('32000000-0000-4000-8000-000000000006', 'follow-f@example.test'),
  ('32000000-0000-4000-8000-000000000007', 'follow-g@example.test'),
  ('32000000-0000-4000-8000-000000000008', 'follow-h@example.test');

update private.account_controls set status='suspended'
where user_id='32000000-0000-4000-8000-000000000004';

update public.profiles set
  username='gate3_follow_a', full_name='Follow A', bio='Bio A',
  city_id='10000000-0000-4000-8000-000000000001', running_level='beginner',
  preferred_distance='up_to_5k', is_private=false, onboarding_completed=true
where id='32000000-0000-4000-8000-000000000001';
update public.profiles set
  username='gate3_follow_b', full_name='Follow B', bio='Bio B',
  city_id='10000000-0000-4000-8000-000000000001', running_level='intermediate',
  preferred_distance='5k_to_10k', is_private=false, onboarding_completed=true
where id='32000000-0000-4000-8000-000000000002';
update public.profiles set
  username='gate3_follow_c', full_name='Follow C', bio='Private C', avatar_url='https://images.example/c.png',
  city_id='10000000-0000-4000-8000-000000000001', running_level='advanced',
  preferred_distance='10k_to_21k', is_private=true, onboarding_completed=true
where id='32000000-0000-4000-8000-000000000003';
update public.profiles set
  username='gate3_follow_d', full_name='Follow D',
  city_id='10000000-0000-4000-8000-000000000001', running_level='beginner',
  preferred_distance='flexible', is_private=false, onboarding_completed=true
where id='32000000-0000-4000-8000-000000000004';
update public.profiles set username='gate3_follow_e', full_name='Follow E'
where id='32000000-0000-4000-8000-000000000005';
update public.profiles set
  username='gate3_follow_f', full_name='Follow F', bio='Bio F',
  city_id='10000000-0000-4000-8000-000000000001', running_level='beginner',
  preferred_distance='up_to_5k', is_private=false, onboarding_completed=true
where id='32000000-0000-4000-8000-000000000006';
update public.profiles set
  username='gate3_follow_g', full_name='Follow G', bio='Private G', avatar_url='https://images.example/g.png',
  city_id='10000000-0000-4000-8000-000000000001', running_level='advanced',
  preferred_distance='flexible', is_private=true, onboarding_completed=true
where id='32000000-0000-4000-8000-000000000007';

select has_function('private','current_account_is_social_ready',array[]::text[],'social-ready helper exists');
select has_function('private','profile_is_socially_eligible',array['uuid'],'target eligibility helper exists');
select has_function('public','list_profile_connections',array['text','text','text','uuid','integer'],'connection list RPC exists');
select is((select count(*) from pg_catalog.pg_policies where schemaname='public' and tablename='user_follows'),3::bigint,'user_follows has exactly three Gate 3 policies');
select ok(has_table_privilege('authenticated','public.user_follows','SELECT'),'authenticated can select permitted own relationships');
select ok(has_table_privilege('authenticated','public.user_follows','DELETE'),'authenticated can delete permitted own relationships');
select isnt(has_table_privilege('authenticated','public.user_follows','UPDATE'),true,'authenticated cannot update follow rows');
select isnt(has_table_privilege('anon','public.user_follows','SELECT'),true,'anon cannot select follow rows');
select isnt(has_table_privilege('anon','public.user_follows','INSERT'),true,'anon cannot insert follow rows');
select ok(has_column_privilege('authenticated','public.user_follows','follower_id','INSERT'),'authenticated has INSERT on follower_id');
select ok(has_column_privilege('authenticated','public.user_follows','followed_id','INSERT'),'authenticated has INSERT on followed_id');
select isnt(has_column_privilege('authenticated','public.user_follows','created_at','INSERT'),true,'authenticated cannot choose created_at');
select ok((select p.prosecdef and p.proconfig @> array['search_path=""'] from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='list_profile_connections'),'connection list is definer with empty search_path');
select is((select count(*) from pg_catalog.aclexplode(p.proacl) a where a.grantee=0 and a.privilege_type='EXECUTE')::bigint,0::bigint,'PUBLIC cannot execute connection list') from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='list_profile_connections';
select isnt(has_function_privilege('anon','public.list_profile_connections(text,text,text,uuid,integer)','EXECUTE'),true,'anon cannot execute connection list');
select ok(has_function_privilege('authenticated','public.list_profile_connections(text,text,text,uuid,integer)','EXECUTE'),'authenticated can execute connection list');
select is((select count(*) from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid=p.pronamespace where n.nspname='private' and p.proname in ('current_account_is_social_ready','profile_is_socially_eligible') and p.prosecdef and p.proconfig @> array['search_path=""']),2::bigint,'social helpers are definer with empty search_path');
select is((select count(*) from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid=p.pronamespace where n.nspname='private' and p.proname in ('current_account_is_social_ready','profile_is_socially_eligible') and has_function_privilege('anon',p.oid,'EXECUTE')),0::bigint,'anon cannot execute social helpers');
select is((select count(*) from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid=p.pronamespace where n.nspname='private' and p.proname in ('current_account_is_social_ready','profile_is_socially_eligible') and has_function_privilege('authenticated',p.oid,'EXECUTE')),2::bigint,'authenticated can execute social helpers');
select is((select count(*) from public.user_follows where follower_id='32000000-0000-4000-8000-000000000008'),0::bigint,'newly provisioned account has no automatic follows');

set local role anon;
set local request.jwt.claims='{"role":"anon"}';
select throws_ok($$select * from public.user_follows$$,'42501',null,'anon cannot read follow table');
select throws_ok($$select * from public.list_profile_connections('gate3_follow_b','followers',null,null,20)$$,'42501',null,'anon cannot call connection list');
reset role;

set local role authenticated;
set local request.jwt.claims='{"sub":"32000000-0000-4000-8000-000000000001","role":"authenticated"}';
select lives_ok($$insert into public.user_follows(follower_id,followed_id) values ('32000000-0000-4000-8000-000000000001','32000000-0000-4000-8000-000000000002')$$,'A follows public B');
select lives_ok($$insert into public.user_follows(follower_id,followed_id) values ('32000000-0000-4000-8000-000000000001','32000000-0000-4000-8000-000000000003')$$,'A follows private C');
select is((select count(*) from public.user_follows),2::bigint,'A sees exactly its two own follow rows');
select throws_ok($$insert into public.user_follows(follower_id,followed_id) values ('32000000-0000-4000-8000-000000000001','32000000-0000-4000-8000-000000000001')$$,'42501',null,'self-follow is rejected by RLS before the CHECK backstop');
select throws_ok($$insert into public.user_follows(follower_id,followed_id) values ('32000000-0000-4000-8000-000000000001','32000000-0000-4000-8000-000000000002')$$,'23505',null,'duplicate follow fails without another row');
select is((select count(*) from public.user_follows where follower_id='32000000-0000-4000-8000-000000000001' and followed_id='32000000-0000-4000-8000-000000000002'),1::bigint,'duplicate follow never duplicates');
select throws_ok($$insert into public.user_follows(follower_id,followed_id) values ('32000000-0000-4000-8000-000000000001','32000000-0000-4000-8000-000000000004')$$,'42501',null,'A cannot follow suspended D');
select throws_ok($$insert into public.user_follows(follower_id,followed_id) values ('32000000-0000-4000-8000-000000000001','32000000-0000-4000-8000-000000000005')$$,'42501',null,'A cannot follow incomplete E');
select throws_ok($$insert into public.user_follows(follower_id,followed_id) values ('32000000-0000-4000-8000-000000000002','32000000-0000-4000-8000-000000000006')$$,'42501',null,'A cannot impersonate B as follower');
select is((select bio from public.get_profile_by_username('gate3_follow_c')),null::text,'follow does not reveal private C bio');
select is((select avatar_url from public.get_profile_by_username('gate3_follow_c')),null::text,'follow does not reveal private C avatar');
select is((select count(*) from public.list_profile_connections('gate3_follow_c','followers',null,null,20)),0::bigint,'follower A cannot read private C graph');
select results_eq($$delete from public.user_follows where followed_id='32000000-0000-4000-8000-000000000002' returning followed_id$$,array['32000000-0000-4000-8000-000000000002'::uuid],'A removes its own follow of B');
select results_eq($$delete from public.user_follows where followed_id='32000000-0000-4000-8000-000000000002' returning followed_id$$,array[]::uuid[],'repeated unfollow is idempotently empty');
reset role;

insert into public.user_follows(follower_id,followed_id) values
  ('32000000-0000-4000-8000-000000000006','32000000-0000-4000-8000-000000000002'),
  ('32000000-0000-4000-8000-000000000007','32000000-0000-4000-8000-000000000002'),
  ('32000000-0000-4000-8000-000000000004','32000000-0000-4000-8000-000000000002'),
  ('32000000-0000-4000-8000-000000000005','32000000-0000-4000-8000-000000000002'),
  ('32000000-0000-4000-8000-000000000007','32000000-0000-4000-8000-000000000003');

set local role authenticated;
set local request.jwt.claims='{"sub":"32000000-0000-4000-8000-000000000003","role":"authenticated"}';
select results_eq($$delete from public.user_follows where follower_id='32000000-0000-4000-8000-000000000001' and followed_id='32000000-0000-4000-8000-000000000003' returning followed_id$$,array[]::uuid[],'C cannot delete follow created by A');
select results_eq(
  $$select username,visibility from public.list_profile_connections('gate3_follow_c','followers',null,null,20) order by username$$,
  $$values ('gate3_follow_a'::text,'public'::text),('gate3_follow_g'::text,'private'::text)$$,
  'private target owner sees public full and private minimal counterparties'
);
select is((select bio from public.list_profile_connections('gate3_follow_c','followers',null,null,20) where username='gate3_follow_g'),null::text,'owner list hides private counterpart bio');
select is((select avatar_url from public.list_profile_connections('gate3_follow_c','followers',null,null,20) where username='gate3_follow_g'),null::text,'owner list hides private counterpart avatar');
reset role;

set local role authenticated;
set local request.jwt.claims='{"sub":"32000000-0000-4000-8000-000000000001","role":"authenticated"}';
select results_eq(
  $$select username,visibility from public.list_profile_connections('gate3_follow_b','followers',null,null,20) order by username$$,
  $$values ('gate3_follow_f'::text,'public'::text)$$,
  'third party sees only public active complete counterpart on public graph'
);
select is((select count(*) from public.list_profile_connections('gate3_follow_b','invalid',null,null,20)),0::bigint,'invalid direction returns no graph rows');
select is((select count(*) from public.list_profile_connections('gate3_follow_b','followers',null,null,1)),1::bigint,'connection page size is bounded and honored');
reset role;

set local role authenticated;
set local request.jwt.claims='{"sub":"32000000-0000-4000-8000-000000000002","role":"authenticated"}';
select results_eq(
  $$select username,visibility from public.list_profile_connections('gate3_follow_b','followers',null,null,20) order by username$$,
  $$values ('gate3_follow_f'::text,'public'::text),('gate3_follow_g'::text,'private'::text)$$,
  'public target owner sees private counterpart only as minimal identity'
);
reset role;

set local role authenticated;
set local request.jwt.claims='{"sub":"32000000-0000-4000-8000-000000000004","role":"authenticated"}';
select is((select count(*) from public.user_follows),0::bigint,'suspended D cannot select even its own historical follow');
select throws_ok($$insert into public.user_follows(follower_id,followed_id) values ('32000000-0000-4000-8000-000000000004','32000000-0000-4000-8000-000000000006')$$,'42501',null,'suspended D cannot follow');
select results_eq($$delete from public.user_follows where follower_id='32000000-0000-4000-8000-000000000004' returning followed_id$$,array[]::uuid[],'suspended D cannot unfollow');
select is((select count(*) from public.list_profile_connections('gate3_follow_b','followers',null,null,20)),0::bigint,'suspended caller cannot list connections');
reset role;

select is((select count(*) from public.user_follows where follower_id='32000000-0000-4000-8000-000000000004'),1::bigint,'suspension preserves historical follow row');
update private.account_controls set status='suspended' where user_id='32000000-0000-4000-8000-000000000002';
set local role authenticated;
set local request.jwt.claims='{"sub":"32000000-0000-4000-8000-000000000001","role":"authenticated"}';
select is((select count(*) from public.list_profile_connections('gate3_follow_b','followers',null,null,20)),0::bigint,'suspended target disappears from connection lists');
reset role;
select ok((select count(*) from public.user_follows where followed_id='32000000-0000-4000-8000-000000000002') >= 4,'target suspension preserves historical graph rows');

select * from finish();
rollback;

begin;
create extension if not exists pgtap with schema extensions;
select plan(27);

insert into auth.users(id,email) values
 ('45000000-0000-4000-8000-000000000001','group-follow-owner@example.test'),
 ('45000000-0000-4000-8000-000000000002','group-follower@example.test'),
 ('45000000-0000-4000-8000-000000000003','group-follow-other@example.test'),
 ('45000000-0000-4000-8000-000000000004','group-follow-reviewer@example.test'),
 ('45000000-0000-4000-8000-000000000005','group-follow-suspended@example.test');
update public.profiles set username='gf_owner',full_name='GF Owner',city_id='10000000-0000-4000-8000-000000000001',running_level='advanced',preferred_distance='flexible',onboarding_completed=true where id='45000000-0000-4000-8000-000000000001';
update public.profiles set username='gf_follower',full_name='GF Follower',city_id='10000000-0000-4000-8000-000000000001',running_level='beginner',preferred_distance='up_to_5k',onboarding_completed=true where id='45000000-0000-4000-8000-000000000002';
update public.profiles set username='gf_other',full_name='GF Other',city_id='10000000-0000-4000-8000-000000000001',running_level='intermediate',preferred_distance='5k_to_10k',onboarding_completed=true where id='45000000-0000-4000-8000-000000000003';
update public.profiles set username='gf_reviewer',full_name='GF Reviewer',city_id='10000000-0000-4000-8000-000000000001',running_level='advanced',preferred_distance='flexible',onboarding_completed=true where id='45000000-0000-4000-8000-000000000004';
update public.profiles set username='gf_suspended',full_name='GF Suspended',city_id='10000000-0000-4000-8000-000000000001',running_level='beginner',preferred_distance='up_to_5k',onboarding_completed=true where id='45000000-0000-4000-8000-000000000005';
update private.account_controls set status='suspended' where user_id='45000000-0000-4000-8000-000000000005';
insert into private.platform_roles(user_id,role) values ('45000000-0000-4000-8000-000000000004','platform_admin');
set local role authenticated;
set local request.jwt.claims='{"sub":"45000000-0000-4000-8000-000000000001","role":"authenticated"}';
select public.request_group('Follow Approved','follow-approved','Approved group','10000000-0000-4000-8000-000000000001','community','open');
select public.request_group('Follow Pending','follow-pending','Pending group','10000000-0000-4000-8000-000000000001','community','open');
reset role;
set local role authenticated;
set local request.jwt.claims='{"sub":"45000000-0000-4000-8000-000000000004","role":"authenticated"}';
select public.approve_group_request((select id from public.groups where slug='follow-approved'));
reset role;

select is((select count(*) from pg_catalog.pg_policies where schemaname='public' and tablename='group_follows'),3::bigint,'group_follows has three narrow policies');
select ok(has_table_privilege('authenticated','public.group_follows','SELECT'),'authenticated can select own follow rows');
select ok(has_table_privilege('authenticated','public.group_follows','DELETE'),'authenticated can delete own follow rows');
select isnt(has_table_privilege('authenticated','public.group_follows','UPDATE'),true,'authenticated cannot update group follow rows');
select isnt(has_table_privilege('anon','public.group_follows','SELECT'),true,'anon cannot read group follows');
select ok(has_column_privilege('authenticated','public.group_follows','user_id','INSERT'),'authenticated can submit user_id under RLS');
select ok(has_column_privilege('authenticated','public.group_follows','group_id','INSERT'),'authenticated can submit group_id under RLS');
select isnt(has_column_privilege('authenticated','public.group_follows','created_at','INSERT'),true,'client cannot choose follow timestamp');

set local role anon;
set local request.jwt.claims='{"role":"anon"}';
select throws_ok($$insert into public.group_follows(user_id,group_id) values ('45000000-0000-4000-8000-000000000002',(select id from public.groups where slug='follow-approved'))$$,'42501',null,'anon cannot follow group');
reset role;

set local role authenticated;
set local request.jwt.claims='{"sub":"45000000-0000-4000-8000-000000000002","role":"authenticated"}';
select lives_ok($$insert into public.group_follows(user_id,group_id) values ('45000000-0000-4000-8000-000000000002',(select id from public.groups where slug='follow-approved'))$$,'active runner follows approved group');
select throws_ok($$insert into public.group_follows(user_id,group_id) values ('45000000-0000-4000-8000-000000000002',(select id from public.groups where slug='follow-approved'))$$,'23505',null,'duplicate group follow does not duplicate');
select throws_ok($$insert into public.group_follows(user_id,group_id) values ('45000000-0000-4000-8000-000000000003',(select id from public.groups where slug='follow-approved'))$$,'42501',null,'runner cannot impersonate another follower');
select throws_ok($$insert into public.group_follows(user_id,group_id) values ('45000000-0000-4000-8000-000000000002',(select id from public.groups where slug='follow-pending'))$$,'42501',null,'pending group cannot be followed');
reset role;

select is((select count(*) from public.group_follows where user_id='45000000-0000-4000-8000-000000000002'),1::bigint,'follow relation exists once');
select is((select count(*) from public.group_members gm join public.groups g on g.id=gm.group_id where g.slug='follow-approved' and gm.user_id='45000000-0000-4000-8000-000000000002'),0::bigint,'follow does not create membership');
select is((select count(*) from private.analytics_events a join public.groups g on g.id=a.entity_id where g.slug='follow-approved' and a.event_name='group_followed' and a.user_id='45000000-0000-4000-8000-000000000002'),1::bigint,'follow persists one analytics event');

set local role authenticated;
set local request.jwt.claims='{"sub":"45000000-0000-4000-8000-000000000003","role":"authenticated"}';
select is(public.join_group((select id from public.groups where slug='follow-approved')),'active','other runner joins approved open group');
reset role;
select is((select count(*) from public.group_follows where user_id='45000000-0000-4000-8000-000000000003'),0::bigint,'membership does not create group follow');

set local role authenticated;
set local request.jwt.claims='{"sub":"45000000-0000-4000-8000-000000000002","role":"authenticated"}';
select results_eq($$delete from public.group_follows where group_id=(select id from public.groups where slug='follow-approved') returning group_id$$,$$select id from public.groups where slug='follow-approved'$$,'follower can unfollow own relation');
select results_eq($$delete from public.group_follows where group_id=(select id from public.groups where slug='follow-approved') returning group_id$$,array[]::uuid[],'repeated unfollow is idempotently empty');
reset role;
select is((select count(*) from public.group_members gm join public.groups g on g.id=gm.group_id where g.slug='follow-approved' and gm.user_id='45000000-0000-4000-8000-000000000003'),1::bigint,'unfollow of another relation cannot affect membership');

set local role authenticated;
set local request.jwt.claims='{"sub":"45000000-0000-4000-8000-000000000003","role":"authenticated"}';
insert into public.group_follows(user_id,group_id) values ('45000000-0000-4000-8000-000000000003',(select id from public.groups where slug='follow-approved'));
select public.leave_group((select id from public.groups where slug='follow-approved'));
reset role;
select is((select count(*) from public.group_follows where user_id='45000000-0000-4000-8000-000000000003'),1::bigint,'leaving group does not remove independent follow');
select is((select count(*) from public.group_members gm join public.groups g on g.id=gm.group_id where g.slug='follow-approved' and gm.user_id='45000000-0000-4000-8000-000000000003'),0::bigint,'leaving removes membership only');

set local role authenticated;
set local request.jwt.claims='{"sub":"45000000-0000-4000-8000-000000000005","role":"authenticated"}';
select throws_ok($$insert into public.group_follows(user_id,group_id) values ('45000000-0000-4000-8000-000000000005',(select id from public.groups where slug='follow-approved'))$$,'42501',null,'suspended account cannot follow with stale JWT');
select results_eq($$delete from public.group_follows where user_id='45000000-0000-4000-8000-000000000005' returning group_id$$,array[]::uuid[],'suspended account cannot mutate follows');
reset role;

set local role authenticated;
set local request.jwt.claims='{"sub":"45000000-0000-4000-8000-000000000002","role":"authenticated"}';
select throws_ok($$insert into private.analytics_events(event_name,user_id,event_key) values ('group_followed','45000000-0000-4000-8000-000000000002','spoof')$$,'42501',null,'client cannot spoof analytics event');
reset role;
select is((select count(*) from private.analytics_events where event_name='group_followed'),2::bigint,'refollow by another runner creates one event per relation identity');

select * from finish();
rollback;

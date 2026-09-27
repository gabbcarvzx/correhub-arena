begin;
create extension if not exists pgtap with schema extensions;
select plan(42);

insert into auth.users(id,email) values
 ('43000000-0000-4000-8000-000000000001','membership-owner@example.test'),
 ('43000000-0000-4000-8000-000000000002','membership-admin@example.test'),
 ('43000000-0000-4000-8000-000000000003','membership-member@example.test'),
 ('43000000-0000-4000-8000-000000000004','membership-applicant@example.test'),
 ('43000000-0000-4000-8000-000000000005','membership-blocked@example.test'),
 ('43000000-0000-4000-8000-000000000006','membership-reviewer@example.test'),
 ('43000000-0000-4000-8000-000000000007','membership-private@example.test'),
 ('43000000-0000-4000-8000-000000000008','membership-outsider@example.test');

update public.profiles set username='member_owner',full_name='Member Owner',city_id='10000000-0000-4000-8000-000000000001',running_level='advanced',preferred_distance='flexible',onboarding_completed=true where id='43000000-0000-4000-8000-000000000001';
update public.profiles set username='member_admin',full_name='Member Admin',city_id='10000000-0000-4000-8000-000000000001',running_level='intermediate',preferred_distance='5k_to_10k',onboarding_completed=true where id='43000000-0000-4000-8000-000000000002';
update public.profiles set username='member_common',full_name='Member Common',city_id='10000000-0000-4000-8000-000000000001',running_level='beginner',preferred_distance='up_to_5k',onboarding_completed=true where id='43000000-0000-4000-8000-000000000003';
update public.profiles set username='member_applicant',full_name='Member Applicant',city_id='10000000-0000-4000-8000-000000000001',running_level='beginner',preferred_distance='up_to_5k',onboarding_completed=true where id='43000000-0000-4000-8000-000000000004';
update public.profiles set username='member_blocked',full_name='Member Blocked',city_id='10000000-0000-4000-8000-000000000001',running_level='beginner',preferred_distance='up_to_5k',onboarding_completed=true where id='43000000-0000-4000-8000-000000000005';
update public.profiles set username='member_reviewer',full_name='Member Reviewer',city_id='10000000-0000-4000-8000-000000000001',running_level='advanced',preferred_distance='flexible',onboarding_completed=true where id='43000000-0000-4000-8000-000000000006';
update public.profiles set username='member_private',full_name='Member Private',avatar_url='https://private.example/avatar.png',bio='Private bio',city_id='10000000-0000-4000-8000-000000000001',running_level='advanced',preferred_distance='10k_to_21k',pace_seconds_per_km=300,is_private=true,onboarding_completed=true where id='43000000-0000-4000-8000-000000000007';
update public.profiles set username='member_outsider',full_name='Member Outsider',city_id='10000000-0000-4000-8000-000000000001',running_level='beginner',preferred_distance='up_to_5k',onboarding_completed=true where id='43000000-0000-4000-8000-000000000008';
insert into private.platform_roles(user_id,role) values ('43000000-0000-4000-8000-000000000006','platform_admin');

set local role authenticated;
set local request.jwt.claims='{"sub":"43000000-0000-4000-8000-000000000001","role":"authenticated"}';
select public.request_group('Open Group','membership-open','Open group','10000000-0000-4000-8000-000000000001','community','open');
select public.request_group('Approval Group','membership-approval','Approval group','10000000-0000-4000-8000-000000000001','community','approval_required');
reset role;
set local role authenticated;
set local request.jwt.claims='{"sub":"43000000-0000-4000-8000-000000000006","role":"authenticated"}';
select public.approve_group_request((select id from public.groups where slug='membership-open'));
select public.approve_group_request((select id from public.groups where slug='membership-approval'));
reset role;

select has_function('public','join_group',array['uuid'],'join RPC exists');
select has_function('public','approve_group_member',array['uuid','uuid'],'member approval RPC exists');
select has_function('public','reject_group_member_request',array['uuid','uuid'],'member rejection RPC exists');
select has_function('public','block_group_member',array['uuid','uuid'],'member block RPC exists');
select has_function('public','leave_group',array['uuid'],'leave RPC exists');
select has_function('public','promote_group_admin',array['uuid','uuid'],'promotion RPC exists');
select has_function('public','demote_group_admin',array['uuid','uuid'],'demotion RPC exists');
select has_function('public','list_group_members',array['uuid','text','text','uuid','integer'],'sanitized roster RPC exists');

set local role authenticated;
set local request.jwt.claims='{"sub":"43000000-0000-4000-8000-000000000003","role":"authenticated"}';
select is(public.join_group((select id from public.groups where slug='membership-open')),'active','open join activates member immediately');
select is(public.join_group((select id from public.groups where slug='membership-open')),'active','repeated open join is idempotent');
reset role;
select is((select count(*) from public.group_members gm join public.groups g on g.id=gm.group_id where g.slug='membership-open' and gm.user_id='43000000-0000-4000-8000-000000000003'),1::bigint,'repeated join never duplicates row');
select is((select count(*) from public.activity_events ae join public.groups g on g.id=ae.group_id where g.slug='membership-open' and ae.actor_user_id='43000000-0000-4000-8000-000000000003' and ae.event_type='group_joined'),1::bigint,'first activation creates one activity event');

set local role authenticated;
set local request.jwt.claims='{"sub":"43000000-0000-4000-8000-000000000004","role":"authenticated"}';
select is(public.join_group((select id from public.groups where slug='membership-approval')),'pending','approval-required join creates pending request');
select is(public.join_group((select id from public.groups where slug='membership-approval')),'pending','repeated pending join is idempotent');
reset role;

set local role authenticated;
set local request.jwt.claims='{"sub":"43000000-0000-4000-8000-000000000001","role":"authenticated"}';
select lives_ok($$select public.approve_group_member((select id from public.groups where slug='membership-approval'),'43000000-0000-4000-8000-000000000004')$$,'owner approves pending common member');
reset role;
select is((select gm.status from public.group_members gm join public.groups g on g.id=gm.group_id where g.slug='membership-approval' and gm.user_id='43000000-0000-4000-8000-000000000004'),'active','approval activates pending member');

set local role authenticated;
set local request.jwt.claims='{"sub":"43000000-0000-4000-8000-000000000005","role":"authenticated"}';
select is(public.join_group((select id from public.groups where slug='membership-approval')),'pending','second applicant becomes pending');
reset role;
set local role authenticated;
set local request.jwt.claims='{"sub":"43000000-0000-4000-8000-000000000001","role":"authenticated"}';
select lives_ok($$select public.reject_group_member_request((select id from public.groups where slug='membership-approval'),'43000000-0000-4000-8000-000000000005')$$,'owner rejects pending membership');
reset role;
select is((select count(*) from public.group_members gm join public.groups g on g.id=gm.group_id where g.slug='membership-approval' and gm.user_id='43000000-0000-4000-8000-000000000005'),0::bigint,'rejection removes pending request');

set local role authenticated;
set local request.jwt.claims='{"sub":"43000000-0000-4000-8000-000000000002","role":"authenticated"}';
select is(public.join_group((select id from public.groups where slug='membership-open')),'active','future admin joins as member');
reset role;
set local role authenticated;
set local request.jwt.claims='{"sub":"43000000-0000-4000-8000-000000000001","role":"authenticated"}';
select lives_ok($$select public.promote_group_admin((select id from public.groups where slug='membership-open'),'43000000-0000-4000-8000-000000000002')$$,'owner promotes active member');
reset role;
select is((select gm.role from public.group_members gm join public.groups g on g.id=gm.group_id where g.slug='membership-open' and gm.user_id='43000000-0000-4000-8000-000000000002'),'admin','promotion changes role to admin');

set local role authenticated;
set local request.jwt.claims='{"sub":"43000000-0000-4000-8000-000000000002","role":"authenticated"}';
select lives_ok($$select public.update_group_profile(
  (select id from public.groups where slug='membership-open'),
  'Open Group Updated','membership-open','Open group updated',
  '10000000-0000-4000-8000-000000000001','community','open'
)$$,'active group admin edits approved group fields through allowlist');
select throws_ok($$select public.update_group_profile(
  (select id from public.groups where slug='membership-open'),
  'Open Group Updated','membership-open-renamed','Open group updated',
  '10000000-0000-4000-8000-000000000001','community','open'
)$$,'42501','approved_slug_immutable','approved group slug stays immutable');
select throws_ok($$select public.promote_group_admin((select id from public.groups where slug='membership-open'),'43000000-0000-4000-8000-000000000003')$$,'42501',null,'admin cannot promote another member');
select throws_ok($$select public.block_group_member((select id from public.groups where slug='membership-open'),'43000000-0000-4000-8000-000000000001')$$,'42501',null,'admin cannot block owner');
select lives_ok($$select public.block_group_member((select id from public.groups where slug='membership-open'),'43000000-0000-4000-8000-000000000003')$$,'admin blocks common member');
reset role;
select is((select gm.status from public.group_members gm join public.groups g on g.id=gm.group_id where g.slug='membership-open' and gm.user_id='43000000-0000-4000-8000-000000000003'),'blocked','block preserves row as blocked');

set local role authenticated;
set local request.jwt.claims='{"sub":"43000000-0000-4000-8000-000000000003","role":"authenticated"}';
select throws_ok($$select public.join_group((select id from public.groups where slug='membership-open'))$$,'42501','membership_blocked','blocked user cannot rejoin');
reset role;

set local role authenticated;
set local request.jwt.claims='{"sub":"43000000-0000-4000-8000-000000000001","role":"authenticated"}';
select lives_ok($$select public.demote_group_admin((select id from public.groups where slug='membership-open'),'43000000-0000-4000-8000-000000000002')$$,'owner demotes admin');
select throws_ok($$select public.leave_group((select id from public.groups where slug='membership-open'))$$,'42501','owner_must_transfer','owner cannot leave');
reset role;
select is((select gm.role from public.group_members gm join public.groups g on g.id=gm.group_id where g.slug='membership-open' and gm.user_id='43000000-0000-4000-8000-000000000002'),'member','demotion returns role to member');

set local role authenticated;
set local request.jwt.claims='{"sub":"43000000-0000-4000-8000-000000000002","role":"authenticated"}';
select lives_ok($$select public.leave_group((select id from public.groups where slug='membership-open'))$$,'common member can leave');
reset role;
select is((select count(*) from public.group_members gm join public.groups g on g.id=gm.group_id where g.slug='membership-open' and gm.user_id='43000000-0000-4000-8000-000000000002'),0::bigint,'leave removes non-owner membership');

set local role authenticated;
set local request.jwt.claims='{"sub":"43000000-0000-4000-8000-000000000007","role":"authenticated"}';
select is(public.join_group((select id from public.groups where slug='membership-open')),'active','private profile joins group');
reset role;
set local role authenticated;
set local request.jwt.claims='{"sub":"43000000-0000-4000-8000-000000000001","role":"authenticated"}';
select is((select visibility from public.list_group_members((select id from public.groups where slug='membership-open'),'active',null,null,20) where username='member_private'),'private','roster marks private identity');
select is((select avatar_url from public.list_group_members((select id from public.groups where slug='membership-open'),'active',null,null,20) where username='member_private'),null::text,'private roster hides real avatar');
select is((select count(*) from public.list_group_members((select id from public.groups where slug='membership-open'),'pending',null,null,20)),0::bigint,'owner can inspect empty pending roster');
reset role;

set local role authenticated;
set local request.jwt.claims='{"sub":"43000000-0000-4000-8000-000000000008","role":"authenticated"}';
select is((select count(*) from public.list_group_members((select id from public.groups where slug='membership-open'),'active',null,null,20)),0::bigint,'outsider cannot enumerate roster');
select throws_ok($$select public.approve_group_member((select id from public.groups where slug='membership-open'),'43000000-0000-4000-8000-000000000004')$$,'42501',null,'outsider cannot manage group');
reset role;

update private.account_controls set status='suspended' where user_id='43000000-0000-4000-8000-000000000004';
set local role authenticated;
set local request.jwt.claims='{"sub":"43000000-0000-4000-8000-000000000004","role":"authenticated"}';
select throws_ok($$select public.leave_group((select id from public.groups where slug='membership-approval'))$$,'42501',null,'suspended account cannot mutate membership with stale JWT');
reset role;

select is((select count(*) from information_schema.columns where table_schema='public' and table_name='group_members' and column_name in ('members_count','followers_count')),0::bigint,'no denormalized social counts exist');
select * from finish();
rollback;

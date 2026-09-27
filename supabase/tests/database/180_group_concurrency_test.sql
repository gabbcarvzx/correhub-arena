create extension if not exists pgtap with schema extensions;
create extension if not exists dblink with schema extensions;

delete from public.notifications where recipient_user_id::text like '46000000-%'
  or target_id in (select id from public.groups where slug in ('concurrent-review','concurrent-domain'));
delete from public.activity_events where actor_user_id::text like '46000000-%'
  or group_id in (select id from public.groups where slug in ('concurrent-review','concurrent-domain'));
delete from private.analytics_events where user_id::text like '46000000-%'
  or entity_id in (select id from public.groups where slug in ('concurrent-review','concurrent-domain'));
delete from private.admin_audit_logs where actor_user_id::text like '46000000-%'
  or target_id in (select id from public.groups where slug in ('concurrent-review','concurrent-domain'));
delete from public.groups where slug in ('concurrent-review','concurrent-domain');
delete from auth.users where id::text like '46000000-%';

select plan(49);

insert into auth.users(id,email) values
 ('46000000-0000-4000-8000-000000000001','race-owner@example.test'),
 ('46000000-0000-4000-8000-000000000002','race-reviewer@example.test'),
 ('46000000-0000-4000-8000-000000000003','race-manager@example.test'),
 ('46000000-0000-4000-8000-000000000004','race-member@example.test'),
 ('46000000-0000-4000-8000-000000000005','race-target@example.test'),
 ('46000000-0000-4000-8000-000000000006','race-suspended@example.test'),
 ('46000000-0000-4000-8000-000000000007','race-block-target@example.test'),
 ('46000000-0000-4000-8000-000000000008','race-promotion-target@example.test');
update public.profiles set username='race_owner',full_name='Race Owner',city_id='10000000-0000-4000-8000-000000000001',running_level='advanced',preferred_distance='flexible',onboarding_completed=true where id='46000000-0000-4000-8000-000000000001';
update public.profiles set username='race_reviewer',full_name='Race Reviewer',city_id='10000000-0000-4000-8000-000000000001',running_level='advanced',preferred_distance='flexible',onboarding_completed=true where id='46000000-0000-4000-8000-000000000002';
update public.profiles set username='race_manager',full_name='Race Manager',city_id='10000000-0000-4000-8000-000000000001',running_level='intermediate',preferred_distance='5k_to_10k',onboarding_completed=true where id='46000000-0000-4000-8000-000000000003';
update public.profiles set username='race_member',full_name='Race Member',city_id='10000000-0000-4000-8000-000000000001',running_level='beginner',preferred_distance='up_to_5k',onboarding_completed=true where id='46000000-0000-4000-8000-000000000004';
update public.profiles set username='race_target',full_name='Race Target',city_id='10000000-0000-4000-8000-000000000001',running_level='intermediate',preferred_distance='5k_to_10k',onboarding_completed=true where id='46000000-0000-4000-8000-000000000005';
update public.profiles set username='race_suspended',full_name='Race Suspended',city_id='10000000-0000-4000-8000-000000000001',running_level='beginner',preferred_distance='up_to_5k',onboarding_completed=true where id='46000000-0000-4000-8000-000000000006';
update public.profiles set username='race_block_target',full_name='Race Block Target',city_id='10000000-0000-4000-8000-000000000001',running_level='beginner',preferred_distance='up_to_5k',onboarding_completed=true where id='46000000-0000-4000-8000-000000000007';
update public.profiles set username='race_promotion_target',full_name='Race Promotion Target',city_id='10000000-0000-4000-8000-000000000001',running_level='intermediate',preferred_distance='5k_to_10k',onboarding_completed=true where id='46000000-0000-4000-8000-000000000008';
update private.account_controls set status='suspended' where user_id='46000000-0000-4000-8000-000000000006';
insert into private.platform_roles(user_id,role) values ('46000000-0000-4000-8000-000000000002','platform_admin');

set role authenticated;
set request.jwt.claims='{"sub":"46000000-0000-4000-8000-000000000001","role":"authenticated"}';
select public.request_group('Concurrent Review','concurrent-review','Concurrent approval','10000000-0000-4000-8000-000000000001','community','open');
select public.request_group('Concurrent Domain','concurrent-domain','Concurrent domain','10000000-0000-4000-8000-000000000001','community','open');
reset role;

select is(extensions.dblink_connect('gate4_a','dbname=postgres user=postgres password=postgres host=host.docker.internal port=54322'),'OK','first independent session connects');
select is(extensions.dblink_connect('gate4_b','dbname=postgres user=postgres password=postgres host=host.docker.internal port=54322'),'OK','second independent session connects');
select is(extensions.dblink_exec('gate4_a','set role authenticated'),'SET','session A assumes authenticated');
select is(extensions.dblink_exec('gate4_b','set role authenticated'),'SET','session B assumes authenticated');
select is(extensions.dblink_exec('gate4_a',$$set request.jwt.claims='{"sub":"46000000-0000-4000-8000-000000000002","role":"authenticated"}'$$),'SET','session A gets reviewer identity');
select is(extensions.dblink_exec('gate4_b',$$set request.jwt.claims='{"sub":"46000000-0000-4000-8000-000000000002","role":"authenticated"}'$$),'SET','session B gets reviewer identity');

select is(extensions.dblink_send_query('gate4_a',format('select public.approve_group_request(%L::uuid)::text',(select id from public.groups where slug='concurrent-review'))),1,'approval A dispatched asynchronously');
select is(extensions.dblink_send_query('gate4_b',format('select public.approve_group_request(%L::uuid)::text',(select id from public.groups where slug='concurrent-review'))),1,'approval B dispatched asynchronously');
select lives_ok($$select * from extensions.dblink_get_result('gate4_a',false) as t(result text)$$,'approval A completes');
select lives_ok($$select * from extensions.dblink_get_result('gate4_b',false) as t(result text)$$,'approval B resolves after lock');
select * from extensions.dblink_get_result('gate4_a',false) as t(result text);
select * from extensions.dblink_get_result('gate4_b',false) as t(result text);
select is((select status from public.groups where slug='concurrent-review'),'approved','concurrent approval has one final approved state');
select is((select count(*) from private.admin_audit_logs a join public.groups g on g.id=a.target_id where g.slug='concurrent-review' and a.action='group_approved'),1::bigint,'concurrent approval writes one audit row');
select is((select count(*) from public.notifications n join public.groups g on g.id=n.target_id where g.slug='concurrent-review' and n.type='group_approved'),1::bigint,'concurrent approval writes one notification');

set role authenticated;
set request.jwt.claims='{"sub":"46000000-0000-4000-8000-000000000002","role":"authenticated"}';
select public.approve_group_request((select id from public.groups where slug='concurrent-domain'));
reset role;
set role authenticated;
set request.jwt.claims='{"sub":"46000000-0000-4000-8000-000000000003","role":"authenticated"}';
select public.join_group((select id from public.groups where slug='concurrent-domain'));
reset role;
set role authenticated;
set request.jwt.claims='{"sub":"46000000-0000-4000-8000-000000000004","role":"authenticated"}';
select public.join_group((select id from public.groups where slug='concurrent-domain'));
reset role;
set role authenticated;
set request.jwt.claims='{"sub":"46000000-0000-4000-8000-000000000005","role":"authenticated"}';
select public.join_group((select id from public.groups where slug='concurrent-domain'));
reset role;
set role authenticated;
set request.jwt.claims='{"sub":"46000000-0000-4000-8000-000000000008","role":"authenticated"}';
select public.join_group((select id from public.groups where slug='concurrent-domain'));
reset role;
set role authenticated;
set request.jwt.claims='{"sub":"46000000-0000-4000-8000-000000000001","role":"authenticated"}';
select public.promote_group_admin((select id from public.groups where slug='concurrent-domain'),'46000000-0000-4000-8000-000000000003');
select public.initiate_group_owner_transfer((select id from public.groups where slug='concurrent-domain'),'46000000-0000-4000-8000-000000000005');
reset role;

select is(extensions.dblink_exec('gate4_a',$$set request.jwt.claims='{"sub":"46000000-0000-4000-8000-000000000005","role":"authenticated"}'$$),'SET','session A becomes transfer target');
select is(extensions.dblink_exec('gate4_b',$$set request.jwt.claims='{"sub":"46000000-0000-4000-8000-000000000005","role":"authenticated"}'$$),'SET','session B becomes transfer target');
select is(extensions.dblink_send_query('gate4_a',format('select public.accept_group_owner_transfer(%L::uuid)::text',(select id from private.group_owner_transfers where status='pending'))),1,'accept A dispatched');
select is(extensions.dblink_send_query('gate4_b',format('select public.accept_group_owner_transfer(%L::uuid)::text',(select id from private.group_owner_transfers where status='pending'))),1,'accept B dispatched');
select lives_ok($$select * from extensions.dblink_get_result('gate4_a',false) as t(result text)$$,'accept A completes');
select lives_ok($$select * from extensions.dblink_get_result('gate4_b',false) as t(result text)$$,'accept B resolves after lock');
select * from extensions.dblink_get_result('gate4_a',false) as t(result text);
select * from extensions.dblink_get_result('gate4_b',false) as t(result text);
select is((select count(*) from public.group_members gm join public.groups g on g.id=gm.group_id where g.slug='concurrent-domain' and gm.role='owner' and gm.status='active'),1::bigint,'concurrent accepts preserve exactly one owner');
select is((select owner_user_id from public.groups where slug='concurrent-domain'),'46000000-0000-4000-8000-000000000005'::uuid,'accepted target is final owner');

select is(extensions.dblink_exec('gate4_a',$$set request.jwt.claims='{"sub":"46000000-0000-4000-8000-000000000005","role":"authenticated"}'$$),'SET','session A becomes current owner for promotion');
select is(extensions.dblink_exec('gate4_b',$$set request.jwt.claims='{"sub":"46000000-0000-4000-8000-000000000005","role":"authenticated"}'$$),'SET','session B becomes current owner for promotion');
select is(extensions.dblink_send_query('gate4_a',format('select public.promote_group_admin(%L::uuid,%L::uuid)::text',(select id from public.groups where slug='concurrent-domain'),'46000000-0000-4000-8000-000000000008')),1,'promotion A dispatched');
select is(extensions.dblink_send_query('gate4_b',format('select public.promote_group_admin(%L::uuid,%L::uuid)::text',(select id from public.groups where slug='concurrent-domain'),'46000000-0000-4000-8000-000000000008')),1,'promotion B dispatched');
select lives_ok($$select * from extensions.dblink_get_result('gate4_a',false) as t(result text)$$,'promotion A completes');
select lives_ok($$select * from extensions.dblink_get_result('gate4_b',false) as t(result text)$$,'promotion B resolves after lock');
select * from extensions.dblink_get_result('gate4_a',false) as t(result text);
select * from extensions.dblink_get_result('gate4_b',false) as t(result text);
select is((select count(*) from public.group_members gm join public.groups g on g.id=gm.group_id where g.slug='concurrent-domain' and gm.user_id='46000000-0000-4000-8000-000000000008' and gm.role='admin' and gm.status='active'),1::bigint,'concurrent promotion leaves one active admin membership');

update public.groups set join_policy='approval_required' where slug='concurrent-domain';
set role authenticated;
set request.jwt.claims='{"sub":"46000000-0000-4000-8000-000000000007","role":"authenticated"}';
select public.join_group((select id from public.groups where slug='concurrent-domain'));
reset role;
select is(extensions.dblink_exec('gate4_a',$$set request.jwt.claims='{"sub":"46000000-0000-4000-8000-000000000005","role":"authenticated"}'$$),'SET','session A becomes owner for member decision');
select is(extensions.dblink_exec('gate4_b',$$set request.jwt.claims='{"sub":"46000000-0000-4000-8000-000000000003","role":"authenticated"}'$$),'SET','session B becomes admin for member decision');
select is(extensions.dblink_send_query('gate4_a',format('select public.approve_group_member(%L::uuid,%L::uuid)::text',(select id from public.groups where slug='concurrent-domain'),'46000000-0000-4000-8000-000000000007')),1,'member approval dispatched');
select is(extensions.dblink_send_query('gate4_b',format('select public.block_group_member(%L::uuid,%L::uuid)::text',(select id from public.groups where slug='concurrent-domain'),'46000000-0000-4000-8000-000000000007')),1,'member block dispatched');
select lives_ok($$select * from extensions.dblink_get_result('gate4_a',false) as t(result text)$$,'member approval completes or observes changed state');
select lives_ok($$select * from extensions.dblink_get_result('gate4_b',false) as t(result text)$$,'member block completes after lock');
select * from extensions.dblink_get_result('gate4_a',false) as t(result text);
select * from extensions.dblink_get_result('gate4_b',false) as t(result text);
select is((select gm.status from public.group_members gm join public.groups g on g.id=gm.group_id where g.slug='concurrent-domain' and gm.user_id='46000000-0000-4000-8000-000000000007'),'blocked','approve-versus-block finishes blocked');
select cmp_ok((select count(*) from public.notifications n join public.groups g on g.id=n.target_id where g.slug='concurrent-domain' and n.recipient_user_id='46000000-0000-4000-8000-000000000007' and n.type='group_membership_approved'),'<=',1::bigint,'approve-versus-block never duplicates approval notification');

select is(extensions.dblink_exec('gate4_a',$$set request.jwt.claims='{"sub":"46000000-0000-4000-8000-000000000003","role":"authenticated"}'$$),'SET','session A becomes manager follower');
select is(extensions.dblink_exec('gate4_b',$$set request.jwt.claims='{"sub":"46000000-0000-4000-8000-000000000003","role":"authenticated"}'$$),'SET','session B becomes manager follower');
select is(extensions.dblink_send_query('gate4_a',format('insert into public.group_follows(user_id,group_id) values (%L::uuid,%L::uuid) returning group_id::text','46000000-0000-4000-8000-000000000003',(select id from public.groups where slug='concurrent-domain'))),1,'follow A dispatched');
select is(extensions.dblink_send_query('gate4_b',format('insert into public.group_follows(user_id,group_id) values (%L::uuid,%L::uuid) returning group_id::text','46000000-0000-4000-8000-000000000003',(select id from public.groups where slug='concurrent-domain'))),1,'follow B dispatched');
select lives_ok($$select * from extensions.dblink_get_result('gate4_a',false) as t(result text)$$,'follow A completes');
select lives_ok($$select * from extensions.dblink_get_result('gate4_b',false) as t(result text)$$,'follow B resolves unique conflict');
select * from extensions.dblink_get_result('gate4_a',false) as t(result text);
select * from extensions.dblink_get_result('gate4_b',false) as t(result text);
select is((select count(*) from public.group_follows gf join public.groups g on g.id=gf.group_id where g.slug='concurrent-domain' and gf.user_id='46000000-0000-4000-8000-000000000003'),1::bigint,'concurrent duplicate follow leaves one row');
select is((select count(*) from private.analytics_events a join public.groups g on g.id=a.entity_id where g.slug='concurrent-domain' and a.event_name='group_followed' and a.user_id='46000000-0000-4000-8000-000000000003'),1::bigint,'concurrent duplicate follow leaves one event');

set role authenticated;
set request.jwt.claims='{"sub":"46000000-0000-4000-8000-000000000006","role":"authenticated"}';
select throws_ok($$select public.join_group((select id from public.groups where slug='concurrent-domain'))$$,'42501',null,'stale JWT of suspended account cannot join');
select throws_ok($$update public.groups set status='approved' where slug='concurrent-domain'$$,'42501',null,'client cannot mass assign group status');
select throws_ok($$update public.group_members set role='owner' where user_id='46000000-0000-4000-8000-000000000006'$$,'42501',null,'client cannot mass assign member role');
reset role;

select is(extensions.dblink_disconnect('gate4_a'),'OK','session A disconnects');
select is(extensions.dblink_disconnect('gate4_b'),'OK','session B disconnects');
select * from finish();

delete from public.notifications where recipient_user_id::text like '46000000-%'
  or target_id in (select id from public.groups where slug in ('concurrent-review','concurrent-domain'));
delete from public.activity_events where actor_user_id::text like '46000000-%'
  or group_id in (select id from public.groups where slug in ('concurrent-review','concurrent-domain'));
delete from private.analytics_events where user_id::text like '46000000-%'
  or entity_id in (select id from public.groups where slug in ('concurrent-review','concurrent-domain'));
delete from private.admin_audit_logs where actor_user_id::text like '46000000-%'
  or target_id in (select id from public.groups where slug in ('concurrent-review','concurrent-domain'));
delete from public.groups where slug in ('concurrent-review','concurrent-domain');
delete from auth.users where id::text like '46000000-%';

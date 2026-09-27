begin;
create extension if not exists pgtap with schema extensions;
select plan(27);

insert into auth.users(id,email) values
 ('44000000-0000-4000-8000-000000000001','transfer-owner@example.test'),
 ('44000000-0000-4000-8000-000000000002','transfer-member@example.test'),
 ('44000000-0000-4000-8000-000000000003','transfer-admin@example.test'),
 ('44000000-0000-4000-8000-000000000004','transfer-blocked@example.test'),
 ('44000000-0000-4000-8000-000000000005','transfer-reviewer@example.test'),
 ('44000000-0000-4000-8000-000000000006','transfer-outsider@example.test');
update public.profiles set username='transfer_owner',full_name='Transfer Owner',city_id='10000000-0000-4000-8000-000000000001',running_level='advanced',preferred_distance='flexible',onboarding_completed=true where id='44000000-0000-4000-8000-000000000001';
update public.profiles set username='transfer_member',full_name='Transfer Member',city_id='10000000-0000-4000-8000-000000000001',running_level='intermediate',preferred_distance='5k_to_10k',onboarding_completed=true where id='44000000-0000-4000-8000-000000000002';
update public.profiles set username='transfer_admin',full_name='Transfer Admin',city_id='10000000-0000-4000-8000-000000000001',running_level='advanced',preferred_distance='flexible',onboarding_completed=true where id='44000000-0000-4000-8000-000000000003';
update public.profiles set username='transfer_blocked',full_name='Transfer Blocked',city_id='10000000-0000-4000-8000-000000000001',running_level='beginner',preferred_distance='up_to_5k',onboarding_completed=true where id='44000000-0000-4000-8000-000000000004';
update public.profiles set username='transfer_reviewer',full_name='Transfer Reviewer',city_id='10000000-0000-4000-8000-000000000001',running_level='advanced',preferred_distance='flexible',onboarding_completed=true where id='44000000-0000-4000-8000-000000000005';
update public.profiles set username='transfer_outsider',full_name='Transfer Outsider',city_id='10000000-0000-4000-8000-000000000001',running_level='beginner',preferred_distance='up_to_5k',onboarding_completed=true where id='44000000-0000-4000-8000-000000000006';
insert into private.platform_roles(user_id,role) values ('44000000-0000-4000-8000-000000000005','platform_admin');
set local role authenticated;
set local request.jwt.claims='{"sub":"44000000-0000-4000-8000-000000000001","role":"authenticated"}';
select public.request_group('Transfer Group','transfer-group','Ownership tests','10000000-0000-4000-8000-000000000001','community','open');
reset role;
set local role authenticated;
set local request.jwt.claims='{"sub":"44000000-0000-4000-8000-000000000005","role":"authenticated"}';
select public.approve_group_request((select id from public.groups where slug='transfer-group'));
reset role;
set local role authenticated;
set local request.jwt.claims='{"sub":"44000000-0000-4000-8000-000000000002","role":"authenticated"}';
select public.join_group((select id from public.groups where slug='transfer-group'));
reset role;
set local role authenticated;
set local request.jwt.claims='{"sub":"44000000-0000-4000-8000-000000000003","role":"authenticated"}';
select public.join_group((select id from public.groups where slug='transfer-group'));
reset role;
set local role authenticated;
set local request.jwt.claims='{"sub":"44000000-0000-4000-8000-000000000004","role":"authenticated"}';
select public.join_group((select id from public.groups where slug='transfer-group'));
reset role;
set local role authenticated;
set local request.jwt.claims='{"sub":"44000000-0000-4000-8000-000000000001","role":"authenticated"}';
select public.promote_group_admin((select id from public.groups where slug='transfer-group'),'44000000-0000-4000-8000-000000000003');
select public.block_group_member((select id from public.groups where slug='transfer-group'),'44000000-0000-4000-8000-000000000004');
reset role;

select has_function('public','initiate_group_owner_transfer',array['uuid','uuid'],'initiate transfer RPC exists');
select has_function('public','cancel_group_owner_transfer',array['uuid'],'cancel transfer RPC exists');
select has_function('public','get_group_owner_transfer',array['uuid'],'read transfer RPC exists');
select has_function('public','accept_group_owner_transfer',array['uuid'],'accept transfer RPC exists');
select is((select count(*) from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname like '%group_owner_transfer%' and p.prosecdef and p.proconfig @> array['search_path=""']),4::bigint,'transfer RPCs are hardened definers');
select isnt(has_table_privilege('authenticated','private.group_owner_transfers','SELECT'),true,'private transfer table is not directly readable');

set local role authenticated;
set local request.jwt.claims='{"sub":"44000000-0000-4000-8000-000000000006","role":"authenticated"}';
select throws_ok($$select public.initiate_group_owner_transfer((select id from public.groups where slug='transfer-group'),'44000000-0000-4000-8000-000000000002')$$,'42501',null,'non-owner cannot initiate transfer');
reset role;

set local role authenticated;
set local request.jwt.claims='{"sub":"44000000-0000-4000-8000-000000000001","role":"authenticated"}';
select throws_ok($$select public.initiate_group_owner_transfer((select id from public.groups where slug='transfer-group'),'44000000-0000-4000-8000-000000000001')$$,'22023',null,'owner cannot transfer to self');
select throws_ok($$select public.initiate_group_owner_transfer((select id from public.groups where slug='transfer-group'),'44000000-0000-4000-8000-000000000004')$$,'42501',null,'blocked target is ineligible');
select lives_ok($$select public.initiate_group_owner_transfer((select id from public.groups where slug='transfer-group'),'44000000-0000-4000-8000-000000000002')$$,'owner initiates transfer to active member');
select is((select expires_at::date-created_at::date from public.get_group_owner_transfer((select id from public.groups where slug='transfer-group'))),7,'transfer expires after seven days');
select throws_ok($$select public.initiate_group_owner_transfer((select id from public.groups where slug='transfer-group'),'44000000-0000-4000-8000-000000000003')$$,'P0001','transfer_already_pending','second pending transfer is rejected');
reset role;
select set_config('test.transfer_id',(select id::text from private.group_owner_transfers where status='pending'),false);

set local role authenticated;
set local request.jwt.claims='{"sub":"44000000-0000-4000-8000-000000000006","role":"authenticated"}';
select is((select count(*) from public.get_group_owner_transfer((select id from public.groups where slug='transfer-group'))),0::bigint,'outsider cannot read transfer');
select throws_ok($$select public.accept_group_owner_transfer(current_setting('test.transfer_id')::uuid)$$,'42501',null,'only target can accept transfer');
reset role;

set local role authenticated;
set local request.jwt.claims='{"sub":"44000000-0000-4000-8000-000000000002","role":"authenticated"}';
select is((select effective_status from public.get_group_owner_transfer((select id from public.groups where slug='transfer-group'))),'pending','target can inspect pending transfer');
select lives_ok($$select public.accept_group_owner_transfer(current_setting('test.transfer_id')::uuid)$$,'target explicitly accepts transfer');
reset role;

select is((select owner_user_id from public.groups where slug='transfer-group'),'44000000-0000-4000-8000-000000000002'::uuid,'group owner_user_id changes to target');
select is((select role from public.group_members gm join public.groups g on g.id=gm.group_id where g.slug='transfer-group' and gm.user_id='44000000-0000-4000-8000-000000000002'),'owner','target becomes owner');
select is((select role from public.group_members gm join public.groups g on g.id=gm.group_id where g.slug='transfer-group' and gm.user_id='44000000-0000-4000-8000-000000000001'),'member','former owner becomes member');
select is((select count(*) from public.group_members gm join public.groups g on g.id=gm.group_id where g.slug='transfer-group' and gm.role='owner' and gm.status='active'),1::bigint,'transfer leaves exactly one active owner');
select is((select status from private.group_owner_transfers order by created_at desc limit 1),'accepted','transfer records accepted state');
select is((select count(*) from private.admin_audit_logs a join public.groups g on g.id=a.target_id where g.slug='transfer-group' and a.action='group_ownership_transferred'),1::bigint,'accepted transfer appends audit');

set local role authenticated;
set local request.jwt.claims='{"sub":"44000000-0000-4000-8000-000000000002","role":"authenticated"}';
select lives_ok($$select public.initiate_group_owner_transfer((select id from public.groups where slug='transfer-group'),'44000000-0000-4000-8000-000000000003')$$,'new owner can initiate later transfer');
reset role;
select set_config('test.transfer_id_2',(select id::text from private.group_owner_transfers where status='pending'),false);
set local role authenticated;
set local request.jwt.claims='{"sub":"44000000-0000-4000-8000-000000000002","role":"authenticated"}';
select lives_ok($$select public.cancel_group_owner_transfer(current_setting('test.transfer_id_2')::uuid)$$,'current owner can cancel transfer');
reset role;
select is((select status from private.group_owner_transfers where id=current_setting('test.transfer_id_2')::uuid),'cancelled','cancellation preserves history');

set local role authenticated;
set local request.jwt.claims='{"sub":"44000000-0000-4000-8000-000000000002","role":"authenticated"}';
select public.initiate_group_owner_transfer((select id from public.groups where slug='transfer-group'),'44000000-0000-4000-8000-000000000003');
reset role;
update private.group_owner_transfers
set created_at=created_at-interval '8 days', expires_at=created_at-interval '1 second'
where status='pending';
select set_config('test.transfer_id_3',(select id::text from private.group_owner_transfers where status='pending'),false);
set local role authenticated;
set local request.jwt.claims='{"sub":"44000000-0000-4000-8000-000000000003","role":"authenticated"}';
select throws_ok($$select public.accept_group_owner_transfer(current_setting('test.transfer_id_3')::uuid)$$,'P0001','transfer_expired','expired transfer cannot be accepted');
reset role;
select is((select owner_user_id from public.groups where slug='transfer-group'),'44000000-0000-4000-8000-000000000002'::uuid,'expired acceptance leaves owner unchanged');

select * from finish();
rollback;

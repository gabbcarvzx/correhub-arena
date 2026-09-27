begin;
create extension if not exists pgtap with schema extensions;
select plan(41);

insert into auth.users(id,email) values
 ('42000000-0000-4000-8000-000000000001','review-owner@example.test'),
 ('42000000-0000-4000-8000-000000000002','review-admin@example.test'),
 ('42000000-0000-4000-8000-000000000003','review-self-admin@example.test'),
 ('42000000-0000-4000-8000-000000000004','review-moderator@example.test'),
 ('42000000-0000-4000-8000-000000000005','review-runner@example.test');

update public.profiles set username='review_owner',full_name='Review Owner',city_id='10000000-0000-4000-8000-000000000001',running_level='beginner',preferred_distance='up_to_5k',onboarding_completed=true where id='42000000-0000-4000-8000-000000000001';
update public.profiles set username='review_admin',full_name='Review Admin',city_id='10000000-0000-4000-8000-000000000001',running_level='advanced',preferred_distance='flexible',onboarding_completed=true where id='42000000-0000-4000-8000-000000000002';
update public.profiles set username='review_self_admin',full_name='Self Admin',city_id='10000000-0000-4000-8000-000000000001',running_level='intermediate',preferred_distance='5k_to_10k',onboarding_completed=true where id='42000000-0000-4000-8000-000000000003';
update public.profiles set username='review_moderator',full_name='Review Moderator',city_id='10000000-0000-4000-8000-000000000001',running_level='advanced',preferred_distance='flexible',onboarding_completed=true where id='42000000-0000-4000-8000-000000000004';
update public.profiles set username='review_runner',full_name='Review Runner',city_id='10000000-0000-4000-8000-000000000001',running_level='beginner',preferred_distance='up_to_5k',onboarding_completed=true where id='42000000-0000-4000-8000-000000000005';
insert into private.platform_roles(user_id,role) values
 ('42000000-0000-4000-8000-000000000002','platform_admin'),
 ('42000000-0000-4000-8000-000000000003','platform_admin'),
 ('42000000-0000-4000-8000-000000000004','moderator');

set local role authenticated;
set local request.jwt.claims='{"sub":"42000000-0000-4000-8000-000000000001","role":"authenticated"}';
select public.request_group('Approve Me','approve-me','Group to approve','10000000-0000-4000-8000-000000000001','community','open');
select public.request_group('Reject Me','reject-me','Group to reject','10000000-0000-4000-8000-000000000001','professional','approval_required');
reset role;
set local role authenticated;
set local request.jwt.claims='{"sub":"42000000-0000-4000-8000-000000000003","role":"authenticated"}';
select public.request_group('Self Review','self-review','Must need another admin','10000000-0000-4000-8000-000000000001','community','open');
reset role;

select has_function('public','list_group_review_queue',array['timestamp with time zone','uuid','integer'],'review queue RPC exists');
select has_function('public','current_user_can_review_groups',array[]::text[],'review authorization RPC exists');
select has_function('public','get_group_review',array['uuid'],'review detail RPC exists');
select has_function('public','approve_group_request',array['uuid'],'approve RPC exists');
select has_function('public','reject_group_request',array['uuid','text'],'reject RPC exists');
select has_function('public','suspend_group',array['uuid','text'],'suspend RPC exists');
select has_function('public','restore_group',array['uuid','text'],'restore RPC exists');
select is((select count(*) from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ('list_group_review_queue','get_group_review','approve_group_request','reject_group_request','suspend_group','restore_group') and p.prosecdef and p.proconfig @> array['search_path=""']),6::bigint,'review functions are hardened definers');
select is((select count(*) from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ('list_group_review_queue','get_group_review','approve_group_request','reject_group_request','suspend_group','restore_group') and has_function_privilege('anon',p.oid,'EXECUTE')),0::bigint,'anon cannot execute review functions');

set local role authenticated;
set local request.jwt.claims='{"sub":"42000000-0000-4000-8000-000000000005","role":"authenticated"}';
select is(public.current_user_can_review_groups(),false,'ordinary runner cannot open review workspace');
select throws_ok($$select public.approve_group_request((select id from public.groups where slug='approve-me'))$$,'42501',null,'ordinary runner cannot approve');
select is((select count(*) from public.list_group_review_queue(null,null,20)),0::bigint,'ordinary runner cannot enumerate review queue');
reset role;

set local role authenticated;
set local request.jwt.claims='{"sub":"42000000-0000-4000-8000-000000000004","role":"authenticated"}';
select is(public.current_user_can_review_groups(),false,'moderator cannot open review workspace');
select throws_ok($$select public.approve_group_request((select id from public.groups where slug='approve-me'))$$,'42501',null,'moderator cannot approve');
reset role;

set local role authenticated;
set local request.jwt.claims='{"sub":"42000000-0000-4000-8000-000000000003","role":"authenticated"}';
select throws_ok($$select public.approve_group_request((select id from public.groups where slug='self-review'))$$,'42501','self_approval_forbidden','platform admin cannot approve own request');
reset role;

set local role authenticated;
set local request.jwt.claims='{"sub":"42000000-0000-4000-8000-000000000002","role":"authenticated"}';
select is(public.current_user_can_review_groups(),true,'platform admin can open review workspace');
select is((select count(*) from public.list_group_review_queue(null,null,20)),3::bigint,'independent platform admin sees pending queue');
select is((select status from public.get_group_review((select id from public.groups where slug='approve-me'))),'pending','review detail returns pending request');
select lives_ok($$select public.approve_group_request((select id from public.groups where slug='approve-me'))$$,'independent platform admin approves');
reset role;

select is((select status from public.groups where slug='approve-me'),'approved','approval changes group status');
select is((select approved_by from public.groups where slug='approve-me'),'42000000-0000-4000-8000-000000000002'::uuid,'approval records reviewer');
select ok((select approved_at is not null from public.groups where slug='approve-me'),'approval records timestamp');
select is((select gm.status from public.group_members gm join public.groups g on g.id=gm.group_id where g.slug='approve-me' and gm.role='owner'),'active','approval activates owner membership');
select is((select count(*) from public.group_members gm join public.groups g on g.id=gm.group_id where g.slug='approve-me' and gm.role='owner' and gm.status='active'),1::bigint,'approved group has exactly one active owner');
select is((select count(*) from private.admin_audit_logs a join public.groups g on g.id=a.target_id where g.slug='approve-me' and a.action='group_approved'),1::bigint,'approval appends one audit row');
select is((select count(*) from public.notifications n join public.groups g on g.id=n.target_id where g.slug='approve-me' and n.type='group_approved'),1::bigint,'approval persists one deduplicated notification');
select is((select count(*) from private.analytics_events a join public.groups g on g.id=a.entity_id where g.slug='approve-me' and a.event_name='group_approved'),1::bigint,'approval persists analytics fact');

set local role authenticated;
set local request.jwt.claims='{"sub":"42000000-0000-4000-8000-000000000002","role":"authenticated"}';
select throws_ok($$select public.approve_group_request((select id from public.groups where slug='approve-me'))$$,'P0001','state_changed','repeated approval reports state change without duplicate effects');
select lives_ok($$select public.reject_group_request((select id from public.groups where slug='reject-me'),'Dados insuficientes para análise')$$,'independent platform admin rejects with reason');
reset role;
select is((select status from public.groups where slug='reject-me'),'rejected','rejection preserves group in rejected state');
select is((select rejection_reason from public.groups where slug='reject-me'),'Dados insuficientes para análise','rejection reason is stored privately');
select is((select count(*) from public.get_group_by_slug('reject-me')),0::bigint,'rejected group stays out of anonymous common projection');

insert into public.run_series(id,group_id,city_id,title,description,weekday,local_start_time,timezone,starts_on,location_text,distance_meters,level,visibility,status)
select '42000000-0000-4000-8000-000000000100',g.id,g.city_id,'Série futura','Treinos do grupo',1,'06:00','America/Recife',current_date,'Praça Central',5000,'all_levels','public','active' from public.groups g where g.slug='approve-me';
insert into public.runs(id,group_id,city_id,title,description,starts_at,location_text,distance_meters,level,visibility,status)
select '42000000-0000-4000-8000-000000000101',g.id,g.city_id,'Corrida futura','Treino futuro',pg_catalog.now()+interval '3 days','Praça Central',5000,'all_levels','public','scheduled' from public.groups g where g.slug='approve-me';

set local role authenticated;
set local request.jwt.claims='{"sub":"42000000-0000-4000-8000-000000000004","role":"authenticated"}';
select lives_ok($$select public.suspend_group((select id from public.groups where slug='approve-me'),'Revisão de segurança')$$,'moderator can suspend approved group');
reset role;
select is((select status from public.groups where slug='approve-me'),'suspended','suspension changes group status');
select is((select status from public.run_series where id='42000000-0000-4000-8000-000000000100'),'paused','suspension pauses active series without deleting it');
select is((select status from public.runs where id='42000000-0000-4000-8000-000000000101'),'cancelled','suspension cancels future scheduled run');

set local role authenticated;
set local request.jwt.claims='{"sub":"42000000-0000-4000-8000-000000000004","role":"authenticated"}';
select throws_ok($$select public.restore_group((select id from public.groups where slug='approve-me'),'Resolved')$$,'42501',null,'moderator cannot restore group');
reset role;
set local role authenticated;
set local request.jwt.claims='{"sub":"42000000-0000-4000-8000-000000000002","role":"authenticated"}';
select lives_ok($$select public.restore_group((select id from public.groups where slug='approve-me'),'Resolved')$$,'platform admin restores group');
reset role;
select is((select status from public.groups where slug='approve-me'),'approved','restoration reopens group');
select is((select status from public.run_series where id='42000000-0000-4000-8000-000000000100'),'paused','restoration does not reactivate series');
select is((select status from public.runs where id='42000000-0000-4000-8000-000000000101'),'cancelled','restoration does not reopen cancelled run');

select * from finish();
rollback;

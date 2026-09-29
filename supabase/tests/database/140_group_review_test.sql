begin;
create extension if not exists pgtap with schema extensions;
select plan(98);

insert into auth.users (id, email) values
  ('42000000-0000-4000-8000-000000000001', 'review-owner@example.test'),
  ('42000000-0000-4000-8000-000000000002', 'independent-admin@example.test'),
  ('42000000-0000-4000-8000-000000000003', 'group-moderator@example.test'),
  ('42000000-0000-4000-8000-000000000004', 'ordinary-reviewer@example.test'),
  ('42000000-0000-4000-8000-000000000005', 'admin-owner@example.test'),
  ('42000000-0000-4000-8000-000000000006', 'suspended-admin@example.test');

update public.profiles set
  username = 'review_owner_420', full_name = 'Review Owner',
  city_id = '10000000-0000-4000-8000-000000000001',
  running_level = 'beginner', preferred_distance = 'up_to_5k', onboarding_completed = true
where id = '42000000-0000-4000-8000-000000000001';
update public.profiles set
  username = 'independent_admin_420', full_name = 'Independent Admin',
  city_id = '10000000-0000-4000-8000-000000000001',
  running_level = 'intermediate', preferred_distance = '5k_to_10k', onboarding_completed = false
where id = '42000000-0000-4000-8000-000000000002';
update public.profiles set
  username = 'moderator_420', full_name = 'Group Moderator',
  city_id = '10000000-0000-4000-8000-000000000001',
  running_level = 'intermediate', preferred_distance = '5k_to_10k', onboarding_completed = false
where id = '42000000-0000-4000-8000-000000000003';
update public.profiles set
  username = 'ordinary_review_420', full_name = 'Ordinary Reviewer',
  city_id = '10000000-0000-4000-8000-000000000001',
  running_level = 'beginner', preferred_distance = 'up_to_5k', onboarding_completed = true
where id = '42000000-0000-4000-8000-000000000004';
update public.profiles set
  username = 'admin_owner_420', full_name = 'Admin Owner',
  city_id = '10000000-0000-4000-8000-000000000001',
  running_level = 'beginner', preferred_distance = 'up_to_5k', onboarding_completed = true
where id = '42000000-0000-4000-8000-000000000005';
update public.profiles set
  username = 'suspended_admin_420', full_name = 'Suspended Admin',
  city_id = '10000000-0000-4000-8000-000000000001',
  running_level = 'beginner', preferred_distance = 'up_to_5k', onboarding_completed = true
where id = '42000000-0000-4000-8000-000000000006';

insert into private.platform_roles(user_id, role) values
  ('42000000-0000-4000-8000-000000000002', 'platform_admin'),
  ('42000000-0000-4000-8000-000000000003', 'moderator'),
  ('42000000-0000-4000-8000-000000000005', 'platform_admin'),
  ('42000000-0000-4000-8000-000000000006', 'platform_admin');
update private.account_controls set status = 'suspended'
where user_id = '42000000-0000-4000-8000-000000000006';

set local role authenticated;
set local request.jwt.claims = '{"sub":"42000000-0000-4000-8000-000000000001","role":"authenticated"}';
select lives_ok($$select public.request_group('Approval Example', 'approval-example', 'Approval fixture', '10000000-0000-4000-8000-000000000001', 'community', 'open')$$,
  'owner creates a pending request for independent approval');
select lives_ok($$select public.request_group('Rejection Example', 'rejection-example', 'Rejection fixture', '10000000-0000-4000-8000-000000000001', 'community', 'open')$$,
  'owner creates a pending request for rejection');
select lives_ok($$select public.request_group('Suspension Example', 'suspension-example', 'Suspension fixture', '10000000-0000-4000-8000-000000000001', 'community', 'open')$$,
  'owner creates a pending request for suspension effects');
select lives_ok($$select public.request_group('Rollback Example', 'rollback-example', 'Rollback fixture', '10000000-0000-4000-8000-000000000001', 'community', 'open')$$,
  'owner creates a pending request for forced rollback');
reset role;
set local role authenticated;
set local request.jwt.claims = '{"sub":"42000000-0000-4000-8000-000000000005","role":"authenticated"}';
select lives_ok($$select public.request_group('Admin Own Group', 'admin-own-group', 'Self review fixture', '10000000-0000-4000-8000-000000000001', 'community', 'open')$$,
  'platform admin can create a request as a runner');
reset role;

select ok(not has_table_privilege('authenticated', 'private.admin_audit_logs', 'INSERT')
    and not has_table_privilege('authenticated', 'private.admin_audit_logs', 'UPDATE')
    and not has_table_privilege('authenticated', 'private.admin_audit_logs', 'DELETE'),
  'API roles cannot insert, update, or delete audit rows');
select has_function('public', 'list_group_review_queue', array['timestamptz','uuid','integer'], 'admin review queue RPC exists');
select has_function('public', 'get_group_review', array['uuid'], 'admin review detail RPC exists');
select has_function('public', 'approve_group_request', array['uuid'], 'approval RPC exists');
select has_function('public', 'reject_group_request', array['uuid','text'], 'rejection RPC exists');
select has_function('public', 'suspend_group', array['uuid','text'], 'suspension RPC exists');
select has_function('public', 'restore_group', array['uuid','text'], 'restoration RPC exists');
select is((select count(*) from pg_catalog.pg_proc p
  join pg_catalog.pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname in ('list_group_review_queue','get_group_review','approve_group_request','reject_group_request','suspend_group','restore_group')
    and p.prosecdef and p.proconfig @> array['search_path=""']),
  6::bigint, 'all six review RPCs are SECURITY DEFINER with an empty search_path');
select is((select count(*) from pg_catalog.pg_proc p
  join pg_catalog.pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname in ('list_group_review_queue','get_group_review','approve_group_request','reject_group_request','suspend_group','restore_group')
    and pg_catalog.pg_get_userbyid(p.proowner) = 'postgres'),
  6::bigint, 'all six review RPCs are owned by postgres');
select is((select count(*) from information_schema.routine_privileges
  where specific_schema = 'public'
    and routine_name in ('list_group_review_queue','get_group_review','approve_group_request','reject_group_request','suspend_group','restore_group')
    and grantee = 'PUBLIC'),
  0::bigint, 'PUBLIC cannot execute review RPCs');
select is((select count(*) from information_schema.routine_privileges
  where specific_schema = 'public'
    and routine_name in ('list_group_review_queue','get_group_review','approve_group_request','reject_group_request','suspend_group','restore_group')
    and grantee = 'anon'),
  0::bigint, 'anon cannot execute review RPCs');
select is((select count(*) from information_schema.routine_privileges
  where specific_schema = 'public'
    and routine_name in ('list_group_review_queue','get_group_review','approve_group_request','reject_group_request','suspend_group','restore_group')
    and grantee = 'authenticated'),
  6::bigint, 'authenticated RPC access is explicit and limited to the six reviewed functions');
select is((select count(*) from pg_catalog.pg_proc p
  join pg_catalog.pg_namespace n on n.oid = p.pronamespace
  cross join lateral pg_catalog.regexp_matches(pg_catalog.lower(pg_catalog.pg_get_functiondef(p.oid)), 'for update', 'g') as lock_clause
  where n.nspname = 'public' and p.proname in ('approve_group_request','reject_group_request')),
  4::bigint, 'approve and reject lock both the group and its owner row');
select is((select p.proargnames from pg_catalog.pg_proc p
  join pg_catalog.pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'approve_group_request'),
  array['target_group_id']::text[], 'approval derives its actor from auth.uid()');
select is((select p.proargnames from pg_catalog.pg_proc p
  join pg_catalog.pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'reject_group_request'),
  array['target_group_id','requested_reason']::text[], 'rejection has no caller-supplied actor');
select is((select p.proargnames from pg_catalog.pg_proc p
  join pg_catalog.pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'suspend_group'),
  array['target_group_id','requested_reason']::text[], 'suspension has no caller-supplied actor');
select is((select p.proargnames from pg_catalog.pg_proc p
  join pg_catalog.pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'restore_group'),
  array['target_group_id','requested_reason']::text[], 'restoration has no caller-supplied actor');

set local role authenticated;
set local request.jwt.claims = '{"sub":"42000000-0000-4000-8000-000000000002","role":"authenticated"}';
select is((select count(*) from public.list_group_review_queue(null, null, 20)), 5::bigint,
  'active platform admin can read all pending review items without runner onboarding');
select is((select group_status from public.get_group_review((select id from public.groups where slug='approval-example'))), 'pending',
  'independent platform admin can inspect a pending group');
select is((select count(*) from public.list_group_review_queue(null, null, 2)), 2::bigint,
  'review queue clamps and honors its page size');
select is((select count(*) from public.list_group_review_queue(pg_catalog.now(), null, 20)), 0::bigint,
  'review queue rejects a partial cursor without widening results');
reset role;

set local role authenticated;
set local request.jwt.claims = '{"sub":"42000000-0000-4000-8000-000000000004","role":"authenticated"}';
select throws_ok($$select * from public.list_group_review_queue(null, null, 20)$$,
  '42501', 'platform admin required', 'ordinary runner cannot read the review queue');
select throws_ok($$select * from public.get_group_review((select id from public.groups where slug='approval-example'))$$,
  '42501', 'platform admin required', 'ordinary runner cannot read review details');
select throws_ok($$select public.approve_group_request((select id from public.groups where slug='approval-example'))$$,
  '42501', 'platform admin required', 'ordinary runner cannot approve a request');
select throws_ok($$select public.reject_group_request((select id from public.groups where slug='rejection-example'), 'Please revise')$$,
  '42501', 'platform admin required', 'ordinary runner cannot reject a request');
select throws_ok($$select public.suspend_group((select id from public.groups where slug='suspension-example'), 'Safety review')$$,
  '42501', 'moderator or platform admin required', 'ordinary runner cannot suspend a group');
select throws_ok($$select public.restore_group((select id from public.groups where slug='suspension-example'), 'Review complete')$$,
  '42501', 'platform admin required', 'ordinary runner cannot restore a group');
reset role;

set local role authenticated;
set local request.jwt.claims = '{"sub":"42000000-0000-4000-8000-000000000003","role":"authenticated"}';
select throws_ok($$select * from public.list_group_review_queue(null, null, 20)$$,
  '42501', 'platform admin required', 'moderator cannot read the platform review queue');
select throws_ok($$select * from public.get_group_review((select id from public.groups where slug='approval-example'))$$,
  '42501', 'platform admin required', 'moderator cannot read platform review details');
select throws_ok($$select public.approve_group_request((select id from public.groups where slug='approval-example'))$$,
  '42501', 'platform admin required', 'moderator cannot approve a request');
select throws_ok($$select public.reject_group_request((select id from public.groups where slug='rejection-example'), 'Please revise')$$,
  '42501', 'platform admin required', 'moderator cannot reject a request');
reset role;

set local role authenticated;
set local request.jwt.claims = '{"sub":"42000000-0000-4000-8000-000000000006","role":"authenticated"}';
select throws_ok($$select * from public.list_group_review_queue(null, null, 20)$$,
  '42501', 'platform admin required', 'suspended platform admin cannot read the review queue');
select throws_ok($$select public.approve_group_request((select id from public.groups where slug='approval-example'))$$,
  '42501', 'platform admin required', 'suspended platform admin cannot approve a request');
reset role;

set local role authenticated;
set local request.jwt.claims = '{"sub":"42000000-0000-4000-8000-000000000005","role":"authenticated"}';
select is((select group_status from public.get_group_review((select id from public.groups where slug='admin-own-group'))), 'pending',
  'platform admin requester may inspect their own request');
select throws_ok($$select public.approve_group_request((select id from public.groups where slug='admin-own-group'))$$,
  '42501', 'independent platform admin required', 'platform admin cannot approve a request they created or own');
select throws_ok($$select public.reject_group_request((select id from public.groups where slug='admin-own-group'), 'Not independent')$$,
  '42501', 'independent platform admin required', 'platform admin cannot reject a request they created or own');
select is((select status from public.groups where slug='admin-own-group'), 'pending',
  'self-decision denial leaves the request pending');
reset role;

set local role authenticated;
set local request.jwt.claims = '{"sub":"42000000-0000-4000-8000-000000000002","role":"authenticated"}';
select throws_ok($$select public.reject_group_request((select id from public.groups where slug='approval-example'), '  ')$$,
  '22023', 'group reason is invalid', 'rejection rejects a blank reason');
select lives_ok($$select public.approve_group_request((select id from public.groups where slug='approval-example'))$$,
  'independent platform admin approves a pending request');
select throws_ok($$select public.approve_group_request((select id from public.groups where slug='approval-example'))$$,
  'P0001', 'group_state_changed', 'a repeated approval has a controlled state_changed result');
reset role;

select is((select status from public.groups where slug='approval-example'), 'approved',
  'approval changes the request to approved');
select is((select count(*) from public.groups g
  where g.slug='approval-example'
    and g.approved_by='42000000-0000-4000-8000-000000000002'
    and g.approved_at is not null and g.rejection_reason is null and g.suspended_at is null),
  1::bigint, 'approval records the independent reviewer and decision timestamp');
select is((select count(*) from public.group_members gm join public.groups g on g.id=gm.group_id
  where g.slug='approval-example' and gm.user_id='42000000-0000-4000-8000-000000000001'
    and gm.role='owner' and gm.status='active' and gm.joined_at is not null),
  1::bigint, 'approval activates the designated owner relation');
select is((select count(*) from public.group_members gm join public.groups g on g.id=gm.group_id
  where g.slug='approval-example' and gm.role='owner' and gm.status='active'),
  1::bigint, 'approved group has exactly one active owner');
select is((select count(*) from private.admin_audit_logs a join public.groups g on g.id=a.target_id
  where g.slug='approval-example' and a.actor_user_id='42000000-0000-4000-8000-000000000002'
    and a.action='group.request_approved' and a.target_type='group'),
  1::bigint, 'approval appends one audit record');
select is((select a.metadata from private.admin_audit_logs a join public.groups g on g.id=a.target_id
  where g.slug='approval-example' and a.action='group.request_approved'),
  '{"previous_status":"pending","new_status":"approved"}'::jsonb,
  'approval audit stores only minimal state metadata');
select is((select count(*) from public.notifications n join public.groups g on g.id=n.target_id
  where g.slug='approval-example' and n.recipient_user_id='42000000-0000-4000-8000-000000000001'
    and n.actor_user_id='42000000-0000-4000-8000-000000000002'
    and n.type='group_request_approved' and n.target_type='group'),
  1::bigint, 'approval creates one deduplicated owner notification');
select is((select count(*) from public.notifications n
  join public.groups g on g.id=n.target_id
  join private.admin_audit_logs a on a.target_id=g.id and a.action='group.request_approved'
  where g.slug='approval-example' and n.dedupe_key='group_request_approved:'||a.id::text),
  1::bigint, 'approval notification dedupe key includes the audit id');
select is((select count(*) from private.analytics_events e join public.groups g on g.id=e.entity_id
  where g.slug='approval-example' and e.event_name='group_approved'
    and e.user_id='42000000-0000-4000-8000-000000000002' and e.entity_type='group'),
  1::bigint, 'approval emits one group_approved analytics event');
select is((select count(*) from private.domain_event_receipts r join public.groups g on g.id=r.entity_id
  where g.slug='approval-example' and r.event_type='group_joined'
    and r.business_key='group:'||g.id::text||':42000000-0000-4000-8000-000000000001'),
  1::bigint, 'first owner activation creates one group_joined receipt');
select is((select count(*) from public.activity_events e join public.groups g on g.id=e.group_id
  where g.slug='approval-example' and e.event_type='group_joined'
    and e.actor_user_id='42000000-0000-4000-8000-000000000001'
    and e.entity_type='group' and e.entity_id=g.id),
  1::bigint, 'first owner activation creates one group_joined activity event');
select is((select count(*) from private.admin_audit_logs a join public.groups g on g.id=a.target_id
  where g.slug='approval-example' and a.action='group.request_approved'),
  1::bigint, 'repeated approval does not append duplicate audit');

set local role authenticated;
set local request.jwt.claims = '{"sub":"42000000-0000-4000-8000-000000000002","role":"authenticated"}';
select lives_ok($$select public.reject_group_request((select id from public.groups where slug='rejection-example'), 'Please clarify the weekly schedule.')$$,
  'independent platform admin rejects with a private reason');
select throws_ok($$select public.reject_group_request((select id from public.groups where slug='rejection-example'), 'Another reason')$$,
  'P0001', 'group_state_changed', 'a repeated rejection has a controlled state_changed result');
select is((select rejection_reason from public.get_group_review((select id from public.groups where slug='rejection-example'))),
  'Please clarify the weekly schedule.', 'admin review detail exposes the rejection reason');
reset role;

select is((select count(*) from public.groups where slug='rejection-example' and status='rejected'
  and rejection_reason='Please clarify the weekly schedule.' and approved_by is null and approved_at is null),
  1::bigint, 'rejection preserves the pending request and stores its private reason');
select is((select count(*) from public.group_members gm join public.groups g on g.id=gm.group_id
  where g.slug='rejection-example' and gm.role='owner' and gm.status='pending' and gm.joined_at is null),
  1::bigint, 'rejection keeps the designated owner pending');
select is((select count(*) from private.admin_audit_logs a join public.groups g on g.id=a.target_id
  where g.slug='rejection-example' and a.actor_user_id='42000000-0000-4000-8000-000000000002'
    and a.action='group.request_rejected'
    and a.metadata='{"previous_status":"pending","new_status":"rejected","reason":"Please clarify the weekly schedule."}'::jsonb),
  1::bigint, 'rejection audit records minimal state and no copied content');
select is((select count(*) from public.notifications n join public.groups g on g.id=n.target_id
  where g.slug='rejection-example' and n.recipient_user_id='42000000-0000-4000-8000-000000000001'
    and n.actor_user_id='42000000-0000-4000-8000-000000000002'
    and n.type='group_request_rejected' and n.target_type='group'),
  1::bigint, 'rejection creates one owner notification');
select is((select count(*) from public.notifications n
  join public.groups g on g.id=n.target_id
  join private.admin_audit_logs a on a.target_id=g.id and a.action='group.request_rejected'
  where g.slug='rejection-example' and n.dedupe_key='group_request_rejected:'||a.id::text),
  1::bigint, 'rejection notification dedupe key includes the audit id');
select is((select count(*) from private.admin_audit_logs a join public.groups g on g.id=a.target_id
  where g.slug='rejection-example' and a.action='group.request_rejected'),
  1::bigint, 'repeated rejection does not append a duplicate audit');

-- The fixture series and runs prove suspension effects without adding run-creation behavior.
select lives_ok($$select public.approve_group_request((select id from public.groups where slug='suspension-example'))$$,
  'independent admin approves the group before suspension fixtures');
insert into public.run_series (
  id, group_id, city_id, title, description, weekday, local_start_time, timezone,
  starts_on, location_text, distance_meters, level, visibility, status, created_by
) values (
  '43000000-0000-4000-8000-000000000001',
  (select id from public.groups where slug='suspension-example'),
  '10000000-0000-4000-8000-000000000001', 'Suspension Series', 'Series fixture',
  extract(isodow from current_date)::smallint, time '08:00', 'America/Recife',
  current_date, 'Parque da Jaqueira', 5000, 'beginner', 'public', 'active',
  '42000000-0000-4000-8000-000000000001'
);
insert into public.runs (
  id, group_id, city_id, title, description, starts_at, location_text, distance_meters,
  level, visibility, status, created_by
) values
  ('43000000-0000-4000-8000-000000000002',
    (select id from public.groups where slug='suspension-example'),
    '10000000-0000-4000-8000-000000000001', 'Future Scheduled Run', 'Future run fixture',
    pg_catalog.now() + interval '2 days', 'Parque da Jaqueira', 5000, 'beginner', 'public', 'scheduled',
    '42000000-0000-4000-8000-000000000001'),
  ('43000000-0000-4000-8000-000000000003',
    (select id from public.groups where slug='suspension-example'),
    '10000000-0000-4000-8000-000000000001', 'Past Scheduled Run', 'Past run fixture',
    pg_catalog.now() - interval '2 days', 'Parque da Jaqueira', 5000, 'beginner', 'public', 'scheduled',
    '42000000-0000-4000-8000-000000000001');

set local role authenticated;
set local request.jwt.claims = '{"sub":"42000000-0000-4000-8000-000000000003","role":"authenticated"}';
select throws_ok($$select public.suspend_group((select id from public.groups where slug='suspension-example'), '  ')$$,
  '22023', 'group reason is invalid', 'suspension rejects a blank reason');
select throws_ok($$select public.restore_group((select id from public.groups where slug='suspension-example'), 'Not an admin')$$,
  '42501', 'platform admin required', 'moderator cannot restore a suspended group');
select lives_ok($$select public.suspend_group((select id from public.groups where slug='suspension-example'), 'Safety review')$$,
  'moderator can suspend an approved group');
select throws_ok($$select public.suspend_group((select id from public.groups where slug='suspension-example'), 'Repeated pause')$$,
  'P0001', 'group_state_changed', 'a repeated suspension has a controlled state_changed result');
reset role;

select is((select count(*) from public.groups where slug='suspension-example' and status='suspended' and suspended_at is not null),
  1::bigint, 'suspension records the suspended state and timestamp');
select is((select count(*) from public.groups where slug='suspension-example'
  and approved_by='42000000-0000-4000-8000-000000000002' and approved_at is not null),
  1::bigint, 'suspension preserves the approval decision');
select is((select count(*) from public.group_members gm join public.groups g on g.id=gm.group_id
  where g.slug='suspension-example' and gm.role='owner' and gm.status='active'),
  1::bigint, 'suspended group retains exactly one active owner relation');
select is((select status from public.run_series where id='43000000-0000-4000-8000-000000000001'),
  'paused', 'suspension pauses an active series');
select is((select count(*) from public.runs where id='43000000-0000-4000-8000-000000000002'
  and status='cancelled' and cancelled_at is not null and cancellation_reason='Safety review'),
  1::bigint, 'suspension cancels a future scheduled run with the reason');
select is((select status from public.runs where id='43000000-0000-4000-8000-000000000003'),
  'scheduled', 'suspension preserves a past scheduled run');
select is((select count(*) from private.admin_audit_logs a join public.groups g on g.id=a.target_id
  where g.slug='suspension-example' and a.action='group.suspended'
    and a.metadata='{"previous_status":"approved","new_status":"suspended","reason":"Safety review"}'::jsonb),
  1::bigint, 'suspension audit contains only state and the supplied reason');
select is((select count(*) from private.notification_jobs j
  join private.admin_audit_logs a on a.id=j.source_entity_id
  join public.groups g on g.id=a.target_id
  where g.slug='suspension-example' and a.action='group.suspended'
    and j.event_type='group_suspended' and j.source_entity_type='admin_audit_log'),
  1::bigint, 'suspension creates one deduplicated notification job');
select is((select count(*) from private.admin_audit_logs a join public.groups g on g.id=a.target_id
  where g.slug='suspension-example' and a.action='group.suspended'),
  1::bigint, 'repeated suspension creates no duplicate audit');
select is((select count(*) from private.notification_jobs j
  join private.admin_audit_logs a on a.id=j.source_entity_id
  join public.groups g on g.id=a.target_id
  where g.slug='suspension-example' and a.action='group.suspended'),
  1::bigint, 'repeated suspension creates no duplicate notification job');

set local role authenticated;
set local request.jwt.claims = '{"sub":"42000000-0000-4000-8000-000000000002","role":"authenticated"}';
select throws_ok($$select public.restore_group((select id from public.groups where slug='suspension-example'), '  ')$$,
  '22023', 'group reason is invalid', 'restoration rejects a blank reason');
select lives_ok($$select public.restore_group((select id from public.groups where slug='suspension-example'), 'Review complete')$$,
  'platform admin restores a suspended group');
reset role;

select is((select status from public.groups where slug='suspension-example' and suspended_at is null),
  'approved', 'restoration returns the group to approved');
select is((select count(*) from public.groups where slug='suspension-example'
  and approved_by='42000000-0000-4000-8000-000000000002' and approved_at is not null),
  1::bigint, 'restoration preserves the original approval decision');
select is((select status from public.run_series where id='43000000-0000-4000-8000-000000000001'),
  'paused', 'restoration does not reopen a paused series');
select is((select count(*) from public.runs where id='43000000-0000-4000-8000-000000000002'
  and status='cancelled' and cancellation_reason='Safety review'),
  1::bigint, 'restoration does not reopen cancelled runs');
select is((select count(*) from private.admin_audit_logs a join public.groups g on g.id=a.target_id
  where g.slug='suspension-example' and a.action='group.restored'
    and a.metadata='{"previous_status":"suspended","new_status":"approved","reason":"Review complete"}'::jsonb),
  1::bigint, 'restoration appends minimal state and reason audit');
select is((select count(*) from private.notification_jobs j
  join private.admin_audit_logs a on a.id=j.source_entity_id
  join public.groups g on g.id=a.target_id
  where g.slug='suspension-example' and a.action='group.restored'),
  0::bigint, 'restoration does not create a suspension notification job');

create or replace function private.test_reject_group_approval_notification()
returns trigger
language plpgsql
as $$
begin
  if new.type = 'group_request_approved'
    and new.target_id::text = pg_catalog.current_setting('test.gate4_fail_group_id', true) then
    raise exception using errcode = 'P0001', message = 'forced_notification_failure';
  end if;
  return new;
end;
$$;
create trigger test_reject_group_approval_notification
before insert on public.notifications
for each row execute function private.test_reject_group_approval_notification();
select pg_catalog.set_config('test.gate4_fail_group_id',
  (select id::text from public.groups where slug='rollback-example'), true);
set local role authenticated;
set local request.jwt.claims = '{"sub":"42000000-0000-4000-8000-000000000002","role":"authenticated"}';
select throws_ok($$select public.approve_group_request((select id from public.groups where slug='rollback-example'))$$,
  'P0001', 'forced_notification_failure', 'failure in notification insertion aborts the complete approval transaction');
reset role;
drop trigger test_reject_group_approval_notification on public.notifications;
drop function private.test_reject_group_approval_notification();
select is((select status from public.groups where slug='rollback-example'),
  'pending', 'failed approval leaves the group pending');
select is((select count(*) from public.group_members gm join public.groups g on g.id=gm.group_id
  where g.slug='rollback-example' and gm.role='owner' and gm.status='pending'),
  1::bigint, 'failed approval leaves the owner relation pending');
select is((select count(*) from private.admin_audit_logs a join public.groups g on g.id=a.target_id
  where g.slug='rollback-example'),
  0::bigint, 'failed approval rolls back its audit row');
select is((select count(*) from public.notifications n join public.groups g on g.id=n.target_id
  where g.slug='rollback-example'),
  0::bigint, 'failed approval rolls back its notification');
select is((select count(*) from private.analytics_events e join public.groups g on g.id=e.entity_id
  where g.slug='rollback-example' and e.event_name='group_approved'),
  0::bigint, 'failed approval rolls back analytics');
select is((select count(*) from private.domain_event_receipts r join public.groups g on g.id=r.entity_id
  where g.slug='rollback-example' and r.event_type='group_joined'),
  0::bigint, 'failed approval rolls back the group_joined receipt');
select is((select count(*) from public.activity_events e join public.groups g on g.id=e.group_id
  where g.slug='rollback-example' and e.event_type='group_joined'),
  0::bigint, 'failed approval rolls back group_joined activity');

select lives_ok($$set constraints all immediate$$,
  'deferred owner consistency trigger accepts every committed state transition');

select * from finish();
rollback;

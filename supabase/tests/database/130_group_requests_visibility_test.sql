begin;
create extension if not exists pgtap with schema extensions;
select plan(81);

insert into auth.users (id, email) values
  ('41000000-0000-4000-8000-000000000001', 'group-owner@example.test'),
  ('41000000-0000-4000-8000-000000000002', 'group-reviewer@example.test'),
  ('41000000-0000-4000-8000-000000000003', 'group-incomplete@example.test'),
  ('41000000-0000-4000-8000-000000000004', 'group-suspended@example.test'),
  ('41000000-0000-4000-8000-000000000005', 'group-rate@example.test'),
  ('41000000-0000-4000-8000-000000000006', 'group-other@example.test');

update public.profiles set
  username = 'group_owner_410', full_name = 'Group Owner',
  city_id = '10000000-0000-4000-8000-000000000001',
  running_level = 'beginner', preferred_distance = 'up_to_5k', onboarding_completed = true
where id = '41000000-0000-4000-8000-000000000001';
update public.profiles set
  username = 'group_reviewer_410', full_name = 'Group Reviewer',
  city_id = '10000000-0000-4000-8000-000000000001',
  running_level = 'intermediate', preferred_distance = '5k_to_10k', onboarding_completed = true
where id = '41000000-0000-4000-8000-000000000002';
update public.profiles set
  username = 'group_rate_410', full_name = 'Group Rate',
  city_id = '10000000-0000-4000-8000-000000000001',
  running_level = 'beginner', preferred_distance = 'up_to_5k', onboarding_completed = true
where id = '41000000-0000-4000-8000-000000000005';
update public.profiles set
  username = 'group_other_410', full_name = 'Group Other',
  city_id = '10000000-0000-4000-8000-000000000001',
  running_level = 'beginner', preferred_distance = 'up_to_5k', onboarding_completed = true
where id = '41000000-0000-4000-8000-000000000006';
update private.account_controls set status = 'suspended'
where user_id = '41000000-0000-4000-8000-000000000004';
insert into private.platform_roles(user_id, role)
values ('41000000-0000-4000-8000-000000000002', 'platform_admin');

insert into public.cities(id, name, country_code, state_code, slug, timezone, is_active)
values ('41000000-0000-4000-8000-000000000099', 'Inactive Fixture City', 'BR', 'PE', 'inactive-fixture', 'America/Recife', false);

select has_function('private', 'current_account_is_group_ready', array[]::text[], 'group readiness helper exists');
select has_function('private', 'group_slug_is_reserved', array['text'], 'group route reservation helper exists');
select has_function('public', 'request_group', array['text','text','text','uuid','text','text'], 'group request RPC exists');
select has_function('public', 'update_group_profile', array['uuid','text','text','text','uuid','text','text'], 'group profile update RPC exists');
select has_function('public', 'resubmit_group', array['uuid'], 'group resubmit RPC exists');
select has_function('public', 'get_group_by_slug', array['text'], 'sanitized group read RPC exists');
select has_function('public', 'list_my_groups', array['timestamptz','uuid','integer'], 'my-groups read RPC exists');
select has_function('public', 'get_current_group_relation', array['uuid'], 'current group relation RPC exists');
select is((select p.pronargs from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'request_group'),
  6::smallint, 'request RPC has no actor or final-state payload arguments');
select is((select p.proargnames from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'request_group'),
  array['requested_name','requested_slug','requested_description','requested_city_id','requested_type','requested_join_policy']::text[],
  'request RPC accepts only approved group profile fields');

select ok((select p.prosecdef and p.proconfig @> array['search_path=""']
  from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'request_group'),
  'request RPC is SECURITY DEFINER with an empty search_path');
select is((select pg_catalog.pg_get_userbyid(p.proowner)
  from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'request_group'),
  'postgres', 'request RPC is owned by postgres');
select isnt(has_function_privilege('anon', 'public.request_group(text,text,text,uuid,text,text)', 'EXECUTE'), true,
  'anon cannot request groups');
select ok(has_function_privilege('authenticated', 'public.request_group(text,text,text,uuid,text,text)', 'EXECUTE'),
  'authenticated can request groups');
select ok(has_function_privilege('anon', 'public.get_group_by_slug(text)', 'EXECUTE'),
  'anon can read approved group projections');
select isnt(has_function_privilege('anon', 'public.list_my_groups(timestamp with time zone,uuid,integer)', 'EXECUTE'), true,
  'anon cannot list personal group relations');
select isnt(has_table_privilege('authenticated', 'public.groups', 'INSERT'), true,
  'authenticated cannot insert directly into groups');
select isnt(has_table_privilege('authenticated', 'public.groups', 'UPDATE'), true,
  'authenticated cannot update groups directly');
select isnt(has_table_privilege('authenticated', 'public.groups', 'DELETE'), true,
  'authenticated cannot delete groups directly');
select ok(has_column_privilege('authenticated', 'public.groups', 'name', 'SELECT'),
  'authenticated can select an approved group name');
select isnt(has_column_privilege('authenticated', 'public.groups', 'rejection_reason', 'SELECT'), true,
  'common group reads cannot select rejection reasons');
select isnt(has_column_privilege('authenticated', 'public.groups', 'owner_user_id', 'SELECT'), true,
  'common group reads cannot select owner identifiers');
select ok((select private.group_slug_is_reserved('solicitar') and private.group_slug_is_reserved('meus')),
  'reserved group route segments are detected');
select isnt((select private.group_slug_is_reserved('corrida-local')), true,
  'ordinary group slugs are not reserved');

set local role authenticated;
set local request.jwt.claims = '{"sub":"41000000-0000-4000-8000-000000000001","role":"authenticated"}';
select ok(private.current_account_is_group_ready(), 'active complete runner is group-ready');
select lives_ok(
  $$select public.request_group('  Morning Runners  ', ' Morning Runners ', '  A local running group.  ', '10000000-0000-4000-8000-000000000001', 'community', 'open')$$,
  'ready runner can request a group'
);
select is((select count(id) from public.groups where slug = 'morning-runners'), 1::bigint,
  'request normalizes slug and creates one group');
select is((select name from public.groups where slug = 'morning-runners'), 'Morning Runners',
  'request trims the group name');
select is((select description from public.groups where slug = 'morning-runners'), 'A local running group.',
  'request trims the description');
select is((select status from public.groups where slug = 'morning-runners'), 'pending',
  'request creates a pending group');
select is((select type from public.groups where slug = 'morning-runners'), 'community',
  'request persists the requested group type');
select is((select join_policy from public.groups where slug = 'morning-runners'), 'open',
  'request persists the requested join policy');
reset role;
select is((select owner_user_id from public.groups where slug = 'morning-runners'),
  '41000000-0000-4000-8000-000000000001'::uuid, 'request derives its owner from auth.uid()');
select is((select created_by from public.groups where slug = 'morning-runners'),
  '41000000-0000-4000-8000-000000000001'::uuid, 'request derives its creator from auth.uid()');
select is((select count(*) from public.group_members gm join public.groups g on g.id = gm.group_id
  where g.slug = 'morning-runners' and gm.user_id = '41000000-0000-4000-8000-000000000001'
    and gm.role = 'owner' and gm.status = 'pending' and gm.joined_at is null),
  1::bigint, 'request atomically creates the owner pending relation');
select is((select count(*) from private.analytics_events e join public.groups g on g.id = e.entity_id
  where g.slug = 'morning-runners' and e.event_name = 'group_requested'
    and e.user_id = '41000000-0000-4000-8000-000000000001'),
  1::bigint, 'request records one group_requested event');
set local role authenticated;
set local request.jwt.claims = '{"sub":"41000000-0000-4000-8000-000000000001","role":"authenticated"}';

select throws_ok(
  $$select public.request_group('Bad reserved', 'solicitar', 'Description', '10000000-0000-4000-8000-000000000001', 'community', 'open')$$,
  '22023', 'group slug is reserved', 'request rejects reserved route slugs'
);
select throws_ok(
  $$select public.request_group('Bad shape', '---', 'Description', '10000000-0000-4000-8000-000000000001', 'community', 'open')$$,
  '22023', 'group slug is invalid', 'request rejects an empty normalized slug'
);
select throws_ok(
  $$select public.request_group('Duplicate', 'MORNING-RUNNERS', 'Description', '10000000-0000-4000-8000-000000000001', 'community', 'open')$$,
  '23505', null, 'normalized duplicate slug is rejected by the unique constraint'
);
select throws_ok(
  $$select public.request_group('Bad type', 'bad-type-run', 'Description', '10000000-0000-4000-8000-000000000001', 'unapproved', 'open')$$,
  '22023', 'group type is invalid', 'request rejects unknown group types'
);
select throws_ok(
  $$select public.request_group('Bad policy', 'bad-policy-run', 'Description', '10000000-0000-4000-8000-000000000001', 'community', 'automatic')$$,
  '22023', 'group join policy is invalid', 'request rejects unknown join policies'
);
select throws_ok(
  $$select public.request_group('Bad city', 'inactive-city-run', 'Description', '41000000-0000-4000-8000-000000000099', 'community', 'open')$$,
  '23514', 'city must be active', 'request rejects an inactive city'
);
select throws_ok(
  $$select public.request_group('Ok', 'small-name-run', 'Description', '10000000-0000-4000-8000-000000000001', 'community', 'open')$$,
  '22023', 'group name is invalid', 'request rejects a name shorter than three characters'
);

select lives_ok(
  $$select public.request_group('Rejected Example', 'rejected-example', 'Needs editing', '10000000-0000-4000-8000-000000000001', 'professional', 'approval_required')$$,
  'owner can create a second group request'
);
select lives_ok(
  $$select public.request_group('Approved Example', 'approved-example', 'Approved group', '10000000-0000-4000-8000-000000000001', 'community', 'open')$$,
  'owner can create a group that will be approved by a fixture'
);
select lives_ok(
  $$select public.request_group('Review Example', 'review-example', 'Review group', '10000000-0000-4000-8000-000000000001', 'community', 'open')$$,
  'owner can create a group that will be rejected for reviewer visibility'
);
reset role;

update public.groups set status = 'rejected', rejection_reason = 'Please clarify the weekly schedule.'
where slug = 'rejected-example';
update public.groups set status = 'rejected', rejection_reason = 'Private review detail.'
where slug = 'review-example';
update public.groups set status = 'approved', approved_by = '41000000-0000-4000-8000-000000000002', approved_at = pg_catalog.now()
where slug = 'approved-example';
update public.group_members gm set status = 'active', joined_at = pg_catalog.now()
from public.groups g where g.id = gm.group_id and g.slug = 'approved-example' and gm.role = 'owner';

set local role anon;
set local request.jwt.claims = '{"role":"anon"}';
select is((select count(id) from public.groups), 1::bigint,
  'anon direct group reads contain only approved groups');
select is((select count(*) from public.get_group_by_slug('morning-runners')), 0::bigint,
  'anon cannot resolve a pending group');
select is((select count(*) from public.get_group_by_slug('rejected-example')), 0::bigint,
  'anon cannot resolve a rejected group');
select is((select group_status from public.get_group_by_slug('approved-example')), 'approved',
  'anon reads the approved group projection');
reset role;

set local role authenticated;
set local request.jwt.claims = '{"sub":"41000000-0000-4000-8000-000000000001","role":"authenticated"}';
select is((select group_view from public.get_group_by_slug('morning-runners')), 'requester',
  'request owner reads the pending group projection');
select is((select group_view from public.get_group_by_slug('rejected-example')), 'requester',
  'request owner reads the rejected group projection');
select is((select rejection_reason from public.list_my_groups(null, null, 20) where slug = 'rejected-example'),
  'Please clarify the weekly schedule.', 'only the owner list returns its private rejection reason');
select is((select count(*) from public.get_group_by_slug('missing-group')), 0::bigint,
  'unknown slug returns no group row');
select is((select group_status from public.get_current_group_relation((select id from public.groups where slug='approved-example'))),
  'approved', 'current account relation returns an approved group context');
select throws_ok(
  $$select public.update_group_profile((select id from public.groups where slug='approved-example'), 'Renamed Approved', 'renamed-approved', 'Updated', '10000000-0000-4000-8000-000000000001', 'community', 'open')$$,
  '22023', 'approved group slug is immutable', 'approved group slug cannot be changed'
);
select lives_ok(
  $$select public.update_group_profile((select id from public.groups where slug='approved-example'), 'Renamed Approved', 'approved-example', 'Updated', '10000000-0000-4000-8000-000000000001', 'community', 'open')$$,
  'owner can edit approved group profile fields without changing its slug'
);
select is((select name from public.groups where slug='approved-example'), 'Renamed Approved',
  'approved group profile update persists allowed fields');
select lives_ok(
  $$select public.update_group_profile((select id from public.groups where slug='rejected-example'), 'Revised Request', 'revised-request', 'Updated schedule', '10000000-0000-4000-8000-000000000001', 'professional', 'approval_required')$$,
  'owner can edit a rejected request using the allowlisted profile fields'
);
select is((select status from public.groups where slug='revised-request'), 'rejected',
  'editing a rejected request does not change its status');
select is((select rejection_reason from public.list_my_groups(null, null, 20) where slug='revised-request'),
  'Please clarify the weekly schedule.', 'editing preserves the private rejection reason');
select lives_ok(
  $$select public.resubmit_group((select id from public.groups where slug='revised-request'))$$,
  'owner can resubmit the same rejected group'
);
select is((select count(id) from public.groups where slug='revised-request' and status='pending'),
  1::bigint, 'resubmission reuses the same group row and returns to pending');
select is((select rejection_reason from public.list_my_groups(null, null, 20) where slug='revised-request'),
  null::text, 'resubmission clears the private rejection reason');
reset role;

set local role authenticated;
set local request.jwt.claims = '{"sub":"41000000-0000-4000-8000-000000000006","role":"authenticated"}';
select throws_ok(
  $$select public.update_group_profile((select id from public.groups where slug='approved-example'), 'Cross User', 'approved-example', 'No', '10000000-0000-4000-8000-000000000001', 'community', 'open')$$,
  '42501', null, 'ordinary runner cannot update another owner group'
);
reset role;

set local role authenticated;
set local request.jwt.claims = '{"sub":"41000000-0000-4000-8000-000000000002","role":"authenticated"}';
select is((select group_view from public.get_group_by_slug('morning-runners')), 'reviewer',
  'platform admin can read a pending group for review');
select is((select group_view from public.get_group_by_slug('review-example')), 'reviewer',
  'platform admin can read a rejected group for review');
select is((select count(id) from public.groups where slug='review-example'), 1::bigint,
  'platform admin can select the rejected group row');
select throws_ok(
  $$select rejection_reason from public.groups where slug='review-example'$$,
  '42501', null, 'reviewer cannot read private rejection reason through the common table projection'
);
reset role;

set local role authenticated;
set local request.jwt.claims = '{"sub":"41000000-0000-4000-8000-000000000003","role":"authenticated"}';
select isnt(private.current_account_is_group_ready(), true,
  'incomplete account is not group-ready');
select throws_ok(
  $$select public.request_group('Incomplete Runner', 'incomplete-runner', 'No profile', '10000000-0000-4000-8000-000000000001', 'community', 'open')$$,
  '42501', null, 'incomplete account cannot request groups'
);
reset role;

set local role authenticated;
set local request.jwt.claims = '{"sub":"41000000-0000-4000-8000-000000000004","role":"authenticated"}';
select isnt(private.current_account_is_group_ready(), true,
  'suspended account is not group-ready');
select throws_ok(
  $$select public.request_group('Suspended Runner', 'suspended-runner', 'No access', '10000000-0000-4000-8000-000000000001', 'community', 'open')$$,
  '42501', null, 'suspended account cannot request groups'
);
reset role;

set local role authenticated;
set local request.jwt.claims = '{"sub":"41000000-0000-4000-8000-000000000005","role":"authenticated"}';
select lives_ok($$select public.request_group('Rate Group One', 'rate-group-one', 'Rate fixture', '10000000-0000-4000-8000-000000000001', 'community', 'open')$$, 'rate fixture request one succeeds');
select lives_ok($$select public.request_group('Rate Group Two', 'rate-group-two', 'Rate fixture', '10000000-0000-4000-8000-000000000001', 'community', 'open')$$, 'rate fixture request two succeeds');
select lives_ok($$select public.request_group('Rate Group Three', 'rate-group-three', 'Rate fixture', '10000000-0000-4000-8000-000000000001', 'community', 'open')$$, 'rate fixture request three succeeds');
select lives_ok($$select public.request_group('Rate Group Four', 'rate-group-four', 'Rate fixture', '10000000-0000-4000-8000-000000000001', 'community', 'open')$$, 'rate fixture request four succeeds');
select lives_ok($$select public.request_group('Rate Group Five', 'rate-group-five', 'Rate fixture', '10000000-0000-4000-8000-000000000001', 'community', 'open')$$, 'rate fixture request five succeeds');
reset role;
select is((select consumed from private.rate_limit_buckets where user_id='41000000-0000-4000-8000-000000000005' and action='group_request'),
  5, 'five successful requests consume exactly five daily slots');
set local role authenticated;
set local request.jwt.claims = '{"sub":"41000000-0000-4000-8000-000000000005","role":"authenticated"}';
select throws_ok(
  $$select public.request_group('Rate Group Six', 'rate-group-six', 'Rate fixture', '10000000-0000-4000-8000-000000000001', 'community', 'open')$$,
  'P0001', 'group_request_rate_limited', 'sixth request is rejected at the daily limit'
);
reset role;

set local role anon;
set local request.jwt.claims = '{}';
select throws_ok(
  $$select public.request_group('Anonymous Runner', 'anonymous-runner', 'No auth', '10000000-0000-4000-8000-000000000001', 'community', 'open')$$,
  '42501', null, 'anonymous request is denied'
);
reset role;

select * from finish();
rollback;

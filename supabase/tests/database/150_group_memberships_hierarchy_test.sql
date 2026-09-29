begin;
create extension if not exists pgtap with schema extensions;
select plan(111);

insert into auth.users (id, email) values
  ('45000000-0000-4000-8000-000000000001', 'membership-owner@example.test'),
  ('45000000-0000-4000-8000-000000000002', 'membership-admin@example.test'),
  ('45000000-0000-4000-8000-000000000003', 'membership-member@example.test'),
  ('45000000-0000-4000-8000-000000000004', 'membership-applicant@example.test'),
  ('45000000-0000-4000-8000-000000000005', 'membership-blocked@example.test'),
  ('45000000-0000-4000-8000-000000000006', 'membership-admin-target@example.test'),
  ('45000000-0000-4000-8000-000000000007', 'membership-suspended@example.test'),
  ('45000000-0000-4000-8000-000000000008', 'membership-incomplete@example.test'),
  ('45000000-0000-4000-8000-000000000009', 'membership-outsider@example.test'),
  ('45000000-0000-4000-8000-000000000010', 'membership-reviewer@example.test'),
  ('45000000-0000-4000-8000-000000000011', 'membership-reject-target@example.test');

update public.profiles set
  username='member_owner_450', full_name='Membership Owner',
  city_id='10000000-0000-4000-8000-000000000001', running_level='beginner',
  preferred_distance='up_to_5k', onboarding_completed=true
where id='45000000-0000-4000-8000-000000000001';
update public.profiles set
  username='member_admin_450', full_name='Membership Admin',
  city_id='10000000-0000-4000-8000-000000000001', running_level='intermediate',
  preferred_distance='5k_to_10k', onboarding_completed=true
where id='45000000-0000-4000-8000-000000000002';
update public.profiles set
  username='member_three_450', full_name='Member Three', is_private=true,
  bio='private biography fixture', city_id='10000000-0000-4000-8000-000000000001',
  running_level='beginner', preferred_distance='up_to_5k', pace_seconds_per_km=360,
  onboarding_completed=true
where id='45000000-0000-4000-8000-000000000003';
update public.profiles set
  username='applicant_four_450', full_name='Applicant Four',
  city_id='10000000-0000-4000-8000-000000000001', running_level='intermediate',
  preferred_distance='5k_to_10k', onboarding_completed=true
where id='45000000-0000-4000-8000-000000000004';
update public.profiles set
  username='blocked_five_450', full_name='Blocked Five',
  city_id='10000000-0000-4000-8000-000000000001', running_level='beginner',
  preferred_distance='up_to_5k', onboarding_completed=true
where id='45000000-0000-4000-8000-000000000005';
update public.profiles set
  username='admin_six_450', full_name='Admin Six',
  city_id='10000000-0000-4000-8000-000000000001', running_level='advanced',
  preferred_distance='10k_to_half', onboarding_completed=true
where id='45000000-0000-4000-8000-000000000006';
update public.profiles set
  username='suspended_seven_450', full_name='Suspended Seven',
  city_id='10000000-0000-4000-8000-000000000001', running_level='beginner',
  preferred_distance='up_to_5k', onboarding_completed=true
where id='45000000-0000-4000-8000-000000000007';
update public.profiles set
  username='incomplete_eight_450', full_name='Incomplete Eight',
  city_id='10000000-0000-4000-8000-000000000001', running_level='beginner',
  preferred_distance='up_to_5k', onboarding_completed=false
where id='45000000-0000-4000-8000-000000000008';
update public.profiles set
  username='outsider_nine_450', full_name='Outsider Nine',
  city_id='10000000-0000-4000-8000-000000000001', running_level='intermediate',
  preferred_distance='5k_to_10k', onboarding_completed=true
where id='45000000-0000-4000-8000-000000000009';
update public.profiles set
  username='reviewer_ten_450', full_name='Reviewer Ten',
  city_id='10000000-0000-4000-8000-000000000001', running_level='beginner',
  preferred_distance='up_to_5k', onboarding_completed=false
where id='45000000-0000-4000-8000-000000000010';
update public.profiles set
  username='reject_eleven_450', full_name='Reject Eleven',
  city_id='10000000-0000-4000-8000-000000000001', running_level='intermediate',
  preferred_distance='5k_to_10k', onboarding_completed=true
where id='45000000-0000-4000-8000-000000000011';

insert into private.platform_roles(user_id, role)
values ('45000000-0000-4000-8000-000000000010', 'platform_admin');
update private.account_controls set status='suspended'
where user_id='45000000-0000-4000-8000-000000000007';

set local role authenticated;
set local request.jwt.claims = '{"sub":"45000000-0000-4000-8000-000000000001","role":"authenticated"}';
select lives_ok($$select public.request_group('Open Crew', 'open-crew', 'Open membership fixture', '10000000-0000-4000-8000-000000000001', 'community', 'open')$$,
  'owner requests an open group');
select lives_ok($$select public.request_group('Approval Crew', 'approval-crew', 'Approval membership fixture', '10000000-0000-4000-8000-000000000001', 'community', 'approval_required')$$,
  'owner requests an approval-required group');
select lives_ok($$select public.request_group('Other Crew', 'other-crew', 'Cross-group fixture', '10000000-0000-4000-8000-000000000001', 'community', 'open')$$,
  'owner requests a separate cross-group fixture');
reset role;
select pg_catalog.set_config('test.gate4_open_group_id', (select id::text from public.groups where slug='open-crew'), true);
select pg_catalog.set_config('test.gate4_approval_group_id', (select id::text from public.groups where slug='approval-crew'), true);
select pg_catalog.set_config('test.gate4_other_group_id', (select id::text from public.groups where slug='other-crew'), true);
set local role authenticated;
set local request.jwt.claims = '{"sub":"45000000-0000-4000-8000-000000000010","role":"authenticated"}';
select lives_ok($$select public.approve_group_request(current_setting('test.gate4_open_group_id')::uuid)$$,
  'platform admin approves the open-group fixture');
select lives_ok($$select public.approve_group_request(current_setting('test.gate4_approval_group_id')::uuid)$$,
  'platform admin approves the approval-required fixture');
select lives_ok($$select public.approve_group_request(current_setting('test.gate4_other_group_id')::uuid)$$,
  'platform admin approves the separate cross-group fixture');
reset role;

select has_function('public', 'join_group', array['uuid'], 'join_group RPC exists');
select has_function('public', 'approve_group_member', array['uuid','uuid'], 'approve member RPC exists');
select has_function('public', 'reject_group_member_request', array['uuid','uuid'], 'reject member request RPC exists');
select has_function('public', 'block_group_member', array['uuid','uuid'], 'block member RPC exists');
select has_function('public', 'leave_group', array['uuid'], 'leave group RPC exists');
select has_function('public', 'promote_group_admin', array['uuid','uuid'], 'promote admin RPC exists');
select has_function('public', 'demote_group_admin', array['uuid','uuid'], 'demote admin RPC exists');
select has_function('public', 'list_group_members', array['uuid','text','uuid','integer'], 'sanitized group roster RPC exists');
select has_function('private', 'current_user_group_role', array['uuid'], 'private current role helper exists');
select has_function('private', 'is_active_group_manager', array['uuid'], 'private manager helper exists');
select has_function('private', 'group_member_is_active', array['uuid','uuid'], 'private active-member helper exists');
select is((select count(*) from pg_catalog.pg_proc p
  join pg_catalog.pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public'
    and p.proname in ('join_group','approve_group_member','reject_group_member_request','block_group_member','leave_group','promote_group_admin','demote_group_admin','list_group_members')
    and p.prosecdef and p.proconfig @> array['search_path=""']),
  8::bigint, 'all public membership RPCs are SECURITY DEFINER with an empty search_path');
select is((select count(*) from pg_catalog.pg_proc p
  join pg_catalog.pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public'
    and p.proname in ('join_group','approve_group_member','reject_group_member_request','block_group_member','leave_group','promote_group_admin','demote_group_admin','list_group_members')
    and pg_catalog.pg_get_userbyid(p.proowner)='postgres'),
  8::bigint, 'all public membership RPCs are owned by postgres');
select is((select count(*) from information_schema.routine_privileges
  where specific_schema='public'
    and routine_name in ('join_group','approve_group_member','reject_group_member_request','block_group_member','leave_group','promote_group_admin','demote_group_admin','list_group_members')
    and grantee='authenticated'),
  8::bigint, 'authenticated has explicit execution on membership RPCs');
select is((select count(*) from information_schema.routine_privileges
  where specific_schema='public'
    and routine_name in ('join_group','approve_group_member','reject_group_member_request','block_group_member','leave_group','promote_group_admin','demote_group_admin','list_group_members')
    and grantee='anon'),
  0::bigint, 'anon cannot execute membership RPCs');
select is((select count(*) from information_schema.routine_privileges
  where specific_schema='public'
    and routine_name in ('join_group','approve_group_member','reject_group_member_request','block_group_member','leave_group','promote_group_admin','demote_group_admin','list_group_members')
    and grantee='PUBLIC'),
  0::bigint, 'PUBLIC cannot execute membership RPCs');
select is((select count(*) from pg_catalog.pg_proc p
  join pg_catalog.pg_namespace n on n.oid=p.pronamespace
  where n.nspname='private'
    and p.proname in ('current_user_group_role','is_active_group_manager','group_member_is_active')
    and p.prosecdef and p.proconfig @> array['search_path=""']
    and pg_catalog.pg_get_userbyid(p.proowner)='postgres'),
  3::bigint, 'private authorization helpers are definer-safe and owned by postgres');
select is((select count(*) from information_schema.routine_privileges
  where specific_schema='private'
    and routine_name in ('current_user_group_role','is_active_group_manager','group_member_is_active')
    and grantee in ('authenticated','anon')),
  0::bigint, 'clients cannot execute the internal membership helpers directly');
select is((select count(*) from information_schema.table_privileges
  where table_schema='public' and table_name='group_members'
    and grantee in ('PUBLIC','anon','authenticated')
    and privilege_type in ('SELECT','INSERT','UPDATE','DELETE')),
  0::bigint, 'group membership remains inaccessible to direct client table access');
select is((select p.proargnames from pg_catalog.pg_proc p
  join pg_catalog.pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='join_group'),
  array['target_group_id']::text[], 'join derives the actor from auth.uid()');
select is((select p.proargnames from pg_catalog.pg_proc p
  join pg_catalog.pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='approve_group_member'),
  array['target_group_id','target_user_id']::text[], 'approval has no caller-supplied actor');
select is((select p.proargnames[1:p.pronargs] from pg_catalog.pg_proc p
  join pg_catalog.pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='list_group_members'),
  array['target_group_id','direction','after_user_id','page_size']::text[], 'roster paging has a fixed contract and no actor parameter');

set local role authenticated;
set local request.jwt.claims = '{"sub":"45000000-0000-4000-8000-000000000001","role":"authenticated"}';
select lives_ok($$select public.promote_group_admin(current_setting('test.gate4_open_group_id')::uuid, '45000000-0000-4000-8000-000000000002')$$,
  'owner promotes an active member to group admin');
select lives_ok($$select public.promote_group_admin(current_setting('test.gate4_approval_group_id')::uuid, '45000000-0000-4000-8000-000000000002')$$,
  'owner promotes the same trusted manager only within the second group');
reset role;

set local role authenticated;
set local request.jwt.claims = '{"sub":"45000000-0000-4000-8000-000000000003","role":"authenticated"}';
select lives_ok($$select public.join_group(current_setting('test.gate4_open_group_id')::uuid)$$,
  'active runner joins an open group immediately');
select lives_ok($$select public.join_group(current_setting('test.gate4_open_group_id')::uuid)$$,
  'repeating an open join is idempotent');
reset role;
select is((select count(*) from public.group_members gm
  where gm.group_id=current_setting('test.gate4_open_group_id')::uuid
    and gm.user_id='45000000-0000-4000-8000-000000000003' and gm.role='member'
    and gm.status='active' and gm.joined_at is not null),
  1::bigint, 'open join stores exactly one active member relation');
select is((select count(*) from private.domain_event_receipts r
  where r.event_type='group_joined'
    and r.business_key='group:'||current_setting('test.gate4_open_group_id')||':45000000-0000-4000-8000-000000000003'),
  1::bigint, 'first open activation creates one group_joined receipt');
select is((select count(*) from public.activity_events e
  where e.event_type='group_joined'
    and e.group_id=current_setting('test.gate4_open_group_id')::uuid
    and e.actor_user_id='45000000-0000-4000-8000-000000000003'),
  1::bigint, 'first open activation creates one group_joined activity event');

set local role authenticated;
set local request.jwt.claims = '{"sub":"45000000-0000-4000-8000-000000000004","role":"authenticated"}';
select lives_ok($$select public.join_group(current_setting('test.gate4_approval_group_id')::uuid)$$,
  'approval-required group creates a pending membership request');
select lives_ok($$select public.join_group(current_setting('test.gate4_approval_group_id')::uuid)$$,
  'repeating a pending request does not duplicate it');
reset role;
select is((select count(*) from public.group_members gm
  where gm.group_id=current_setting('test.gate4_approval_group_id')::uuid
    and gm.user_id='45000000-0000-4000-8000-000000000004'
    and gm.role='member' and gm.status='pending'),
  1::bigint, 'approval-required join stores one pending relation');
select is((select count(*) from private.domain_event_receipts r
  where r.event_type='group_joined'
    and r.business_key='group:'||current_setting('test.gate4_approval_group_id')||':45000000-0000-4000-8000-000000000004'),
  0::bigint, 'pending request does not emit group_joined before approval');
set local role authenticated;
set local request.jwt.claims = '{"sub":"45000000-0000-4000-8000-000000000001","role":"authenticated"}';
select lives_ok($$select public.update_group_profile(
  current_setting('test.gate4_approval_group_id')::uuid,
  'Approval Crew', 'approval-crew', 'Approval membership fixture',
  '10000000-0000-4000-8000-000000000001', 'community', 'open'
)$$, 'owner can change join policy without converting an existing request');
reset role;
select is((select status from public.group_members gm
  where gm.group_id=current_setting('test.gate4_approval_group_id')::uuid
    and gm.user_id='45000000-0000-4000-8000-000000000004'),
  'pending', 'changing policy to open leaves an existing request pending');
set local role authenticated;
set local request.jwt.claims = '{"sub":"45000000-0000-4000-8000-000000000004","role":"authenticated"}';
select lives_ok($$select public.join_group(current_setting('test.gate4_approval_group_id')::uuid)$$,
  'repeating a pending request after policy change remains idempotent');
select is((select count(*) from public.list_group_members(
    current_setting('test.gate4_approval_group_id')::uuid, 'pending', null, 50)
  where user_id='45000000-0000-4000-8000-000000000004'),
  1::bigint, 'requester can read their own pending relationship');
reset role;
set local role authenticated;
set local request.jwt.claims = '{"sub":"45000000-0000-4000-8000-000000000003","role":"authenticated"}';
select lives_ok($$select public.join_group(current_setting('test.gate4_approval_group_id')::uuid)$$,
  'active runner can join after the owner opens the group');
select is((select count(*) from public.list_group_members(
    current_setting('test.gate4_approval_group_id')::uuid, 'pending', null, 50)
  where user_id='45000000-0000-4000-8000-000000000004'),
  0::bigint, 'active non-manager cannot read another member pending roster');
select ok(exists(select 1 from public.list_group_members(
    current_setting('test.gate4_approval_group_id')::uuid, 'active', null, 50)
  where user_id='45000000-0000-4000-8000-000000000003'
    and username='member_three_450' and full_name='Member Three'),
  'active member roster exposes minimum identity even for a private profile');
select ok(not exists(select 1 from public.list_group_members(
    current_setting('test.gate4_approval_group_id')::uuid, 'active', null, 50) as roster
  where pg_catalog.to_jsonb(roster) ?| array[
    'email','bio','city_id','running_level','preferred_distance','pace_seconds_per_km','avatar_url'
  ]), 'roster never returns full private profile data');
reset role;
set local role authenticated;
set local request.jwt.claims = '{"sub":"45000000-0000-4000-8000-000000000001","role":"authenticated"}';
select lives_ok($$select public.update_group_profile(
  current_setting('test.gate4_approval_group_id')::uuid,
  'Approval Crew', 'approval-crew', 'Approval membership fixture',
  '10000000-0000-4000-8000-000000000001', 'community', 'approval_required'
)$$, 'owner can restore approval-required policy for a new request');
reset role;
set local role authenticated;
set local request.jwt.claims = '{"sub":"45000000-0000-4000-8000-000000000002","role":"authenticated"}';
select is((select count(*) from public.list_group_members(
    current_setting('test.gate4_approval_group_id')::uuid, 'pending', null, 50)
  where user_id='45000000-0000-4000-8000-000000000004'),
  1::bigint, 'same-group admin can read pending roster');
select lives_ok($$select public.approve_group_member(
  current_setting('test.gate4_approval_group_id')::uuid, '45000000-0000-4000-8000-000000000004'
)$$, 'same-group admin approves a pending member');
select throws_ok($$select public.approve_group_member(
  current_setting('test.gate4_approval_group_id')::uuid, '45000000-0000-4000-8000-000000000004'
)$$, 'P0001', 'group_member_state_changed', 'repeated member approval returns controlled state_changed');
reset role;
select is((select count(*) from public.group_members gm
  where gm.group_id=current_setting('test.gate4_approval_group_id')::uuid
    and gm.user_id='45000000-0000-4000-8000-000000000004'
    and gm.role='member' and gm.status='active' and gm.joined_at is not null),
  1::bigint, 'member approval activates the existing relation');
select is((select count(*) from public.notifications n
  where n.recipient_user_id='45000000-0000-4000-8000-000000000004'
    and n.type='group_membership_approved'
    and n.target_id=current_setting('test.gate4_approval_group_id')::uuid),
  1::bigint, 'member approval creates one notification');
select is((select count(*) from public.notifications n
  where n.recipient_user_id='45000000-0000-4000-8000-000000000004'
    and n.type='group_membership_approved'
    and n.target_id=current_setting('test.gate4_approval_group_id')::uuid
    and n.dedupe_key like 'group_member_approved:%'),
  1::bigint, 'member approval notification has a stable dedupe key');
select is((select count(*) from private.domain_event_receipts r
  where r.event_type='group_joined'
    and r.business_key='group:'||current_setting('test.gate4_approval_group_id')||':45000000-0000-4000-8000-000000000004'),
  1::bigint, 'first approved membership creates one group_joined receipt');
select is((select count(*) from public.activity_events e
  where e.event_type='group_joined'
    and e.group_id=current_setting('test.gate4_approval_group_id')::uuid
    and e.actor_user_id='45000000-0000-4000-8000-000000000004'),
  1::bigint, 'first approved membership creates one group_joined activity');

set local role authenticated;
set local request.jwt.claims = '{"sub":"45000000-0000-4000-8000-000000000001","role":"authenticated"}';
select lives_ok($$select public.update_group_profile(
  current_setting('test.gate4_approval_group_id')::uuid,
  'Approval Crew', 'approval-crew', 'Approval membership fixture',
  '10000000-0000-4000-8000-000000000001', 'community', 'approval_required'
)$$, 'owner keeps approval-required policy for a rejection fixture');
reset role;
set local role authenticated;
set local request.jwt.claims = '{"sub":"45000000-0000-4000-8000-000000000011","role":"authenticated"}';
select lives_ok($$select public.join_group(current_setting('test.gate4_approval_group_id')::uuid)$$,
  'second user creates a pending request for manager rejection');
reset role;
set local role authenticated;
set local request.jwt.claims = '{"sub":"45000000-0000-4000-8000-000000000002","role":"authenticated"}';
select throws_ok($$select public.reject_group_member_request(
  current_setting('test.gate4_other_group_id')::uuid, '45000000-0000-4000-8000-000000000011'
)$$, '42501', 'group management is not allowed', 'admin cannot reject a request in another group');
select lives_ok($$select public.reject_group_member_request(
  current_setting('test.gate4_approval_group_id')::uuid, '45000000-0000-4000-8000-000000000011'
)$$, 'same-group admin rejects a pending member request');
select throws_ok($$select public.reject_group_member_request(
  current_setting('test.gate4_approval_group_id')::uuid, '45000000-0000-4000-8000-000000000011'
)$$, 'P0001', 'group_member_state_changed', 'repeated rejection returns controlled state_changed');
reset role;
select is((select count(*) from public.group_members gm
  where gm.group_id=current_setting('test.gate4_approval_group_id')::uuid
    and gm.user_id='45000000-0000-4000-8000-000000000011'),
  0::bigint, 'rejection removes a pending member request');
select is((select count(*) from private.domain_event_receipts r
  where r.event_type='group_joined'
    and r.business_key='group:'||current_setting('test.gate4_approval_group_id')||':45000000-0000-4000-8000-000000000011'),
  0::bigint, 'rejected pending request emits no group_joined receipt');

-- Future runs cover leave (members_only only) and block (all visibility) without exposing run creation RPCs.
insert into public.runs (
  id, group_id, city_id, title, description, starts_at, location_text,
  distance_meters, level, visibility, status, created_by
) values
  ('46000000-0000-4000-8000-000000000001', current_setting('test.gate4_open_group_id')::uuid,
   '10000000-0000-4000-8000-000000000001', 'Public For Three', 'Fixture', pg_catalog.now()+interval '2 days',
   'Parque da Jaqueira', 5000, 'beginner', 'public', 'scheduled', '45000000-0000-4000-8000-000000000001'),
  ('46000000-0000-4000-8000-000000000002', current_setting('test.gate4_open_group_id')::uuid,
   '10000000-0000-4000-8000-000000000001', 'Members For Three', 'Fixture', pg_catalog.now()+interval '2 days',
   'Parque da Jaqueira', 5000, 'beginner', 'members_only', 'scheduled', '45000000-0000-4000-8000-000000000001'),
  ('46000000-0000-4000-8000-000000000003', current_setting('test.gate4_open_group_id')::uuid,
   '10000000-0000-4000-8000-000000000001', 'Past Members For Three', 'Fixture', pg_catalog.now()-interval '2 days',
   'Parque da Jaqueira', 5000, 'beginner', 'members_only', 'scheduled', '45000000-0000-4000-8000-000000000001'),
  ('46000000-0000-4000-8000-000000000004', current_setting('test.gate4_open_group_id')::uuid,
   '10000000-0000-4000-8000-000000000001', 'Public For Five', 'Fixture', pg_catalog.now()+interval '2 days',
   'Parque da Jaqueira', 5000, 'beginner', 'public', 'scheduled', '45000000-0000-4000-8000-000000000001'),
  ('46000000-0000-4000-8000-000000000005', current_setting('test.gate4_open_group_id')::uuid,
   '10000000-0000-4000-8000-000000000001', 'Members For Five', 'Fixture', pg_catalog.now()+interval '2 days',
   'Parque da Jaqueira', 5000, 'beginner', 'members_only', 'scheduled', '45000000-0000-4000-8000-000000000001'),
  ('46000000-0000-4000-8000-000000000006', current_setting('test.gate4_open_group_id')::uuid,
   '10000000-0000-4000-8000-000000000001', 'Members For Four', 'Fixture', pg_catalog.now()+interval '2 days',
   'Parque da Jaqueira', 5000, 'beginner', 'members_only', 'scheduled', '45000000-0000-4000-8000-000000000001'),
  ('46000000-0000-4000-8000-000000000007', current_setting('test.gate4_open_group_id')::uuid,
   '10000000-0000-4000-8000-000000000001', 'Public For Four', 'Fixture', pg_catalog.now()+interval '2 days',
   'Parque da Jaqueira', 5000, 'beginner', 'public', 'scheduled', '45000000-0000-4000-8000-000000000001'),
  ('46000000-0000-4000-8000-000000000008', current_setting('test.gate4_open_group_id')::uuid,
   '10000000-0000-4000-8000-000000000001', 'Public For Six', 'Fixture', pg_catalog.now()+interval '2 days',
   'Parque da Jaqueira', 5000, 'beginner', 'public', 'scheduled', '45000000-0000-4000-8000-000000000001'),
  ('46000000-0000-4000-8000-000000000009', current_setting('test.gate4_open_group_id')::uuid,
   '10000000-0000-4000-8000-000000000001', 'Members For Six', 'Fixture', pg_catalog.now()+interval '2 days',
   'Parque da Jaqueira', 5000, 'beginner', 'members_only', 'scheduled', '45000000-0000-4000-8000-000000000001'),
  ('46000000-0000-4000-8000-000000000010', current_setting('test.gate4_other_group_id')::uuid,
   '10000000-0000-4000-8000-000000000001', 'Other Public For Five', 'Fixture', pg_catalog.now()+interval '2 days',
   'Parque da Jaqueira', 5000, 'beginner', 'public', 'scheduled', '45000000-0000-4000-8000-000000000001');
insert into public.run_participations(run_id,user_id,status) values
  ('46000000-0000-4000-8000-000000000001','45000000-0000-4000-8000-000000000003','going'),
  ('46000000-0000-4000-8000-000000000002','45000000-0000-4000-8000-000000000003','going'),
  ('46000000-0000-4000-8000-000000000003','45000000-0000-4000-8000-000000000003','going'),
  ('46000000-0000-4000-8000-000000000004','45000000-0000-4000-8000-000000000005','going'),
  ('46000000-0000-4000-8000-000000000005','45000000-0000-4000-8000-000000000005','going'),
  ('46000000-0000-4000-8000-000000000006','45000000-0000-4000-8000-000000000004','going'),
  ('46000000-0000-4000-8000-000000000007','45000000-0000-4000-8000-000000000004','going'),
  ('46000000-0000-4000-8000-000000000008','45000000-0000-4000-8000-000000000006','going'),
  ('46000000-0000-4000-8000-000000000009','45000000-0000-4000-8000-000000000006','going'),
  ('46000000-0000-4000-8000-000000000010','45000000-0000-4000-8000-000000000005','going');

set local role authenticated;
set local request.jwt.claims = '{"sub":"45000000-0000-4000-8000-000000000005","role":"authenticated"}';
select lives_ok($$select public.join_group(current_setting('test.gate4_open_group_id')::uuid)$$,
  'active member joins open group before the block fixture');
select lives_ok($$select public.join_group(current_setting('test.gate4_other_group_id')::uuid)$$,
  'active member joins the separate group before cross-group authorization');
reset role;
set local role authenticated;
set local request.jwt.claims = '{"sub":"45000000-0000-4000-8000-000000000004","role":"authenticated"}';
select lives_ok($$select public.join_group(current_setting('test.gate4_open_group_id')::uuid)$$,
  'approved member joins the open group');
reset role;
set local role authenticated;
set local request.jwt.claims = '{"sub":"45000000-0000-4000-8000-000000000006","role":"authenticated"}';
select lives_ok($$select public.join_group(current_setting('test.gate4_open_group_id')::uuid)$$,
  'admin target first joins as an ordinary active member');
reset role;
set local role authenticated;
set local request.jwt.claims = '{"sub":"45000000-0000-4000-8000-000000000001","role":"authenticated"}';
select lives_ok($$select public.promote_group_admin(current_setting('test.gate4_open_group_id')::uuid, '45000000-0000-4000-8000-000000000006')$$,
  'owner promotes an active member to admin');
reset role;
set local role authenticated;
set local request.jwt.claims = '{"sub":"45000000-0000-4000-8000-000000000002","role":"authenticated"}';
select throws_ok($$select public.promote_group_admin(current_setting('test.gate4_open_group_id')::uuid, '45000000-0000-4000-8000-000000000003')$$,
  '42501', 'group owner required', 'admin cannot promote a member');
select throws_ok($$select public.demote_group_admin(current_setting('test.gate4_open_group_id')::uuid, '45000000-0000-4000-8000-000000000006')$$,
  '42501', 'group owner required', 'admin cannot demote another admin');
select throws_ok($$select public.block_group_member(current_setting('test.gate4_open_group_id')::uuid, '45000000-0000-4000-8000-000000000006')$$,
  '42501', 'group management is not allowed', 'admin cannot block another admin');
select throws_ok($$select public.block_group_member(current_setting('test.gate4_other_group_id')::uuid, '45000000-0000-4000-8000-000000000005')$$,
  '42501', 'group management is not allowed', 'admin cannot manage a member in another group');
select throws_ok($$select public.block_group_member(current_setting('test.gate4_open_group_id')::uuid, '45000000-0000-4000-8000-000000000001')$$,
  '42501', 'group management is not allowed', 'admin cannot block the group owner');
reset role;

set local role authenticated;
set local request.jwt.claims = '{"sub":"45000000-0000-4000-8000-000000000001","role":"authenticated"}';
select throws_ok($$select public.leave_group(current_setting('test.gate4_open_group_id')::uuid)$$,
  '42501', 'group owner cannot leave', 'group owner cannot leave their responsibility');
select throws_ok($$select public.block_group_member(
  current_setting('test.gate4_open_group_id')::uuid, '45000000-0000-4000-8000-000000000001'
)$$, '42501', 'group management is not allowed', 'group owner cannot block their own owner relation');
select lives_ok($$select public.demote_group_admin(current_setting('test.gate4_open_group_id')::uuid, '45000000-0000-4000-8000-000000000006')$$,
  'owner explicitly demotes an admin before block');
reset role;
set local role authenticated;
set local request.jwt.claims = '{"sub":"45000000-0000-4000-8000-000000000002","role":"authenticated"}';
select lives_ok($$select public.block_group_member(current_setting('test.gate4_open_group_id')::uuid, '45000000-0000-4000-8000-000000000005')$$,
  'same-group admin blocks an ordinary active member');
select lives_ok($$select public.block_group_member(current_setting('test.gate4_open_group_id')::uuid, '45000000-0000-4000-8000-000000000006')$$,
  'same-group admin blocks a member only after explicit demotion');
select is((select count(*) from public.list_group_members(
    current_setting('test.gate4_open_group_id')::uuid, 'blocked', null, 50)
  where user_id='45000000-0000-4000-8000-000000000005'),
  1::bigint, 'manager sees a blocked relationship in the roster');
reset role;
select is((select count(*) from public.group_members gm
  where gm.group_id=current_setting('test.gate4_open_group_id')::uuid
    and gm.user_id='45000000-0000-4000-8000-000000000005'
    and gm.role='member' and gm.status='blocked'),
  1::bigint, 'blocking preserves the membership row as blocked');
set local role authenticated;
set local request.jwt.claims = '{"sub":"45000000-0000-4000-8000-000000000005","role":"authenticated"}';
select throws_ok($$select public.join_group(current_setting('test.gate4_open_group_id')::uuid)$$,
  '42501', 'group membership is blocked', 'blocked user cannot rejoin');
select is((select count(*) from public.list_group_members(
    current_setting('test.gate4_open_group_id')::uuid, 'blocked', null, 50)
  where user_id='45000000-0000-4000-8000-000000000005'),
  1::bigint, 'blocked user can still read their own relation');
reset role;
set local role authenticated;
set local request.jwt.claims = '{"sub":"45000000-0000-4000-8000-000000000003","role":"authenticated"}';
select is((select count(*) from public.list_group_members(
    current_setting('test.gate4_open_group_id')::uuid, 'blocked', null, 50)
  where user_id='45000000-0000-4000-8000-000000000005'),
  0::bigint, 'active member cannot read another member blocked roster');
select ok(exists(select 1 from public.list_group_members(
    current_setting('test.gate4_open_group_id')::uuid, 'active', null, 50)
  where user_id='45000000-0000-4000-8000-000000000003'
    and username='member_three_450' and full_name='Member Three'),
  'active member can read the minimal active roster');
select ok(not exists(select 1 from public.list_group_members(
    current_setting('test.gate4_open_group_id')::uuid, 'active', null, 50) as roster
  where pg_catalog.to_jsonb(roster) ?| array[
    'email','bio','city_id','running_level','preferred_distance','pace_seconds_per_km','avatar_url'
  ]), 'active roster does not leak private profile fields');
select throws_ok($$select * from public.list_group_members(
  current_setting('test.gate4_open_group_id')::uuid, 'all', null, 50
)$$, '22023', 'group member direction is invalid', 'roster only accepts fixed status directions');
reset role;
set local role authenticated;
set local request.jwt.claims = '{"sub":"45000000-0000-4000-8000-000000000009","role":"authenticated"}';
select is((select count(*) from public.list_group_members(
    current_setting('test.gate4_open_group_id')::uuid, 'active', null, 50)),
  0::bigint, 'non-member cannot enumerate the group roster');
reset role;
set local role authenticated;
set local request.jwt.claims = '{"sub":"45000000-0000-4000-8000-000000000002","role":"authenticated"}';
select lives_ok($$select public.block_group_member(current_setting('test.gate4_open_group_id')::uuid, '45000000-0000-4000-8000-000000000006')$$,
  'demoted active member is blocked after its role transition');
reset role;
select is((select count(*) from public.group_members gm
  where gm.group_id=current_setting('test.gate4_open_group_id')::uuid
    and gm.role='owner' and gm.status='active'),
  1::bigint, 'membership changes preserve exactly one active owner');

select is((select status from public.run_participations where run_id='46000000-0000-4000-8000-000000000004'
  and user_id='45000000-0000-4000-8000-000000000005'), 'cancelled',
  'blocking cancels future public participation');
select is((select status from public.run_participations where run_id='46000000-0000-4000-8000-000000000005'
  and user_id='45000000-0000-4000-8000-000000000005'), 'cancelled',
  'blocking cancels future members-only participation');
select is((select status from public.run_participations where run_id='46000000-0000-4000-8000-000000000010'
  and user_id='45000000-0000-4000-8000-000000000005'), 'going',
  'failed cross-group block does not cancel participation elsewhere');
select is((select count(*) from public.run_participations where user_id='45000000-0000-4000-8000-000000000006'
  and run_id in ('46000000-0000-4000-8000-000000000008','46000000-0000-4000-8000-000000000009')
  and status='cancelled'), 2::bigint, 'blocking after demotion cancels all future visibility types');

set local role authenticated;
set local request.jwt.claims = '{"sub":"45000000-0000-4000-8000-000000000003","role":"authenticated"}';
select lives_ok($$select public.leave_group(current_setting('test.gate4_open_group_id')::uuid)$$,
  'active member leaves an approved group');
select lives_ok($$select public.join_group(current_setting('test.gate4_open_group_id')::uuid)$$,
  'former unblocked member can rejoin an open group');
reset role;
select is((select count(*) from public.group_members gm
  where gm.group_id=current_setting('test.gate4_open_group_id')::uuid
    and gm.user_id='45000000-0000-4000-8000-000000000003'
    and gm.role='member' and gm.status='active'),
  1::bigint, 'leave removes the relation and rejoin creates a new active relation');
select is((select count(*) from private.domain_event_receipts r
  where r.event_type='group_joined'
    and r.business_key='group:'||current_setting('test.gate4_open_group_id')||':45000000-0000-4000-8000-000000000003'),
  1::bigint, 're-entry does not create a second group_joined receipt');
select is((select count(*) from public.activity_events e
  where e.event_type='group_joined'
    and e.group_id=current_setting('test.gate4_open_group_id')::uuid
    and e.actor_user_id='45000000-0000-4000-8000-000000000003'),
  1::bigint, 're-entry does not create a second group_joined activity');
select is((select status from public.run_participations where run_id='46000000-0000-4000-8000-000000000002'
  and user_id='45000000-0000-4000-8000-000000000003'), 'cancelled',
  'leave cancels future members-only participation');
select is((select status from public.run_participations where run_id='46000000-0000-4000-8000-000000000001'
  and user_id='45000000-0000-4000-8000-000000000003'), 'going',
  'leave preserves future public participation');
select is((select status from public.run_participations where run_id='46000000-0000-4000-8000-000000000003'
  and user_id='45000000-0000-4000-8000-000000000003'), 'going',
  'leave preserves historical participation');

set local role authenticated;
set local request.jwt.claims = '{"sub":"45000000-0000-4000-8000-000000000007","role":"authenticated"}';
select throws_ok($$select public.join_group(current_setting('test.gate4_open_group_id')::uuid)$$,
  '42501', 'account is not eligible to join groups', 'suspended account cannot join with a stale JWT');
reset role;
set local role authenticated;
set local request.jwt.claims = '{"sub":"45000000-0000-4000-8000-000000000008","role":"authenticated"}';
select throws_ok($$select public.join_group(current_setting('test.gate4_open_group_id')::uuid)$$,
  '42501', 'account is not eligible to join groups', 'incomplete account cannot join');
reset role;

set local role authenticated;
set local request.jwt.claims = '{"sub":"45000000-0000-4000-8000-000000000010","role":"authenticated"}';
select lives_ok($$select public.suspend_group(current_setting('test.gate4_other_group_id')::uuid, 'Membership fixture suspension')$$,
  'platform admin suspends the separate group fixture');
reset role;
select is((select status from public.groups where id=current_setting('test.gate4_other_group_id')::uuid),
  'suspended', 'group is suspended before membership access checks');
set local role authenticated;
set local request.jwt.claims = '{"sub":"45000000-0000-4000-8000-000000000009","role":"authenticated"}';
select throws_ok($$select public.join_group(current_setting('test.gate4_other_group_id')::uuid)$$,
  'P0001', 'group_state_changed', 'runner cannot join a suspended group');
select is((select count(*) from public.list_group_members(
    current_setting('test.gate4_other_group_id')::uuid, 'active', null, 50)),
  0::bigint, 'non-member cannot read a suspended group roster');
reset role;
set local role authenticated;
set local request.jwt.claims = '{"sub":"45000000-0000-4000-8000-000000000001","role":"authenticated"}';
select throws_ok($$select public.promote_group_admin(current_setting('test.gate4_other_group_id')::uuid, '45000000-0000-4000-8000-000000000005')$$,
  'P0001', 'group_state_changed', 'owner cannot change roles while the group is suspended');
reset role;
set local role authenticated;
set local request.jwt.claims = '{"sub":"45000000-0000-4000-8000-000000000005","role":"authenticated"}';
select lives_ok($$select public.leave_group(current_setting('test.gate4_other_group_id')::uuid)$$,
  'member can leave a suspended group');
reset role;
select is((select count(*) from public.group_members gm
  where gm.group_id=current_setting('test.gate4_other_group_id')::uuid
    and gm.user_id='45000000-0000-4000-8000-000000000005'),
  0::bigint, 'leaving a suspended group removes only the member relation');

select lives_ok($$set constraints all immediate$$,
  'deferred owner consistency accepts all membership and hierarchy changes');

select * from finish();
rollback;

begin;
create extension if not exists pgtap with schema extensions;
select plan(34);

insert into auth.users(id,email) values
  ('41000000-0000-4000-8000-000000000001','gate4-owner@example.test'),
  ('41000000-0000-4000-8000-000000000002','gate4-other@example.test'),
  ('41000000-0000-4000-8000-000000000003','gate4-admin@example.test'),
  ('41000000-0000-4000-8000-000000000004','gate4-suspended@example.test');

update public.profiles set username='gate4_owner', full_name='Gate Four Owner', city_id='10000000-0000-4000-8000-000000000001', running_level='beginner', preferred_distance='up_to_5k', onboarding_completed=true where id='41000000-0000-4000-8000-000000000001';
update public.profiles set username='gate4_other', full_name='Gate Four Other', city_id='10000000-0000-4000-8000-000000000001', running_level='intermediate', preferred_distance='5k_to_10k', onboarding_completed=true where id='41000000-0000-4000-8000-000000000002';
update public.profiles set username='gate4_admin', full_name='Gate Four Admin', city_id='10000000-0000-4000-8000-000000000001', running_level='advanced', preferred_distance='flexible', onboarding_completed=true where id='41000000-0000-4000-8000-000000000003';
update public.profiles set username='gate4_suspended', full_name='Gate Four Suspended', city_id='10000000-0000-4000-8000-000000000001', running_level='beginner', preferred_distance='up_to_5k', onboarding_completed=true where id='41000000-0000-4000-8000-000000000004';
update private.account_controls set status='suspended' where user_id='41000000-0000-4000-8000-000000000004';
insert into private.platform_roles(user_id,role) values ('41000000-0000-4000-8000-000000000003','platform_admin');

select has_function('public','request_group',array['text','text','text','uuid','text','text'],'request RPC exists');
select has_function('public','update_group_profile',array['uuid','text','text','text','uuid','text','text'],'update RPC exists');
select has_function('public','resubmit_group',array['uuid'],'resubmit RPC exists');
select has_function('public','get_group_by_slug',array['text'],'sanitized group reader exists');
select has_function('public','list_my_groups',array['timestamp with time zone','uuid','integer'],'owner list exists');
select has_function('public','get_current_group_relation',array['uuid'],'relation reader exists');
select is((select count(*) from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ('request_group','update_group_profile','resubmit_group','get_group_by_slug','list_my_groups','get_current_group_relation') and p.prosecdef and p.proconfig @> array['search_path=""']),6::bigint,'all Gate 4 request/read RPCs are definers with empty search_path');
select is((select count(*) from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ('request_group','update_group_profile','resubmit_group','get_group_by_slug','list_my_groups','get_current_group_relation') and has_function_privilege('public',p.oid,'EXECUTE')),0::bigint,'PUBLIC has no execute on Gate 4 RPCs');
select isnt(has_table_privilege('authenticated','public.groups','INSERT'),true,'authenticated cannot insert groups directly');
select isnt(has_table_privilege('authenticated','public.group_members','INSERT'),true,'authenticated cannot create owner membership directly');

set local role authenticated;
set local request.jwt.claims='{"sub":"41000000-0000-4000-8000-000000000001","role":"authenticated"}';
select lives_ok($$select public.request_group(' Corredores do Centro ','corredores-centro',' Grupo local de corrida ','10000000-0000-4000-8000-000000000001','community','open')$$,'ready runner requests group');
reset role;

select is((select count(*) from public.groups where slug='corredores-centro' and status='pending' and created_by='41000000-0000-4000-8000-000000000001' and owner_user_id='41000000-0000-4000-8000-000000000001'),1::bigint,'request creates one pending group with actor as creator and owner');
select is((select count(*) from public.group_members gm join public.groups g on g.id=gm.group_id where g.slug='corredores-centro' and gm.user_id='41000000-0000-4000-8000-000000000001' and gm.role='owner' and gm.status='pending' and gm.joined_at is null),1::bigint,'request atomically creates owner pending membership');
select is((select count(*) from private.analytics_events where event_name='group_requested' and user_id='41000000-0000-4000-8000-000000000001'),1::bigint,'request persists analytics fact once');

set local role anon;
set local request.jwt.claims='{"role":"anon"}';
select is((select count(*) from public.get_group_by_slug('corredores-centro')),0::bigint,'anon cannot see pending group');
select throws_ok($$select * from public.list_my_groups(null,null,20)$$,'42501',null,'anon cannot list owner groups');
reset role;

set local role authenticated;
set local request.jwt.claims='{"sub":"41000000-0000-4000-8000-000000000002","role":"authenticated"}';
select is((select count(*) from public.get_group_by_slug('corredores-centro')),0::bigint,'another runner cannot see pending group');
reset role;

set local role authenticated;
set local request.jwt.claims='{"sub":"41000000-0000-4000-8000-000000000001","role":"authenticated"}';
select is((select count(*) from public.get_group_by_slug('corredores-centro')),1::bigint,'owner sees own pending group');
select is((select count(*) from public.list_my_groups(null,null,20) where slug='corredores-centro' and status='pending'),1::bigint,'owner list contains own request');
select is((select relation_role||'/'||relation_status from public.get_current_group_relation((select id from public.groups where slug='corredores-centro'))),'owner/pending','owner relation is explicit');
select throws_ok($$select public.request_group('Upper Group','Upper-Group','Description','10000000-0000-4000-8000-000000000001','community','open')$$,'22023',null,'uppercase slug is rejected');
select throws_ok($$select public.request_group('Reserved Group','solicitar','Description','10000000-0000-4000-8000-000000000001','community','open')$$,'22023',null,'reserved group slug is rejected');
select throws_ok($$select public.request_group('Duplicate Group','corredores-centro','Description','10000000-0000-4000-8000-000000000001','community','open')$$,'23505',null,'duplicate slug is rejected by database authority');
select throws_ok($$select public.request_group('Invalid Type','invalid-type','Description','10000000-0000-4000-8000-000000000001','paid','open')$$,'22023',null,'unsupported group type is rejected');
select throws_ok($$select public.request_group('Invalid Policy','invalid-policy','Description','10000000-0000-4000-8000-000000000001','community','invite_only')$$,'22023',null,'unsupported join policy is rejected');
reset role;

update public.cities set is_active=false where id='10000000-0000-4000-8000-000000000001';
set local role authenticated;
set local request.jwt.claims='{"sub":"41000000-0000-4000-8000-000000000002","role":"authenticated"}';
select throws_ok($$select public.request_group('Inactive City','inactive-city','Description','10000000-0000-4000-8000-000000000001','community','open')$$,'23514',null,'inactive city is rejected');
reset role;
update public.cities set is_active=true where id='10000000-0000-4000-8000-000000000001';

set local role authenticated;
set local request.jwt.claims='{"sub":"41000000-0000-4000-8000-000000000004","role":"authenticated"}';
select throws_ok($$select public.request_group('Suspended Request','suspended-request','Description','10000000-0000-4000-8000-000000000001','community','open')$$,'42501',null,'suspended account cannot request group');
reset role;

set local role authenticated;
set local request.jwt.claims='{"sub":"41000000-0000-4000-8000-000000000002","role":"authenticated"}';
select lives_ok($$select public.request_group('Rate One','rate-one','Description','10000000-0000-4000-8000-000000000001','community','open')$$,'rate request one');
select lives_ok($$select public.request_group('Rate Two','rate-two','Description','10000000-0000-4000-8000-000000000001','professional','approval_required')$$,'rate request two');
select lives_ok($$select public.request_group('Rate Three','rate-three','Description','10000000-0000-4000-8000-000000000001','community','open')$$,'rate request three');
select lives_ok($$select public.request_group('Rate Four','rate-four','Description','10000000-0000-4000-8000-000000000001','community','open')$$,'rate request four');
select lives_ok($$select public.request_group('Rate Five','rate-five','Description','10000000-0000-4000-8000-000000000001','community','open')$$,'rate request five');
select throws_ok($$select public.request_group('Rate Six','rate-six','Description','10000000-0000-4000-8000-000000000001','community','open')$$,'P0001','rate_limited','sixth request in one day is rate limited');
reset role;

select is((select count(*) from public.groups where created_by='41000000-0000-4000-8000-000000000002'),5::bigint,'rate limit rollback leaves exactly five groups');

select * from finish();
rollback;

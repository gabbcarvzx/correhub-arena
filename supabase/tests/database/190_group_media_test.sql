begin;
create extension if not exists pgtap with schema extensions;
select plan(18);

select ok(exists(select 1 from storage.buckets where id='group-media' and public=false),'group-media bucket is private');
select is((select file_size_limit from storage.buckets where id='group-media'),1048576::bigint,'bucket caps request body at one MiB');
select has_function('public','authorize_group_media_upload',array['uuid','text','text','bigint'],'authorization RPC exists');
select has_function('public','finalize_group_media_upload',array['uuid'],'finalize RPC exists');
select has_function('public','fail_group_media_upload',array['uuid'],'failure RPC exists');
select has_function('public','get_group_media_path',array['uuid','text'],'read authorization RPC exists');
select function_privs_are('public','authorize_group_media_upload',array['uuid','text','text','bigint'],'authenticated',array['EXECUTE'],'authenticated can request an upload attempt');
select function_privs_are('public','authorize_group_media_upload',array['uuid','text','text','bigint'],'anon',array[]::text[],'anon cannot request upload');
select ok(not exists(
  select 1 from pg_proc p cross join lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a
  where p.oid='public.authorize_group_media_upload(uuid,text,text,bigint)'::regprocedure
    and a.grantee=0 and a.privilege_type='EXECUTE'
),'PUBLIC cannot request upload');
select is((select count(*) from pg_policies where schemaname='storage' and tablename='objects' and policyname like 'group_media%'),0::bigint,'no direct client Storage policy exists');

insert into auth.users(id,email) values
 ('47000000-0000-4000-8000-000000000001','media-owner@example.test'),
 ('47000000-0000-4000-8000-000000000002','media-member@example.test');
update public.profiles set username='media_owner',full_name='Media Owner',city_id='10000000-0000-4000-8000-000000000001',running_level='advanced',preferred_distance='flexible',onboarding_completed=true where id='47000000-0000-4000-8000-000000000001';
update public.profiles set username='media_member',full_name='Media Member',city_id='10000000-0000-4000-8000-000000000001',running_level='beginner',preferred_distance='up_to_5k',onboarding_completed=true where id='47000000-0000-4000-8000-000000000002';

set local role authenticated;
set local request.jwt.claims='{"sub":"47000000-0000-4000-8000-000000000001","role":"authenticated"}';
select public.request_group('Media Group','media-group','Grupo para mídia','10000000-0000-4000-8000-000000000001','community','open');
select matches((select object_path from public.authorize_group_media_upload((select id from public.groups where slug='media-group'),'avatar',repeat('a',64),1000::bigint)), '^[-0-9a-f]{36}/avatar\.webp$','pending owner receives canonical avatar path');
select throws_ok($$select public.authorize_group_media_upload((select id from public.groups where slug='media-group'),'avatar',repeat('b',64),256001::bigint)$$,'22023',null,'avatar over output limit is rejected');
select throws_ok($$select public.authorize_group_media_upload((select id from public.groups where slug='media-group'),'../cover',repeat('b',64),1000::bigint)$$,'22023',null,'path kind tampering is rejected');

set local request.jwt.claims='{"sub":"47000000-0000-4000-8000-000000000002","role":"authenticated"}';
select throws_ok($$select public.authorize_group_media_upload((select id from public.groups where slug='media-group'),'avatar',repeat('c',64),1000::bigint)$$,'42501',null,'ordinary member cannot upload pending media');

reset role;
update private.account_controls set status='suspended' where user_id='47000000-0000-4000-8000-000000000001';
set local role authenticated;
set local request.jwt.claims='{"sub":"47000000-0000-4000-8000-000000000001","role":"authenticated"}';
select throws_ok($$select public.authorize_group_media_upload((select id from public.groups where slug='media-group'),'cover',repeat('d',64),1000::bigint)$$,'42501',null,'suspended owner cannot upload');
select throws_ok($$insert into storage.objects(bucket_id,name,owner_id,metadata) values ('group-media','spoof/avatar.webp','47000000-0000-4000-8000-000000000001','{}')$$,'42501',null,'authenticated direct Storage insert is denied');
select throws_ok($$update public.groups set avatar_url='https://evil.example/avatar.webp' where slug='media-group'$$,'42501',null,'client cannot attach arbitrary media reference');
reset role;
select is((select count(*) from private.media_uploads where object_path like '%/avatar.webp'),1::bigint,'one canonical pending attempt exists');

select * from finish();
rollback;

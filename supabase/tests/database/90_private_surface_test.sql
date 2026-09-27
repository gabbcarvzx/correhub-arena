begin;
create extension if not exists pgtap with schema extensions;
select plan(14);

select is((select count(*) from pg_catalog.pg_class c join pg_catalog.pg_namespace n on n.oid=c.relnamespace
 where n.nspname in ('public','private') and c.relkind='r' and c.relrowsecurity),26::bigint,'all application tables have RLS enabled');
select is((select count(*) from pg_catalog.pg_policies where schemaname in ('public','private')),12::bigint,'only base, Gate 3 social and four Gate 4 group policies exist');
select is((select count(*) from pg_catalog.pg_policies where schemaname='public' and tablename='user_follows'),3::bigint,'user_follows has exactly the three approved Gate 3 policies');
select is((select count(*) from pg_catalog.pg_policies where tablename not in ('cities','app_settings','profiles','user_follows','groups','group_members')),0::bigint,'remaining future domain tables have zero policies');
select is((select count(*) from information_schema.role_table_grants where table_schema='private' and grantee='anon'),0::bigint,'anon has no private table grants');
select is((select count(*) from information_schema.role_table_grants where table_schema='private' and grantee='authenticated'),0::bigint,'authenticated has no private table grants');
select ok((select reloptions @> array['security_invoker=true'] from pg_catalog.pg_class c join pg_catalog.pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname='profile_directory'),'profile directory is security invoker');
select is((select count(*) from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid=p.pronamespace where n.nspname='private' and p.proname in ('current_account_is_active','account_is_active_for_visibility','current_user_has_platform_role') and p.prosecdef),3::bigint,'three authorization helpers are security definer');
select is((select count(*) from information_schema.routine_privileges where specific_schema='private' and grantee='PUBLIC' and routine_name in ('current_account_is_active','account_is_active_for_visibility','current_user_has_platform_role')),0::bigint,'PUBLIC cannot execute authorization helpers');

insert into auth.users(id,email) values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','surface@example.test');
insert into private.account_controls(user_id,status) values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','active')
on conflict (user_id) do update set status = excluded.status;
set local role authenticated;
set local request.jwt.claims = '{"sub":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","role":"authenticated"}';
select throws_ok($$insert into public.groups(slug,name,description,city_id,type,join_policy,owner_user_id)
 values ('sem-grant','Sem Grant','Descrição','10000000-0000-4000-8000-000000000001','community','open','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa')$$,'42501',null,'authenticated cannot insert groups');
select throws_ok($$insert into public.runs(group_id,city_id,title,description,starts_at,location_text,distance_meters,level,visibility)
 values ('40000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','Sem Grant','Descrição',now(),'Local',5000,'beginner','public')$$,'42501',null,'authenticated cannot insert runs');
select throws_ok($$insert into public.posts(author_user_id,body,visibility)
 values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','Sem grant','public')$$,'42501',null,'authenticated cannot insert posts');
select throws_ok('select * from public.notifications','42501',null,'authenticated cannot read notifications');
select throws_ok('select * from private.reports','42501',null,'authenticated cannot read private reports');
reset role;

select * from finish();
rollback;

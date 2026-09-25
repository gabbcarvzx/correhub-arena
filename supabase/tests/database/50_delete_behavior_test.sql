begin;
create extension if not exists pgtap with schema extensions;
select plan(19);

insert into auth.users(id,email) values
 ('80000000-0000-4000-8000-000000000001','delete-owner@example.test'),
 ('80000000-0000-4000-8000-000000000002','delete-member@example.test'),
 ('80000000-0000-4000-8000-000000000003','delete-actor@example.test');
insert into public.profiles(id,username) values ('80000000-0000-4000-8000-000000000002','delete_member');
insert into private.account_controls(user_id) values ('80000000-0000-4000-8000-000000000002');
insert into private.platform_roles(user_id,role,granted_by) values ('80000000-0000-4000-8000-000000000002','moderator','80000000-0000-4000-8000-000000000003');
insert into public.groups(id,slug,name,description,city_id,type,join_policy,status,owner_user_id,approved_by,approved_at)
values ('81000000-0000-4000-8000-000000000001','grupo-delete','Grupo Delete','Descrição',
 '10000000-0000-4000-8000-000000000001','community','open','approved',
 '80000000-0000-4000-8000-000000000001','80000000-0000-4000-8000-000000000003',now());
insert into public.group_members(group_id,user_id,role,status,joined_at) values
 ('81000000-0000-4000-8000-000000000001','80000000-0000-4000-8000-000000000001','owner','active',now()),
 ('81000000-0000-4000-8000-000000000001','80000000-0000-4000-8000-000000000002','member','active',now());
insert into public.group_follows(user_id,group_id) values ('80000000-0000-4000-8000-000000000002','81000000-0000-4000-8000-000000000001');
insert into public.user_follows(follower_id,followed_id) values ('80000000-0000-4000-8000-000000000002','80000000-0000-4000-8000-000000000003');
insert into public.run_series(id,group_id,city_id,title,description,weekday,local_start_time,timezone,starts_on,location_text,distance_meters,level,visibility)
values ('82000000-0000-4000-8000-000000000001','81000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','Série Delete','Descrição',2,'06:00','America/Recife',current_date,'Parque Central',5000,'all_levels','public');
insert into public.runs(id,group_id,city_id,series_id,occurrence_date,title,description,starts_at,location_text,distance_meters,level,visibility)
values ('83000000-0000-4000-8000-000000000001','81000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','82000000-0000-4000-8000-000000000001',current_date,'Run Delete','Descrição',now(),'Parque Central',5000,'all_levels','public');
insert into public.run_participations(id,run_id,user_id) values ('84000000-0000-4000-8000-000000000001','83000000-0000-4000-8000-000000000001','80000000-0000-4000-8000-000000000002');
insert into public.posts(id,author_user_id,group_id,body,visibility) values ('85000000-0000-4000-8000-000000000001','80000000-0000-4000-8000-000000000002','81000000-0000-4000-8000-000000000001','Post histórico','public');
insert into public.post_likes(post_id,user_id) values ('85000000-0000-4000-8000-000000000001','80000000-0000-4000-8000-000000000003');
insert into public.comments(id,post_id,user_id,body) values ('86000000-0000-4000-8000-000000000001','85000000-0000-4000-8000-000000000001','80000000-0000-4000-8000-000000000002','Comentário');
insert into public.notifications(recipient_user_id,actor_user_id,type,target_type,target_id,dedupe_key) values
 ('80000000-0000-4000-8000-000000000002','80000000-0000-4000-8000-000000000003','like','post','85000000-0000-4000-8000-000000000001','recipient-delete'),
 ('80000000-0000-4000-8000-000000000001','80000000-0000-4000-8000-000000000003','like','post','85000000-0000-4000-8000-000000000001','actor-delete');
insert into private.admin_audit_logs(actor_user_id,action,target_type,target_id) values ('80000000-0000-4000-8000-000000000002','moderate','post','85000000-0000-4000-8000-000000000001');
insert into private.rate_limit_buckets(user_id,action,window_started_at,expires_at) values ('80000000-0000-4000-8000-000000000002','post',now(),now()+interval '1 hour');
set constraints all immediate;

select throws_ok($$delete from auth.users where id='80000000-0000-4000-8000-000000000001'$$,'23503',null,'owner deletion is blocked');
select lives_ok($$delete from auth.users where id='80000000-0000-4000-8000-000000000002'$$,'non-owner identity deletion succeeds');
select is((select count(*) from public.profiles where id='80000000-0000-4000-8000-000000000002'),0::bigint,'profile cascades');
select is((select count(*) from private.account_controls where user_id='80000000-0000-4000-8000-000000000002'),0::bigint,'account control cascades');
select is((select count(*) from private.platform_roles where user_id='80000000-0000-4000-8000-000000000002'),0::bigint,'platform role cascades');
select is((select count(*) from public.group_members where user_id='80000000-0000-4000-8000-000000000002'),0::bigint,'membership cascades');
select is((select count(*) from public.group_follows where user_id='80000000-0000-4000-8000-000000000002'),0::bigint,'group follow cascades');
select is((select count(*) from public.user_follows where follower_id='80000000-0000-4000-8000-000000000002'),0::bigint,'user follow cascades');
select is((select user_id from public.run_participations where id='84000000-0000-4000-8000-000000000001'),null::uuid,'participation is anonymized');
select is((select author_user_id from public.posts where id='85000000-0000-4000-8000-000000000001'),null::uuid,'group post authorship is anonymized');
select is((select user_id from public.comments where id='86000000-0000-4000-8000-000000000001'),null::uuid,'comment authorship is anonymized');
select is((select actor_user_id from private.admin_audit_logs where target_id='85000000-0000-4000-8000-000000000001'),null::uuid,'audit actor is anonymized');
select is((select count(*) from private.rate_limit_buckets where user_id='80000000-0000-4000-8000-000000000002'),0::bigint,'rate bucket cascades');
select is((select count(*) from public.notifications where recipient_user_id='80000000-0000-4000-8000-000000000002'),0::bigint,'recipient inbox cascades');
select throws_ok($$delete from public.runs where id='83000000-0000-4000-8000-000000000001'$$,'23503',null,'referenced run deletion is blocked');
select throws_ok($$delete from public.run_series where id='82000000-0000-4000-8000-000000000001'$$,'23503',null,'referenced series deletion is blocked');
select throws_ok($$delete from public.groups where id='81000000-0000-4000-8000-000000000001'$$,'23503',null,'group with domain history is blocked');
select lives_ok($$delete from public.posts where id='85000000-0000-4000-8000-000000000001'$$,'post deletion succeeds and cascades interactions');
select is((select count(*) from public.post_likes where post_id='85000000-0000-4000-8000-000000000001') +
          (select count(*) from public.comments where post_id='85000000-0000-4000-8000-000000000001'),0::bigint,'post likes and comments cascade');

select * from finish();
rollback;

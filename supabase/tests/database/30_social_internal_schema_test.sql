begin;
create extension if not exists pgtap with schema extensions;
select plan(46);

select has_table(schema_name,table_name,format('%s.%s exists',schema_name,table_name))
from (values
 ('public','user_follows'),('public','posts'),('public','post_likes'),('public','comments'),
 ('public','activity_events'),('public','notifications'),('private','reports'),
 ('private','admin_audit_logs'),('private','analytics_events'),('private','notification_jobs'),
 ('private','media_uploads'),('private','rate_limit_buckets'),('private','group_owner_transfers'),
 ('private','domain_event_receipts')
) expected(schema_name,table_name);

select fk_ok('public','user_follows','follower_id','auth','users','id','followers reference users');
select fk_ok('public','posts','author_user_id','auth','users','id','post authors reference users');
select fk_ok('public','posts','group_id','public','groups','id','posts reference groups');
select fk_ok('public','comments','post_id','public','posts','id','comments reference posts');
select fk_ok('public','notifications','recipient_user_id','auth','users','id','notifications reference recipients');
select fk_ok('private','reports','reporter_user_id','auth','users','id','reports reference reporters');
select fk_ok('private','admin_audit_logs','actor_user_id','auth','users','id','audit logs reference actors');
select fk_ok('private','analytics_events','city_id','public','cities','id','analytics reference cities');
select fk_ok('private','media_uploads','owner_user_id','auth','users','id','uploads reference owners');
select fk_ok('private','rate_limit_buckets','user_id','auth','users','id','rate limits reference users');
select fk_ok('private','group_owner_transfers','group_id','public','groups','id','owner transfers reference groups');
select fk_ok('private','group_owner_transfers','to_user_id','auth','users','id','owner transfers reference destination users');

insert into auth.users(id,email) values
 ('70000000-0000-4000-8000-000000000001','social-1@example.test'),
 ('70000000-0000-4000-8000-000000000002','social-2@example.test'),
 ('70000000-0000-4000-8000-000000000003','social-3@example.test');
insert into public.groups(id,slug,name,description,city_id,type,join_policy,status,owner_user_id,approved_by,approved_at)
values ('71000000-0000-4000-8000-000000000001','grupo-social','Grupo Social','Descrição',
 '10000000-0000-4000-8000-000000000001','community','open','approved',
 '70000000-0000-4000-8000-000000000001','70000000-0000-4000-8000-000000000003',now());
insert into public.group_members(group_id,user_id,role,status,joined_at)
values ('71000000-0000-4000-8000-000000000001','70000000-0000-4000-8000-000000000001','owner','active',now());
set constraints all immediate;

select throws_ok($$insert into public.user_follows(follower_id,followed_id)
 values ('70000000-0000-4000-8000-000000000001','70000000-0000-4000-8000-000000000001')$$,'23514',null,'self-follow is rejected');
insert into public.user_follows values ('70000000-0000-4000-8000-000000000001','70000000-0000-4000-8000-000000000002',now());
select throws_ok($$insert into public.user_follows(follower_id,followed_id)
 values ('70000000-0000-4000-8000-000000000001','70000000-0000-4000-8000-000000000002')$$,'23505',null,'duplicate user follow is rejected');
select throws_ok($$insert into public.posts(author_user_id,body,visibility)
 values ('70000000-0000-4000-8000-000000000001',' ','public')$$,'23514',null,'blank post body is rejected');
select throws_ok($$insert into public.posts(author_user_id,body,visibility)
 values ('70000000-0000-4000-8000-000000000001','Post','members_only')$$,'23514',null,'personal post cannot be members-only');
select throws_ok($$insert into public.posts(author_user_id,group_id,body,visibility)
 values ('70000000-0000-4000-8000-000000000001','71000000-0000-4000-8000-000000000001','Post','private')$$,'23514',null,'group post cannot be private');
select lives_ok($$insert into public.posts(id,group_id,body,visibility)
 values ('72000000-0000-4000-8000-000000000001','71000000-0000-4000-8000-000000000001','Post institucional','members_only')$$,'institutional group post is accepted');
insert into public.post_likes(post_id,user_id) values ('72000000-0000-4000-8000-000000000001','70000000-0000-4000-8000-000000000002');
select throws_ok($$insert into public.post_likes(post_id,user_id)
 values ('72000000-0000-4000-8000-000000000001','70000000-0000-4000-8000-000000000002')$$,'23505',null,'duplicate post like is rejected');
select throws_ok($$insert into public.comments(post_id,user_id,body)
 values ('72000000-0000-4000-8000-000000000001','70000000-0000-4000-8000-000000000002',' ')$$,'23514',null,'blank comment is rejected');
select throws_ok($$insert into public.activity_events(event_type,entity_type,entity_id,metadata,dedupe_key)
 values ('run_created','run','60000000-0000-4000-8000-000000000001','[]','event-array')$$,'23514',null,'activity metadata must be an object');
insert into public.activity_events(event_type,entity_type,entity_id,dedupe_key)
values ('run_created','run','60000000-0000-4000-8000-000000000001','event-unique');
select throws_ok($$insert into public.activity_events(event_type,entity_type,entity_id,dedupe_key)
 values ('run_created','run','60000000-0000-4000-8000-000000000001','event-unique')$$,'23505',null,'activity dedupe key is unique');
select throws_ok($$insert into public.notifications(recipient_user_id,type,target_type,dedupe_key)
 values ('70000000-0000-4000-8000-000000000001',' ','post','notice')$$,'23514',null,'blank notification type is rejected');
select throws_ok($$insert into private.reports(target_type,target_id,reason,status)
 values ('post','72000000-0000-4000-8000-000000000001','spam','resolved')$$,'23514',null,'resolved report requires resolution');
select throws_ok($$insert into private.admin_audit_logs(action,target_type,metadata)
 values ('moderate','post','[]')$$,'23514',null,'audit metadata must be an object');
select throws_ok($$insert into private.analytics_events(event_name,properties,event_key)
 values ('view','[]','analytics-array')$$,'23514',null,'analytics properties must be an object');
select throws_ok($$insert into private.notification_jobs(event_type,source_entity_type,source_entity_id,status)
 values ('post','post','72000000-0000-4000-8000-000000000001','unknown')$$,'23514',null,'notification job rejects invalid state');
select throws_ok($$insert into private.notification_jobs(event_type,source_entity_type,source_entity_id,attempt_count)
 values ('post','post','72000000-0000-4000-8000-000000000001',-1)$$,'23514',null,'notification job rejects negative attempts');
select throws_ok($$insert into private.media_uploads(target_type,object_path,content_hash,size_bytes,status)
 values ('post','path/file','hash',-1,'pending')$$,'23514',null,'media upload rejects negative size');
select throws_ok($$insert into private.rate_limit_buckets(user_id,action,window_started_at,consumed,expires_at)
 values ('70000000-0000-4000-8000-000000000001','post',now(),-1,now()+interval '1 hour')$$,'23514',null,'rate bucket rejects negative consumption');
select throws_ok($$insert into private.group_owner_transfers(group_id,from_user_id,to_user_id,expires_at)
 values ('71000000-0000-4000-8000-000000000001','70000000-0000-4000-8000-000000000001','70000000-0000-4000-8000-000000000001',now()+interval '1 day')$$,'23514',null,'owner transfer rejects same source and destination');
select throws_ok($$insert into private.domain_event_receipts(event_type,business_key,entity_type)
 values (' ','business','post')$$,'23514',null,'event receipt rejects blank event type');

select * from finish();
rollback;

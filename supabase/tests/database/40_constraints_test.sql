begin;
create extension if not exists pgtap with schema extensions;
select plan(34);

insert into auth.users (id,email)
select format('30000000-0000-4000-8000-%s',lpad(i::text,12,'0'))::uuid, format('domain-%s@example.test',i)
from generate_series(1,8) fixture(i);

insert into public.cities (id,name,country_code,state_code,slug,timezone,is_active)
values ('10000000-0000-4000-8000-000000000010','Outra Cidade','BR','PE','outra-cidade','America/Recife',false);

insert into public.groups (id,slug,name,description,city_id,type,join_policy,status,owner_user_id)
values ('40000000-0000-4000-8000-000000000001','grupo-pendente','Grupo Pendente','Descrição',
  '10000000-0000-4000-8000-000000000001','community','open','pending','30000000-0000-4000-8000-000000000001');
insert into public.group_members (group_id,user_id,role,status)
values ('40000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000001','owner','pending');
select lives_ok('set constraints all immediate','pending group accepts its designated pending owner');
set constraints all deferred;

insert into public.groups (id,slug,name,description,city_id,type,join_policy,status,owner_user_id,approved_by,approved_at)
values ('40000000-0000-4000-8000-000000000002','grupo-aprovado','Grupo Aprovado','Descrição',
  '10000000-0000-4000-8000-000000000001','community','approval_required','approved',
  '30000000-0000-4000-8000-000000000002','30000000-0000-4000-8000-000000000003',now());
insert into public.group_members (group_id,user_id,role,status,joined_at)
values ('40000000-0000-4000-8000-000000000002','30000000-0000-4000-8000-000000000002','owner','active',now());
select lives_ok('set constraints all immediate','approved group accepts its designated active owner');
set constraints all deferred;

select throws_ok(
  $$insert into public.group_members (group_id,user_id,role,status,joined_at)
    values ('40000000-0000-4000-8000-000000000002','30000000-0000-4000-8000-000000000004','owner','active',now())$$,
  '23505',null,'second active owner is rejected'
);

create or replace function pg_temp.insert_owner_with_wrong_status() returns void language plpgsql as $$
begin
  set constraints all deferred;
  insert into public.group_members (group_id,user_id,role,status)
  values ('40000000-0000-4000-8000-000000000002','30000000-0000-4000-8000-000000000004','owner','pending');
  set constraints all immediate;
end;
$$;
select throws_ok(
  'select pg_temp.insert_owner_with_wrong_status()',
  '23514',null,'approved group rejects an additional pending owner'
);

create or replace function pg_temp.move_owner_out_of_group() returns void language plpgsql as $$
begin
  set constraints all deferred;
  update public.group_members
  set group_id = '40000000-0000-4000-8000-000000000002', role = 'member'
  where group_id = '40000000-0000-4000-8000-000000000001'
    and user_id = '30000000-0000-4000-8000-000000000001';
  set constraints all immediate;
end;
$$;
select throws_ok(
  'select pg_temp.move_owner_out_of_group()',
  '23514',null,'moving owner membership validates the former group'
);

create or replace function pg_temp.insert_divergent_owner() returns void language plpgsql as $$
begin
  set constraints all deferred;
  insert into public.groups (id,slug,name,description,city_id,type,join_policy,status,owner_user_id)
  values ('40000000-0000-4000-8000-000000000003','grupo-divergente','Grupo Divergente','Descrição',
    '10000000-0000-4000-8000-000000000001','community','open','pending','30000000-0000-4000-8000-000000000004');
  insert into public.group_members (group_id,user_id,role,status)
  values ('40000000-0000-4000-8000-000000000003','30000000-0000-4000-8000-000000000005','owner','pending');
  set constraints all immediate;
end;
$$;
select throws_ok('select pg_temp.insert_divergent_owner()','23514',null,'divergent designated owner is rejected');

select throws_ok($$insert into public.groups (slug,name,description,city_id,type,join_policy,status,owner_user_id)
 values ('status-invalido','Status Inválido','Descrição','10000000-0000-4000-8000-000000000001','community','open','unknown','30000000-0000-4000-8000-000000000001')$$,'23514',null,'invalid group status is rejected');
select throws_ok($$insert into public.groups (slug,name,description,city_id,type,join_policy,owner_user_id)
 values ('nome-vazio',' ','Descrição','10000000-0000-4000-8000-000000000001','community','open','30000000-0000-4000-8000-000000000001')$$,'23514',null,'blank group name is rejected');
select throws_ok($$insert into public.groups (slug,name,description,city_id,type,join_policy,owner_user_id)
 values ('descricao-vazia','Descrição Vazia',' ','10000000-0000-4000-8000-000000000001','community','open','30000000-0000-4000-8000-000000000001')$$,'23514',null,'blank group description is rejected');
select throws_ok($$insert into public.groups (slug,name,description,city_id,type,join_policy,owner_user_id)
 values ('cidade-inativa','Cidade Inativa','Descrição','10000000-0000-4000-8000-000000000010','community','open','30000000-0000-4000-8000-000000000001')$$,'23514',null,'new group rejects inactive city');
select throws_ok($$insert into public.groups (slug,name,description,city_id,type,join_policy,status,owner_user_id)
 values ('aprovacao-incompleta','Aprovação Incompleta','Descrição','10000000-0000-4000-8000-000000000001','community','open','approved','30000000-0000-4000-8000-000000000001')$$,'23514',null,'approved group requires approval metadata');

select lives_ok($$insert into public.run_series
 (id,group_id,city_id,title,description,weekday,local_start_time,timezone,starts_on,location_text,distance_meters,level,visibility,created_by)
 values ('50000000-0000-4000-8000-000000000001','40000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001',
 'Treino Semanal','Descrição',2,'06:00','America/Recife',current_date,'Parque Central',5000,'all_levels','public','30000000-0000-4000-8000-000000000002')$$,'valid series is accepted');

select throws_ok($$insert into public.run_series (group_id,city_id,title,description,weekday,local_start_time,timezone,starts_on,location_text,distance_meters,level,visibility)
 values ('40000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001','Dia Zero','Descrição',0,'06:00','America/Recife',current_date,'Parque Central',5000,'beginner','public')$$,'23514',null,'weekday below one is rejected');
select throws_ok($$insert into public.run_series (group_id,city_id,title,description,weekday,local_start_time,timezone,starts_on,location_text,distance_meters,level,visibility)
 values ('40000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001','Dia Oito','Descrição',8,'06:00','America/Recife',current_date,'Parque Central',5000,'beginner','public')$$,'23514',null,'weekday above seven is rejected');
select throws_ok($$insert into public.run_series (group_id,city_id,title,description,weekday,local_start_time,meeting_offset_minutes,timezone,starts_on,location_text,distance_meters,level,visibility)
 values ('40000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001','Offset Inválido','Descrição',2,'06:00',121,'America/Recife',current_date,'Parque Central',5000,'beginner','public')$$,'23514',null,'meeting offset above 120 is rejected');
select throws_ok($$insert into public.run_series (group_id,city_id,title,description,weekday,local_start_time,timezone,starts_on,ends_on,location_text,distance_meters,level,visibility)
 values ('40000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001','Datas Inválidas','Descrição',2,'06:00','America/Recife',current_date,current_date-1,'Parque Central',5000,'beginner','public')$$,'23514',null,'series end before start is rejected');
select throws_ok($$insert into public.run_series (group_id,city_id,title,description,weekday,local_start_time,timezone,starts_on,location_text,distance_meters,level,visibility)
 values ('40000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001','Distância Curta','Descrição',2,'06:00','America/Recife',current_date,'Parque Central',99,'beginner','public')$$,'23514',null,'series distance below 100 is rejected');
select throws_ok($$insert into public.run_series (group_id,city_id,title,description,weekday,local_start_time,timezone,starts_on,location_text,distance_meters,level,visibility)
 values ('40000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001','Distância Longa','Descrição',2,'06:00','America/Recife',current_date,'Parque Central',100001,'beginner','public')$$,'23514',null,'series distance above 100000 is rejected');
select throws_ok($$insert into public.run_series (group_id,city_id,title,description,weekday,local_start_time,timezone,starts_on,location_text,distance_meters,level,visibility,max_participants)
 values ('40000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001','Capacidade Zero','Descrição',2,'06:00','America/Recife',current_date,'Parque Central',5000,'beginner','public',0)$$,'23514',null,'zero capacity is rejected');
select throws_ok($$insert into public.run_series (group_id,city_id,title,description,weekday,local_start_time,timezone,starts_on,location_text,distance_meters,level,visibility)
 values ('40000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001','Timezone Inválido','Descrição',2,'06:00','Mars/Olympus',current_date,'Parque Central',5000,'beginner','public')$$,'23514',null,'invalid series timezone is rejected');
select throws_ok($$insert into public.run_series (group_id,city_id,title,description,weekday,local_start_time,timezone,starts_on,location_text,distance_meters,level,visibility)
 values ('40000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001','Nível Inválido','Descrição',2,'06:00','America/Recife',current_date,'Parque Central',5000,'elite','public')$$,'23514',null,'invalid series level is rejected');
select throws_ok($$insert into public.run_series (group_id,city_id,title,description,weekday,local_start_time,timezone,starts_on,location_text,distance_meters,level,visibility)
 values ('40000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001','Visibilidade Inválida','Descrição',2,'06:00','America/Recife',current_date,'Parque Central',5000,'beginner','private')$$,'23514',null,'invalid series visibility is rejected');

select lives_ok($$insert into public.runs
 (id,group_id,city_id,title,description,starts_at,meeting_time,location_text,distance_meters,level,visibility)
 values ('60000000-0000-4000-8000-000000000001','40000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001',
 'Corrida Avulsa','Descrição',now()+interval '1 day',now()+interval '23 hours 30 minutes','Parque Central',5000,'all_levels','public')$$,'standalone run with null series fields is accepted');
select lives_ok($$insert into public.runs
 (id,group_id,city_id,series_id,occurrence_date,title,description,starts_at,location_text,distance_meters,level,visibility)
 values ('60000000-0000-4000-8000-000000000002','40000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001',
 '50000000-0000-4000-8000-000000000001',current_date,'Ocorrência','Descrição',now()+interval '2 days','Parque Central',5000,'all_levels','public')$$,'series occurrence is accepted');
select throws_ok($$insert into public.runs
 (group_id,city_id,series_id,occurrence_date,title,description,starts_at,location_text,distance_meters,level,visibility)
 values ('40000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001','50000000-0000-4000-8000-000000000001',current_date,'Duplicada','Descrição',now()+interval '3 days','Parque Central',5000,'beginner','public')$$,'23505',null,'duplicate series occurrence is rejected');
select throws_ok($$insert into public.runs
 (group_id,city_id,series_id,occurrence_date,title,description,starts_at,location_text,distance_meters,level,visibility)
 values ('40000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','50000000-0000-4000-8000-000000000001',current_date+1,'Grupo Divergente','Descrição',now()+interval '3 days','Parque Central',5000,'beginner','public')$$,'23503',null,'occurrence cannot change its series group');
select throws_ok($$insert into public.runs (group_id,city_id,series_id,title,description,starts_at,location_text,distance_meters,level,visibility)
 values ('40000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001','50000000-0000-4000-8000-000000000001','Parcial','Descrição',now(),'Parque Central',5000,'beginner','public')$$,'23514',null,'series without occurrence date is rejected');
select throws_ok($$insert into public.runs (group_id,city_id,occurrence_date,title,description,starts_at,location_text,distance_meters,level,visibility)
 values ('40000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001',current_date,'Parcial','Descrição',now(),'Parque Central',5000,'beginner','public')$$,'23514',null,'occurrence date without series is rejected');
select throws_ok($$insert into public.runs (group_id,city_id,title,description,starts_at,meeting_time,location_text,distance_meters,level,visibility)
 values ('40000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001','Reunião Cedo','Descrição',now()+interval '1 day',now()+interval '21 hours','Parque Central',5000,'beginner','public')$$,'23514',null,'meeting more than two hours early is rejected');
select throws_ok($$insert into public.runs (group_id,city_id,title,description,starts_at,meeting_time,location_text,distance_meters,level,visibility)
 values ('40000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001','Reunião Tarde','Descrição',now()+interval '1 day',now()+interval '25 hours','Parque Central',5000,'beginner','public')$$,'23514',null,'meeting after start is rejected');
select throws_ok($$insert into public.runs (group_id,city_id,title,description,starts_at,location_text,distance_meters,level,visibility,status)
 values ('40000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001','Cancelada','Descrição',now(),'Parque Central',5000,'beginner','public','cancelled')$$,'23514',null,'cancelled run requires cancellation data');
select throws_ok($$insert into public.runs (group_id,city_id,title,description,starts_at,location_text,distance_meters,level,visibility,cancelled_at,cancellation_reason)
 values ('40000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001','Agendada','Descrição',now(),'Parque Central',5000,'beginner','public',now(),'motivo')$$,'23514',null,'scheduled run cannot carry cancellation data');
select throws_ok($$insert into public.run_participations (run_id,user_id,status)
 values ('60000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000006','unknown')$$,'23514',null,'invalid participation status is rejected');
insert into public.run_participations (run_id,user_id)
values ('60000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000006');
select throws_ok($$insert into public.run_participations (run_id,user_id)
 values ('60000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000006')$$,'23505',null,'duplicate participation is rejected');

select * from finish();
rollback;

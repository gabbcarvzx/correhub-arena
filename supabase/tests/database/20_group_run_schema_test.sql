begin;
create extension if not exists pgtap with schema extensions;
select plan(24);

select has_table('public', table_name, format('public.%s exists', table_name))
from unnest(array['groups','group_members','group_follows','run_series','runs','run_participations']) table_name;

select fk_ok('public','groups','city_id','public','cities','id','groups reference cities');
select fk_ok('public','groups','owner_user_id','auth','users','id','groups reference owners');
select fk_ok('public','group_members','group_id','public','groups','id','members reference groups');
select fk_ok('public','group_members','user_id','auth','users','id','members reference users');
select fk_ok('public','group_follows','group_id','public','groups','id','group follows reference groups');
select fk_ok('public','run_series','group_id','public','groups','id','series reference groups');
select fk_ok('public','run_series','city_id','public','cities','id','series reference cities');
select fk_ok('public','runs',array['series_id','group_id','city_id'],'public','run_series',array['id','group_id','city_id'],'occurrences reference their series group and city');
select fk_ok('public','run_participations','run_id','public','runs','id','participations reference runs');
select fk_ok('public','run_participations','user_id','auth','users','id','participations reference users');

select is((select confdeltype from pg_constraint where conname='groups_owner_user_id_fkey'),'r'::"char",'group owner deletion is restricted');
select is((select confdeltype from pg_constraint where conname='runs_series_group_city_fkey'),'r'::"char",'series deletion is restricted');
select is((select confdeltype from pg_constraint where conname='run_participations_run_id_fkey'),'r'::"char",'run deletion is restricted');
select is((select confdeltype from pg_constraint where conname='run_participations_user_id_fkey'),'n'::"char",'participant identity deletion anonymizes');

select has_index('public','group_members','group_members_one_active_owner_idx','active owner uniqueness index exists');
select has_index('public','runs','runs_series_occurrence_key','series occurrence uniqueness exists');
select has_index('public','run_participations','run_participations_run_id_user_id_key','participation uniqueness exists');
select has_index('public','runs','runs_city_visibility_status_starts_idx','run discovery index exists');

select * from finish();
rollback;

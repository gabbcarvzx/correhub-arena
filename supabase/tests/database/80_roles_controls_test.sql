begin;
create extension if not exists pgtap with schema extensions;
select plan(9);

insert into auth.users(id,email) values
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','a@example.test'),
 ('cccccccc-cccc-4ccc-8ccc-cccccccccccc','moderator@example.test'),
 ('dddddddd-dddd-4ddd-8ddd-dddddddddddd','admin@example.test'),
 ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','suspended@example.test');
insert into private.account_controls(user_id,status) values
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','active'),
 ('cccccccc-cccc-4ccc-8ccc-cccccccccccc','active'),
 ('dddddddd-dddd-4ddd-8ddd-dddddddddddd','active'),
 ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee','suspended')
on conflict (user_id) do update set status = excluded.status;
insert into private.platform_roles(user_id,role,granted_by) values
 ('cccccccc-cccc-4ccc-8ccc-cccccccccccc','moderator','dddddddd-dddd-4ddd-8ddd-dddddddddddd'),
 ('dddddddd-dddd-4ddd-8ddd-dddddddddddd','platform_admin',null);

set local role authenticated;
set local request.jwt.claims = '{"sub":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","role":"authenticated"}';
select ok(private.current_account_is_active(),'active user helper returns true');
select isnt(private.current_user_has_platform_role('moderator'),true,'common user has no moderator role');
select throws_ok('select * from private.platform_roles','42501',null,'common user cannot read platform roles');
select throws_ok($$insert into private.platform_roles(user_id,role) values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','platform_admin')$$,'42501',null,'common user cannot self-assign platform role');
select throws_ok($$update private.account_controls set status='active' where user_id='eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee'$$,'42501',null,'common user cannot alter account controls');
select throws_ok('select * from private.account_controls','42501',null,'common user cannot read account controls');
reset role;

set local role authenticated;
set local request.jwt.claims = '{"sub":"cccccccc-cccc-4ccc-8ccc-cccccccccccc","role":"authenticated"}';
select ok(private.current_user_has_platform_role('moderator'),'moderator helper recognizes moderator');
reset role;

set local role authenticated;
set local request.jwt.claims = '{"sub":"dddddddd-dddd-4ddd-8ddd-dddddddddddd","role":"authenticated"}';
select ok(private.current_user_has_platform_role('platform_admin'),'role helper recognizes platform admin');
reset role;

set local role authenticated;
set local request.jwt.claims = '{"sub":"eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee","role":"authenticated"}';
select isnt(private.current_account_is_active(),true,'suspended account helper returns false');
reset role;

select * from finish();
rollback;

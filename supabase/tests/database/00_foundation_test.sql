begin;

create extension if not exists pgtap with schema extensions;

select plan(10);

select has_schema('private', 'private schema exists');
select has_extension('pgcrypto', 'pgcrypto is available');
select has_function(
  'private',
  'set_updated_at',
  array[]::text[],
  'updated_at trigger helper exists'
);
select has_function(
  'private',
  'assert_valid_timezone',
  array['text'],
  'timezone validator exists'
);

select is(
  (
    select p.provolatile
    from pg_catalog.pg_proc p
    join pg_catalog.pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'private' and p.proname = 'set_updated_at'
  ),
  'v'::"char",
  'updated_at helper has VOLATILE semantics'
);

select is(
  (
    select p.provolatile
    from pg_catalog.pg_proc p
    join pg_catalog.pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'private' and p.proname = 'assert_valid_timezone'
  ),
  's'::"char",
  'timezone validator has STABLE semantics'
);

select ok(
  (
    select p.proconfig @> array['search_path=""']
    from pg_catalog.pg_proc p
    join pg_catalog.pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'private' and p.proname = 'set_updated_at'
  ),
  'updated_at helper fixes an empty search_path'
);

select ok(
  (
    select p.proconfig @> array['search_path=""']
    from pg_catalog.pg_proc p
    join pg_catalog.pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'private' and p.proname = 'assert_valid_timezone'
  ),
  'timezone validator fixes an empty search_path'
);

select is(
  (
    select count(*)
    from information_schema.role_table_grants
    where table_schema = 'private'
      and grantee in ('PUBLIC', 'anon', 'authenticated')
  ),
  0::bigint,
  'client roles have no grants on current private tables'
);

select is(
  (
    select count(*)
    from pg_catalog.pg_default_acl d
    left join pg_catalog.pg_namespace n on n.oid = d.defaclnamespace
    cross join lateral pg_catalog.aclexplode(d.defaclacl) a
    left join pg_catalog.pg_roles grantee on grantee.oid = a.grantee
    where n.nspname in ('public', 'private')
      and d.defaclrole = 'postgres'::regrole
      and coalesce(grantee.rolname, 'PUBLIC') in ('PUBLIC', 'anon', 'authenticated')
  ),
  0::bigint,
  'future public and private objects grant nothing to client roles by default'
);

select * from finish();
rollback;

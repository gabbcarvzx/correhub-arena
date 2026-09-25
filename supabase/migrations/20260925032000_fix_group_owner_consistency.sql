create or replace function private.assert_group_owner_consistency()
returns trigger
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  target_group_ids uuid[];
  target_group_id uuid;
  group_status text;
  designated_owner uuid;
  matching_owner_count integer;
  total_owner_count integer;
  required_member_status text;
begin
  if tg_table_name = 'groups' then
    target_group_ids := array[new.id];
  elsif tg_op = 'INSERT' then
    target_group_ids := array[new.group_id];
  elsif tg_op = 'DELETE' then
    target_group_ids := array[old.group_id];
  elsif new.group_id = old.group_id then
    target_group_ids := array[new.group_id];
  else
    target_group_ids := array[old.group_id, new.group_id];
  end if;

  foreach target_group_id in array target_group_ids
  loop
    select g.status, g.owner_user_id
    into group_status, designated_owner
    from public.groups g
    where g.id = target_group_id;

    if not found then
      continue;
    end if;

    required_member_status := case
      when group_status in ('approved', 'suspended') then 'active'
      else 'pending'
    end;

    select
      count(*) filter (where gm.role = 'owner'),
      count(*) filter (
        where gm.role = 'owner'
          and gm.status = required_member_status
          and gm.user_id = designated_owner
      )
    into total_owner_count, matching_owner_count
    from public.group_members gm
    where gm.group_id = target_group_id;

    if total_owner_count <> 1 or matching_owner_count <> 1 then
      raise exception using
        errcode = '23514',
        message = 'group owner membership is inconsistent';
    end if;
  end loop;

  return null;
end;
$$;

revoke all on function private.assert_group_owner_consistency() from public, anon, authenticated;

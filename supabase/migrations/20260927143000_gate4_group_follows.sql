grant select, delete on public.group_follows to authenticated;
grant insert (user_id,group_id) on public.group_follows to authenticated;

create policy group_follows_read_own
on public.group_follows for select
to authenticated
using (
  user_id=(select auth.uid())
  and private.current_account_is_group_ready()
);

create policy group_follows_insert_own_approved
on public.group_follows for insert
to authenticated
with check (
  user_id=(select auth.uid())
  and private.current_account_is_group_ready()
  and exists (
    select 1 from public.groups g
    where g.id=group_id and g.status='approved'
  )
);

create policy group_follows_delete_own
on public.group_follows for delete
to authenticated
using (
  user_id=(select auth.uid())
  and private.current_account_is_group_ready()
);

create or replace function private.record_group_follow_event()
returns trigger
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare target_city_id uuid;
begin
  select g.city_id into target_city_id from public.groups g where g.id=new.group_id;
  insert into private.analytics_events(event_name,user_id,city_id,entity_type,entity_id,properties,event_key)
  values('group_followed',new.user_id,target_city_id,'group',new.group_id,'{}'::jsonb,
    'group_followed:'||new.user_id::text||':'||new.group_id::text)
  on conflict(event_key) do nothing;
  return new;
end;
$$;

alter function private.record_group_follow_event() owner to postgres;
revoke all on function private.record_group_follow_event() from public,anon,authenticated;

create trigger group_follows_record_event
after insert on public.group_follows
for each row execute function private.record_group_follow_event();

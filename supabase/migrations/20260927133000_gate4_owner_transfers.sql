create or replace function public.initiate_group_owner_transfer(target_group_id uuid, target_user_id uuid)
returns uuid
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  actor uuid := (select auth.uid());
  transfer_id uuid;
begin
  if actor is null or not private.current_account_is_group_ready()
    or private.current_group_role(target_group_id) is distinct from 'owner' then
    raise exception using errcode='42501', message='forbidden';
  end if;
  if actor=target_user_id then raise exception using errcode='22023', message='invalid_transfer_target'; end if;
  perform 1 from public.groups g where g.id=target_group_id and g.status='approved' and g.owner_user_id=actor for update;
  if not found then raise exception using errcode='P0001', message='state_changed'; end if;
  update private.group_owner_transfers set status='expired'
    where group_id=target_group_id and status='pending' and expires_at<=pg_catalog.now();
  if exists(select 1 from private.group_owner_transfers t where t.group_id=target_group_id and t.status='pending') then
    raise exception using errcode='P0001', message='transfer_already_pending';
  end if;
  perform 1 from public.group_members gm
    where gm.group_id=target_group_id and gm.user_id=target_user_id
      and gm.status='active' and gm.role in ('member','admin') for update;
  if not found or not private.account_is_active_for_visibility(target_user_id) then
    raise exception using errcode='42501', message='target_ineligible';
  end if;
  insert into private.group_owner_transfers(group_id,from_user_id,to_user_id,status,expires_at)
  values(target_group_id,actor,target_user_id,'pending',pg_catalog.now()+interval '7 days')
  returning id into transfer_id;
  return transfer_id;
end;
$$;

create or replace function public.cancel_group_owner_transfer(target_transfer_id uuid)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare actor uuid := (select auth.uid()); transfer private.group_owner_transfers%rowtype;
begin
  if actor is null or not private.current_account_is_group_ready() then
    raise exception using errcode='42501', message='forbidden';
  end if;
  select * into transfer from private.group_owner_transfers t where t.id=target_transfer_id for update;
  if not found or transfer.status<>'pending' then raise exception using errcode='P0001', message='state_changed'; end if;
  perform 1 from public.groups g where g.id=transfer.group_id and g.status='approved'
    and g.owner_user_id=actor and transfer.from_user_id=actor for update;
  if not found then raise exception using errcode='42501', message='forbidden'; end if;
  update private.group_owner_transfers set status='cancelled' where id=target_transfer_id;
end;
$$;

create or replace function public.get_group_owner_transfer(target_group_id uuid)
returns table(
  transfer_id uuid, group_id uuid, from_user_id uuid, to_user_id uuid,
  effective_status text, expires_at timestamptz, created_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select t.id,t.group_id,t.from_user_id,t.to_user_id,
    case when t.status='pending' and t.expires_at<=pg_catalog.now() then 'expired' else t.status end,
    t.expires_at,t.created_at
  from private.group_owner_transfers t
  where t.group_id=target_group_id
    and private.current_account_is_group_ready()
    and (
      t.from_user_id=(select auth.uid())
      or t.to_user_id=(select auth.uid())
      or private.current_group_role(target_group_id)='owner'
    )
  order by t.created_at desc
  limit 1;
$$;

create or replace function public.accept_group_owner_transfer(target_transfer_id uuid)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  actor uuid := (select auth.uid());
  transfer private.group_owner_transfers%rowtype;
begin
  if actor is null or not private.current_account_is_group_ready() then
    raise exception using errcode='42501', message='forbidden';
  end if;
  select * into transfer from private.group_owner_transfers t where t.id=target_transfer_id for update;
  if not found or transfer.status<>'pending' then raise exception using errcode='P0001', message='state_changed'; end if;
  if transfer.to_user_id<>actor then raise exception using errcode='42501', message='forbidden'; end if;
  if transfer.expires_at<=pg_catalog.now() then raise exception using errcode='P0001', message='transfer_expired'; end if;
  perform 1 from public.groups g where g.id=transfer.group_id and g.status='approved'
    and g.owner_user_id=transfer.from_user_id for update;
  if not found then raise exception using errcode='P0001', message='state_changed'; end if;
  perform 1 from public.group_members gm where gm.group_id=transfer.group_id
    and gm.user_id=transfer.from_user_id and gm.role='owner' and gm.status='active' for update;
  if not found then raise exception using errcode='23514', message='owner_membership_inconsistent'; end if;
  perform 1 from public.group_members gm where gm.group_id=transfer.group_id
    and gm.user_id=actor and gm.role in ('member','admin') and gm.status='active' for update;
  if not found or not private.account_is_active_for_visibility(actor) then
    raise exception using errcode='42501', message='target_ineligible';
  end if;

  update public.group_members set role='member'
    where group_id=transfer.group_id and user_id=transfer.from_user_id;
  update public.group_members set role='owner'
    where group_id=transfer.group_id and user_id=actor;
  update public.groups set owner_user_id=actor where id=transfer.group_id;
  update private.group_owner_transfers set status='accepted',accepted_at=pg_catalog.now()
    where id=target_transfer_id;
  insert into private.admin_audit_logs(actor_user_id,action,target_type,target_id,metadata)
  values(actor,'group_ownership_transferred','group',transfer.group_id,
    pg_catalog.jsonb_build_object('from_user_id',transfer.from_user_id,'to_user_id',actor));
  insert into public.notifications(recipient_user_id,actor_user_id,type,target_type,target_id,dedupe_key)
  values(transfer.from_user_id,actor,'group_ownership_transferred','group',transfer.group_id,
    'group_ownership_transferred:'||target_transfer_id::text)
  on conflict(recipient_user_id,dedupe_key) do nothing;
end;
$$;

alter function public.initiate_group_owner_transfer(uuid,uuid) owner to postgres;
alter function public.cancel_group_owner_transfer(uuid) owner to postgres;
alter function public.get_group_owner_transfer(uuid) owner to postgres;
alter function public.accept_group_owner_transfer(uuid) owner to postgres;
revoke all on function public.initiate_group_owner_transfer(uuid,uuid) from public,anon,authenticated;
revoke all on function public.cancel_group_owner_transfer(uuid) from public,anon,authenticated;
revoke all on function public.get_group_owner_transfer(uuid) from public,anon,authenticated;
revoke all on function public.accept_group_owner_transfer(uuid) from public,anon,authenticated;
grant execute on function public.initiate_group_owner_transfer(uuid,uuid) to authenticated;
grant execute on function public.cancel_group_owner_transfer(uuid) to authenticated;
grant execute on function public.get_group_owner_transfer(uuid) to authenticated;
grant execute on function public.accept_group_owner_transfer(uuid) to authenticated;

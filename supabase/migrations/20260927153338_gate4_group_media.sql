insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values ('group-media','group-media',false,1048576,array['image/webp'])
on conflict(id) do update set
  public=false,
  file_size_limit=excluded.file_size_limit,
  allowed_mime_types=excluded.allowed_mime_types;

create or replace function private.current_user_can_manage_group_media(target_group_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.current_account_is_group_ready()
    and exists (
      select 1
      from public.groups g
      where g.id=target_group_id
        and (
          (g.status in ('pending','rejected') and g.owner_user_id=(select auth.uid()))
          or (
            g.status='approved'
            and exists (
              select 1 from public.group_members gm
              where gm.group_id=g.id
                and gm.user_id=(select auth.uid())
                and gm.status='active'
                and gm.role in ('admin','owner')
            )
          )
        )
    );
$$;

create or replace function private.consume_group_media_rate_limit()
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  actor uuid := (select auth.uid());
  window_start timestamptz := pg_catalog.date_trunc('hour',pg_catalog.now());
  total integer;
begin
  insert into private.rate_limit_buckets(user_id,action,window_started_at,consumed,expires_at)
  values(actor,'group_media_upload',window_start,1,window_start+interval '25 hours')
  on conflict(user_id,action,window_started_at)
  do update set consumed=private.rate_limit_buckets.consumed+1
  returning consumed into total;
  if total>20 then raise exception using errcode='P0001',message='rate_limited'; end if;
end;
$$;

create or replace function public.authorize_group_media_upload(
  target_group_id uuid,
  media_kind text,
  requested_content_hash text,
  requested_size_bytes bigint
)
returns table(upload_id uuid,object_path text)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  actor uuid := (select auth.uid());
  canonical_path text;
  target_kind text;
begin
  if actor is null or not private.current_user_can_manage_group_media(target_group_id) then
    raise exception using errcode='42501',message='forbidden';
  end if;
  if media_kind not in ('avatar','cover')
    or requested_content_hash !~ '^[0-9a-f]{64}$'
    or requested_size_bytes<1
    or (media_kind='avatar' and requested_size_bytes>250000)
    or (media_kind='cover' and requested_size_bytes>600000) then
    raise exception using errcode='22023',message='invalid_media';
  end if;
  perform 1 from public.groups g where g.id=target_group_id for update;
  if not found then raise exception using errcode='P0002',message='group_not_found'; end if;
  perform private.consume_group_media_rate_limit();
  canonical_path := target_group_id::text || '/' || media_kind || '.webp';
  target_kind := 'group_' || media_kind;
  insert into private.media_uploads(owner_user_id,target_type,target_id,object_path,content_hash,size_bytes,expires_at,status)
  values(actor,target_kind,target_group_id,canonical_path,requested_content_hash,requested_size_bytes,pg_catalog.now()+interval '24 hours','pending')
  on conflict on constraint media_uploads_object_path_key do update set
    owner_user_id=excluded.owner_user_id,
    target_type=excluded.target_type,
    target_id=excluded.target_id,
    content_hash=excluded.content_hash,
    size_bytes=excluded.size_bytes,
    expires_at=excluded.expires_at,
    status='pending',
    updated_at=pg_catalog.now()
  returning id,private.media_uploads.object_path into upload_id,object_path;
  return next;
end;
$$;

create or replace function public.finalize_group_media_upload(target_upload_id uuid)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  actor uuid := (select auth.uid());
  attempt private.media_uploads%rowtype;
begin
  if actor is null or not private.current_account_is_group_ready() then
    raise exception using errcode='42501',message='forbidden';
  end if;
  select * into attempt from private.media_uploads m where m.id=target_upload_id for update;
  if not found or attempt.status<>'pending' or attempt.expires_at<=pg_catalog.now() then
    raise exception using errcode='P0001',message='state_changed';
  end if;
  if attempt.owner_user_id<>actor or attempt.target_id is null
    or not private.current_user_can_manage_group_media(attempt.target_id) then
    raise exception using errcode='42501',message='authorization_revoked';
  end if;
  if attempt.target_type='group_avatar' then
    update public.groups set avatar_url=attempt.object_path where id=attempt.target_id;
  elsif attempt.target_type='group_cover' then
    update public.groups set cover_url=attempt.object_path where id=attempt.target_id;
  else
    raise exception using errcode='22023',message='invalid_media_target';
  end if;
  update private.media_uploads set status='ready',expires_at=null where id=target_upload_id;
end;
$$;

create or replace function public.fail_group_media_upload(target_upload_id uuid)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare actor uuid := (select auth.uid());
begin
  if actor is null then raise exception using errcode='42501',message='forbidden'; end if;
  update private.media_uploads set status='failed'
  where id=target_upload_id and owner_user_id=actor and status='pending';
end;
$$;

create or replace function public.get_group_media_path(target_group_id uuid,media_kind text)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case media_kind when 'avatar' then g.avatar_url when 'cover' then g.cover_url end
  from public.groups g
  where g.id=target_group_id
    and media_kind in ('avatar','cover')
    and (
      g.status='approved'
      or (
        g.status in ('pending','rejected')
        and g.owner_user_id=(select auth.uid())
        and private.current_account_is_group_ready()
      )
    )
    and exists (
      select 1 from private.media_uploads m
      where m.target_id=g.id
        and m.target_type='group_'||media_kind
        and m.object_path=case media_kind when 'avatar' then g.avatar_url else g.cover_url end
        and m.status='ready'
    );
$$;

alter function private.current_user_can_manage_group_media(uuid) owner to postgres;
alter function private.consume_group_media_rate_limit() owner to postgres;
alter function public.authorize_group_media_upload(uuid,text,text,bigint) owner to postgres;
alter function public.finalize_group_media_upload(uuid) owner to postgres;
alter function public.fail_group_media_upload(uuid) owner to postgres;
alter function public.get_group_media_path(uuid,text) owner to postgres;

revoke all on function private.current_user_can_manage_group_media(uuid) from public,anon,authenticated;
revoke all on function private.consume_group_media_rate_limit() from public,anon,authenticated;
revoke all on function public.authorize_group_media_upload(uuid,text,text,bigint) from public,anon,authenticated;
revoke all on function public.finalize_group_media_upload(uuid) from public,anon,authenticated;
revoke all on function public.fail_group_media_upload(uuid) from public,anon,authenticated;
revoke all on function public.get_group_media_path(uuid,text) from public,anon,authenticated;

grant execute on function public.authorize_group_media_upload(uuid,text,text,bigint) to authenticated;
grant execute on function public.finalize_group_media_upload(uuid) to authenticated;
grant execute on function public.fail_group_media_upload(uuid) to authenticated;
grant execute on function public.get_group_media_path(uuid,text) to anon,authenticated;


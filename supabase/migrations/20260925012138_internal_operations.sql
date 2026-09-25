create table private.reports (
  id uuid primary key default extensions.gen_random_uuid(),
  reporter_user_id uuid references auth.users(id) on delete set null,
  target_type text not null,
  target_id uuid not null,
  reason text not null,
  details text,
  status text not null default 'open',
  assigned_to uuid references auth.users(id) on delete set null,
  resolution text,
  created_at timestamptz not null default pg_catalog.now(),
  updated_at timestamptz not null default pg_catalog.now(),
  constraint reports_target_type_check check (target_type in ('user', 'post', 'comment', 'group')),
  constraint reports_reason_check check (
    reason = pg_catalog.btrim(reason) and pg_catalog.char_length(reason) between 1 and 120
  ),
  constraint reports_details_check check (
    details is null or (details = pg_catalog.btrim(details) and pg_catalog.char_length(details) between 1 and 2000)
  ),
  constraint reports_status_check check (status in ('open', 'in_review', 'resolved', 'dismissed')),
  constraint reports_resolution_check check (
    (status in ('resolved', 'dismissed') and resolution is not null
      and resolution = pg_catalog.btrim(resolution)
      and pg_catalog.char_length(resolution) between 1 and 2000)
    or (status in ('open', 'in_review') and resolution is null)
  )
);

create table private.admin_audit_logs (
  id uuid primary key default extensions.gen_random_uuid(),
  actor_user_id uuid references auth.users(id) on delete set null,
  action text not null,
  target_type text not null,
  target_id uuid,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default pg_catalog.now(),
  constraint admin_audit_logs_action_check check (
    action = pg_catalog.btrim(action) and pg_catalog.char_length(action) between 1 and 200
  ),
  constraint admin_audit_logs_target_type_check check (
    target_type = pg_catalog.btrim(target_type) and pg_catalog.char_length(target_type) between 1 and 200
  ),
  constraint admin_audit_logs_metadata_check check (pg_catalog.jsonb_typeof(metadata) = 'object')
);

create table private.analytics_events (
  id uuid primary key default extensions.gen_random_uuid(),
  event_name text not null,
  user_id uuid references auth.users(id) on delete set null,
  anonymous_session_id uuid,
  city_id uuid references public.cities(id) on delete set null,
  entity_type text,
  entity_id uuid,
  properties jsonb not null default '{}'::jsonb,
  event_key text not null unique,
  created_at timestamptz not null default pg_catalog.now(),
  constraint analytics_events_name_check check (
    event_name = pg_catalog.btrim(event_name) and pg_catalog.char_length(event_name) between 1 and 200
  ),
  constraint analytics_events_entity_type_check check (
    entity_type is null or (entity_type = pg_catalog.btrim(entity_type) and pg_catalog.char_length(entity_type) between 1 and 200)
  ),
  constraint analytics_events_properties_check check (pg_catalog.jsonb_typeof(properties) = 'object'),
  constraint analytics_events_key_check check (
    event_key = pg_catalog.btrim(event_key) and pg_catalog.char_length(event_key) between 1 and 200
  )
);

create table private.notification_jobs (
  id uuid primary key default extensions.gen_random_uuid(),
  event_type text not null,
  source_entity_type text not null,
  source_entity_id uuid not null,
  recipient_cursor uuid,
  status text not null default 'pending',
  attempt_count integer not null default 0,
  available_at timestamptz not null default pg_catalog.now(),
  last_error_code text,
  created_at timestamptz not null default pg_catalog.now(),
  updated_at timestamptz not null default pg_catalog.now(),
  constraint notification_jobs_source_key unique (event_type, source_entity_type, source_entity_id),
  constraint notification_jobs_event_type_check check (
    event_type = pg_catalog.btrim(event_type) and pg_catalog.char_length(event_type) between 1 and 200
  ),
  constraint notification_jobs_source_type_check check (
    source_entity_type = pg_catalog.btrim(source_entity_type) and pg_catalog.char_length(source_entity_type) between 1 and 200
  ),
  constraint notification_jobs_status_check check (status in ('pending', 'processing', 'completed', 'failed')),
  constraint notification_jobs_attempt_count_check check (attempt_count >= 0),
  constraint notification_jobs_error_code_check check (
    last_error_code is null or (last_error_code = pg_catalog.btrim(last_error_code) and pg_catalog.char_length(last_error_code) between 1 and 200)
  )
);

create table private.media_uploads (
  id uuid primary key default extensions.gen_random_uuid(),
  owner_user_id uuid references auth.users(id) on delete set null,
  target_type text not null,
  target_id uuid,
  object_path text not null unique,
  content_hash text not null,
  size_bytes bigint not null,
  expires_at timestamptz,
  status text not null default 'pending',
  created_at timestamptz not null default pg_catalog.now(),
  updated_at timestamptz not null default pg_catalog.now(),
  constraint media_uploads_target_type_check check (
    target_type = pg_catalog.btrim(target_type) and pg_catalog.char_length(target_type) between 1 and 200
  ),
  constraint media_uploads_object_path_check check (
    object_path = pg_catalog.btrim(object_path) and pg_catalog.char_length(object_path) between 1 and 1024
  ),
  constraint media_uploads_content_hash_check check (
    content_hash = pg_catalog.btrim(content_hash) and pg_catalog.char_length(content_hash) between 1 and 200
  ),
  constraint media_uploads_size_check check (size_bytes >= 0),
  constraint media_uploads_expiry_check check (expires_at is null or expires_at > created_at),
  constraint media_uploads_status_check check (status in ('pending', 'ready', 'expired', 'failed'))
);

create table private.rate_limit_buckets (
  user_id uuid not null references auth.users(id) on delete cascade,
  action text not null,
  window_started_at timestamptz not null,
  consumed integer not null default 0,
  expires_at timestamptz not null,
  primary key (user_id, action, window_started_at),
  constraint rate_limit_buckets_action_check check (
    action = pg_catalog.btrim(action) and pg_catalog.char_length(action) between 1 and 200
  ),
  constraint rate_limit_buckets_consumed_check check (consumed >= 0),
  constraint rate_limit_buckets_expiry_check check (expires_at > window_started_at)
);

create table private.group_owner_transfers (
  id uuid primary key default extensions.gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  from_user_id uuid not null references auth.users(id) on delete restrict,
  to_user_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'pending',
  accepted_at timestamptz,
  expires_at timestamptz not null,
  created_at timestamptz not null default pg_catalog.now(),
  updated_at timestamptz not null default pg_catalog.now(),
  constraint group_owner_transfers_users_check check (from_user_id <> to_user_id),
  constraint group_owner_transfers_status_check check (status in ('pending', 'accepted', 'cancelled', 'expired')),
  constraint group_owner_transfers_acceptance_check check (
    (status = 'accepted' and accepted_at is not null)
    or (status <> 'accepted' and accepted_at is null)
  ),
  constraint group_owner_transfers_expiry_check check (expires_at > created_at)
);

create unique index group_owner_transfers_one_pending_idx
on private.group_owner_transfers(group_id) where status = 'pending';

create table private.domain_event_receipts (
  id uuid primary key default extensions.gen_random_uuid(),
  event_type text not null,
  business_key text not null,
  first_processed_at timestamptz not null default pg_catalog.now(),
  entity_type text not null,
  entity_id uuid,
  constraint domain_event_receipts_event_business_key unique (event_type, business_key),
  constraint domain_event_receipts_event_type_check check (
    event_type = pg_catalog.btrim(event_type) and pg_catalog.char_length(event_type) between 1 and 200
  ),
  constraint domain_event_receipts_business_key_check check (
    business_key = pg_catalog.btrim(business_key) and pg_catalog.char_length(business_key) between 1 and 200
  ),
  constraint domain_event_receipts_entity_type_check check (
    entity_type = pg_catalog.btrim(entity_type) and pg_catalog.char_length(entity_type) between 1 and 200
  )
);

create index reports_status_created_idx on private.reports(status, created_at);
create index analytics_events_city_name_created_idx on private.analytics_events(city_id, event_name, created_at);
create index notification_jobs_status_available_idx on private.notification_jobs(status, available_at);
create index media_uploads_status_expires_idx on private.media_uploads(status, expires_at);
create index rate_limit_buckets_expires_idx on private.rate_limit_buckets(expires_at);
create index group_owner_transfers_status_expires_idx on private.group_owner_transfers(status, expires_at);
create index domain_event_receipts_processed_idx on private.domain_event_receipts(first_processed_at);

create trigger reports_set_updated_at before update on private.reports
for each row execute function private.set_updated_at();
create trigger notification_jobs_set_updated_at before update on private.notification_jobs
for each row execute function private.set_updated_at();
create trigger media_uploads_set_updated_at before update on private.media_uploads
for each row execute function private.set_updated_at();
create trigger group_owner_transfers_set_updated_at before update on private.group_owner_transfers
for each row execute function private.set_updated_at();

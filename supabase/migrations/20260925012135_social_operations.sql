create table public.user_follows (
  follower_id uuid not null references auth.users(id) on delete cascade,
  followed_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default pg_catalog.now(),
  primary key (follower_id, followed_id),
  constraint user_follows_no_self_check check (follower_id <> followed_id)
);

create table public.posts (
  id uuid primary key default extensions.gen_random_uuid(),
  author_user_id uuid references auth.users(id) on delete set null,
  group_id uuid references public.groups(id) on delete restrict,
  body text not null,
  image_url text,
  visibility text not null,
  created_at timestamptz not null default pg_catalog.now(),
  updated_at timestamptz not null default pg_catalog.now(),
  deleted_at timestamptz,
  constraint posts_body_check check (
    body = pg_catalog.btrim(body) and pg_catalog.char_length(body) between 1 and 2000
  ),
  constraint posts_image_url_check check (
    image_url is null or (
      image_url = pg_catalog.btrim(image_url) and pg_catalog.char_length(image_url) between 1 and 2048
    )
  ),
  constraint posts_visibility_check check (visibility in ('public', 'members_only', 'private')),
  constraint posts_scope_visibility_check check (
    (group_id is null and author_user_id is not null and visibility in ('public', 'private'))
    or (group_id is not null and visibility in ('public', 'members_only'))
  )
);

create table public.post_likes (
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default pg_catalog.now(),
  primary key (post_id, user_id)
);

create table public.comments (
  id uuid primary key default extensions.gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid references auth.users(id) on delete set null,
  body text not null,
  created_at timestamptz not null default pg_catalog.now(),
  updated_at timestamptz not null default pg_catalog.now(),
  deleted_at timestamptz,
  constraint comments_body_check check (
    body = pg_catalog.btrim(body) and pg_catalog.char_length(body) between 1 and 1000
  )
);

create table public.activity_events (
  id uuid primary key default extensions.gen_random_uuid(),
  actor_user_id uuid references auth.users(id) on delete set null,
  group_id uuid references public.groups(id) on delete set null,
  event_type text not null,
  entity_type text not null,
  entity_id uuid not null,
  metadata jsonb not null default '{}'::jsonb,
  dedupe_key text not null unique,
  created_at timestamptz not null default pg_catalog.now(),
  constraint activity_events_type_check check (event_type in ('run_created', 'run_joined', 'group_joined')),
  constraint activity_events_entity_type_check check (
    entity_type = pg_catalog.btrim(entity_type) and pg_catalog.char_length(entity_type) between 1 and 80
  ),
  constraint activity_events_metadata_check check (pg_catalog.jsonb_typeof(metadata) = 'object'),
  constraint activity_events_dedupe_key_check check (
    dedupe_key = pg_catalog.btrim(dedupe_key) and pg_catalog.char_length(dedupe_key) between 1 and 200
  )
);

create table public.notifications (
  id uuid primary key default extensions.gen_random_uuid(),
  recipient_user_id uuid not null references auth.users(id) on delete cascade,
  actor_user_id uuid references auth.users(id) on delete set null,
  type text not null,
  target_type text not null,
  target_id uuid,
  dedupe_key text not null,
  read_at timestamptz,
  created_at timestamptz not null default pg_catalog.now(),
  constraint notifications_recipient_dedupe_key unique (recipient_user_id, dedupe_key),
  constraint notifications_type_check check (
    type = pg_catalog.btrim(type) and pg_catalog.char_length(type) between 1 and 80
  ),
  constraint notifications_target_type_check check (
    target_type = pg_catalog.btrim(target_type) and pg_catalog.char_length(target_type) between 1 and 80
  ),
  constraint notifications_dedupe_key_check check (
    dedupe_key = pg_catalog.btrim(dedupe_key) and pg_catalog.char_length(dedupe_key) between 1 and 200
  )
);

create index user_follows_followed_id_idx on public.user_follows(followed_id);
create index posts_author_created_idx on public.posts(author_user_id, created_at desc) where deleted_at is null;
create index posts_group_created_idx on public.posts(group_id, created_at desc) where deleted_at is null;
create index comments_post_created_idx on public.comments(post_id, created_at) where deleted_at is null;
create index activity_events_actor_created_idx on public.activity_events(actor_user_id, created_at desc);
create index activity_events_group_created_idx on public.activity_events(group_id, created_at desc);
create index notifications_recipient_read_created_idx on public.notifications(recipient_user_id, read_at, created_at desc);

create trigger posts_set_updated_at before update on public.posts
for each row execute function private.set_updated_at();
create trigger comments_set_updated_at before update on public.comments
for each row execute function private.set_updated_at();

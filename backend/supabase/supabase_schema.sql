-- Family Garden Supabase schema
-- Run this in Supabase Dashboard → SQL Editor.
-- This MVP uses a fixed text family_id: Happy_birthday_David.

create extension if not exists pgcrypto;

create table if not exists public.family_members (
  id uuid primary key default gen_random_uuid(),
  family_id text not null,
  role_key text not null,
  display_name text not null,
  is_online boolean default false,
  last_seen_at timestamptz default now(),
  created_at timestamptz default now()
);

create table if not exists public.travel_places (
  id uuid primary key default gen_random_uuid(),
  family_id text not null,
  member_id uuid null,
  title text not null,
  note text,
  map_x double precision not null,
  map_y double precision not null,
  photo_path text,
  created_at timestamptz default now()
);

create table if not exists public.postcards (
  id uuid primary key default gen_random_uuid(),
  family_id text not null,
  place_id uuid null,
  member_id uuid null,
  title text not null,
  message text,
  photo_path text,
  is_new boolean default true,
  created_at timestamptz default now()
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  family_id text not null,
  member_id uuid null,
  author_name text,
  body text not null,
  created_at timestamptz default now()
);

create table if not exists public.mailbox_events (
  id uuid primary key default gen_random_uuid(),
  family_id text not null,
  type text not null,
  title text,
  message text,
  target_id uuid null,
  is_read boolean default false,
  created_at timestamptz default now()
);

alter table public.family_members enable row level security;
alter table public.travel_places enable row level security;
alter table public.postcards enable row level security;
alter table public.messages enable row level security;
alter table public.mailbox_events enable row level security;

-- Drop old MVP policies if rerunning.
drop policy if exists "fg_select_members" on public.family_members;
drop policy if exists "fg_insert_members" on public.family_members;
drop policy if exists "fg_update_members" on public.family_members;
drop policy if exists "fg_delete_members" on public.family_members;

drop policy if exists "fg_select_places" on public.travel_places;
drop policy if exists "fg_insert_places" on public.travel_places;
drop policy if exists "fg_update_places" on public.travel_places;
drop policy if exists "fg_delete_places" on public.travel_places;

drop policy if exists "fg_select_postcards" on public.postcards;
drop policy if exists "fg_insert_postcards" on public.postcards;
drop policy if exists "fg_update_postcards" on public.postcards;
drop policy if exists "fg_delete_postcards" on public.postcards;

drop policy if exists "fg_select_messages" on public.messages;
drop policy if exists "fg_insert_messages" on public.messages;
drop policy if exists "fg_update_messages" on public.messages;
drop policy if exists "fg_delete_messages" on public.messages;

drop policy if exists "fg_select_mailbox" on public.mailbox_events;
drop policy if exists "fg_insert_mailbox" on public.mailbox_events;
drop policy if exists "fg_update_mailbox" on public.mailbox_events;
drop policy if exists "fg_delete_mailbox" on public.mailbox_events;

-- MVP policies for one private family id.
-- This is simple but not strong authentication. Do not publish widely yet.
create policy "fg_select_members" on public.family_members
for select to anon using (family_id = 'Happy_birthday_David');
create policy "fg_insert_members" on public.family_members
for insert to anon with check (family_id = 'Happy_birthday_David');
create policy "fg_update_members" on public.family_members
for update to anon using (family_id = 'Happy_birthday_David') with check (family_id = 'Happy_birthday_David');
create policy "fg_delete_members" on public.family_members
for delete to anon using (family_id = 'Happy_birthday_David');

create policy "fg_select_places" on public.travel_places
for select to anon using (family_id = 'Happy_birthday_David');
create policy "fg_insert_places" on public.travel_places
for insert to anon with check (family_id = 'Happy_birthday_David');
create policy "fg_update_places" on public.travel_places
for update to anon using (family_id = 'Happy_birthday_David') with check (family_id = 'Happy_birthday_David');
create policy "fg_delete_places" on public.travel_places
for delete to anon using (family_id = 'Happy_birthday_David');

create policy "fg_select_postcards" on public.postcards
for select to anon using (family_id = 'Happy_birthday_David');
create policy "fg_insert_postcards" on public.postcards
for insert to anon with check (family_id = 'Happy_birthday_David');
create policy "fg_update_postcards" on public.postcards
for update to anon using (family_id = 'Happy_birthday_David') with check (family_id = 'Happy_birthday_David');
create policy "fg_delete_postcards" on public.postcards
for delete to anon using (family_id = 'Happy_birthday_David');

create policy "fg_select_messages" on public.messages
for select to anon using (family_id = 'Happy_birthday_David');
create policy "fg_insert_messages" on public.messages
for insert to anon with check (family_id = 'Happy_birthday_David');
create policy "fg_update_messages" on public.messages
for update to anon using (family_id = 'Happy_birthday_David') with check (family_id = 'Happy_birthday_David');
create policy "fg_delete_messages" on public.messages
for delete to anon using (family_id = 'Happy_birthday_David');

create policy "fg_select_mailbox" on public.mailbox_events
for select to anon using (family_id = 'Happy_birthday_David');
create policy "fg_insert_mailbox" on public.mailbox_events
for insert to anon with check (family_id = 'Happy_birthday_David');
create policy "fg_update_mailbox" on public.mailbox_events
for update to anon using (family_id = 'Happy_birthday_David') with check (family_id = 'Happy_birthday_David');
create policy "fg_delete_mailbox" on public.mailbox_events
for delete to anon using (family_id = 'Happy_birthday_David');

-- Storage bucket for photos.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'family-photos',
  'family-photos',
  true,
  6291456,
  array['image/png', 'image/jpeg', 'image/webp']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "fg_storage_select" on storage.objects;
drop policy if exists "fg_storage_insert" on storage.objects;
drop policy if exists "fg_storage_update" on storage.objects;
drop policy if exists "fg_storage_delete" on storage.objects;

create policy "fg_storage_select" on storage.objects
for select to anon
using (
  bucket_id = 'family-photos'
  and (storage.foldername(name))[1] = 'Happy_birthday_David'
);

create policy "fg_storage_insert" on storage.objects
for insert to anon
with check (
  bucket_id = 'family-photos'
  and (storage.foldername(name))[1] = 'Happy_birthday_David'
);

create policy "fg_storage_update" on storage.objects
for update to anon
using (
  bucket_id = 'family-photos'
  and (storage.foldername(name))[1] = 'Happy_birthday_David'
)
with check (
  bucket_id = 'family-photos'
  and (storage.foldername(name))[1] = 'Happy_birthday_David'
);

create policy "fg_storage_delete" on storage.objects
for delete to anon
using (
  bucket_id = 'family-photos'
  and (storage.foldername(name))[1] = 'Happy_birthday_David'
);

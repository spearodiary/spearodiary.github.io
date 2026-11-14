-- Spearfisher's Notebook: run once in Supabase → SQL Editor → New query → Run.
-- Every row belongs to one user. Row level security makes sure people only see their own data.

create table if not exists public.entries (
  user_id    uuid not null default auth.uid() references auth.users on delete cascade,
  id         text not null,
  data       jsonb not null,
  updated_at timestamptz not null default now(),
  primary key (user_id, id)
);
alter table public.entries enable row level security;
drop policy if exists "own entries" on public.entries;
create policy "own entries" on public.entries
  for all to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Previous versions of every entry. The page only ever adds rows here.
create table if not exists public.history (
  hid      bigserial primary key,
  user_id  uuid not null default auth.uid() references auth.users on delete cascade,
  entry_id text not null,
  saved_at bigint not null,
  deleted  boolean not null default false,
  data     jsonb not null
);
create index if not exists history_user_saved on public.history (user_id, saved_at desc);
alter table public.history enable row level security;
drop policy if exists "own history read" on public.history;
drop policy if exists "own history add" on public.history;
create policy "own history read" on public.history for select to authenticated using (auth.uid() = user_id);
create policy "own history add"  on public.history for insert to authenticated with check (auth.uid() = user_id);

-- Photos and app screenshots: a private bucket, one folder per user.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('photos', 'photos', false, 20971520, array['image/jpeg','image/png','image/webp'])
on conflict (id) do nothing;

drop policy if exists "own photos read" on storage.objects;
drop policy if exists "own photos add" on storage.objects;
create policy "own photos read" on storage.objects for select to authenticated
  using (bucket_id = 'photos' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "own photos add" on storage.objects for insert to authenticated
  with check (bucket_id = 'photos' and (storage.foldername(name))[1] = auth.uid()::text);

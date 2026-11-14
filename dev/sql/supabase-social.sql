-- Spearo Diary: social (follow, search, feed, likes, comments). Run after supabase-friends.sql.
-- Run each part separately in Supabase → SQL Editor. Safe to run again.

-- ===== PART 1 =====
alter table public.profiles add column if not exists username text;
alter table public.profiles add column if not exists discoverable boolean not null default false;
alter table public.profiles add column if not exists private boolean not null default true;
create unique index if not exists profiles_username_key on public.profiles (username);
alter table public.profiles drop constraint if exists profiles_username_chk;
alter table public.profiles add constraint profiles_username_chk
  check (username is null or username ~ '^[a-z0-9._]{3,20}$');

create table if not exists public.follows(
  follower uuid not null references auth.users on delete cascade,
  followee uuid not null references auth.users on delete cascade,
  status text not null default 'pending' check (status in ('pending','accepted')),
  created_at timestamptz default now(),
  primary key (follower, followee), check (follower <> followee));
alter table public.follows enable row level security;
drop policy if exists "see own follows" on public.follows;
create policy "see own follows" on public.follows for select to authenticated
  using (auth.uid() in (follower, followee));

insert into public.follows(follower, followee, status)
  select a, b, 'accepted' from public.friends where status = 'accepted'
  union all
  select b, a, 'accepted' from public.friends where status = 'accepted'
on conflict do nothing;

create or replace function public.can_see(o uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select o = auth.uid()
    or exists(select 1 from follows where follower = auth.uid() and followee = o and status = 'accepted')
    or exists(select 1 from profiles where user_id = o and discoverable and not private);
$$;

-- ===== PART 2 =====
alter table public.shared_catches add column if not exists caught text
  generated always as (data->>'date') stored;
create index if not exists shared_catches_feed on public.shared_catches (user_id, caught desc);
drop policy if exists "friends read shared" on public.shared_catches;
drop policy if exists "followers read shared" on public.shared_catches;
create policy "followers read shared" on public.shared_catches for select to authenticated
  using (public.can_see(user_id));

create table if not exists public.likes(
  owner uuid not null,
  entry_id text not null,
  user_id uuid not null default auth.uid() references auth.users on delete cascade,
  created_at timestamptz default now(),
  primary key (owner, entry_id, user_id),
  foreign key (owner, entry_id) references public.shared_catches(user_id, entry_id) on delete cascade);
alter table public.likes enable row level security;
drop policy if exists "read likes" on public.likes;
create policy "read likes" on public.likes for select to authenticated using (public.can_see(owner));
drop policy if exists "add like" on public.likes;
create policy "add like" on public.likes for insert to authenticated
  with check (user_id = auth.uid() and public.can_see(owner));
drop policy if exists "remove like" on public.likes;
create policy "remove like" on public.likes for delete to authenticated using (user_id = auth.uid());

-- ===== PART 3 =====
create table if not exists public.comments(
  id bigint generated always as identity primary key,
  owner uuid not null,
  entry_id text not null,
  user_id uuid not null default auth.uid() references auth.users on delete cascade,
  body text not null check (char_length(body) between 1 and 500),
  created_at timestamptz default now(),
  foreign key (owner, entry_id) references public.shared_catches(user_id, entry_id) on delete cascade);
create index if not exists comments_entry on public.comments (owner, entry_id);
alter table public.comments enable row level security;
drop policy if exists "read comments" on public.comments;
create policy "read comments" on public.comments for select to authenticated using (public.can_see(owner));
drop policy if exists "add comment" on public.comments;
create policy "add comment" on public.comments for insert to authenticated
  with check (user_id = auth.uid() and public.can_see(owner));
drop policy if exists "remove comment" on public.comments;
create policy "remove comment" on public.comments for delete to authenticated
  using (user_id = auth.uid() or owner = auth.uid());

drop policy if exists "friends read shared photos" on storage.objects;
drop policy if exists "followers read shared photos" on storage.objects;
create policy "followers read shared photos" on storage.objects for select to authenticated
  using (bucket_id = 'photos' and (storage.foldername(name))[2] = 'share'
         and public.can_see(((storage.foldername(name))[1])::uuid));

-- ===== PART 4 =====
create or replace function public.follow(o uuid) returns text
language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); s text;
begin
  if me is null or o is null or o = me then return 'self'; end if;
  if not exists(select 1 from profiles where user_id = o) then return 'not_found'; end if;
  s := case when exists(select 1 from profiles where user_id = o and not private) then 'accepted' else 'pending' end;
  insert into follows(follower, followee, status) values (me, o, s) on conflict do nothing;
  select status into s from follows where follower = me and followee = o;
  return s;
end $$;

create or replace function public.unfollow(o uuid) returns void
language sql security definer set search_path = public as $$
  delete from follows where follower = auth.uid() and followee = o;
$$;

create or replace function public.follower_accept(o uuid) returns void
language sql security definer set search_path = public as $$
  update follows set status = 'accepted' where follower = o and followee = auth.uid();
$$;

create or replace function public.follower_remove(o uuid) returns void
language sql security definer set search_path = public as $$
  delete from follows where follower = o and followee = auth.uid();
$$;

create or replace function public.username_free(u text) returns boolean
language sql stable security definer set search_path = public as $$
  select not exists(select 1 from profiles where username = lower(trim(u)) and user_id <> auth.uid());
$$;

-- ===== PART 5 =====
create or replace function public.search_profiles(q text)
returns table(id uuid, username text, name text, private boolean, status text)
language sql stable security definer set search_path = public as $$
  select p.user_id, p.username, p.name, p.private,
    (select f.status from follows f where f.follower = auth.uid() and f.followee = p.user_id)
  from profiles p
  where p.discoverable and p.user_id <> auth.uid() and length(trim(q)) >= 2
    and (p.username like replace(lower(trim(q)), '@', '') || '%' or p.name ilike '%' || trim(q) || '%')
  order by (p.username = replace(lower(trim(q)), '@', '')) desc, p.username nulls last
  limit 20;
$$;

create or replace function public.profile_get(o uuid)
returns table(id uuid, username text, name text, private boolean, followers int, following int,
              fish int, status text, follows_me text, visible boolean)
language sql stable security definer set search_path = public as $$
  select p.user_id, p.username, p.name, p.private,
    (select count(*)::int from follows where followee = p.user_id and status = 'accepted'),
    (select count(*)::int from follows where follower = p.user_id and status = 'accepted'),
    case when public.can_see(p.user_id) then
      (select coalesce(sum(coalesce((c->>'count')::int, 1)), 0)::int
       from shared_catches s, jsonb_array_elements(s.data->'catches') c where s.user_id = p.user_id) end,
    (select status from follows where follower = auth.uid() and followee = p.user_id),
    (select status from follows where follower = p.user_id and followee = auth.uid()),
    public.can_see(p.user_id)
  from profiles p where p.user_id = o;
$$;

create or replace function public.my_follows()
returns table(id uuid, username text, name text, kind text, status text, created_at timestamptz)
language sql stable security definer set search_path = public as $$
  select f.followee, p.username, p.name, 'following', f.status, f.created_at
    from follows f left join profiles p on p.user_id = f.followee where f.follower = auth.uid()
  union all
  select f.follower, p.username, p.name, 'follower', f.status, f.created_at
    from follows f left join profiles p on p.user_id = f.follower where f.followee = auth.uid();
$$;

create or replace function public.profile_cards(ids uuid[])
returns table(id uuid, username text, name text)
language sql stable security definer set search_path = public as $$
  select user_id, username, name from profiles where user_id = any(ids);
$$;

revoke all on function public.can_see(uuid), public.follow(uuid), public.unfollow(uuid),
  public.follower_accept(uuid), public.follower_remove(uuid), public.username_free(text),
  public.search_profiles(text), public.profile_get(uuid), public.my_follows(),
  public.profile_cards(uuid[]) from public, anon;
grant execute on function public.can_see(uuid), public.follow(uuid), public.unfollow(uuid),
  public.follower_accept(uuid), public.follower_remove(uuid), public.username_free(text),
  public.search_profiles(text), public.profile_get(uuid), public.my_follows(),
  public.profile_cards(uuid[]) to authenticated;

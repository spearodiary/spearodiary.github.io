-- Spearo Diary: Amigos (run once in Supabase → SQL Editor → New query → Run)

create table if not exists public.profiles(
  user_id uuid primary key references auth.users on delete cascade,
  name text,
  code text unique not null default substr(md5(random()::text || clock_timestamp()::text),1,8),
  share jsonb not null default '{}'::jsonb,
  updated_at timestamptz default now());
alter table public.profiles enable row level security;
drop policy if exists "own profile" on public.profiles;
create policy "own profile" on public.profiles for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

create table if not exists public.friends(
  a uuid not null references auth.users on delete cascade,
  b uuid not null references auth.users on delete cascade,
  status text not null default 'pending' check (status in ('pending','accepted')),
  requested_by uuid not null,
  created_at timestamptz default now(),
  primary key (a,b), check (a < b));
alter table public.friends enable row level security;
drop policy if exists "see own friendships" on public.friends;
create policy "see own friendships" on public.friends for select to authenticated
  using (auth.uid() in (a,b));

create or replace function public.is_friend(o uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists(select 1 from friends where status='accepted'
    and ((a=auth.uid() and b=o) or (b=auth.uid() and a=o)));
$$;

create table if not exists public.shared_catches(
  user_id uuid not null references auth.users on delete cascade,
  entry_id text not null,
  data jsonb not null,
  updated_at timestamptz default now(),
  primary key (user_id, entry_id));
alter table public.shared_catches enable row level security;
drop policy if exists "own shared" on public.shared_catches;
create policy "own shared" on public.shared_catches for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists "friends read shared" on public.shared_catches;
create policy "friends read shared" on public.shared_catches for select to authenticated
  using (public.is_friend(user_id));

create or replace function public.friend_request(c text) returns text
language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); o uuid; s text;
begin
  if me is null then raise exception 'not signed in'; end if;
  select user_id into o from profiles where code = lower(trim(c));
  if o is null then return 'not_found'; end if;
  if o = me then return 'self'; end if;
  insert into friends(a,b,status,requested_by) values (least(me,o), greatest(me,o), 'pending', me)
  on conflict (a,b) do update
    set status = case when friends.requested_by <> me then 'accepted' else friends.status end;
  select status into s from friends where a = least(me,o) and b = greatest(me,o);
  return s;
end $$;

create or replace function public.friend_accept(o uuid) returns void
language sql security definer set search_path = public as $$
  update friends set status='accepted'
  where a = least(auth.uid(),o) and b = greatest(auth.uid(),o) and requested_by <> auth.uid();
$$;

create or replace function public.friend_remove(o uuid) returns void
language sql security definer set search_path = public as $$
  delete from friends where a = least(auth.uid(),o) and b = greatest(auth.uid(),o);
$$;

create or replace function public.friend_list() returns table(id uuid, name text, status text, mine boolean)
language sql stable security definer set search_path = public as $$
  select case when f.a = auth.uid() then f.b else f.a end, p.name, f.status, f.requested_by = auth.uid()
  from friends f
  left join profiles p on p.user_id = case when f.a = auth.uid() then f.b else f.a end
  where auth.uid() in (f.a, f.b)
  order by f.status, p.name;
$$;

revoke all on function public.is_friend(uuid), public.friend_request(text), public.friend_accept(uuid),
  public.friend_remove(uuid), public.friend_list() from public, anon;
grant execute on function public.is_friend(uuid), public.friend_request(text), public.friend_accept(uuid),
  public.friend_remove(uuid), public.friend_list() to authenticated;

-- friends may open only the cleaned copies of photos in <owner>/share/
drop policy if exists "friends read shared photos" on storage.objects;
create policy "friends read shared photos" on storage.objects for select to authenticated
  using (bucket_id = 'photos' and (storage.foldername(name))[2] = 'share'
         and public.is_friend(((storage.foldername(name))[1])::uuid));

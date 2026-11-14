-- Spearo Diary: show/hide single posts, a master switch, and feed by publication date.
-- Safe to run more than once. Nothing is deleted.
alter table public.profiles add column if not exists paused boolean not null default false;

create or replace function public.can_see(o uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select o = auth.uid()
    or (not exists(select 1 from profiles where user_id = o and paused)
        and (exists(select 1 from follows where follower = auth.uid() and followee = o and status = 'accepted')
             or exists(select 1 from profiles where user_id = o and discoverable and not private)));
$$;

alter table public.shared_catches add column if not exists hidden boolean not null default false;
alter table public.shared_catches add column if not exists published_at timestamptz not null default now();
update public.shared_catches set published_at = updated_at where updated_at is not null and published_at > updated_at;
create index if not exists shared_catches_pub on public.shared_catches (published_at desc);

drop policy if exists "followers read shared" on public.shared_catches;
create policy "followers read shared" on public.shared_catches for select to authenticated
  using (user_id = auth.uid() or (not hidden and public.can_see(user_id)));

drop policy if exists "avatars readable" on storage.objects;
create policy "avatars readable" on storage.objects for select to authenticated
  using (bucket_id = 'photos' and name like '%/share/avatar.jpg');

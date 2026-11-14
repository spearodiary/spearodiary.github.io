alter table public.profiles add column if not exists paused boolean not null default false;

create or replace function public.can_see(o uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select o = auth.uid()
    or (not exists(select 1 from profiles where user_id = o and paused)
        and (exists(select 1 from follows where follower = auth.uid() and followee = o and status = 'accepted')
             or exists(select 1 from profiles where user_id = o and discoverable and not private)));
$$;

drop policy if exists "avatars readable" on storage.objects;
create policy "avatars readable" on storage.objects for select to authenticated
  using (bucket_id = 'photos' and name like '%/share/avatar.jpg');

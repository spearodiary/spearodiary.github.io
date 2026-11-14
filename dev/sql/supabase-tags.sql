-- Spearo Diary: friends tagged in a post can see it, its photos, and share it.
-- Safe to run more than once. Nothing is deleted.
create or replace function public.tagged_by(o uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select not exists(select 1 from profiles where user_id = o and paused)
     and exists(select 1 from shared_catches s
                where s.user_id = o and not s.hidden and (s.data->'with') ? auth.uid()::text);
$$;

drop policy if exists "followers read shared" on public.shared_catches;
create policy "followers read shared" on public.shared_catches for select to authenticated
  using (user_id = auth.uid()
         or (not hidden and (public.can_see(user_id)
             or ((data->'with') ? auth.uid()::text
                 and not exists(select 1 from public.profiles p where p.user_id = shared_catches.user_id and p.paused)))));

drop policy if exists "tagged read shared photos" on storage.objects;
create policy "tagged read shared photos" on storage.objects for select to authenticated
  using (bucket_id = 'photos' and (storage.foldername(name))[2] = 'share'
         and public.tagged_by(((storage.foldername(name))[1])::uuid));

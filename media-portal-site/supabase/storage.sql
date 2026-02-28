insert into storage.buckets (id, name, public)
values ('project-files', 'project-files', false)
on conflict (id) do nothing;

create policy "admin all files"
on storage.objects for all
using (bucket_id = 'project-files' and public.is_admin(auth.uid()))
with check (bucket_id = 'project-files' and public.is_admin(auth.uid()));

create policy "client own project files with active boost"
on storage.objects for all
using (
  bucket_id = 'project-files'
  and public.is_boost_active(auth.uid())
  and split_part(name, '/', 1) = 'client'
  and split_part(name, '/', 2) = auth.uid()::text
)
with check (
  bucket_id = 'project-files'
  and public.is_boost_active(auth.uid())
  and split_part(name, '/', 1) = 'client'
  and split_part(name, '/', 2) = auth.uid()::text
);

-- Migration 4: Supabase Storage Bucket & Access Policies for Property Images
-- Reference: docs/SCHEMA.md Section 8

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'property-images',
  'property-images',
  true,
  1048576,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'property_images_bucket_public_select'
  ) then
    create policy "property_images_bucket_public_select"
      on storage.objects
      for select
      to public
      using (bucket_id = 'property-images');
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'property_images_bucket_admin_insert'
  ) then
    create policy "property_images_bucket_admin_insert"
      on storage.objects
      for insert
      to authenticated
      with check (bucket_id = 'property-images' and public.is_admin());
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'property_images_bucket_admin_update'
  ) then
    create policy "property_images_bucket_admin_update"
      on storage.objects
      for update
      to authenticated
      using (bucket_id = 'property-images' and public.is_admin())
      with check (bucket_id = 'property-images' and public.is_admin());
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'property_images_bucket_admin_delete'
  ) then
    create policy "property_images_bucket_admin_delete"
      on storage.objects
      for delete
      to authenticated
      using (bucket_id = 'property-images' and public.is_admin());
  end if;
end $$;

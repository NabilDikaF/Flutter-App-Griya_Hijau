-- Migration 2: Row Level Security (RLS) & Admin Role Helpers
-- Reference: docs/SCHEMA.md Sections 4 & 5

create or replace function public.is_admin()
returns boolean
language sql
stable
set search_path = public
as $$
  select coalesce(auth.jwt() -> 'app_metadata' ->> 'role', '') = 'admin';
$$;

-- Enable RLS on all 7 tables
alter table public.property_categories enable row level security;
alter table public.locations enable row level security;
alter table public.properties enable row level security;
alter table public.property_images enable row level security;
alter table public.property_view_logs enable row level security;
alter table public.search_logs enable row level security;
alter table public.bookings enable row level security;

-- Revoke direct write access on log tables and bookings delete for extra safety
revoke insert, update, delete on public.property_view_logs from anon, authenticated;
revoke insert, update, delete on public.search_logs from anon, authenticated;
revoke insert, delete on public.bookings from anon, authenticated;
revoke update on public.bookings from anon;

-- 1. property_categories
create policy "property_categories_anon_select_active"
  on public.property_categories
  for select
  to anon
  using (is_active = true);

create policy "property_categories_admin_select_all"
  on public.property_categories
  for select
  to authenticated
  using (public.is_admin());

create policy "property_categories_admin_insert"
  on public.property_categories
  for insert
  to authenticated
  with check (public.is_admin());

create policy "property_categories_admin_update"
  on public.property_categories
  for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create policy "property_categories_admin_delete"
  on public.property_categories
  for delete
  to authenticated
  using (public.is_admin());

-- 2. locations
create policy "locations_anon_select_all"
  on public.locations
  for select
  to anon
  using (true);

create policy "locations_admin_select_all"
  on public.locations
  for select
  to authenticated
  using (public.is_admin());

create policy "locations_admin_insert"
  on public.locations
  for insert
  to authenticated
  with check (public.is_admin());

create policy "locations_admin_update"
  on public.locations
  for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create policy "locations_admin_delete"
  on public.locations
  for delete
  to authenticated
  using (public.is_admin());

-- 3. properties
create policy "properties_anon_select_published"
  on public.properties
  for select
  to anon
  using (is_published = true);

create policy "properties_admin_select_all"
  on public.properties
  for select
  to authenticated
  using (public.is_admin());

create policy "properties_admin_insert"
  on public.properties
  for insert
  to authenticated
  with check (public.is_admin());

create policy "properties_admin_update"
  on public.properties
  for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create policy "properties_admin_delete"
  on public.properties
  for delete
  to authenticated
  using (public.is_admin());

-- 4. property_images
create policy "property_images_anon_select_published"
  on public.property_images
  for select
  to anon
  using (
    exists (
      select 1
      from public.properties p
      where p.id = property_images.property_id
        and p.is_published = true
    )
  );

create policy "property_images_admin_select_all"
  on public.property_images
  for select
  to authenticated
  using (public.is_admin());

create policy "property_images_admin_insert"
  on public.property_images
  for insert
  to authenticated
  with check (public.is_admin());

create policy "property_images_admin_update"
  on public.property_images
  for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create policy "property_images_admin_delete"
  on public.property_images
  for delete
  to authenticated
  using (public.is_admin());

-- 5. property_view_logs (admin read-only; customer writes only via record_property_view RPC)
create policy "property_view_logs_admin_select"
  on public.property_view_logs
  for select
  to authenticated
  using (public.is_admin());

-- 6. search_logs (admin read-only; customer writes only via search_properties RPC)
create policy "search_logs_admin_select"
  on public.search_logs
  for select
  to authenticated
  using (public.is_admin());

-- 7. bookings (admin read + update only, no delete; customer creates via create_booking RPC)
create policy "bookings_admin_select"
  on public.bookings
  for select
  to authenticated
  using (public.is_admin());

create policy "bookings_admin_update"
  on public.bookings
  for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- Manual First Admin Account Setup (run after creating admin user in Supabase Auth Dashboard):
-- Disabled public signups should remain OFF in Supabase Auth Settings.
-- Replace '<admin-email>' with the email you created manually in Authentication -> Users:
--
-- update auth.users
--    set raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb) || '{"role": "admin"}'::jsonb
--  where email = '<admin-email>';

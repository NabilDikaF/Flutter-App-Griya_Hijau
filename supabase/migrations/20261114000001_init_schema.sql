-- Migration 1: Initial Schema (7 Tables & 4 Enums) — Paket Semi Full
-- Reference: docs/SCHEMA.md

create type public.availability_status as enum ('available', 'booked', 'sold');
create type public.intent_type as enum ('survey_location', 'book_unit');
create type public.payment_plan as enum ('kpr', 'cash_hard', 'cash_installment');
create type public.funnel_status as enum (
  'new',
  'contacted',
  'survey_scheduled',
  'office_visit',
  'closed_won',
  'closed_lost'
);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- 1. property_categories
create table public.property_categories (
  id bigint generated always as identity primary key,
  name text not null,
  slug text not null unique,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger trg_property_categories_set_updated_at
  before update on public.property_categories
  for each row
  execute function public.set_updated_at();

-- 2. locations
create table public.locations (
  id bigint generated always as identity primary key,
  city text not null,
  district text not null,
  slug text not null unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint locations_city_district_unique unique (city, district)
);

create trigger trg_locations_set_updated_at
  before update on public.locations
  for each row
  execute function public.set_updated_at();

-- 3. properties
create table public.properties (
  id bigint generated always as identity primary key,
  property_category_id bigint not null references public.property_categories(id) on delete restrict,
  location_id bigint not null references public.locations(id) on delete restrict,
  title text not null,
  slug text not null unique,
  price bigint not null check (price >= 0),
  building_area integer check (building_area >= 0),
  land_area integer check (land_area >= 0),
  bedrooms smallint check (bedrooms >= 0),
  bathrooms smallint check (bathrooms >= 0),
  floors smallint check (floors >= 0),
  electricity text,
  certificate_type text,
  description text,
  address_detail text,
  latitude double precision check (latitude between -90 and 90),
  longitude double precision check (longitude between -180 and 180),
  google_maps_url text,
  availability_status public.availability_status not null default 'available',
  views_count bigint not null default 0 check (views_count >= 0),
  is_published boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_properties_published_availability
  on public.properties (is_published, availability_status);

create index idx_properties_category_id
  on public.properties (property_category_id);

create index idx_properties_location_id
  on public.properties (location_id);

create index idx_properties_text_search
  on public.properties
  using gin (to_tsvector('simple', coalesce(title, '') || ' ' || coalesce(address_detail, '')));

create trigger trg_properties_set_updated_at
  before update on public.properties
  for each row
  execute function public.set_updated_at();

-- 4. property_images
create table public.property_images (
  id bigint generated always as identity primary key,
  property_id bigint not null references public.properties(id) on delete cascade,
  image_path text not null,
  is_primary boolean not null default false,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index idx_property_images_one_primary
  on public.property_images (property_id)
  where is_primary = true;

create index idx_property_images_property_sort
  on public.property_images (property_id, sort_order, id);

create trigger trg_property_images_set_updated_at
  before update on public.property_images
  for each row
  execute function public.set_updated_at();

-- 5. property_view_logs
create table public.property_view_logs (
  id bigint generated always as identity primary key,
  property_id bigint not null references public.properties(id) on delete cascade,
  ip_address text,
  user_agent text,
  viewed_at timestamptz not null default now()
);

create index idx_property_view_logs_property_viewed_at
  on public.property_view_logs (property_id, viewed_at);

-- 6. search_logs
create table public.search_logs (
  id bigint generated always as identity primary key,
  keyword text,
  location_id bigint references public.locations(id) on delete set null,
  property_category_id bigint references public.property_categories(id) on delete set null,
  results_count integer not null check (results_count >= 0),
  searched_at timestamptz not null default now()
);

create index idx_search_logs_searched_at
  on public.search_logs (searched_at);

-- 7. bookings
create table public.bookings (
  id bigint generated always as identity primary key,
  booking_code text not null unique,
  property_id bigint not null references public.properties(id) on delete restrict,
  customer_name text not null check (length(btrim(customer_name)) > 0),
  customer_whatsapp text not null check (customer_whatsapp ~ '^628[0-9]{8,12}$'),
  intent_type public.intent_type not null,
  preferred_survey_date timestamptz,
  confirmed_survey_date timestamptz,
  payment_plan public.payment_plan,
  customer_notes text,
  funnel_status public.funnel_status not null default 'new',
  admin_notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint bookings_survey_requires_date
    check (intent_type <> 'survey_location' or preferred_survey_date is not null),
  constraint bookings_unit_requires_payment_plan
    check (intent_type <> 'book_unit' or payment_plan is not null)
);

create index idx_bookings_funnel_created
  on public.bookings (funnel_status, created_at desc);

create index idx_bookings_property_id
  on public.bookings (property_id);

create trigger trg_bookings_set_updated_at
  before update on public.bookings
  for each row
  execute function public.set_updated_at();

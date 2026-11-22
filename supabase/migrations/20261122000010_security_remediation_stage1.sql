-- Migration 10: Security Remediation Stage 1 (Supabase RLS, Storage, RPCs & Hardening)
-- Scope: Audit run-3 findings 2.1, 2.2 (DB/Storage), 2.3, 2.4, 2.5, 2.6, 2.7,
--        SQL support for 2.8 & 2.9, and Database Hardening (Bagian B1).

create extension if not exists pgcrypto;

-- =============================================================================
-- 1. Inactive Category Full Block (2.1)
-- Aligns public RLS on properties & property_images with search_properties
-- (`c.is_active = true`). Admin policies remain unchanged.
-- =============================================================================
drop policy if exists "properties_anon_select_published" on public.properties;
create policy "properties_anon_select_published"
  on public.properties
  for select
  to anon, authenticated
  using (
    is_published = true
    and exists (
      select 1
      from public.property_categories c
      where c.id = properties.property_category_id
        and c.is_active = true
    )
  );

drop policy if exists "property_images_anon_select_published" on public.property_images;
create policy "property_images_anon_select_published"
  on public.property_images
  for select
  to anon, authenticated
  using (
    exists (
      select 1
      from public.properties p
      join public.property_categories c
        on c.id = p.property_category_id
      where p.id = property_images.property_id
        and p.is_published = true
        and c.is_active = true
    )
  );

-- =============================================================================
-- 2. Storage Bucket `property-images` Policy Tightening (2.2)
-- Bucket remains public = true so public object URLs continue working;
-- remove broad SELECT listing policy and restrict SELECT metadata/list to admin.
-- =============================================================================
drop policy if exists "property_images_bucket_public_select" on storage.objects;
drop policy if exists "property_images_bucket_admin_select" on storage.objects;
create policy "property_images_bucket_admin_select"
  on storage.objects
  for select
  to authenticated
  using (bucket_id = 'property-images' and public.is_admin());

-- =============================================================================
-- 3. Constraints & Indexes (B1.3, B1.5, B1.9)
-- New constraints use NOT VALID so legacy rows do not fail deployment while
-- all new INSERT/UPDATE writes are strictly validated.
-- =============================================================================
alter table public.properties
  drop constraint if exists properties_google_maps_url_scheme_check;

alter table public.properties
  add constraint properties_google_maps_url_scheme_check
    check (
      google_maps_url is null
      or btrim(google_maps_url) = ''
      or (
        google_maps_url !~ '[[:space:][:cntrl:]]'
        and google_maps_url ~* '^https://((maps\.google\.(com|co\.id)(/|\?|$))|((www\.)?google\.(com|co\.id)/maps(/|\?|$))|(maps\.app\.goo\.gl/[a-z0-9_-]+(/|\?|$))|(goo\.gl/maps/[a-z0-9_-]+(/|\?|$)))'
      )
    ) not valid;

alter table public.property_images
  drop constraint if exists property_images_image_path_format_check;

alter table public.property_images
  add constraint property_images_image_path_format_check
    check (
      image_path ~* '^properties/[0-9]+/[a-z0-9][a-z0-9_-]{0,127}\.(jpg|jpeg|png|webp)$'
    ) not valid;

create index if not exists idx_bookings_upper_booking_code
  on public.bookings (upper(booking_code));

create index if not exists idx_bookings_whatsapp_created
  on public.bookings (customer_whatsapp, created_at desc);

create index if not exists idx_bookings_created_at_desc
  on public.bookings (created_at desc, id desc);

create index if not exists idx_search_logs_location_category
  on public.search_logs (location_id, property_category_id);

-- =============================================================================
-- 4. RPC: record_property_view (2.1 + 2.6)
-- Enforces c.is_active = true, uses transactional advisory locks against
-- READ COMMITTED races, and applies a 10s fallback cooldown when headers are null.
-- =============================================================================
create or replace function public.record_property_view(p_property_id bigint)
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count bigint;
  v_is_published boolean;
  v_category_active boolean;
  v_headers json := coalesce(nullif(current_setting('request.headers', true), ''), '{}')::json;
  v_ip text := left(nullif(btrim(split_part(coalesce(v_headers ->> 'x-forwarded-for', ''), ',', 1)), ''), 64);
  v_ua text := left(nullif(btrim(coalesce(v_headers ->> 'user-agent', '')), ''), 500);
begin
  select p.is_published, c.is_active
    into v_is_published, v_category_active
    from public.properties p
    join public.property_categories c
      on c.id = p.property_category_id
   where p.id = p_property_id;

  if not found or not v_is_published or not coalesce(v_category_active, false) then
    return null;
  end if;

  if v_ip is not null or v_ua is not null then
    perform pg_advisory_xact_lock(
      hashtext('record_property_view'),
      hashtext(
        p_property_id::text || '|' ||
        coalesce(v_ip, '') || '|' ||
        coalesce(v_ua, '')
      )
    );

    if exists (
      select 1
        from public.property_view_logs pvl
       where pvl.property_id = p_property_id
         and pvl.viewed_at >= now() - interval '10 minutes'
         and coalesce(pvl.ip_address, '') = coalesce(v_ip, '')
         and coalesce(pvl.user_agent, '') = coalesce(v_ua, '')
    ) then
      select p.views_count
        into v_count
        from public.properties p
        join public.property_categories c
          on c.id = p.property_category_id
       where p.id = p_property_id
         and p.is_published = true
         and c.is_active = true;
      return v_count;
    end if;
  else
    -- Fallback cooldown when proxy headers are both absent so empty-header bursts cannot inflate counters.
    perform pg_advisory_xact_lock(
      hashtext('record_property_view_null'),
      hashtext(p_property_id::text)
    );

    if exists (
      select 1
        from public.property_view_logs pvl
       where pvl.property_id = p_property_id
         and pvl.viewed_at >= now() - interval '10 seconds'
         and pvl.ip_address is null
         and pvl.user_agent is null
    ) then
      select p.views_count
        into v_count
        from public.properties p
        join public.property_categories c
          on c.id = p.property_category_id
       where p.id = p_property_id
         and p.is_published = true
         and c.is_active = true;
      return v_count;
    end if;
  end if;

  update public.properties p
     set views_count = p.views_count + 1
    from public.property_categories c
   where p.id = p_property_id
     and p.property_category_id = c.id
     and p.is_published = true
     and c.is_active = true
  returning p.views_count into v_count;

  if v_count is null then
    return null;
  end if;

  insert into public.property_view_logs (property_id, ip_address, user_agent)
  values (p_property_id, v_ip, v_ua);

  return v_count;
end;
$$;

revoke execute on function public.record_property_view(bigint) from public;
grant execute on function public.record_property_view(bigint) to anon, authenticated;

-- =============================================================================
-- 5. RPC: search_properties (2.7 + SQLSTATE 23503 handling)
-- Normalizes keyword with lower(btrim(...)) before dedup and logging, and
-- swallows FK violations from invalid location_id/category_id filters.
-- =============================================================================
create or replace function public.search_properties(
  p_keyword text default null,
  p_location_id bigint default null,
  p_category_id bigint default null,
  p_min_price bigint default null,
  p_max_price bigint default null,
  p_availability public.availability_status default null,
  p_sort text default 'newest',
  p_limit integer default 20,
  p_offset integer default 0
)
returns table (
  id bigint,
  slug text,
  title text,
  price bigint,
  building_area integer,
  land_area integer,
  bedrooms smallint,
  bathrooms smallint,
  availability_status public.availability_status,
  views_count bigint,
  category_name text,
  city text,
  district text,
  primary_image_path text,
  total_count bigint
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_keyword text := nullif(left(lower(btrim(coalesce(p_keyword, ''))), 100), '');
  v_keyword_pattern text;
  v_limit integer := least(greatest(coalesce(p_limit, 20), 1), 100);
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_sort text := coalesce(nullif(btrim(p_sort), ''), 'newest');
  v_total_count bigint := 0;
begin
  if v_keyword is not null then
    v_keyword_pattern := '%' || replace(replace(replace(v_keyword, '\', '\\'), '%', '\%'), '_', '\_') || '%';
  end if;

  select count(*)::bigint
    into v_total_count
    from public.properties p
    join public.property_categories c on c.id = p.property_category_id
   where p.is_published = true
     and c.is_active = true
     and (v_keyword is null or p.title ilike v_keyword_pattern escape '\'
          or coalesce(p.address_detail, '') ilike v_keyword_pattern escape '\')
     and (p_location_id is null or p.location_id = p_location_id)
     and (p_category_id is null or p.property_category_id = p_category_id)
     and (p_min_price is null or p.price >= p_min_price)
     and (p_max_price is null or p.price <= p_max_price)
     and (p_availability is null or p.availability_status = p_availability);

  if v_offset = 0 and (v_keyword is not null or p_location_id is not null or p_category_id is not null) then
    perform pg_advisory_xact_lock(
      hashtext('search_properties'),
      hashtext(
        coalesce(v_keyword, '') || '|' ||
        coalesce(p_location_id::text, '') || '|' ||
        coalesce(p_category_id::text, '')
      )
    );

    if not exists (
      select 1
        from public.search_logs sl
       where sl.searched_at >= now() - interval '30 seconds'
         and coalesce(lower(btrim(sl.keyword)), '') = coalesce(v_keyword, '')
         and sl.location_id is not distinct from p_location_id
         and sl.property_category_id is not distinct from p_category_id
    ) then
      begin
        insert into public.search_logs (
          keyword,
          location_id,
          property_category_id,
          results_count
        ) values (
          v_keyword,
          p_location_id,
          p_category_id,
          v_total_count::integer
        );
      exception
        when foreign_key_violation then
          null;
      end;
    end if;
  end if;

  return query
  select
    p.id,
    p.slug,
    p.title,
    p.price,
    p.building_area,
    p.land_area,
    p.bedrooms,
    p.bathrooms,
    p.availability_status,
    p.views_count,
    c.name as category_name,
    l.city,
    l.district,
    pi.image_path as primary_image_path,
    v_total_count as total_count
  from public.properties p
  join public.property_categories c on c.id = p.property_category_id
  join public.locations l on l.id = p.location_id
  left join public.property_images pi
    on pi.property_id = p.id
   and pi.is_primary = true
  where p.is_published = true
    and c.is_active = true
    and (v_keyword is null or p.title ilike v_keyword_pattern escape '\'
         or coalesce(p.address_detail, '') ilike v_keyword_pattern escape '\')
    and (p_location_id is null or p.location_id = p_location_id)
    and (p_category_id is null or p.property_category_id = p_category_id)
    and (p_min_price is null or p.price >= p_min_price)
    and (p_max_price is null or p.price <= p_max_price)
    and (p_availability is null or p.availability_status = p_availability)
  order by
    case when v_sort = 'price_asc' then p.price end asc nulls last,
    case when v_sort = 'price_desc' then p.price end desc nulls last,
    p.created_at desc,
    p.id desc
  limit v_limit
  offset v_offset;
end;
$$;

revoke execute on function public.search_properties(
  text, bigint, bigint, bigint, bigint, public.availability_status, text, integer, integer
) from public;
grant execute on function public.search_properties(
  text, bigint, bigint, bigint, bigint, public.availability_status, text, integer, integer
) to anon, authenticated;

-- =============================================================================
-- 6. RPC: create_booking (2.1 + 2.4 + 2.5)
-- Enforces c.is_active = true, strips control chars (keeping ASCII space 0x20),
-- validates survey date bounds, serializes per-WA rate limit with advisory lock,
-- and generates 64-bit random hex codes using pgcrypto gen_random_bytes(8).
-- =============================================================================
create or replace function public.create_booking(
  p_property_id bigint,
  p_customer_name text,
  p_customer_whatsapp text,
  p_intent_type public.intent_type,
  p_preferred_survey_date timestamptz default null,
  p_payment_plan public.payment_plan default null,
  p_customer_notes text default null
)
returns text
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_name text := nullif(btrim(regexp_replace(coalesce(p_customer_name, ''), '[[:cntrl:]]', '', 'g')), '');
  v_whatsapp text := btrim(regexp_replace(coalesce(p_customer_whatsapp, ''), '[[:cntrl:]]', '', 'g'));
  v_notes text := nullif(btrim(regexp_replace(coalesce(p_customer_notes, ''), '[[:cntrl:]]', '', 'g')), '');
  v_is_published boolean;
  v_availability public.availability_status;
  v_category_active boolean;
  v_recent_count integer;
  v_date_part text := to_char((now() at time zone 'Asia/Jakarta')::date, 'YYYYMMDD');
  v_code text;
  v_attempt integer := 0;
begin
  if v_name is null then
    raise exception 'Nama pelanggan wajib diisi.' using errcode = '22023';
  end if;

  if char_length(v_name) > 120 then
    raise exception 'Nama pelanggan maksimal 120 karakter.' using errcode = '22023';
  end if;

  if v_notes is not null and char_length(v_notes) > 1000 then
    raise exception 'Catatan maksimal 1000 karakter.' using errcode = '22023';
  end if;

  if v_whatsapp !~ '^628[0-9]{8,12}$' then
    raise exception 'Format nomor WhatsApp harus diawali 628 dan terdiri dari 11-15 digit.' using errcode = '22023';
  end if;

  if p_intent_type is null then
    raise exception 'Tujuan pengajuan wajib dipilih.' using errcode = '22023';
  end if;

  if p_intent_type = 'survey_location' then
    if p_preferred_survey_date is null then
      raise exception 'Tanggal pilihan survei wajib diisi untuk tujuan survei lokasi.' using errcode = '22023';
    end if;

    if p_preferred_survey_date < now() then
      raise exception 'Tanggal pilihan survei tidak boleh di masa lalu.' using errcode = '22023';
    end if;

    if p_preferred_survey_date > now() + interval '180 days' then
      raise exception 'Tanggal pilihan survei maksimal 180 hari ke depan.' using errcode = '22023';
    end if;
  end if;

  if p_intent_type = 'book_unit' and p_payment_plan is null then
    raise exception 'Rencana pembayaran wajib dipilih untuk pemesanan unit.' using errcode = '22023';
  end if;

  select p.is_published, p.availability_status, c.is_active
    into v_is_published, v_availability, v_category_active
    from public.properties p
    join public.property_categories c
      on c.id = p.property_category_id
   where p.id = p_property_id;

  if not found or not v_is_published or not coalesce(v_category_active, false) then
    raise exception 'Properti tidak ditemukan atau belum dipublikasikan.' using errcode = '22023';
  end if;

  if v_availability <> 'available' then
    raise exception 'Properti sudah dipesan atau terjual dan tidak dapat dibooking.' using errcode = '22023';
  end if;

  -- Serialize concurrent bookings per normalized WhatsApp number inside this transaction.
  perform pg_advisory_xact_lock(
    hashtext('create_booking'),
    hashtext(v_whatsapp)
  );

  select count(*)::integer
    into v_recent_count
    from public.bookings b
   where b.customer_whatsapp = v_whatsapp
     and b.created_at >= now() - interval '1 hour';

  if v_recent_count >= 3 then
    raise exception 'Maksimal 3 pengajuan booking per jam untuk nomor WhatsApp yang sama.' using errcode = 'P0001';
  end if;

  loop
    v_attempt := v_attempt + 1;
    v_code := 'BK-' || v_date_part || '-' || upper(encode(gen_random_bytes(8), 'hex'));

    begin
      insert into public.bookings (
        booking_code,
        property_id,
        customer_name,
        customer_whatsapp,
        intent_type,
        preferred_survey_date,
        payment_plan,
        customer_notes,
        funnel_status
      ) values (
        v_code,
        p_property_id,
        v_name,
        v_whatsapp,
        p_intent_type,
        case when p_intent_type = 'survey_location' then p_preferred_survey_date else null end,
        case when p_intent_type = 'book_unit' then p_payment_plan else null end,
        v_notes,
        'new'
      );
      return v_code;
    exception
      when unique_violation then
        if v_attempt >= 5 then
          raise exception 'Gagal menghasilkan kode booking unik. Silakan coba lagi.';
        end if;
    end;
  end loop;
end;
$$;

revoke execute on function public.create_booking(
  bigint, text, text, public.intent_type, timestamptz, public.payment_plan, text
) from public;
grant execute on function public.create_booking(
  bigint, text, text, public.intent_type, timestamptz, public.payment_plan, text
) to anon, authenticated;

-- =============================================================================
-- 7. RPC: check_booking_status (2.3 + 2.4)
-- Requires BOTH booking code and customer WhatsApp simultaneously.
-- Drops previous definition because customer_whatsapp is removed from RETURNS TABLE.
-- =============================================================================
drop function if exists public.check_booking_status(text, text);

create or replace function public.check_booking_status(
  p_booking_code text default null,
  p_customer_whatsapp text default null
)
returns table (
  id bigint,
  booking_code text,
  property_id bigint,
  property_title text,
  property_slug text,
  property_price bigint,
  category_name text,
  location_label text,
  primary_image_path text,
  customer_name text,
  intent_type public.intent_type,
  preferred_survey_date timestamptz,
  confirmed_survey_date timestamptz,
  payment_plan public.payment_plan,
  customer_notes text,
  funnel_status public.funnel_status,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
#variable_conflict use_column
declare
  v_code text := nullif(upper(btrim(coalesce(p_booking_code, ''))), '');
  v_wa_digits text := nullif(regexp_replace(btrim(coalesce(p_customer_whatsapp, '')), '[^0-9]', '', 'g'), '');
begin
  if v_wa_digits is not null then
    if v_wa_digits like '08%' then
      v_wa_digits := '62' || substr(v_wa_digits, 2);
    elsif v_wa_digits like '8%' then
      v_wa_digits := '62' || v_wa_digits;
    end if;
  end if;

  if v_code is null or v_wa_digits is null then
    raise exception 'Kode booking dan nomor WhatsApp wajib diisi.'
      using errcode = '22023';
  end if;

  return query
  select
    b.id,
    b.booking_code,
    b.property_id,
    p.title as property_title,
    p.slug as property_slug,
    p.price as property_price,
    c.name as category_name,
    (l.district || ', ' || l.city) as location_label,
    pi.image_path as primary_image_path,
    b.customer_name,
    b.intent_type,
    b.preferred_survey_date,
    b.confirmed_survey_date,
    b.payment_plan,
    b.customer_notes,
    b.funnel_status,
    b.created_at,
    b.updated_at
  from public.bookings b
  join public.properties p on p.id = b.property_id
  join public.property_categories c on c.id = p.property_category_id
  join public.locations l on l.id = p.location_id
  left join public.property_images pi
    on pi.property_id = p.id
   and pi.is_primary = true
  where upper(b.booking_code) = v_code
    and b.customer_whatsapp = v_wa_digits
  order by b.created_at desc, b.id desc
  limit 1;
end;
$$;

revoke execute on function public.check_booking_status(text, text) from public;
grant execute on function public.check_booking_status(text, text) to anon, authenticated;

-- =============================================================================
-- 8. New Admin RPCs for Dashboard & CRM Pagination (2.8 + 2.9)
-- =============================================================================

-- 8a. Dashboard KPI & Aggregate Summary (total views, total searches, active leads, scheduled surveys)
create or replace function public.admin_dashboard_summary(
  p_from date default null,
  p_to date default null
)
returns table (
  total_views bigint,
  total_searches bigint,
  active_leads_count bigint,
  scheduled_surveys_count bigint
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_today date := (now() at time zone 'Asia/Jakarta')::date;
  v_from date := coalesce(p_from, v_today - 6);
  v_to date := coalesce(p_to, v_today);
  v_start timestamptz;
  v_end timestamptz;
begin
  if not public.is_admin() then
    raise exception 'Akses ditolak: hanya Admin yang diizinkan.' using errcode = '42501';
  end if;

  if v_from > v_to then
    v_from := v_to;
  end if;

  v_start := v_from::timestamp at time zone 'Asia/Jakarta';
  v_end := (v_to + 1)::timestamp at time zone 'Asia/Jakarta';

  return query
  select
    coalesce((select sum(p.views_count) from public.properties p), 0)::bigint as total_views,
    (
      select count(*)::bigint
        from public.search_logs sl
       where sl.searched_at >= v_start
         and sl.searched_at < v_end
    ) as total_searches,
    (
      select count(*)::bigint
        from public.bookings b
       where b.funnel_status not in ('closed_won', 'closed_lost')
    ) as active_leads_count,
    (
      select count(*)::bigint
        from public.bookings b
       where b.confirmed_survey_date is not null
         and b.funnel_status not in ('closed_won', 'closed_lost')
    ) as scheduled_surveys_count;
end;
$$;

-- 8b. Upcoming Surveys ordered ascending by confirmed_survey_date
create or replace function public.admin_upcoming_surveys(
  p_limit integer default 5
)
returns table (
  id bigint,
  booking_code text,
  property_id bigint,
  customer_name text,
  customer_whatsapp text,
  intent_type public.intent_type,
  preferred_survey_date timestamptz,
  confirmed_survey_date timestamptz,
  payment_plan public.payment_plan,
  customer_notes text,
  funnel_status public.funnel_status,
  admin_notes text,
  created_at timestamptz,
  updated_at timestamptz,
  property_title text,
  property_slug text,
  property_category_name text,
  property_district text,
  property_availability_status public.availability_status
)
language plpgsql
security definer
set search_path = public
as $$
#variable_conflict use_column
declare
  v_limit integer := least(greatest(coalesce(p_limit, 5), 1), 50);
begin
  if not public.is_admin() then
    raise exception 'Akses ditolak: hanya Admin yang diizinkan.' using errcode = '42501';
  end if;

  return query
  select
    b.id,
    b.booking_code,
    b.property_id,
    b.customer_name,
    b.customer_whatsapp,
    b.intent_type,
    b.preferred_survey_date,
    b.confirmed_survey_date,
    b.payment_plan,
    b.customer_notes,
    b.funnel_status,
    b.admin_notes,
    b.created_at,
    b.updated_at,
    p.title as property_title,
    p.slug as property_slug,
    c.name as property_category_name,
    l.district as property_district,
    p.availability_status as property_availability_status
  from public.bookings b
  join public.properties p on p.id = b.property_id
  join public.property_categories c on c.id = p.property_category_id
  join public.locations l on l.id = p.location_id
  where b.confirmed_survey_date is not null
    and b.funnel_status not in ('closed_won', 'closed_lost')
  order by b.confirmed_survey_date asc, b.id asc
  limit v_limit;
end;
$$;

-- 8c. Server-side filtered and paginated CRM Bookings listing
create or replace function public.admin_list_bookings(
  p_status public.funnel_status default null,
  p_keyword text default null,
  p_limit integer default 50,
  p_offset integer default 0
)
returns table (
  id bigint,
  booking_code text,
  property_id bigint,
  customer_name text,
  customer_whatsapp text,
  intent_type public.intent_type,
  preferred_survey_date timestamptz,
  confirmed_survey_date timestamptz,
  payment_plan public.payment_plan,
  customer_notes text,
  funnel_status public.funnel_status,
  admin_notes text,
  created_at timestamptz,
  updated_at timestamptz,
  property_title text,
  property_slug text,
  property_category_name text,
  property_district text,
  property_availability_status public.availability_status,
  total_count bigint
)
language plpgsql
security definer
set search_path = public
as $$
#variable_conflict use_column
declare
  v_limit integer := least(greatest(coalesce(p_limit, 50), 1), 100);
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_keyword text := nullif(left(btrim(coalesce(p_keyword, '')), 100), '');
  v_keyword_pattern text;
begin
  if not public.is_admin() then
    raise exception 'Akses ditolak: hanya Admin yang diizinkan.' using errcode = '42501';
  end if;

  if v_keyword is not null then
    v_keyword_pattern := '%' || replace(replace(replace(v_keyword, '\', '\\'), '%', '\%'), '_', '\_') || '%';
  end if;

  return query
  select
    b.id,
    b.booking_code,
    b.property_id,
    b.customer_name,
    b.customer_whatsapp,
    b.intent_type,
    b.preferred_survey_date,
    b.confirmed_survey_date,
    b.payment_plan,
    b.customer_notes,
    b.funnel_status,
    b.admin_notes,
    b.created_at,
    b.updated_at,
    p.title as property_title,
    p.slug as property_slug,
    c.name as property_category_name,
    l.district as property_district,
    p.availability_status as property_availability_status,
    count(*) over()::bigint as total_count
  from public.bookings b
  join public.properties p on p.id = b.property_id
  join public.property_categories c on c.id = p.property_category_id
  join public.locations l on l.id = p.location_id
  where (p_status is null or b.funnel_status = p_status)
    and (
      v_keyword is null
      or b.customer_name ilike v_keyword_pattern escape '\'
      or b.booking_code ilike v_keyword_pattern escape '\'
      or b.customer_whatsapp ilike v_keyword_pattern escape '\'
      or p.title ilike v_keyword_pattern escape '\'
    )
  order by b.created_at desc, b.id desc
  limit v_limit
  offset v_offset;
end;
$$;

-- =============================================================================
-- 9. Privilege Hardening (B1.9)
-- Revoke default PUBLIC/anon EXECUTE on all Admin RPCs and dangerous table privileges.
-- =============================================================================
revoke execute on function public.admin_top_properties(integer) from public, anon;
grant execute on function public.admin_top_properties(integer) to authenticated;

revoke execute on function public.admin_view_trend(bigint, date, date, text) from public, anon;
grant execute on function public.admin_view_trend(bigint, date, date, text) to authenticated;

revoke execute on function public.admin_search_stats(date, date, integer) from public, anon;
grant execute on function public.admin_search_stats(date, date, integer) to authenticated;

revoke execute on function public.admin_dashboard_summary(date, date) from public, anon;
grant execute on function public.admin_dashboard_summary(date, date) to authenticated;

revoke execute on function public.admin_upcoming_surveys(integer) from public, anon;
grant execute on function public.admin_upcoming_surveys(integer) to authenticated;

revoke execute on function public.admin_list_bookings(
  public.funnel_status, text, integer, integer
) from public, anon;
grant execute on function public.admin_list_bookings(
  public.funnel_status, text, integer, integer
) to authenticated;

revoke truncate, references, trigger on public.property_categories from public, anon, authenticated;
revoke truncate, references, trigger on public.locations from public, anon, authenticated;
revoke truncate, references, trigger on public.properties from public, anon, authenticated;
revoke truncate, references, trigger on public.property_images from public, anon, authenticated;
revoke truncate, references, trigger on public.property_view_logs from public, anon, authenticated;
revoke truncate, references, trigger on public.search_logs from public, anon, authenticated;
revoke truncate, references, trigger on public.bookings from public, anon, authenticated;

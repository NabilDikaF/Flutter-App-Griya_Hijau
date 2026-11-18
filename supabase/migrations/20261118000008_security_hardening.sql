-- Migration 8: Security Hardening (PII Masking, Input Bounds, Analytics Throttling, URL Validation & RLS)

-- 1. Bounds & URL safety constraints
alter table public.bookings
  drop constraint if exists bookings_customer_name_length_check,
  add constraint bookings_customer_name_length_check
    check (char_length(customer_name) <= 120);

alter table public.bookings
  drop constraint if exists bookings_customer_notes_length_check,
  add constraint bookings_customer_notes_length_check
    check (customer_notes is null or char_length(customer_notes) <= 1000);

alter table public.bookings
  drop constraint if exists bookings_admin_notes_length_check,
  add constraint bookings_admin_notes_length_check
    check (admin_notes is null or char_length(admin_notes) <= 2000);

alter table public.properties
  drop constraint if exists properties_google_maps_url_scheme_check,
  add constraint properties_google_maps_url_scheme_check
    check (
      google_maps_url is null
      or btrim(google_maps_url) = ''
      or google_maps_url ~* '^https://([a-z0-9-]+\.)?(google\.com|google\.co\.id|goo\.gl|maps\.app\.goo\.gl)(/|\?|$)'
    );

-- 2. Harden record_property_view with 10-minute per-(ip, ua) deduplication & header length bounds
create or replace function public.record_property_view(p_property_id bigint)
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count bigint;
  v_headers json := coalesce(nullif(current_setting('request.headers', true), ''), '{}')::json;
  v_ip text := left(nullif(btrim(split_part(coalesce(v_headers ->> 'x-forwarded-for', ''), ',', 1)), ''), 64);
  v_ua text := left(nullif(btrim(coalesce(v_headers ->> 'user-agent', '')), ''), 500);
begin
  if v_ip is not null or v_ua is not null then
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
       where p.id = p_property_id
         and p.is_published = true;
      return v_count;
    end if;
  end if;

  update public.properties
     set views_count = views_count + 1
   where id = p_property_id
     and is_published = true
  returning views_count into v_count;

  if v_count is null then
    return null;
  end if;

  insert into public.property_view_logs (property_id, ip_address, user_agent)
  values (p_property_id, v_ip, v_ua);

  return v_count;
end;
$$;

grant execute on function public.record_property_view(bigint) to anon, authenticated;

-- 3. Harden search_properties with keyword truncation & 30-second log deduplication
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
  v_keyword text := left(nullif(btrim(coalesce(p_keyword, '')), ''), 100);
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
    if not exists (
      select 1
        from public.search_logs sl
       where sl.searched_at >= now() - interval '30 seconds'
         and coalesce(sl.keyword, '') = coalesce(v_keyword, '')
         and sl.location_id is not distinct from p_location_id
         and sl.property_category_id is not distinct from p_category_id
    ) then
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

grant execute on function public.search_properties(
  text, bigint, bigint, bigint, bigint, public.availability_status, text, integer, integer
) to anon, authenticated;

-- 4. Harden create_booking with length caps and 8-hex (32-bit) booking code entropy
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
set search_path = public
as $$
declare
  v_name text := nullif(btrim(coalesce(p_customer_name, '')), '');
  v_whatsapp text := btrim(coalesce(p_customer_whatsapp, ''));
  v_notes text := nullif(btrim(coalesce(p_customer_notes, '')), '');
  v_is_published boolean;
  v_availability public.availability_status;
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

  if p_intent_type = 'survey_location' and p_preferred_survey_date is null then
    raise exception 'Tanggal pilihan survei wajib diisi untuk tujuan survei lokasi.' using errcode = '22023';
  end if;

  if p_intent_type = 'book_unit' and p_payment_plan is null then
    raise exception 'Rencana pembayaran wajib dipilih untuk pemesanan unit.' using errcode = '22023';
  end if;

  select p.is_published, p.availability_status
    into v_is_published, v_availability
    from public.properties p
   where p.id = p_property_id;

  if not found or not v_is_published then
    raise exception 'Properti tidak ditemukan atau belum dipublikasikan.' using errcode = '22023';
  end if;

  if v_availability <> 'available' then
    raise exception 'Properti sudah dipesan atau terjual dan tidak dapat dibooking.' using errcode = '22023';
  end if;

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
    v_code := 'BK-' || v_date_part || '-' || upper(
      substr(md5(random()::text || clock_timestamp()::text || txid_current()::text || v_whatsapp || v_attempt::text), 1, 8)
    );

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

grant execute on function public.create_booking(
  bigint, text, text, public.intent_type, timestamptz, public.payment_plan, text
) to anon, authenticated;

-- 5. Harden check_booking_status: mask PII on phone-only lookups, keep code lookups seamless
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
  customer_whatsapp text,
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

  if v_code is null and v_wa_digits is null then
    raise exception 'Masukkan kode booking atau nomor WhatsApp untuk mengecek status.'
      using errcode = '22023';
  end if;

  return query
  select
    b.id,
    case
      when v_code is not null then b.booking_code
      else left(b.booking_code, 12) || '***'
    end as booking_code,
    b.property_id,
    p.title as property_title,
    p.slug as property_slug,
    p.price as property_price,
    c.name as category_name,
    (l.district || ', ' || l.city) as location_label,
    pi.image_path as primary_image_path,
    case
      when v_code is not null then b.customer_name
      when char_length(btrim(b.customer_name)) <= 1 then '***'
      else left(btrim(b.customer_name), 1) || '***'
    end as customer_name,
    case
      when v_code is not null then b.customer_whatsapp
      else left(b.customer_whatsapp, 5) || '****' || right(b.customer_whatsapp, 3)
    end as customer_whatsapp,
    b.intent_type,
    b.preferred_survey_date,
    b.confirmed_survey_date,
    b.payment_plan,
    case
      when v_code is not null then b.customer_notes
      else null::text
    end as customer_notes,
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
  where (v_code is null or upper(b.booking_code) = v_code)
    and (v_wa_digits is null or b.customer_whatsapp = v_wa_digits)
  order by b.created_at desc, b.id desc
  limit 5;
end;
$$;

grant execute on function public.check_booking_status(text, text) to anon, authenticated;

-- 6. Allow authenticated non-admin users to also read public catalog tables seamlessly
alter policy "property_categories_anon_select_active"
  on public.property_categories
  to anon, authenticated;

alter policy "locations_anon_select_all"
  on public.locations
  to anon, authenticated;

alter policy "properties_anon_select_published"
  on public.properties
  to anon, authenticated;

alter policy "property_images_anon_select_published"
  on public.property_images
  to anon, authenticated;

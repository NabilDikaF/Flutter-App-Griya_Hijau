-- Migration 9: Fully mask booking_code to 'BK-***********' on phone-only check_booking_status lookups
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
      else 'BK-***********'
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

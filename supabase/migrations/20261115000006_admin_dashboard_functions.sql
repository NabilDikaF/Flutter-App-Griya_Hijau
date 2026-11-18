-- Migration 6: Admin Dashboard Aggregate RPC Functions (Read-Only)
-- Reference: docs/SCHEMA.md Section 7.2 & CLAUDE.md Section 8.3

-- 1. Top properties by views_count
create or replace function public.admin_top_properties(p_limit integer default 10)
returns table (
  id bigint,
  slug text,
  title text,
  category_name text,
  city text,
  district text,
  views_count bigint,
  availability_status public.availability_status,
  is_published boolean
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_limit integer := least(greatest(coalesce(p_limit, 10), 1), 50);
begin
  if not public.is_admin() then
    raise exception 'Akses ditolak: hanya Admin yang diizinkan.' using errcode = '42501';
  end if;

  return query
  select
    p.id,
    p.slug,
    p.title,
    c.name as category_name,
    l.city,
    l.district,
    p.views_count,
    p.availability_status,
    p.is_published
  from public.properties p
  join public.property_categories c on c.id = p.property_category_id
  join public.locations l on l.id = p.location_id
  order by p.views_count desc, p.id asc
  limit v_limit;
end;
$$;

grant execute on function public.admin_top_properties(integer) to authenticated;

-- 2. View trend per day or month from property_view_logs
create or replace function public.admin_view_trend(
  p_property_id bigint default null,
  p_from date default null,
  p_to date default null,
  p_interval text default 'day'
)
returns table (
  bucket_date date,
  view_count bigint
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_today date := (now() at time zone 'Asia/Jakarta')::date;
  v_from date := coalesce(p_from, v_today - 6);
  v_to date := coalesce(p_to, v_today);
  v_interval text := case when lower(btrim(coalesce(p_interval, 'day'))) = 'month' then 'month' else 'day' end;
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
  with buckets as (
    select gs::date as bucket_date
    from generate_series(
      case
        when v_interval = 'month' then date_trunc('month', v_from::timestamp)
        else v_from::timestamp
      end,
      case
        when v_interval = 'month' then date_trunc('month', v_to::timestamp)
        else v_to::timestamp
      end,
      case
        when v_interval = 'month' then interval '1 month'
        else interval '1 day'
      end
    ) as gs
  ),
  counts as (
    select
      case
        when v_interval = 'month'
          then date_trunc('month', pvl.viewed_at at time zone 'Asia/Jakarta')::date
        else (pvl.viewed_at at time zone 'Asia/Jakarta')::date
      end as bucket_date,
      count(*)::bigint as view_count
    from public.property_view_logs pvl
    where (p_property_id is null or pvl.property_id = p_property_id)
      and pvl.viewed_at >= v_start
      and pvl.viewed_at < v_end
    group by 1
  )
  select
    b.bucket_date,
    coalesce(c.view_count, 0)::bigint as view_count
  from buckets b
  left join counts c on c.bucket_date = b.bucket_date
  order by b.bucket_date asc;
end;
$$;

grant execute on function public.admin_view_trend(bigint, date, date, text) to authenticated;

-- 3. Search demand analytics (location, category, keyword) from search_logs
create or replace function public.admin_search_stats(
  p_from date default null,
  p_to date default null,
  p_limit integer default 10
)
returns table (
  dimension text,
  label text,
  search_count bigint,
  zero_result_count bigint
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_today date := (now() at time zone 'Asia/Jakarta')::date;
  v_from date := coalesce(p_from, v_today - 6);
  v_to date := coalesce(p_to, v_today);
  v_limit integer := least(greatest(coalesce(p_limit, 10), 1), 50);
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
  (
    select
      'location'::text as dimension,
      (l.district || ', ' || l.city)::text as label,
      count(*)::bigint as search_count,
      count(*) filter (where sl.results_count = 0)::bigint as zero_result_count
    from public.search_logs sl
    join public.locations l on l.id = sl.location_id
    where sl.searched_at >= v_start
      and sl.searched_at < v_end
    group by l.id, l.district, l.city
    order by search_count desc, zero_result_count desc, label asc
    limit v_limit
  )
  union all
  (
    select
      'category'::text as dimension,
      c.name::text as label,
      count(*)::bigint as search_count,
      count(*) filter (where sl.results_count = 0)::bigint as zero_result_count
    from public.search_logs sl
    join public.property_categories c on c.id = sl.property_category_id
    where sl.searched_at >= v_start
      and sl.searched_at < v_end
    group by c.id, c.name
    order by search_count desc, zero_result_count desc, label asc
    limit v_limit
  )
  union all
  (
    select
      'keyword'::text as dimension,
      lower(btrim(sl.keyword))::text as label,
      count(*)::bigint as search_count,
      count(*) filter (where sl.results_count = 0)::bigint as zero_result_count
    from public.search_logs sl
    where sl.searched_at >= v_start
      and sl.searched_at < v_end
      and sl.keyword is not null
      and btrim(sl.keyword) <> ''
    group by lower(btrim(sl.keyword))
    order by search_count desc, zero_result_count desc, label asc
    limit v_limit
  );
end;
$$;

grant execute on function public.admin_search_stats(date, date, integer) to authenticated;

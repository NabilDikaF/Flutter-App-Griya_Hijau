-- Supabase local development seed script (idempotent)
-- Safe to run alongside migration 20261114000005_seed_data.sql on `supabase db reset`.

insert into public.property_categories (name, slug, is_active)
values
  ('Komplek Perumahan', 'komplek-perumahan', true),
  ('Ruko', 'ruko', true)
on conflict (slug) do nothing;

insert into public.locations (city, district, slug)
values
  ('Bandung', 'Kec. Sukamaju', 'bandung-kec-sukamaju'),
  ('Bandung', 'Kec. Mekar Jaya', 'bandung-kec-mekar-jaya'),
  ('Bandung', 'Kec. Bumi Asri', 'bandung-kec-bumi-asri'),
  ('Bandung', 'Kec. Tanjung Baru', 'bandung-kec-tanjung-baru'),
  ('Bandung', 'Kec. Sari Indah', 'bandung-kec-sari-indah')
on conflict (slug) do nothing;

with cat as (
  select slug, id from public.property_categories
),
loc as (
  select slug, id from public.locations
)
insert into public.properties (
  property_category_id,
  location_id,
  title,
  slug,
  price,
  building_area,
  land_area,
  bedrooms,
  bathrooms,
  floors,
  electricity,
  certificate_type,
  description,
  address_detail,
  latitude,
  longitude,
  google_maps_url,
  availability_status,
  views_count,
  is_published
)
select
  c.id,
  l.id,
  v.title,
  v.slug,
  v.price,
  v.building_area,
  v.land_area,
  v.bedrooms,
  v.bathrooms,
  v.floors,
  v.electricity,
  v.certificate_type,
  v.description,
  v.address_detail,
  v.latitude,
  v.longitude,
  v.google_maps_url,
  v.availability_status::public.availability_status,
  v.views_count,
  v.is_published
from (
  values
    (
      'komplek-perumahan',
      'bandung-kec-sukamaju',
      'Griya Hijau Residence Tipe 45/84',
      'griya-hijau-residence-45-84',
      680000000::bigint,
      45, 84, 2::smallint, 1::smallint, 1::smallint,
      '1300 VA', 'SHM',
      'Hunian minimalis asri 1 lantai dengan taman depan luas, sistem keamanan 24 jam, dan akses dekat pintu tol.',
      'Jl. Rindang Raya Blok A1 No. 5, Kec. Sukamaju, Bandung',
      -6.914744::double precision, 107.609810::double precision,
      'https://maps.google.com/?q=-6.914744,107.609810',
      'available', 42::bigint, true
    ),
    (
      'komplek-perumahan',
      'bandung-kec-mekar-jaya',
      'Taman Rindang Residence Tipe 60/105',
      'taman-rindang-residence-60-105',
      925000000::bigint,
      60, 105, 3::smallint, 2::smallint, 1::smallint,
      '2200 VA', 'SHM',
      'Rumah keluarga nyaman dengan sirkulasi udara silang, carport 2 mobil, dan area bermain anak di dalam cluster.',
      'Jl. Mekar Indah No. 12, Kec. Mekar Jaya, Bandung',
      -6.921200::double precision, 107.635400::double precision,
      'https://maps.google.com/?q=-6.921200,107.635400',
      'available', 35::bigint, true
    ),
    (
      'komplek-perumahan',
      'bandung-kec-bumi-asri',
      'Bukit Asri Villa Tipe 90/120',
      'bukit-asri-villa-90-120',
      1450000000::bigint,
      90, 120, 3::smallint, 3::smallint, 2::smallint,
      '2200 VA', 'SHM',
      'Hunian 2 lantai bernuansa sejuk pegunungan Bandung Utara dengan balkon privat dan tata ruang modern.',
      'Jl. Bukit Asri Kav. 8, Kec. Bumi Asri, Bandung',
      -6.889100::double precision, 107.618900::double precision,
      'https://maps.google.com/?q=-6.889100,107.618900',
      'available', 58::bigint, true
    ),
    (
      'komplek-perumahan',
      'bandung-kec-tanjung-baru',
      'Harmoni Alam Cluster Tipe 54/90',
      'harmoni-alam-cluster-54-90',
      790000000::bigint,
      54, 90, 2::smallint, 2::smallint, 1::smallint,
      '1300 VA', 'SHM',
      'Unit cluster strategis dekat fasilitas pendidikan dan rumah sakit dengan desain ramah lingkungan.',
      'Jl. Tanjung Harmoni Blok C3 No. 9, Kec. Tanjung Baru, Bandung',
      -6.942500::double precision, 107.645100::double precision,
      'https://maps.google.com/?q=-6.942500,107.645100',
      'booked', 27::bigint, true
    ),
    (
      'ruko',
      'bandung-kec-sari-indah',
      'Ruko Sentra Niaga Sari Indah',
      'ruko-sentra-niaga-sari-indah',
      1650000000::bigint,
      140, 95, 0::smallint, 2::smallint, 2::smallint,
      '3500 VA', 'HGB',
      'Ruko komersial 2 lantai di jalur utama kawasan bisnis dengan area parkir lebar dan visibilitas tinggi.',
      'Jl. Sentra Niaga No. 24, Kec. Sari Indah, Bandung',
      -6.930800::double precision, 107.590200::double precision,
      'https://maps.google.com/?q=-6.930800,107.590200',
      'available', 31::bigint, true
    ),
    (
      'ruko',
      'bandung-kec-sukamaju',
      'Ruko Gerbang Utama Sukamaju',
      'ruko-gerbang-utama-sukamaju',
      1850000000::bigint,
      160, 110, 0::smallint, 2::smallint, 2::smallint,
      '3500 VA', 'SHM',
      'Ruko posisi sudut tepat di gerbang komplek Sukamaju, cocok untuk retail, klinik, maupun kantor operasional.',
      'Jl. Rindang Raya Ruko No. 1, Kec. Sukamaju, Bandung',
      -6.911400::double precision, 107.614300::double precision,
      'https://maps.google.com/?q=-6.911400,107.614300',
      'sold', 64::bigint, true
    ),
    (
      'komplek-perumahan',
      'bandung-kec-mekar-jaya',
      'Draft Cluster Anggrek Blok D2',
      'draft-cluster-anggrek-d2',
      850000000::bigint,
      58, 96, 3::smallint, 2::smallint, 1::smallint,
      '2200 VA', 'SHM',
      'Unit persiapan tahap pengembangan berikutnya (belum dipublikasikan untuk uji RLS).',
      'Jl. Mekar Anggrek Blok D2, Kec. Mekar Jaya, Bandung',
      -6.924000::double precision, 107.638000::double precision,
      'https://maps.google.com/?q=-6.924000,107.638000',
      'available', 0::bigint, false
    ),
    (
      'komplek-perumahan',
      'bandung-kec-bumi-asri',
      'Draft Hunian Pinus Blok E1',
      'draft-hunian-pinus-e1',
      1100000000::bigint,
      72, 108, 3::smallint, 2::smallint, 2::smallint,
      '2200 VA', 'SHM',
      'Unit tahap pra-peluncuran di kawasan Bumi Asri (belum dipublikasikan untuk uji RLS).',
      'Jl. Pinus Asri Blok E1, Kec. Bumi Asri, Bandung',
      -6.892000::double precision, 107.621500::double precision,
      'https://maps.google.com/?q=-6.892000,107.621500',
      'available', 0::bigint, false
    )
) as v(
  cat_slug, loc_slug, title, slug, price, building_area, land_area,
  bedrooms, bathrooms, floors, electricity, certificate_type,
  description, address_detail, latitude, longitude, google_maps_url,
  availability_status, views_count, is_published
)
join cat c on c.slug = v.cat_slug
join loc l on l.slug = v.loc_slug
on conflict (slug) do nothing;

insert into public.property_images (property_id, image_path, is_primary, sort_order)
select
  p.id,
  'properties/' || p.id || '/main.jpg',
  true,
  0
from public.properties p
where p.slug in (
  'griya-hijau-residence-45-84',
  'taman-rindang-residence-60-105',
  'bukit-asri-villa-90-120',
  'harmoni-alam-cluster-54-90',
  'ruko-sentra-niaga-sari-indah',
  'ruko-gerbang-utama-sukamaju',
  'draft-cluster-anggrek-d2',
  'draft-hunian-pinus-e1'
)
and not exists (
  select 1
  from public.property_images pi
  where pi.property_id = p.id
    and pi.is_primary = true
);

insert into public.property_images (property_id, image_path, is_primary, sort_order)
select
  p.id,
  'properties/' || p.id || '/interior-1.jpg',
  false,
  1
from public.properties p
where p.slug in (
  'griya-hijau-residence-45-84',
  'taman-rindang-residence-60-105',
  'bukit-asri-villa-90-120',
  'harmoni-alam-cluster-54-90',
  'ruko-sentra-niaga-sari-indah',
  'ruko-gerbang-utama-sukamaju'
)
and not exists (
  select 1
  from public.property_images pi
  where pi.property_id = p.id
    and pi.sort_order = 1
);

# Griya Hijau — Aplikasi Admin (`apps/app_admin`)

Aplikasi Android khusus tim internal/marketing **PT Rindang Alam (Griya Hijau)** (`applicationId: id.rindangalam.admin`).

## Daftar Fitur & Rute

| Rute | Layar | Fitur Utama |
|---|---|---|
| `/login` | `AdminLoginScreen` | Login Supabase Auth + Role Guard (`app_metadata['role'] == 'admin'`; akun non-admin ditolak & langsung sign out) |
| `/dashboard` | `AdminDashboardScreen` | Analitik riset pasar (`fl_chart`): total views, pencarian, leads aktif, tren kunjungan harian/bulanan (`admin_view_trend`), properti terpopuler (`admin_top_properties`), statistik kecamatan/kategori/kata kunci (`admin_search_stats`), jadwal survei & leads terbaru |
| `/properties` | `AdminPropertiesScreen` | Daftar seluruh properti (Publish + Draft), filter kategori/Draft, ubah status (`Tersedia`/`Dipesan`/`Terjual`), toggle Publish/Draft, hapus aman (otomatis ke Draft jika sudah punya booking) |
| `/properties/new` & `/properties/:id/edit` | `AdminPropertyFormScreen` | Form tambah/ubah properti **tanpa** input `views_count`, unggah & kompres foto (`<=1600px`, `<=1MB` JPEG, maks 10 foto, pilih utama), `LocationPickerField` (GoogleMap saat `MAPS_API_KEY` aktif + preset kecamatan + input koordinat manual) |
| `/bookings` | `AdminBookingsScreen` | Daftar leads masuk, pencarian nama/kode/WA, filter 6 status funnel, tombol **Chat WA** (`wa.me`) & bottom sheet `Tetapkan Jadwal Survei` |
| `/bookings/:id` | `AdminBookingDetailScreen` | Detail pengajuan, ubah `funnel_status` (`new` s/d `closed_won`/`closed_lost`), `confirmed_survey_date`, `admin_notes`, serta konfirmasi ubah status unit saat `closed_won` |
| `/master-data` | `AdminMasterDataScreen` | CRUD Master Kategori & Master Daerah dengan auto-slug, info akun Admin, serta tombol Keluar |

## Konfigurasi, Akun Admin & Build

1. **Pembuatan Akun Admin:** Publik signup dimatikan. Buat user lewat **Supabase Dashboard -> Authentication -> Users**, lalu set peran lewat SQL Editor:
   ```sql
   update auth.users
      set raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb) || '{"role": "admin"}'::jsonb
    where email = 'admin@rindangalam.id';
   ```
2. **Google Maps API Key:** Isi `MAPS_API_KEY=...` di `apps/app_admin/android/local.properties` (tidak di-*commit*).
3. **Jalankan debug / test / APK rilis:**
   ```powershell
   flutter pub get
   flutter analyze
   flutter test
   flutter build apk --release
   ```
   Untuk menandatangani rilis produksi, salin `android/key.properties.example` ke `android/key.properties` dan arahkan ke berkas `.jks` Anda.

# Griya Hijau (PT Rindang Alam) — Paket Semi Full

Monorepo Flutter Android + Supabase untuk katalog properti hunian & ruko (`app_customer`), pengelolaan katalog/CRM/riset pasar (`app_admin`), dan paket utilitas/tema bersama (`shared`).

## Struktur Monorepo

```text
rindang_alam/
  apps/
    app_customer/          # Aplikasi calon pembeli (id.rindangalam.customer)
    app_admin/             # Aplikasi admin & CRM/dashboard (id.rindangalam.admin)
  packages/
    shared/                # Model skema, tema Putih & Hijau Muda, kalkulator KPR, widget & seeder
  supabase/
    migrations/            # 6 berkas migrasi SQL berurutan (tabel, RLS, fungsi, storage, seeder, RPC dashboard)
    tests/                 # Skrip SQL verifikasi transaksional RLS & kriteria penerimaan
  docs/
    PRD.md                 # Spesifikasi produk Paket Semi Full
    IMPLEMENTATION_PLAN.md # Rencana pengerjaan 4 tahap
    SCHEMA.md              # Kontrak skema database, RLS, & RPC
    UAT_CHECKLIST.md       # Laporan QA otomatis & daftar periksa UAT perangkat fisik
```

## Ruang Lingkup (Paket Semi Full)

Aplikasi ini dibuat khusus untuk **Android** dengan batasan Paket Semi Full:
- **Disertakan:** Katalog properti terstruktur (`property_categories`, `locations`), galeri foto zoomable, pelacakan kunjungan (`record_property_view`), pencatatan pencarian (`search_logs`), Google Maps + *Petunjuk Arah*, kalkulator KPR simulasi dengan disclaimer wajib, formulir booking tanpa pembayaran (`create_booking`), CRUD properti/master Admin, kompresi foto otomatis (`<=1600px`, `<=1MB`), pemilih koordinat peta, CRM booking 6 status + klik-ke-WhatsApp (`wa.me`), serta dashboard riset pasar (`fl_chart`).
- **Dikecualikan (Paket Full):** AI Chatbot, pesan WhatsApp otomatis / Gateway, Edge Functions / cron reminder, grafik funnel otomatis, pembayaran online (Midtrans/Xendit), dan target Web/iOS/Desktop.

---

## Prasyarat & Setup Awal

1. **Flutter SDK** (`channel stable`, Dart SDK `^3.14.0`), **Android SDK**, dan **Java JDK** (untuk Gradle & `keytool`).
2. **Proyek Supabase** yang telah menerapkan seluruh berkas migrasi di `supabase/migrations/`:
   1. `20261114000001_init_schema.sql`
   2. `20261114000002_rls_and_roles.sql`
   3. `20261114000003_functions_and_column_grants.sql`
   4. `20261114000004_storage_bucket.sql`
   5. `20261114000005_seed_data.sql`
   6. `20261115000006_admin_dashboard_functions.sql`

### Konfigurasi Google Maps API Key (Non-Repo)
Tambahkan kunci API Google Maps Android ke masing-masing berkas `local.properties` (sudah diabaikan `.gitignore`, jangan pernah di-*commit*):
- `apps/app_customer/android/local.properties`
- `apps/app_admin/android/local.properties`

```properties
flutter.sdk=C:\\src\\flutter
MAPS_API_KEY=AIzaSy...
```

> Di Google Cloud Console, aktifkan **Maps SDK for Android** dan **Billing**, lalu batasi API key hanya untuk package Android `id.rindangalam.customer` dan `id.rindangalam.admin` beserta SHA-1 keystore Anda.

### Membuat Akun Admin Supabase
Pendaftaran publik Auth dinonaktifkan. Buat akun Admin di **Supabase Dashboard -> Authentication -> Users -> Add user**, lalu jalankan SQL berikut di **SQL Editor** agar klaim peran tersimpan di `app_metadata` (bukan `user_metadata`):

```sql
update auth.users
   set raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb) || '{"role": "admin"}'::jsonb
 where email = 'admin@rindangalam.id';
```

---

## Menjalankan Uji & Analisis

Jalankan analisis dan seluruh tes unit/widget dari masing-masing direktori:

```powershell
# Paket shared (kalkulator KPR & tema/widget bersama)
cd packages\shared
flutter pub get
flutter analyze
flutter test

# Customer App
cd ..\..\apps\app_customer
flutter pub get
flutter analyze
flutter test

# Admin App
cd ..\app_admin
flutter pub get
flutter analyze
flutter test
```

> Untuk verifikasi RLS & log transaksional di database hidup tanpa meninggalkan data sampah, buka [supabase/tests/rls_and_acceptance_test.sql](supabase/tests/rls_and_acceptance_test.sql) lalu jalankan di **Supabase SQL Editor** (`BEGIN; ... ROLLBACK;`).

---

## Build APK Rilis & Penandatanganan (Signing)

Kedua aplikasi mendukung konfigurasi *signing hybrid* di `android/app/build.gradle.kts`:
- Jika `android/key.properties` dan berkas `.jks` ada -> APK rilis ditandatangani dengan keystore produksi.
- Jika `android/key.properties` belum dibuat -> otomatis memakai *debug key* untuk keperluan UAT/instalasi uji internal.

### Membuat Keystore Produksi (Opsional sebelum rilis resmi)
1. Buat keystore (jangan simpan file `.jks` ke Git):
   ```powershell
   keytool -genkey -v -keystore apps\app_customer\android\app\upload-keystore.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
2. Salin `apps/<app>/android/key.properties.example` menjadi `apps/<app>/android/key.properties` dan isi sandi/alias sesuai keystore. (`**/key.properties` dan `*.jks` sudah masuk `.gitignore`).
3. Jalankan build APK:
   ```powershell
   cd apps\app_customer
   flutter build apk --release

   cd ..\app_admin
   flutter build apk --release
   ```
   Hasil build berada di `build/app/outputs/flutter-apk/app-release.apk` pada masing-masing aplikasi.

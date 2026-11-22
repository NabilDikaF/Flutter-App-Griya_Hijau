# Griya Hijau — PT Rindang Alam

Monorepo Flutter (Android) untuk aplikasi katalog properti hunian dan ruko **Griya Hijau** milik **PT Rindang Alam**.

## Struktur Proyek

```text
rindang_alam/
  apps/
    app_customer/    # Aplikasi Android untuk calon pembeli
    app_admin/       # Aplikasi Android untuk tim internal & pengelolaan katalog
  packages/
    shared/          # Tema UI, komponen, model data, dan utilitas bersama
  supabase/          # Konfigurasi dan skema backend
```

## Ringkasan Aplikasi

- **Customer App (`apps/app_customer`)**: jelajah katalog properti, pencarian dan filter, galeri foto, peta lokasi, simulasi kalkulator KPR, pengajuan jadwal survei atau booking unit, serta cek status booking.
- **Admin App (`apps/app_admin`)**: ringkasan performa katalog, pengelolaan properti dan galeri foto, tindak lanjut leads booking, serta pengelolaan kategori dan area.
- **Shared Package (`packages/shared`)**: token desain, komponen antarmuka, model bersama, pemformat tampilan, dan kalkulator KPR.

## Prasyarat

- Flutter SDK (`channel stable`)
- Android SDK & Java JDK (`keytool`, `apksigner`, `adb`)

Konfigurasi lingkungan runtime dan penandatanganan rilis disimpan pada berkas lokal terpisah yang diabaikan oleh `.gitignore` (`android/key.properties`, `android/local.properties`, `*.jks`, `*.keystore`).

## Menjalankan & Menguji (Development)

Jalankan perintah berikut dari direktori paket yang ingin dijalankan (`packages/shared`, `apps/app_customer`, atau `apps/app_admin`):

```powershell
flutter pub get
dart analyze
flutter test
```

Untuk menjalankan mode debug dengan koneksi Supabase lokal/staging di emulator atau perangkat:

```powershell
flutter run `
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=<supabase-publishable-or-anon-key> `
  --dart-define=MAPS_API_KEY=<google-maps-api-key>
```

> Bila `--dart-define` tidak disertakan saat debug/test, kedua aplikasi berjalan offline memakai `SeedData` lokal (tanpa terhubung ke backend).

## Menyiapkan Keystore Rilis (Jangan Di-Commit)

Build rilis (`--release`) secara default **wajib** memiliki berkas `android/key.properties` yang mengarah ke keystore upload rilis yang valid. Tanpa konfigurasi ini, Gradle menggagalkan build secara eksplisit.

1. Buat keystore baru (sekali saja, simpan di luar repo atau lokasi yang di-ignore):

   ```powershell
   keytool -genkeypair -v -keystore android/app/upload-keystore.jks `
     -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```

2. Salin templat ke masing-masing aplikasi lalu isi nilai sebenarnya:

   ```powershell
   Copy-Item apps\app_customer\android\key.properties.example apps\app_customer\android\key.properties
   Copy-Item apps\app_admin\android\key.properties.example apps\app_admin\android\key.properties
   ```

3. Isi `apps/<app>/android/key.properties`:

   ```properties
   storePassword=<password-keystore>
   keyPassword=<password-key>
   keyAlias=upload
   storeFile=../app/upload-keystore.jks
   ```

4. Isi `MAPS_API_KEY=<google-maps-api-key>` pada `apps/<app>/android/local.properties` bila manifest Android Google Maps diaktifkan.
5. Pastikan `.gitignore` tetap mengabaikan `key.properties`, `local.properties`, `*.jks`, dan `*.keystore` — jangan pernah menaruh file tersebut ke Git.

## Konfigurasi Wajib Build Rilis (`--dart-define`)

Kedua aplikasi bersifat **fail-closed** pada build rilis dan tidak menyediakan nilai default URL/key di kode sumber:

- **Wajib**: `SUPABASE_URL` (harus `https://...`)
- **Wajib**: `SUPABASE_ANON_KEY` (publishable/anon key proyek Supabase — **jangan** pernah memakai `service_role` key)
- **Opsional**: `MAPS_API_KEY` (atau `--dart-define=DISABLE_GOOGLE_MAPS=true` bila peta tertanam tidak dipakai; fitur fallback koordinat & tautan Google Maps tetap berjalan)

## Perintah Build Rilis Resmi

Jalankan per aplikasi (`apps\app_customer` dan `apps\app_admin`) dengan lockfile ketat (`--enforce-lockfile`) setelah `android/key.properties` terisi. R8 minification, resource shrinking, `allowBackup="false"`, `usesCleartextTraffic="false"`, serta (`app_admin`) `FLAG_SECURE` dan penyimpanan sesi Android Keystore otomatis aktif pada build rilis.

```powershell
flutter pub get --enforce-lockfile
flutter build apk --release `
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=<supabase-publishable-or-anon-key> `
  --dart-define=MAPS_API_KEY=<google-maps-api-key>
```

Untuk distribusi Google Play (`appbundle`):

```powershell
flutter build appbundle --release `
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=<supabase-publishable-or-anon-key> `
  --dart-define=MAPS_API_KEY=<google-maps-api-key>
```

### Opt-Out Uji Coba Rilis Lokal Tanpa Keystore

Hanya untuk uji coba lokal darurat di mesin pengembang (APK hasil build ditandatangani debug key dan **tidak** mengaktifkan R8/ProGuard; **dilarang didistribusikan ke pengguna/Play Store**):

```powershell
$env:ORG_GRADLE_PROJECT_ALLOW_DEBUG_SIGNING = "true"
flutter build apk --release `
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=<supabase-publishable-or-anon-key>
Remove-Item Env:ORG_GRADLE_PROJECT_ALLOW_DEBUG_SIGNING
```

Atau langsung lewat Gradle di `apps\<app>\android`:

```powershell
.\gradlew.bat assembleRelease -PALLOW_DEBUG_SIGNING=true
```

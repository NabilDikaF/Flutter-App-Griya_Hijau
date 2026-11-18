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
- Android SDK & Java JDK

Konfigurasi lingkungan runtime dan penandatanganan rilis disimpan pada berkas lokal terpisah yang diabaikan oleh `.gitignore`.

## Menjalankan & Menguji

Jalankan perintah berikut dari direktori paket yang ingin dijalankan (`packages/shared`, `apps/app_customer`, atau `apps/app_admin`):

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

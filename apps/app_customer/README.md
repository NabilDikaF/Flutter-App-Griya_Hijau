# Griya Hijau — Customer App (`apps/app_customer`)

Aplikasi Android resmi untuk calon pembeli properti **PT Rindang Alam (Griya Hijau)**.

## Fitur Utama

- **Beranda (`HomeScreen`)**: hero promosi, pencarian cepat ke katalog, daftar properti unggulan, dan kontak kantor.
- **Katalog Properti (`CatalogScreen`)**: daftar properti terpublikasi dengan pencarian kata kunci, filter kategori/area/harga/status, serta paginasi.
- **Detail Properti (`PropertyDetailScreen`)**: galeri foto interaktif dengan zoom, spesifikasi unit, kalkulator simulasi KPR, peta lokasi, dan tautan petunjuk arah.
- **Formulir Booking (`BookingFormScreen`)**: pengajuan jadwal survei lokasi atau pemesanan unit.
- **Konfirmasi Booking (`BookingSuccessScreen`)**: ringkasan kode booking dan pintasan hubungi admin via WhatsApp.
- **Cek Booking (`CheckBookingScreen`)**: pencarian dan pemantauan progres status pengajuan booking.
- **Tentang Kami (`AboutScreen`)**: profil perusahaan, visi dan misi, ringkasan layanan, serta kontak resmi.

## Menjalankan & Menguji

Konfigurasi kunci runtime dan penandatanganan rilis disimpan pada berkas lokal yang diabaikan oleh `.gitignore`.

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

# Griya Hijau — Aplikasi Admin (`apps/app_admin`)

Aplikasi Android khusus tim internal dan pemasaran **PT Rindang Alam (Griya Hijau)**.

## Fitur Utama

- **Login Admin (`AdminLoginScreen`)**: akses masuk khusus pengguna internal yang terotorisasi.
- **Dashboard (`AdminDashboardScreen`)**: ringkasan analitik performa properti, tren kunjungan, statistik pencarian, dan jadwal terbaru.
- **Kelola Properti (`AdminPropertiesScreen`)**: daftar properti, filter status dan kategori, serta pembaruan status publikasi dan ketersediaan unit.
- **Form Properti (`AdminPropertyFormScreen`)**: tambah dan ubah data properti, unggah serta kelola foto galeri, dan pilih lokasi pada peta.
- **Manajemen Booking (`AdminBookingsScreen` & `AdminBookingDetailScreen`)**: daftar leads masuk, filter status tindak lanjut, penetapan jadwal survei, pembaruan catatan tindak lanjut, dan pintasan WhatsApp.
- **Master Data (`AdminMasterDataScreen`)**: pengelolaan daftar kategori properti, area lokasi, dan informasi akun.

## Menjalankan & Menguji

Konfigurasi kunci runtime dan penandatanganan rilis disimpan pada berkas lokal yang diabaikan oleh `.gitignore`.

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

# Griya Hijau — Customer App (`apps/app_customer`)

Aplikasi Android untuk calon pembeli properti **PT Rindang Alam (Griya Hijau)** (`applicationId: id.rindangalam.customer`).

## Daftar Fitur & Rute

| Rute | Layar | Fitur Utama |
|---|---|---|
| `/` | `HomeScreen` | Hero promosi, pencarian cepat ke katalog, proyek unggulan, ringkasan & kontak kantor (`wa.me`) |
| `/katalog` | `CatalogScreen` | Daftar kartu properti terpublikasi, pencarian dengan jeda `400ms`, filter kategori/kecamatan/harga/status, paginasi 20 item (`search_properties` + catat `search_logs`) |
| `/properti/:slug` | `PropertyDetailScreen` | Galeri geser + zoom fullscreen (`photo_view`), 8 item spesifikasi, Simbol Mata + `record_property_view`, kalkulator KPR simulasi + disclaimer wajib, peta Google Maps & *Petunjuk Arah* |
| `/properti/:slug/booking` | `BookingFormScreen` | Form booking tanpa pembayaran, validasi nomor WhatsApp `628xxx`, tujuan *Survei Lokasi* atau *Langsung Booking Unit* (`create_booking`) |
| `/booking-berhasil` | `BookingSuccessScreen` | Kode booking unik (`BK-...`) dan CTA **Hubungi Admin via WhatsApp** |
| `/tentang-kami` | `AboutScreen` | Profil perusahaan, visi & misi, statistik, serta tombol WhatsApp kantor |

Semua layar data dilengkapi state *loading*, *empty*, dan *error* dengan tombol **Coba Lagi**.

## Konfigurasi & Menjalankan

1. **Google Maps API Key:** Pastikan `MAPS_API_KEY=...` terisi di `apps/app_customer/android/local.properties` (tidak di-*commit*). Saat dijalankan di Android (`main.dart` menyelesaikan `Supabase.initialize`), `EnvConfig.hasMapsApiKey` aktif otomatis kecuali di-override `--dart-define=DISABLE_GOOGLE_MAPS=true`.
2. **Supabase Config:** Menggunakan `SUPABASE_URL` dan `SUPABASE_ANON_KEY` (opsional override lewat `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`). Jangan pernah menaruh `service_role` key.
3. **Jalankan debug / test / APK rilis:**
   ```powershell
   flutter pub get
   flutter analyze
   flutter test
   flutter build apk --release
   ```
   Untuk menandatangani rilis produksi, salin `android/key.properties.example` ke `android/key.properties` dan arahkan ke berkas `.jks` Anda.

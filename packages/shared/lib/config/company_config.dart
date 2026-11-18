/// Item statistik ringkas perusahaan untuk Beranda dan Tentang Kami.
class CompanyStat {
  const CompanyStat({required this.value, required this.label});

  final String value;
  final String label;
}

/// Konfigurasi konten dan batasan aplikasi PT Rindang Alam / Griya Hijau.
abstract final class CompanyConfig {
  static const String brandName = 'Griya Hijau';
  static const String companyName = 'PT Rindang Alam';
  static const String displayBrand = '$brandName ($companyName)';
  static const String tagline =
      'Developer properti terpercaya untuk hunian dan ruko berkualitas.';
  static const String shortDescription =
      'Menghadirkan kawasan perumahan asri dan ruko strategis dengan legalitas '
      'jelas serta layanan pendampingan KPR yang transparan sejak 2012.';
  static const String aboutStory =
      'PT Rindang Alam melalui merek Griya Hijau berkomitmen membangun hunian '
      'dan area komersial yang nyaman, aman, serta bernilai investasi tinggi. '
      'Setiap proyek dirancang dengan tata ruang fungsional, lingkungan hijau, '
      'dan kepastian legalitas untuk ketenangan keluarga maupun pelaku usaha.';
  static const String vision =
      'Menjadi pengembang properti pilihan utama yang menghadirkan hunian '
      'berkualitas, legalitas terjamin, dan layanan purna jual terpercaya.';
  static const List<String> missions = <String>[
    'Membangun perumahan dan ruko di lokasi strategis dengan akses mudah.',
    'Menjamin kelengkapan legalitas SHM/HGB untuk setiap unit yang dipasarkan.',
    'Memberikan pendampingan survei dan proses KPR yang jujur serta transparan.',
  ];
  static const List<CompanyStat> stats = <CompanyStat>[
    CompanyStat(value: '12+', label: 'Tahun Pengalaman'),
    CompanyStat(value: '850+', label: 'Unit Terjual'),
    CompanyStat(value: '100%', label: 'Legalitas SHM/HGB'),
    CompanyStat(value: '24 Jam', label: 'Keamanan Kawasan'),
  ];

  static const String officeAddress =
      'Jl. Contoh Raya No. 12, Kec. Sukamaju, Bandung';
  static const String officeHours = 'Senin - Sabtu, 08.00 - 17.00 WIB';
  static const String officeWhatsapp = '6281200000000';
  static const String officePhoneDisplay = '0812-0000-0000';
  static const double officeLatitude = -6.914744;
  static const double officeLongitude = 107.609810;

  /// Teks wajib disclaimer kalkulator KPR sesuai PRD Bagian 4.3.4.
  static const String kprDisclaimer =
      'Perhitungan di atas hanya bersifat simulasi estimasi awal. Untuk '
      'penentuan suku bunga KPR resmi, minimal DP yang berlaku, serta promo '
      'khusus, silakan isi Formulir Booking di bawah ini atau kunjungi '
      'langsung Kantor Pemasaran kami.';

  /// Parameter default sesuai ANTIGRAVITY.md Bagian 11.
  static const int catalogPageSize = 20;
  static const int searchDebounceMs = 400;
  static const int maxBookingPerHourPerWhatsapp = 3;
  static const int maxImageWidthPx = 1600;
  static const int maxImageBytes = 1024 * 1024;
  static const int maxImagesPerProperty = 10;

  /// Nama bucket Storage Supabase.
  static const String propertyImagesBucket = 'property-images';
}

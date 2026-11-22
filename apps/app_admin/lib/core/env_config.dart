/// Konfigurasi runtime Aplikasi Admin dari `--dart-define`.
/// Jangan pernah menaruh `service_role` key, API key Google Maps, atau fallback kredensial di kode sumber.
abstract final class EnvConfig {
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');
  static const String mapsApiKey = String.fromEnvironment('MAPS_API_KEY');
  static const bool mapsDisabled = bool.fromEnvironment('DISABLE_GOOGLE_MAPS');

  /// Diubah menjadi `true` setelah `Supabase.initialize` selesai di `main()`.
  /// Membuat widget/unit test tetap berjalan dengan data lokal in-memory.
  static bool isSupabaseInitialized = false;

  /// Pesan kegagalan inisialisasi Supabase (dipakai fail-closed pada mode rilis).
  static String? supabaseInitError;

  static List<String> missingRequiredKeys({
    String url = supabaseUrl,
    String anonKey = supabaseAnonKey,
  }) {
    return <String>[
      if (url.trim().isEmpty) 'SUPABASE_URL',
      if (anonKey.trim().isEmpty) 'SUPABASE_ANON_KEY',
    ];
  }

  static bool hasValidReleaseUrl([String url = supabaseUrl]) {
    final Uri? uri = Uri.tryParse(url.trim());
    return uri != null &&
        uri.scheme.toLowerCase() == 'https' &&
        uri.host.trim().isNotEmpty;
  }

  static String? releaseConfigError({
    String url = supabaseUrl,
    String anonKey = supabaseAnonKey,
  }) {
    final List<String> missing = missingRequiredKeys(
      url: url,
      anonKey: anonKey,
    );
    if (missing.isNotEmpty) {
      return 'Konfigurasi layanan belum tersedia (${missing.join(', ')} kosong). '
          'Silakan perbarui aplikasi atau hubungi administrator.';
    }
    if (!hasValidReleaseUrl(url)) {
      return 'Konfigurasi alamat server tidak valid (wajib HTTPS). '
          'Silakan perbarui aplikasi atau hubungi administrator.';
    }
    return null;
  }

  static bool get hasSupabaseConfig =>
      supabaseUrl.trim().isNotEmpty && supabaseAnonKey.trim().isNotEmpty;

  static bool get hasMapsApiKey =>
      !mapsDisabled && mapsApiKey.trim().isNotEmpty;
}

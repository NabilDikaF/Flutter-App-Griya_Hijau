/// Konfigurasi runtime aplikasi dari `--dart-define`.
/// Jangan pernah menaruh `service_role` key atau API key Google Maps di kode sumber.
abstract final class EnvConfig {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://rekqhpdaenzgnjvajquv.supabase.co',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_H0TlDdvmffa9BQ5y1ASA8w_ghA9-kzd',
  );
  static const String mapsApiKey = String.fromEnvironment('MAPS_API_KEY');
  static const bool mapsDisabled = bool.fromEnvironment('DISABLE_GOOGLE_MAPS');

  /// Diubah menjadi `true` setelah `Supabase.initialize` selesai di `main()`.
  /// Membuat unit/widget test tetap berjalan offline dengan `SeedData`.
  static bool isSupabaseInitialized = false;

  static bool get hasSupabaseConfig =>
      supabaseUrl.trim().isNotEmpty && supabaseAnonKey.trim().isNotEmpty;

  static bool get hasMapsApiKey =>
      !mapsDisabled && (isSupabaseInitialized || mapsApiKey.trim().isNotEmpty);
}

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Abstraksi penyimpanan key-value terenkripsi untuk pengujian dan runtime Android Keystore.
abstract interface class SecureKeyValueStore {
  Future<bool> containsKey(String key);
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// Implementasi default berbasis `flutter_secure_storage` (Android Keystore RSA-OAEP + AES-GCM).
class FlutterSecureKeyValueStore implements SecureKeyValueStore {
  const FlutterSecureKeyValueStore({
    FlutterSecureStorage? storage,
  }) : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(),
            );

  final FlutterSecureStorage _storage;

  @override
  Future<bool> containsKey(String key) => _storage.containsKey(key: key);

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// Penyimpanan sesi Supabase terenkripsi menggunakan Android Keystore (tanpa plaintext SharedPreferences).
class SecureSupabaseLocalStorage extends LocalStorage {
  const SecureSupabaseLocalStorage({
    required this.persistSessionKey,
    SecureKeyValueStore store = const FlutterSecureKeyValueStore(),
  }) : _store = store;

  final String persistSessionKey;
  final SecureKeyValueStore _store;

  static String sessionKeyForUrl(String supabaseUrl) {
    final String host = Uri.tryParse(supabaseUrl.trim())?.host ?? '';
    final String projectRef = host.split('.').first.trim();
    if (projectRef.isEmpty) {
      return supabasePersistSessionKey;
    }
    return 'sb-$projectRef-auth-token';
  }

  Future<void> _deleteQuietly() async {
    try {
      await _store.delete(persistSessionKey);
    } catch (_) {
      // Abaikan kegagalan penghapusan entri rusak; status tetap fail-closed.
    }
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() async {
    try {
      return await _store.containsKey(persistSessionKey);
    } catch (_) {
      await _deleteQuietly();
      return false;
    }
  }

  @override
  Future<String?> accessToken() async {
    try {
      return await _store.read(persistSessionKey);
    } catch (_) {
      await _deleteQuietly();
      return null;
    }
  }

  @override
  Future<void> persistSession(String persistSessionString) =>
      _store.write(persistSessionKey, persistSessionString);

  @override
  Future<void> removePersistedSession() => _store.delete(persistSessionKey);
}

/// Penyimpanan PKCE verifier terenkripsi untuk `FlutterAuthClientOptions.pkceAsyncStorage`.
class SecureGotrueAsyncStorage extends GotrueAsyncStorage {
  const SecureGotrueAsyncStorage({
    SecureKeyValueStore store = const FlutterSecureKeyValueStore(),
  }) : _store = store;

  final SecureKeyValueStore _store;

  Future<void> _deleteQuietly(String key) async {
    try {
      await _store.delete(key);
    } catch (_) {
      // Abaikan kegagalan penghapusan entri rusak.
    }
  }

  @override
  Future<String?> getItem({required String key}) async {
    try {
      return await _store.read(key);
    } catch (_) {
      await _deleteQuietly(key);
      return null;
    }
  }

  @override
  Future<void> setItem({required String key, required String value}) =>
      _store.write(key, value);

  @override
  Future<void> removeItem({required String key}) => _store.delete(key);
}

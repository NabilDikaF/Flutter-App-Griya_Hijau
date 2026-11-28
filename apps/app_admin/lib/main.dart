import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared/shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/env_config.dart';
import 'core/secure_session_storage.dart';
import 'data/admin_repository.dart';
import 'routing/app_router.dart';

Future<bool> initializeAdminSupabase({
  bool isRelease = kReleaseMode,
  SecureKeyValueStore? activityStore,
}) async {
  final String? releaseError =
      isRelease ? EnvConfig.releaseConfigError() : null;
  if (releaseError != null || !EnvConfig.hasSupabaseConfig) {
    EnvConfig.isSupabaseInitialized = false;
    EnvConfig.supabaseInitError = releaseError;
    return false;
  }

  try {
    await Supabase.initialize(
      url: EnvConfig.supabaseUrl,
      publishableKey: EnvConfig.supabaseAnonKey,
      authOptions: FlutterAuthClientOptions(
        localStorage: SecureSupabaseLocalStorage(
          persistSessionKey: SecureSupabaseLocalStorage.sessionKeyForUrl(
            EnvConfig.supabaseUrl,
          ),
        ),
        pkceAsyncStorage: const SecureGotrueAsyncStorage(),
      ),
    );
    EnvConfig.isSupabaseInitialized = true;
    EnvConfig.supabaseInitError = null;
  } catch (_) {
    EnvConfig.isSupabaseInitialized = false;
    EnvConfig.supabaseInitError =
        'Gagal terhubung ke server autentikasi. Periksa koneksi internet Anda lalu coba lagi.';
    return false;
  }

  try {
    final AdminRepository repo = AdminRepository(Supabase.instance.client);
    final bool hasSession =
        Supabase.instance.client.auth.currentSession != null;
    if (hasSession) {
      final bool expired =
          await AdminSessionNotifier.enforcePersistedIdleTimeout(
        repository: repo,
        store: activityStore ?? const FlutterSecureKeyValueStore(),
      );
      if (expired) {
        AdminSessionNotifier.markColdStartSessionExpired();
      } else {
        await repo.ensureValidAdminSession();
      }
    }
  } catch (_) {
    // Tetap fail-closed bila verifikasi awal sesi gagal; pengguna harus login ulang.
  }
  return true;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeAdminSupabase();
  runApp(const ProviderScope(child: AdminApp()));
}

class AdminApp extends ConsumerStatefulWidget {
  const AdminApp({
    super.key,
    this.requireSupabase = kReleaseMode,
    this.onRetryInit,
  });

  final bool requireSupabase;
  final Future<bool> Function()? onRetryInit;

  @override
  ConsumerState<AdminApp> createState() => _AdminAppState();
}

class _AdminAppState extends ConsumerState<AdminApp>
    with WidgetsBindingObserver {
  bool _isRetrying = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent && mounted) {
      if (widget.requireSupabase && !EnvConfig.isSupabaseInitialized) {
        return false;
      }
      ref.read(adminSessionProvider).recordUserActivity();
    }
    return false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (widget.requireSupabase && !EnvConfig.isSupabaseInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      unawaited(ref.read(adminSessionProvider).flushActivityTimestamp());
    } else if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(adminSessionProvider).checkIdleTimeout());
    }
  }

  Future<void> _retryInit() async {
    if (_isRetrying) return;
    setState(() => _isRetrying = true);
    final bool initialized =
        await (widget.onRetryInit ?? initializeAdminSupabase)();
    if (!mounted) return;
    if (initialized) {
      ref.invalidate(adminRepositoryProvider);
      ref.invalidate(adminSessionProvider);
    }
    setState(() => _isRetrying = false);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.requireSupabase && !EnvConfig.isSupabaseInitialized) {
      return MaterialApp(
        title: '${CompanyConfig.displayBrand} — Admin',
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          key: const Key('admin_release_connectivity_error_screen'),
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(
                        Icons.cloud_off_outlined,
                        size: 56,
                        color: AppColors.errorText,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const Text(
                        'Koneksi server gagal',
                        textAlign: TextAlign.center,
                        style: AppTypography.h2,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        EnvConfig.supabaseInitError ??
                            'Gagal terhubung ke server autentikasi. Periksa koneksi internet Anda lalu coba lagi.',
                        textAlign: TextAlign.center,
                        style: AppTypography.bodyNormal,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      ElevatedButton(
                        key: const Key('admin_release_connectivity_retry_button'),
                        onPressed: _isRetrying ? null : _retryInit,
                        child: _isRetrying
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.white,
                                ),
                              )
                            : const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final GoRouter router = ref.watch(adminRouterProvider);
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => ref.read(adminSessionProvider).recordUserActivity(),
      onPointerMove: (_) => ref.read(adminSessionProvider).recordUserActivity(),
      onPointerSignal: (_) =>
          ref.read(adminSessionProvider).recordUserActivity(),
      child: MaterialApp.router(
        title: '${CompanyConfig.displayBrand} — Admin',
        theme: AppTheme.lightTheme,
        routerConfig: router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared/shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/env_config.dart';
import 'data/customer_repository.dart';
import 'routing/app_router.dart';

Future<bool> initializeCustomerSupabase() async {
  if (!EnvConfig.hasSupabaseConfig) {
    EnvConfig.isSupabaseInitialized = false;
    EnvConfig.supabaseInitError = kReleaseMode
        ? 'Konfigurasi layanan belum tersedia. Silakan perbarui aplikasi atau hubungi tim dukungan.'
        : null;
    return false;
  }

  try {
    await Supabase.initialize(
      url: EnvConfig.supabaseUrl,
      publishableKey: EnvConfig.supabaseAnonKey,
    );
    EnvConfig.isSupabaseInitialized = true;
    EnvConfig.supabaseInitError = null;
    return true;
  } catch (_) {
    EnvConfig.isSupabaseInitialized = false;
    EnvConfig.supabaseInitError =
        'Gagal terhubung ke server. Periksa koneksi internet Anda lalu coba lagi.';
    return false;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeCustomerSupabase();
  runApp(const ProviderScope(child: CustomerApp()));
}

class CustomerApp extends ConsumerStatefulWidget {
  const CustomerApp({
    super.key,
    this.requireSupabase = kReleaseMode,
    this.onRetryInit,
  });

  final bool requireSupabase;
  final Future<bool> Function()? onRetryInit;

  @override
  ConsumerState<CustomerApp> createState() => _CustomerAppState();
}

class _CustomerAppState extends ConsumerState<CustomerApp> {
  bool _isRetrying = false;

  Future<void> _retryInit() async {
    if (_isRetrying) return;
    setState(() => _isRetrying = true);
    final bool initialized =
        await (widget.onRetryInit ?? initializeCustomerSupabase)();
    if (!mounted) return;
    if (initialized) {
      ref.invalidate(customerRepositoryProvider);
      ref.invalidate(customerBootstrapProvider);
    }
    setState(() => _isRetrying = false);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.requireSupabase && !EnvConfig.isSupabaseInitialized) {
      return MaterialApp(
        title: CompanyConfig.displayBrand,
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          key: const Key('release_connectivity_error_screen'),
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
                            'Gagal terhubung ke server. Periksa koneksi internet Anda lalu coba lagi.',
                        textAlign: TextAlign.center,
                        style: AppTypography.bodyNormal,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      ElevatedButton(
                        key: const Key('release_connectivity_retry_button'),
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

    final GoRouter router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: CompanyConfig.displayBrand,
      theme: AppTheme.lightTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}

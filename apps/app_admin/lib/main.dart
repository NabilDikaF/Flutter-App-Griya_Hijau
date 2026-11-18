import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared/shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/env_config.dart';
import 'routing/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (EnvConfig.hasSupabaseConfig) {
    try {
      await Supabase.initialize(
        url: EnvConfig.supabaseUrl,
        publishableKey: EnvConfig.supabaseAnonKey,
      );
      EnvConfig.isSupabaseInitialized = true;

      final User? current = Supabase.instance.client.auth.currentUser;
      if (current != null &&
          current.appMetadata['role']?.toString() != 'admin') {
        await Supabase.instance.client.auth.signOut();
      }
    } catch (_) {}
  }
  runApp(const ProviderScope(child: AdminApp()));
}

class AdminApp extends ConsumerWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GoRouter router = ref.watch(adminRouterProvider);
    return MaterialApp.router(
      title: '${CompanyConfig.displayBrand} — Admin',
      theme: AppTheme.lightTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}

import 'package:app_customer/core/env_config.dart';
import 'package:app_customer/core/external_launcher.dart';
import 'package:app_customer/data/customer_repository.dart';
import 'package:app_customer/main.dart';
import 'package:app_customer/screens/about_screen.dart';
import 'package:app_customer/screens/booking_form_screen.dart';
import 'package:app_customer/screens/booking_success_screen.dart';
import 'package:app_customer/screens/catalog_screen.dart';
import 'package:app_customer/screens/check_booking_screen.dart';
import 'package:app_customer/screens/property_detail_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared/shared.dart';

class _FailingViewCustomerRepository extends CustomerRepository {
  const _FailingViewCustomerRepository() : super(null);

  @override
  Future<int?> recordPropertyView(int propertyId) async {
    throw Exception('Simulated view failure');
  }
}

class _InactiveCategoryPropertyRepository extends CustomerRepository {
  const _InactiveCategoryPropertyRepository() : super(null);

  @override
  Future<Property?> getPropertyBySlug(String slug) async {
    return Property(
      id: 99,
      propertyCategoryId: 99,
      locationId: 1,
      title: 'Properti Kategori Nonaktif',
      slug: slug,
      price: 750000000,
      availabilityStatus: AvailabilityStatus.available,
      viewsCount: 5,
      isPublished: true,
      category: const PropertyCategory(
        id: 99,
        name: 'Kategori Nonaktif',
        slug: 'kategori-nonaktif',
        isActive: false,
      ),
      location: SeedData.locations.first,
    );
  }
}

Widget _wrapWithRouter(
  Widget child, {
  CustomerRepository? repositoryOverride,
  String initialLocation = '/',
}) {
  final GoRouter router = GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(path: '/', builder: (_, _) => child),
      GoRoute(path: '/katalog', builder: (_, _) => const CatalogScreen()),
      GoRoute(
        path: '/cek-booking',
        builder: (_, GoRouterState state) => CheckBookingScreen(
          initialCode: state.uri.queryParameters['code'],
          initialWhatsapp: state.uri.queryParameters['wa'],
        ),
      ),
      GoRoute(path: '/tentang-kami', builder: (_, _) => const AboutScreen()),
      GoRoute(
        path: '/properti/:slug',
        builder: (_, GoRouterState state) =>
            PropertyDetailScreen(slug: state.pathParameters['slug'] ?? ''),
      ),
      GoRoute(
        path: '/properti/:slug/booking',
        builder: (_, GoRouterState state) => BookingFormScreen(
          slug: state.pathParameters['slug'] ?? '',
          initialProperty:
              state.extra is Property ? state.extra as Property : null,
        ),
      ),
      GoRoute(
        path: '/booking-berhasil',
        builder: (_, GoRouterState state) => BookingSuccessScreen(
          args: state.extra is BookingSuccessArgs
              ? state.extra as BookingSuccessArgs
              : null,
        ),
      ),
    ],
  );
  return ProviderScope(
    overrides: repositoryOverride != null
        ? [customerRepositoryProvider.overrideWithValue(repositoryOverride)]
        : const [],
    child: MaterialApp.router(
      theme: AppTheme.lightTheme,
      routerConfig: router,
    ),
  );
}

void main() {
  testWidgets('HomeScreen renders hero, published featured properties, and excludes AI elements', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: CustomerApp()));
    await tester.pumpAndSettle();

    expect(find.text('Temukan rumah dan ruko impian Anda'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(4));
    expect(find.text('Cek Booking'), findsOneWidget);
    expect(find.textContaining('Asisten AI'), findsNothing);
    expect(find.textContaining('Tanya AI'), findsNothing);

    final Finder mainScrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('Proyek Unggulan'),
      300,
      scrollable: mainScrollable,
    );
    expect(find.text('Proyek Unggulan'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Griya Hijau Residence Tipe 45/84'),
      300,
      scrollable: mainScrollable,
    );
    expect(find.text('Griya Hijau Residence Tipe 45/84'), findsOneWidget);
    expect(find.text('Draft Cluster Anggrek Blok D2'), findsNothing);
  });

  testWidgets('AboutScreen uses WhatsApp CTA without Tanya AI label', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrapWithRouter(const AboutScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Tentang ${CompanyConfig.brandName}'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Siap survei lokasi bersama kami?'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Hubungi via WhatsApp'), findsOneWidget);
    expect(find.textContaining('Tanya AI'), findsNothing);
  });

  testWidgets('CatalogScreen filters by category chip and debounced keyword search', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrapWithRouter(const CatalogScreen()));
    await tester.pumpAndSettle();

    expect(
      find.text('6 unit properti tersedia untuk disurvei maupun dipesan.'),
      findsOneWidget,
    );
    expect(find.byType(NavigationBar), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Ruko'));
    await tester.pumpAndSettle();

    expect(
      find.text('2 unit properti tersedia untuk disurvei maupun dipesan.'),
      findsOneWidget,
    );
    expect(find.text('Ruko Sentra Niaga Sari Indah'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Semua'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Bukit Asri');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();

    expect(find.text('Bukit Asri Villa Tipe 90/120'), findsOneWidget);
    expect(
      find.text('1 unit properti tersedia untuk disurvei maupun dipesan.'),
      findsOneWidget,
    );
  });

  testWidgets('PropertyDetailScreen shows incremented view count, 8 specs, KPR disclaimer, and Maps CTA', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrapWithRouter(
        const PropertyDetailScreen(slug: 'griya-hijau-residence-45-84'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Griya Hijau Residence Tipe 45/84'), findsWidgets);
    expect(find.text('Dilihat 43 kali'), findsOneWidget);
    expect(find.text('Luas Tanah'), findsOneWidget);
    expect(find.text('84 m²'), findsOneWidget);
    expect(find.text('SHM'), findsOneWidget);

    final Finder mainScrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text(CompanyConfig.kprDisclaimer),
      300,
      scrollable: mainScrollable,
    );
    expect(find.text(CompanyConfig.kprDisclaimer), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Petunjuk Arah (Buka di Google Maps)'),
      300,
      scrollable: mainScrollable,
    );
    expect(find.text('Petunjuk Arah (Buka di Google Maps)'), findsOneWidget);
    expect(find.text('Booking / Jadwalkan Survei'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('Booking flow validates WhatsApp 628 format and navigates to BookingSuccessScreen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: CustomerApp()));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Griya Hijau Residence Tipe 45/84'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Griya Hijau Residence Tipe 45/84'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Griya Hijau Residence Tipe 45/84'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Booking / Jadwalkan Survei'));
    await tester.pumpAndSettle();

    expect(find.text('Formulir Booking'), findsOneWidget);

    final Finder textFields = find.byType(TextFormField);
    await tester.enterText(textFields.at(0), 'Budi Santoso');
    await tester.pumpAndSettle();
    await tester.enterText(textFields.at(1), '081234567890');
    await tester.pumpAndSettle();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Kirim Pengajuan Booking'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kirim Pengajuan Booking'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Format nomor WhatsApp harus diawali 628 (contoh: 6281234567890).',
      ),
      findsOneWidget,
    );

    await tester.ensureVisible(textFields.at(1));
    await tester.pumpAndSettle();
    await tester.enterText(textFields.at(1), '6281234567890');
    await tester.pumpAndSettle();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Langsung Booking Unit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Langsung Booking Unit'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Kirim Pengajuan Booking'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kirim Pengajuan Booking'));
    await tester.pumpAndSettle();

    expect(find.text('Data Anda sudah kami terima'), findsOneWidget);
    expect(find.text('BK-20261114-DEMO1'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Hubungi Admin via WhatsApp'),
      300,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Hubungi Admin via WhatsApp'), findsOneWidget);
  });

  testWidgets('renders key screens without overflow across 360x640 and 412x915 phone sizes', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final Size size in const <Size>[Size(360, 640), Size(412, 915)]) {
      await tester.binding.setSurfaceSize(size);

      await tester.pumpWidget(
        ProviderScope(
          key: ValueKey<String>('home_$size'),
          child: const CustomerApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Temukan rumah dan ruko impian Anda'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        KeyedSubtree(
          key: ValueKey<String>('catalog_$size'),
          child: _wrapWithRouter(const CatalogScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Griya Hijau Residence Tipe 45/84'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        KeyedSubtree(
          key: ValueKey<String>('detail_$size'),
          child: _wrapWithRouter(
            const PropertyDetailScreen(slug: 'griya-hijau-residence-45-84'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Booking / Jadwalkan Survei'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('CheckBookingScreen looks up booking with both code + WA and hides customer_whatsapp row', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: CustomerApp()));
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Cek Booking'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cek Status Booking'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('check_booking_code_input')),
      'BK-20261114-DEMO1',
    );
    await tester.enterText(
      find.byKey(const Key('check_booking_wa_input')),
      '081234567890',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('check_booking_submit_button')));
    await tester.pumpAndSettle();

    expect(find.text('Jadwal survei'), findsOneWidget);
    expect(find.text('Griya Hijau Residence Tipe 45/84'), findsOneWidget);
    expect(find.text('Rina Marlina'), findsOneWidget);
    expect(find.text('Nomor WhatsApp'), findsNothing);
    expect(find.text('6281234567890'), findsNothing);
    expect(
      find.byKey(const Key('check_booking_wa_admin_button')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('CheckBookingScreen rejects phone-only or code-only lookup and shows identical not-found state for mismatches', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: CustomerApp()));
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Cek Booking'),
      ),
    );
    await tester.pumpAndSettle();

    // Phone-only lookup must be rejected and never emit masked codes.
    await tester.enterText(
      find.byKey(const Key('check_booking_wa_input')),
      '081234567890',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('check_booking_submit_button')));
    await tester.pumpAndSettle();

    expect(find.text('Kode booking wajib diisi.'), findsOneWidget);
    expect(find.text('BK-***********'), findsNothing);
    expect(find.text('Griya Hijau Residence Tipe 45/84'), findsNothing);

    // Code-only lookup must be rejected.
    await tester.ensureVisible(
      find.byKey(const Key('check_booking_code_input')),
    );
    await tester.enterText(
      find.byKey(const Key('check_booking_code_input')),
      'BK-20261114-DEMO1',
    );
    await tester.enterText(find.byKey(const Key('check_booking_wa_input')), '');
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('check_booking_submit_button')),
    );
    await tester.tap(find.byKey(const Key('check_booking_submit_button')));
    await tester.pumpAndSettle();

    expect(find.text('Nomor WhatsApp wajib diisi.'), findsOneWidget);

    // Wrong WA with valid code gives generic not-found notice.
    await tester.enterText(
      find.byKey(const Key('check_booking_wa_input')),
      '089999999999',
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('check_booking_submit_button')),
    );
    await tester.tap(find.byKey(const Key('check_booking_submit_button')));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Data booking tidak ditemukan'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Data booking tidak ditemukan'), findsOneWidget);

    // Wrong code with valid WA gives the exact same generic not-found notice.
    await tester.ensureVisible(
      find.byKey(const Key('check_booking_code_input')),
    );
    await tester.enterText(
      find.byKey(const Key('check_booking_code_input')),
      'BK-20261114-99999',
    );
    await tester.enterText(
      find.byKey(const Key('check_booking_wa_input')),
      '081234567890',
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('check_booking_submit_button')),
    );
    await tester.tap(find.byKey(const Key('check_booking_submit_button')));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Data booking tidak ditemukan'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Data booking tidak ditemukan'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('CheckBookingScreen clears code on /cek-booking?wa=... deep link without auto-lookup and BookingSuccessScreen passes both code & wa', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      KeyedSubtree(
        key: const ValueKey<String>('deeplink_clear'),
        child: _wrapWithRouter(
          const SizedBox.shrink(),
          initialLocation:
              '/cek-booking?code=BK-20261114-DEMO1&wa=081234567890',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Rina Marlina'), findsOneWidget);

    GoRouter.of(tester.element(find.byType(CheckBookingScreen)))
        .go('/cek-booking?wa=081234567890');
    await tester.pumpAndSettle();

    final TextFormField codeField = tester.widget<TextFormField>(
      find.byKey(const Key('check_booking_code_input')),
    );
    final TextFormField waField = tester.widget<TextFormField>(
      find.byKey(const Key('check_booking_wa_input')),
    );
    expect(codeField.controller?.text, isEmpty);
    expect(waField.controller?.text, '081234567890');
    expect(find.text('Rina Marlina'), findsNothing);
    expect(find.text('Cara mengecek status pengajuan'), findsOneWidget);

    final BookingSuccessArgs args = BookingSuccessArgs(
      booking: Booking(
        id: 1,
        bookingCode: 'BK-20261114-DEMO1',
        propertyId: 1,
        customerName: 'Rina Marlina',
        customerWhatsapp: '6281234567890',
        intentType: IntentType.surveyLocation,
        preferredSurveyDate: DateTime(2026, 11, 23, 10, 0),
        funnelStatus: FunnelStatus.newLead,
      ),
      propertyTitle: 'Griya Hijau Residence Tipe 45/84',
      propertySlug: 'griya-hijau-residence-45-84',
    );
    await tester.pumpWidget(
      KeyedSubtree(
        key: const ValueKey<String>('booking_success_flow'),
        child: _wrapWithRouter(BookingSuccessScreen(args: args)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('booking_success_check_status_button')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('booking_success_check_status_button')));
    await tester.pumpAndSettle();

    expect(find.text('Cek Status Booking'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Rina Marlina'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Jadwal survei'), findsOneWidget);
    expect(find.text('Rina Marlina'), findsOneWidget);
  });

  testWidgets('Inactive category properties render not-found on detail and booking form without fallback Properti badge', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      KeyedSubtree(
        key: const ValueKey<String>('inactive_detail'),
        child: _wrapWithRouter(
          const PropertyDetailScreen(slug: 'inactive-cat-prop'),
          repositoryOverride: const _InactiveCategoryPropertyRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Properti tidak ditemukan'), findsOneWidget);
    expect(find.text('Properti Kategori Nonaktif'), findsNothing);
    expect(find.text('Booking / Jadwalkan Survei'), findsNothing);
    expect(find.text('Properti'), findsNothing);

    await tester.pumpWidget(
      KeyedSubtree(
        key: const ValueKey<String>('inactive_booking'),
        child: _wrapWithRouter(
          const BookingFormScreen(slug: 'inactive-cat-prop'),
          repositoryOverride: const _InactiveCategoryPropertyRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Properti tidak ditemukan'), findsOneWidget);
    expect(find.text('Kirim Pengajuan Booking'), findsNothing);
  });

  testWidgets('Fail-closed release mode blocks demo fallback when Supabase is uninitialized', (
    WidgetTester tester,
  ) async {
    final bool prevInit = EnvConfig.isSupabaseInitialized;
    final String? prevErr = EnvConfig.supabaseInitError;
    addTearDown(() {
      EnvConfig.isSupabaseInitialized = prevInit;
      EnvConfig.supabaseInitError = prevErr;
    });

    EnvConfig.isSupabaseInitialized = false;
    EnvConfig.supabaseInitError =
        'Gagal terhubung ke server. Periksa koneksi internet Anda lalu coba lagi.';

    await tester.pumpWidget(
      const ProviderScope(child: CustomerApp(requireSupabase: true)),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('release_connectivity_error_screen')),
      findsOneWidget,
    );
    expect(find.text('Koneksi server gagal'), findsOneWidget);
    expect(find.text('Temukan rumah dan ruko impian Anda'), findsNothing);

    const CustomerRepository strictRepo =
        CustomerRepository(null, allowLocalSeeder: false);
    await expectLater(strictRepo.loadBootstrap(), throwsStateError);
    await expectLater(strictRepo.getPropertyBySlug('x'), throwsStateError);
    await expectLater(
      strictRepo.checkBookingStatus(
        bookingCode: 'BK-20261114-DEMO1',
        customerWhatsapp: '081234567890',
      ),
      throwsStateError,
    );
  });

  testWidgets('Customer hardening: resolveImageUrl, view-tracking isolation, and survey time validation', (
    WidgetTester tester,
  ) async {
    const CustomerRepository repo = CustomerRepository(null);
    expect(
      repo.resolveImageUrl('  HTTPS://cdn.example.com/a.jpg  '),
      'https://cdn.example.com/a.jpg',
    );
    expect(repo.resolveImageUrl('HTTP://evil.com/a.jpg'), isNull);
    expect(repo.resolveImageUrl('javascript:alert(1)'), isNull);
    expect(repo.resolveImageUrl('data:image/png;base64,AAAA'), isNull);
    expect(repo.resolveImageUrl('//evil.com/a.jpg'), isNull);
    expect(repo.resolveImageUrl('../secret.jpg'), isNull);

    final DateTime fixedNow = DateTime(2026, 11, 22, 14, 0);
    expect(
      BookingFormScreen.validateSurveyDateTime(
        DateTime(2026, 11, 22, 10, 0),
        now: fixedNow,
      ),
      isNotNull,
    );
    expect(
      BookingFormScreen.validateSurveyDateTime(fixedNow, now: fixedNow),
      isNotNull,
    );
    expect(
      BookingFormScreen.validateSurveyDateTime(
        fixedNow.add(const Duration(days: 181)),
        now: fixedNow,
      ),
      isNotNull,
    );
    expect(
      BookingFormScreen.validateSurveyDateTime(
        DateTime(2026, 11, 22, 16, 0),
        now: fixedNow,
      ),
      isNull,
    );

    await tester.pumpWidget(
      _wrapWithRouter(
        const PropertyDetailScreen(slug: 'griya-hijau-residence-45-84'),
        repositoryOverride: const _FailingViewCustomerRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Griya Hijau Residence Tipe 45/84'), findsWidgets);
    expect(find.text('Dilihat 42 kali'), findsOneWidget);
    expect(find.text('Booking / Jadwalkan Survei'), findsOneWidget);
  });

  test('ExternalLauncher allows official HTTPS Google Maps URLs and rejects unsafe schemes/hosts', () {
    expect(
      ExternalLauncher.isAllowedGoogleMapsUri(
        Uri.parse('https://maps.google.com/?q=-6.914744,107.609810'),
      ),
      isTrue,
    );
    expect(
      ExternalLauncher.isAllowedGoogleMapsUri(
        Uri.parse('https://maps.app.goo.gl/PCcwbg84BmPS5BJs8'),
      ),
      isTrue,
    );
    expect(
      ExternalLauncher.isAllowedGoogleMapsUri(
        Uri.parse('http://maps.google.com/?q=-6.914744,107.609810'),
      ),
      isFalse,
    );
    expect(
      ExternalLauncher.isAllowedGoogleMapsUri(
        Uri.parse('javascript:alert(1)'),
      ),
      isFalse,
    );
    expect(
      ExternalLauncher.isAllowedGoogleMapsUri(
        Uri.parse('https://evilgoogle.com/phish'),
      ),
      isFalse,
    );
  });

  test('Stage-4 EnvConfig requires explicit dart-define in release and guards hasMapsApiKey', () async {
    final bool prevInit = EnvConfig.isSupabaseInitialized;
    final String? prevErr = EnvConfig.supabaseInitError;
    addTearDown(() {
      EnvConfig.isSupabaseInitialized = prevInit;
      EnvConfig.supabaseInitError = prevErr;
    });

    expect(EnvConfig.supabaseUrl, isEmpty);
    expect(EnvConfig.supabaseAnonKey, isEmpty);
    expect(EnvConfig.hasSupabaseConfig, isFalse);

    EnvConfig.isSupabaseInitialized = true;
    expect(EnvConfig.hasMapsApiKey, isFalse);

    expect(
      EnvConfig.missingRequiredKeys(url: '', anonKey: ''),
      <String>['SUPABASE_URL', 'SUPABASE_ANON_KEY'],
    );
    expect(
      EnvConfig.releaseConfigError(url: '', anonKey: ''),
      allOf(contains('SUPABASE_URL'), contains('SUPABASE_ANON_KEY')),
    );
    expect(
      EnvConfig.releaseConfigError(
        url: 'http://example.supabase.co',
        anonKey: 'anon-key',
      ),
      contains('HTTPS'),
    );
    expect(
      EnvConfig.releaseConfigError(
        url: 'https://example.supabase.co',
        anonKey: 'anon-key',
      ),
      isNull,
    );

    EnvConfig.isSupabaseInitialized = true;
    EnvConfig.supabaseInitError = null;
    final bool initialized = await initializeCustomerSupabase(isRelease: true);
    expect(initialized, isFalse);
    expect(EnvConfig.isSupabaseInitialized, isFalse);
    expect(EnvConfig.supabaseInitError, contains('SUPABASE_URL'));
    expect(EnvConfig.supabaseInitError, contains('SUPABASE_ANON_KEY'));
  });
}

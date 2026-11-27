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
import 'package:app_customer/widgets/app_dropdown.dart';
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

  testWidgets('CustomerScaffold removes sidebar drawer and hamburger button while keeping AppBar brand & bottom navigation', (
    WidgetTester tester,
  ) async {
    Future<void> expectNoDrawerOrHamburger() async {
      expect(find.byIcon(Icons.menu), findsNothing);
      expect(find.byTooltip('Menu Navigasi'), findsNothing);
      expect(find.byType(Drawer), findsNothing);
      final Scaffold scaffold =
          tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.drawer, isNull);
    }

    await tester.pumpWidget(
      const ProviderScope(
        key: ValueKey<String>('scaffold_home'),
        child: CustomerApp(),
      ),
    );
    await tester.pumpAndSettle();

    await expectNoDrawerOrHamburger();
    expect(find.byIcon(Icons.home_work_outlined), findsOneWidget);
    expect(find.text(CompanyConfig.brandName), findsOneWidget);
    expect(find.text(CompanyConfig.companyName), findsOneWidget);
    expect(
      tester.getTopLeft(find.byIcon(Icons.home_work_outlined)).dx,
      lessThan(32.0),
    );
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(4));

    await tester.pumpWidget(
      KeyedSubtree(
        key: const ValueKey<String>('scaffold_catalog'),
        child: _wrapWithRouter(const CatalogScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await expectNoDrawerOrHamburger();

    await tester.pumpWidget(
      KeyedSubtree(
        key: const ValueKey<String>('scaffold_check_booking'),
        child: _wrapWithRouter(const CheckBookingScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await expectNoDrawerOrHamburger();

    await tester.pumpWidget(
      KeyedSubtree(
        key: const ValueKey<String>('scaffold_about'),
        child: _wrapWithRouter(const AboutScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await expectNoDrawerOrHamburger();

    await tester.pumpWidget(
      KeyedSubtree(
        key: const ValueKey<String>('scaffold_detail'),
        child: _wrapWithRouter(
          const PropertyDetailScreen(slug: 'griya-hijau-residence-45-84'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectNoDrawerOrHamburger();
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
  });

  testWidgets('AppDropdown opens strictly below field at identical top position across selections without keyboard', (
    WidgetTester tester,
  ) async {
    String? selected = 'Opsi 1';
    final List<AppDropdownItem<String>> items = List<AppDropdownItem<String>>.generate(
      8,
      (int i) => AppDropdownItem<String>(
        value: 'Opsi ${i + 1}',
        label: 'Opsi ${i + 1}',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: StatefulBuilder(
                builder: (BuildContext context, StateSetter setLocalState) {
                  return AppDropdown<String>(
                    key: const Key('test_dropdown'),
                    items: items,
                    value: selected,
                    onChanged: (String? next) {
                      setLocalState(() => selected = next);
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder fieldFinder = find.byKey(const Key('test_dropdown'));
    final Finder menuFinder = find.byKey(const Key('app_dropdown_menu'));

    expect(
      find.descendant(of: fieldFinder, matching: find.byType(EditableText)),
      findsNothing,
    );

    await tester.tap(fieldFinder);
    await tester.pumpAndSettle();

    expect(find.byType(EditableText), findsNothing);
    final Rect fieldRect = tester.getRect(fieldFinder);
    final Rect menuRect1 = tester.getRect(menuFinder);
    final Rect firstItemRect1 = tester.getRect(
      find.descendant(of: menuFinder, matching: find.text('Opsi 1')),
    );

    expect(menuRect1.top, greaterThanOrEqualTo(fieldRect.bottom));
    expect(menuRect1.width, moreOrLessEquals(fieldRect.width, epsilon: 0.5));
    expect(menuRect1.left, moreOrLessEquals(fieldRect.left, epsilon: 0.5));
    expect(firstItemRect1.top, greaterThanOrEqualTo(fieldRect.bottom));

    // Choose 5th item, close, then reopen and verify identical menu & first-item position.
    await tester.tap(
      find.descendant(of: menuFinder, matching: find.text('Opsi 5')),
    );
    await tester.pumpAndSettle();
    expect(menuFinder, findsNothing);
    expect(
      find.descendant(of: fieldFinder, matching: find.text('Opsi 5')),
      findsOneWidget,
    );

    await tester.tap(fieldFinder);
    await tester.pumpAndSettle();

    final Rect menuRect2 = tester.getRect(menuFinder);
    final Rect firstItemRect2 = tester.getRect(
      find.descendant(of: menuFinder, matching: find.text('Opsi 1')),
    );
    expect(menuRect2.top, moreOrLessEquals(menuRect1.top, epsilon: 0.5));
    expect(
      firstItemRect2.top,
      moreOrLessEquals(firstItemRect1.top, epsilon: 0.5),
    );
    expect(firstItemRect2.top, greaterThanOrEqualTo(fieldRect.bottom));
  });

  testWidgets('AppDropdown caps 8-item menu to 5 full items with Scrollbar and lets user scroll to & tap item 8', (
    WidgetTester tester,
  ) async {
    String? selected = 'Opsi 1';
    final List<AppDropdownItem<String>> items = List<AppDropdownItem<String>>.generate(
      8,
      (int i) => AppDropdownItem<String>(
        value: 'Opsi ${i + 1}',
        label: 'Opsi ${i + 1}',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: StatefulBuilder(
                builder: (BuildContext context, StateSetter setLocalState) {
                  return AppDropdown<String>(
                    key: const Key('eight_item_dropdown'),
                    items: items,
                    value: selected,
                    onChanged: (String? next) {
                      setLocalState(() => selected = next);
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder fieldFinder = find.byKey(const Key('eight_item_dropdown'));
    final Finder menuFinder = find.byKey(const Key('app_dropdown_menu'));

    await tester.tap(fieldFinder);
    await tester.pumpAndSettle();

    final Rect menuRect = tester.getRect(menuFinder);
    expect(
      menuRect.height,
      moreOrLessEquals(
        (kDropdownMaxVisibleItems * kDropdownItemHeight) +
            (kDropdownMenuVerticalPadding * 2),
        epsilon: 0.5,
      ),
    );
    expect(find.byType(Scrollbar), findsOneWidget);

    for (int i = 1; i <= 5; i++) {
      final Rect itemRect = tester.getRect(
        find.descendant(of: menuFinder, matching: find.text('Opsi $i')),
      );
      expect(itemRect.top, greaterThanOrEqualTo(menuRect.top));
      expect(itemRect.bottom, lessThanOrEqualTo(menuRect.bottom));
    }
    expect(find.text('Opsi 8'), findsNothing);

    final Finder menuScrollable = find.descendant(
      of: menuFinder,
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.descendant(of: menuFinder, matching: find.text('Opsi 8')),
      kDropdownItemHeight,
      scrollable: menuScrollable,
    );
    await tester.pumpAndSettle();

    final Finder item8Finder =
        find.descendant(of: menuFinder, matching: find.text('Opsi 8'));
    expect(item8Finder, findsOneWidget);

    await tester.tap(item8Finder);
    await tester.pumpAndSettle();

    expect(menuFinder, findsNothing);
    expect(
      find.descendant(of: fieldFinder, matching: find.text('Opsi 8')),
      findsOneWidget,
    );
    expect(selected, 'Opsi 8');
  });

  testWidgets('AppDropdown sizes 3-item menu without Scrollbar, clamps cleanly near screen bottom, and supports Form validation', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));

    String? selected3 = 'Pilihan 1';
    final List<AppDropdownItem<String>> threeItems =
        const <AppDropdownItem<String>>[
      AppDropdownItem<String>(value: 'Pilihan 1', label: 'Pilihan 1'),
      AppDropdownItem<String>(value: 'Pilihan 2', label: 'Pilihan 2'),
      AppDropdownItem<String>(value: 'Pilihan 3', label: 'Pilihan 3'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: StatefulBuilder(
                builder: (BuildContext context, StateSetter setLocalState) {
                  return AppDropdown<String>(
                    key: const Key('three_item_dropdown'),
                    items: threeItems,
                    value: selected3,
                    onChanged: (String? next) {
                      setLocalState(() => selected3 = next);
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('three_item_dropdown')));
    await tester.pumpAndSettle();

    final Finder menuFinder = find.byKey(const Key('app_dropdown_menu'));
    final Rect threeMenuRect = tester.getRect(menuFinder);
    expect(
      threeMenuRect.height,
      moreOrLessEquals(
        (3 * kDropdownItemHeight) + (kDropdownMenuVerticalPadding * 2),
        epsilon: 0.5,
      ),
    );
    expect(find.byType(Scrollbar), findsNothing);
    expect(
      find.descendant(of: menuFinder, matching: find.text('Pilihan 3')),
      findsOneWidget,
    );

    // Near bottom edge of 360x640 phone screen: shorten menu below field and scroll cleanly.
    await tester.binding.setSurfaceSize(const Size(360, 640));
    String? bottomSelected = 'Opsi 1';
    final List<AppDropdownItem<String>> eightItems =
        List<AppDropdownItem<String>>.generate(
      8,
      (int i) => AppDropdownItem<String>(
        value: 'Opsi ${i + 1}',
        label: 'Opsi ${i + 1}',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        key: const ValueKey<String>('bottom_edge_dropdown_app'),
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Stack(
            children: <Widget>[
              Positioned(
                left: 16,
                right: 16,
                top: 470,
                child: StatefulBuilder(
                  builder: (BuildContext context, StateSetter setLocalState) {
                    return AppDropdown<String>(
                      key: const Key('bottom_edge_dropdown'),
                      items: eightItems,
                      value: bottomSelected,
                      onChanged: (String? next) {
                        setLocalState(() => bottomSelected = next);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder bottomField = find.byKey(const Key('bottom_edge_dropdown'));
    await tester.tap(bottomField);
    await tester.pumpAndSettle();

    final Rect bottomFieldRect = tester.getRect(bottomField);
    final Rect clampedMenuRect = tester.getRect(menuFinder);
    expect(clampedMenuRect.top, greaterThanOrEqualTo(bottomFieldRect.bottom));
    expect(clampedMenuRect.bottom, lessThanOrEqualTo(640.0));
    expect(
      clampedMenuRect.height,
      lessThan(AppDropdown.idealMenuHeightForCount(8)),
    );
    expect(find.byType(Scrollbar), findsOneWidget);

    await tester.scrollUntilVisible(
      find.descendant(of: menuFinder, matching: find.text('Opsi 8')),
      kDropdownItemHeight,
      scrollable: find.descendant(
        of: menuFinder,
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: menuFinder, matching: find.text('Opsi 8')),
    );
    await tester.pumpAndSettle();
    expect(bottomSelected, 'Opsi 8');
    expect(tester.takeException(), isNull);

    // Form validation support.
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    String? validatedValue;
    await tester.pumpWidget(
      MaterialApp(
        key: const ValueKey<String>('form_dropdown_app'),
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formKey,
              child: StatefulBuilder(
                builder: (BuildContext context, StateSetter setLocalState) {
                  return AppDropdown<String?>(
                    key: const Key('validated_dropdown'),
                    label: 'Pilih Unit',
                    hint: 'Pilih satu',
                    items: threeItems
                        .map(
                          (AppDropdownItem<String> item) =>
                              AppDropdownItem<String?>(
                            value: item.value,
                            label: item.label,
                          ),
                        )
                        .toList(),
                    value: validatedValue,
                    validator: (String? v) =>
                        v == null ? 'Pilihan wajib diisi.' : null,
                    onChanged: (String? next) {
                      setLocalState(() => validatedValue = next);
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(formKey.currentState!.validate(), isFalse);
    await tester.pumpAndSettle();
    expect(find.text('Pilihan wajib diisi.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('validated_dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: menuFinder, matching: find.text('Pilihan 2')),
    );
    await tester.pumpAndSettle();
    expect(formKey.currentState!.validate(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('Pilihan wajib diisi.'), findsNothing);
  });

  testWidgets('HomeScreen Daerah & CatalogScreen Sort use AppDropdown below field and preserve filters', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        key: ValueKey<String>('integration_dropdowns'),
        child: CustomerApp(),
      ),
    );
    await tester.pumpAndSettle();

    final Finder homeDropdown = find.byKey(const Key('home_location_dropdown'));
    final Finder menuFinder = find.byKey(const Key('app_dropdown_menu'));

    await tester.drag(
      find.byType(Scrollable).first,
      const Offset(0, -220),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(homeDropdown);
    await tester.pumpAndSettle();
    await tester.tap(homeDropdown);
    await tester.pumpAndSettle();

    final Rect homeFieldRect = tester.getRect(homeDropdown);
    final Rect homeMenu1 = tester.getRect(menuFinder);
    expect(homeMenu1.top, greaterThanOrEqualTo(homeFieldRect.bottom));

    await tester.tap(
      find.descendant(
        of: menuFinder,
        matching: find.text('Kec. Bumi Asri, Bandung'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: homeDropdown,
        matching: find.text('Kec. Bumi Asri, Bandung'),
      ),
      findsOneWidget,
    );

    await tester.tap(homeDropdown);
    await tester.pumpAndSettle();
    final Rect homeMenu2 = tester.getRect(menuFinder);
    expect(homeMenu2.top, moreOrLessEquals(homeMenu1.top, epsilon: 0.5));

    await tester.tap(
      find.descendant(of: menuFinder, matching: find.text('Semua daerah')),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: homeDropdown, matching: find.text('Semua daerah')),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Katalog'),
      ),
    );
    await tester.pumpAndSettle();

    final Finder sortDropdown = find.byKey(const Key('catalog_sort_dropdown'));
    expect(
      find.descendant(of: sortDropdown, matching: find.text('Terbaru')),
      findsOneWidget,
    );

    await tester.tap(sortDropdown);
    await tester.pumpAndSettle();
    final Rect sortFieldRect = tester.getRect(sortDropdown);
    final Rect sortMenuRect = tester.getRect(menuFinder);
    expect(sortMenuRect.top, greaterThanOrEqualTo(sortFieldRect.bottom));
    expect(
      sortMenuRect.height,
      moreOrLessEquals(
        (3 * kDropdownItemHeight) + (kDropdownMenuVerticalPadding * 2),
        epsilon: 0.5,
      ),
    );
    expect(find.byType(Scrollbar), findsNothing);

    await tester.tap(
      find.descendant(of: menuFinder, matching: find.text('Harga Termurah')),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: sortDropdown, matching: find.text('Harga Termurah')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

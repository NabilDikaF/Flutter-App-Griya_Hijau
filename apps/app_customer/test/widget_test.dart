import 'package:app_customer/core/external_launcher.dart';
import 'package:app_customer/main.dart';
import 'package:app_customer/screens/about_screen.dart';
import 'package:app_customer/screens/booking_form_screen.dart';
import 'package:app_customer/screens/catalog_screen.dart';
import 'package:app_customer/screens/check_booking_screen.dart';
import 'package:app_customer/screens/property_detail_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared/shared.dart';

Widget _wrapWithRouter(Widget child) {
  final GoRouter router = GoRouter(
    initialLocation: '/',
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
    ],
  );
  return ProviderScope(
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

  testWidgets('CheckBookingScreen looks up BK-20261114-DEMO1 via bottom nav tab and renders status details', (
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
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('check_booking_submit_button')));
    await tester.pumpAndSettle();

    expect(find.text('Jadwal survei'), findsOneWidget);
    expect(find.text('Griya Hijau Residence Tipe 45/84'), findsOneWidget);
    expect(find.text('Rina Marlina'), findsOneWidget);
    expect(
      find.byKey(const Key('check_booking_wa_admin_button')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('CheckBookingScreen masks booking code and PII on phone-only lookup', (
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

    await tester.enterText(
      find.byKey(const Key('check_booking_wa_input')),
      '081234567890',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('check_booking_submit_button')));
    await tester.pumpAndSettle();

    expect(find.text('BK-***********'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(Card).last,
        matching: find.text('BK-***********'),
      ),
      findsOneWidget,
    );
    expect(find.text('R***'), findsOneWidget);
    expect(find.text('62812****890'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(Card).last,
        matching: find.text('BK-20261114-DEMO1'),
      ),
      findsNothing,
    );
    expect(find.text('Rina Marlina'), findsNothing);
    expect(
      find.text('Ingin melihat rumah contoh bersama keluarga.'),
      findsNothing,
    );

    await tester.drag(find.byType(ListView), const Offset(0, -250));
    await tester.pumpAndSettle();
    await tester.tap(find.text('BK-***********'));
    await tester.pump();
    expect(find.textContaining('berhasil disalin'), findsNothing);
    expect(tester.takeException(), isNull);
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
}

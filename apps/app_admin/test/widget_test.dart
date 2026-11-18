import 'dart:typed_data';

import 'package:app_admin/core/image_compressor.dart';
import 'package:app_admin/core/slug_helper.dart';
import 'package:app_admin/data/admin_models.dart';
import 'package:app_admin/data/admin_repository.dart';
import 'package:app_admin/main.dart';
import 'package:app_admin/screens/booking_detail_screen.dart';
import 'package:app_admin/screens/bookings_screen.dart';
import 'package:app_admin/screens/dashboard_screen.dart';
import 'package:app_admin/screens/login_screen.dart';
import 'package:app_admin/screens/properties_screen.dart';
import 'package:app_admin/screens/property_form_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:material_ui/material_ui.dart';
import 'package:shared/shared.dart';

Future<void> _signInAsAdmin(WidgetTester tester, {Key? scopeKey}) async {
  await tester.pumpWidget(ProviderScope(key: scopeKey, child: const AdminApp()));
  await tester.pumpAndSettle();

  await tester.enterText(
    find.byKey(const Key('admin_login_email')),
    'admin@rindangalam.id',
  );
  await tester.enterText(
    find.byKey(const Key('admin_login_password')),
    'admin123',
  );
  await tester.pumpAndSettle();
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();

  await tester.ensureVisible(find.byKey(const Key('admin_login_submit')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('admin_login_submit')));
  await tester.pumpAndSettle();
}

void main() {
  test('SlugHelper and ImageCompressor enforce slug and <=1600px <1MB limits', () {
    expect(
      SlugHelper.slugify('Tanah Kavling — Kec. Sari Indah!'),
      'tanah-kavling-kec-sari-indah',
    );

    final img.Image oversized = img.Image(width: 2000, height: 1200);
    img.fill(oversized, color: img.ColorRgb8(16, 185, 129));
    final Uint8List pngBytes = Uint8List.fromList(img.encodePng(oversized));

    final Uint8List compressed = ImageCompressor.compressToJpeg(pngBytes);
    final img.Image? decoded = img.decodeJpg(compressed);

    expect(decoded, isNotNull);
    expect(decoded!.width, lessThanOrEqualTo(CompanyConfig.maxImageWidthPx));
    expect(compressed.lengthInBytes, lessThanOrEqualTo(CompanyConfig.maxImageBytes));
  });

  testWidgets('Role Guard rejects non-admin and admits admin account', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: AdminApp()));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('admin_login_email')),
      'pelanggan@rindangalam.id',
    );
    await tester.enterText(
      find.byKey(const Key('admin_login_password')),
      'rahasia123',
    );
    await tester.pumpAndSettle();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('admin_login_submit')));
    await tester.pumpAndSettle();

    expect(
      find.text('Akun ini tidak memiliki akses Admin.'),
      findsOneWidget,
    );
    expect(find.text('Masuk ke Dashboard Admin'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('admin_login_email')),
      'admin@rindangalam.id',
    );
    await tester.pumpAndSettle();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('admin_login_submit')));
    await tester.pumpAndSettle();

    expect(find.text('Riset Pasar & Ringkasan'), findsWidgets);
  });

  testWidgets('Dashboard shows market analytics without Paket Full Funnel card', (
    WidgetTester tester,
  ) async {
    await _signInAsAdmin(tester);

    expect(find.text('Total Dilihat'), findsOneWidget);
    expect(find.text('Properti Paling Sering Dilihat'), findsOneWidget);
    expect(find.text('Funnel booking'), findsNothing);

    final Finder dashboardScroll = find
        .descendant(
          of: find.byType(AdminDashboardScreen),
          matching: find.byType(Scrollable),
        )
        .first;

    await tester.scrollUntilVisible(
      find.text('Tren Kunjungan Properti'),
      300,
      scrollable: dashboardScroll,
    );
    expect(find.text('Tren Kunjungan Properti'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Daerah Paling Sering Dicari'),
      300,
      scrollable: dashboardScroll,
    );
    expect(find.text('Daerah Paling Sering Dicari'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Minat: Perumahan vs Ruko'),
      300,
      scrollable: dashboardScroll,
    );
    expect(find.text('Minat: Perumahan vs Ruko'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Kata Kunci Paling Sering Dicari'),
      300,
      scrollable: dashboardScroll,
    );
    expect(find.text('"rumah dekat stasiun"'), findsOneWidget);
    expect(find.text('28x kosong'), findsOneWidget);
  });

  testWidgets('Properties module keeps views_count read-only and supports adding property', (
    WidgetTester tester,
  ) async {
    const PropertyInput sampleInput = PropertyInput(
      propertyCategoryId: 1,
      locationId: 1,
      title: 'Test Unit',
      slug: 'test-unit',
      price: 500000000,
    );
    expect(sampleInput.toJson().containsKey('views_count'), isFalse);

    final AdminRepository offlineRepo = AdminRepository(null);
    final PropertyDeleteResult safeDelete =
        await offlineRepo.deleteOrDeactivateProperty(1);
    expect(safeDelete.wasDeactivatedInstead, isTrue);

    await _signInAsAdmin(tester);

    await tester.tap(find.text('Properti'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Jumlah dilihat dihitung otomatis dari halaman detail pelanggan dan tidak dapat diubah manual.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(FilterChip, 'Draft (2)'));
    await tester.pumpAndSettle();
    expect(find.text('Draft Cluster Anggrek Blok D2'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, 'Semua (8)'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('admin_add_property_fab')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('property_title_input')),
      'Cluster Melati Blok F1',
    );
    await tester.enterText(
      find.byKey(const Key('property_price_input')),
      '750000000',
    );
    await tester.pumpAndSettle();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    final Finder formScroll = find
        .descendant(
          of: find.byType(AdminPropertyFormScreen),
          matching: find.byType(Scrollable),
        )
        .first;

    await tester.scrollUntilVisible(
      find.byKey(const Key('property_maps_url_input')),
      300,
      scrollable: formScroll,
    );
    expect(find.widgetWithText(ActionChip, 'Kec. Sukamaju'), findsNothing);
    await tester.ensureVisible(
      find.byKey(const Key('property_maps_url_input')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('property_maps_url_input')),
      'https://www.google.com/maps/@-6.914744,107.609810,17z',
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Titik pin aktif: -6.914744, 107.609810'),
      findsOneWidget,
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('property_readonly_views_card')),
      300,
      scrollable: formScroll,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('property_readonly_views_card')),
        matching: find.byType(EditableText),
      ),
      findsNothing,
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('admin_property_save')),
      300,
      scrollable: formScroll,
    );
    await tester.ensureVisible(find.byKey(const Key('admin_property_save')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('admin_property_save')));
    await tester.pumpAndSettle();

    expect(find.text('Cluster Melati Blok F1'), findsOneWidget);
  });

  testWidgets('CRM Bookings omits Paket Full steps and offers property status update on closed_won', (
    WidgetTester tester,
  ) async {
    await _signInAsAdmin(tester);

    await tester.tap(find.text('Leads'));
    await tester.pumpAndSettle();

    expect(find.text('Rina Marlina'), findsOneWidget);
    expect(find.text('Budi Santoso'), findsOneWidget);
    expect(find.text('Funnel booking'), findsNothing);

    await tester.tap(find.text('Budi Santoso'));
    await tester.pumpAndSettle();

    expect(find.text('Pesan WA terkirim'), findsNothing);

    final Finder detailScroll = find
        .descendant(
          of: find.byType(AdminBookingDetailScreen),
          matching: find.byType(Scrollable),
        )
        .first;

    await tester.scrollUntilVisible(
      find.widgetWithText(ChoiceChip, 'Closing'),
      250,
      scrollable: detailScroll,
    );
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Closing'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Closing'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('admin_booking_save')),
      250,
      scrollable: detailScroll,
    );
    await tester.ensureVisible(find.byKey(const Key('admin_booking_save')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('admin_booking_save')));
    await tester.pumpAndSettle();

    expect(
      find.text('Closing Berhasil — Ubah Status Unit?'),
      findsOneWidget,
    );
    await tester.tap(find.text('Tandai Terjual'));
    await tester.pumpAndSettle();

    expect(find.text('Status booking berhasil diperbarui.'), findsOneWidget);
  });

  testWidgets('Master Data supports adding a new property category with automatic slug', (
    WidgetTester tester,
  ) async {
    await _signInAsAdmin(tester);

    await tester.tap(find.text('Master'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('master_add_category_btn')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('master_category_name')),
      'Villa Pegunungan',
    );
    await tester.pumpAndSettle();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('master_category_save')));
    await tester.pumpAndSettle();

    expect(find.text('Villa Pegunungan'), findsOneWidget);
    expect(find.textContaining('villa-pegunungan'), findsOneWidget);
  });

  testWidgets('renders admin screens without overflow across 360x640 and 412x915 phone sizes', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final Size size in const <Size>[Size(360, 640), Size(412, 915)]) {
      await tester.binding.setSurfaceSize(size);

      await tester.pumpWidget(
        ProviderScope(
          key: ValueKey<String>('admin_login_$size'),
          child: const AdminApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AdminLoginScreen), findsOneWidget);
      expect(tester.takeException(), isNull);

      await _signInAsAdmin(
        tester,
        scopeKey: ValueKey<String>('admin_app_$size'),
      );
      expect(find.byType(AdminDashboardScreen), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Properti'));
      await tester.pumpAndSettle();
      expect(find.byType(AdminPropertiesScreen), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Leads'));
      await tester.pumpAndSettle();
      expect(find.byType(AdminBookingsScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}

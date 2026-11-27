import 'dart:async';
import 'dart:typed_data';

import 'package:app_admin/core/env_config.dart';
import 'package:app_admin/core/image_compressor.dart';
import 'package:app_admin/core/secure_session_storage.dart';
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

class _SessionTestAdminRepository extends AdminRepository {
  _SessionTestAdminRepository({
    AdminSessionUser? initialUser,
    this.verifiedServerUser,
    this.throwOnSignOut = false,
  })  : _activeUser = initialUser,
        super(null);

  final StreamController<AdminSessionUser?> _authController =
      StreamController<AdminSessionUser?>.broadcast();

  AdminSessionUser? _activeUser;
  AdminSessionUser? verifiedServerUser;
  bool throwOnSignOut;
  int signOutCallCount = 0;
  int clearCacheCallCount = 0;

  void emitAuthState(AdminSessionUser? user) {
    _activeUser = (user != null && user.isAdmin) ? user : null;
    _authController.add(user);
  }

  Future<void> closeController() => _authController.close();

  @override
  Stream<AdminSessionUser?> get authSessionChanges => _authController.stream;

  @override
  AdminSessionUser? currentAdminUserSync() => _activeUser;

  @override
  Future<AdminSessionUser?> ensureValidAdminSession() async =>
      verifiedServerUser;

  @override
  Future<AdminSessionUser> signInAdmin({
    required String email,
    required String password,
  }) async {
    final AdminSessionUser user = await super.signInAdmin(
      email: email,
      password: password,
    );
    _activeUser = user;
    return user;
  }

  @override
  Future<void> signOut() async {
    signOutCallCount++;
    try {
      if (throwOnSignOut) {
        throw Exception('Simulated network error on signOut');
      }
      await super.signOut();
    } finally {
      _activeUser = null;
      clearSensitiveCache();
    }
  }

  @override
  void clearSensitiveCache() {
    clearCacheCallCount++;
    super.clearSensitiveCache();
  }
}

class _PaginatedSearchTestAdminRepository extends AdminRepository {
  _PaginatedSearchTestAdminRepository() : super(null);

  final List<({FunnelStatus? status, String keyword, int limit, int offset})>
      calls =
      <({FunnelStatus? status, String keyword, int limit, int offset})>[];

  @override
  AdminSessionUser? currentAdminUserSync() => const AdminSessionUser(
        id: 'test-admin',
        email: 'admin@rindangalam.id',
        role: 'admin',
      );

  @override
  Future<AdminBookingsPage> getBookingsPage({
    FunnelStatus? statusFilter,
    String keyword = '',
    int limit = 25,
    int offset = 0,
  }) async {
    calls.add((
      status: statusFilter,
      keyword: keyword,
      limit: limit,
      offset: offset,
    ));
    if (keyword.trim().isNotEmpty || statusFilter != null) {
      return super.getBookingsPage(
        statusFilter: statusFilter,
        keyword: keyword,
        limit: limit,
        offset: offset,
      );
    }
    return super.getBookingsPage(
      statusFilter: statusFilter,
      keyword: keyword,
      limit: 1,
      offset: offset,
    );
  }
}

class _ShiftingTopPropertiesAdminRepository extends AdminRepository {
  _ShiftingTopPropertiesAdminRepository() : super(null);

  @override
  AdminSessionUser? currentAdminUserSync() => const AdminSessionUser(
        id: 'test-admin',
        email: 'admin@rindangalam.id',
        role: 'admin',
      );

  @override
  Future<AdminDashboardBundle> loadDashboard({
    required int daysWindow,
    int? trendPropertyId,
  }) async {
    final AdminDashboardBundle base = await super.loadDashboard(
      daysWindow: daysWindow,
      trendPropertyId: trendPropertyId,
    );
    final List<AdminPropertyTopItem> shiftedTop = daysWindow == 7
        ? const <AdminPropertyTopItem>[
            AdminPropertyTopItem(
              id: 101,
              slug: 'unit-a',
              title: 'Unit Top 101',
              categoryName: 'Komplek Perumahan',
              city: 'Bandung',
              district: 'Kec. Sukamaju',
              viewsCount: 50,
              availabilityStatus: AvailabilityStatus.available,
              isPublished: true,
            ),
          ]
        : const <AdminPropertyTopItem>[
            AdminPropertyTopItem(
              id: 202,
              slug: 'unit-b',
              title: 'Unit Top 202',
              categoryName: 'Ruko',
              city: 'Bandung',
              district: 'Kec. Sari Indah',
              viewsCount: 80,
              availabilityStatus: AvailabilityStatus.available,
              isPublished: true,
            ),
          ];
    return AdminDashboardBundle(
      totalViews: base.totalViews,
      totalSearches: base.totalSearches,
      activeLeadsCount: base.activeLeadsCount,
      scheduledSurveysCount: base.scheduledSurveysCount,
      topProperties: shiftedTop,
      viewTrend: base.viewTrend,
      locationStats: base.locationStats,
      categoryStats: base.categoryStats,
      keywordStats: base.keywordStats,
      upcomingSurveys: base.upcomingSurveys,
      recentBookings: base.recentBookings,
      usingLocalSeeder: false,
    );
  }
}

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

  group('Stage-3 Session lifecycle & Security Hardening (B3)', () {
    test('Admin hardening utilities: SlugHelper, ImageCompressor isolate/bounds, random photo UUID, BookingWithProperty.fromRpcJson, resolveImageUrl, adminNotes cap, hasMapsApiKey', () async {
      // SlugHelper rejects punctuation-only / empty slugs.
      expect(SlugHelper.validate(''), isNotNull);
      expect(SlugHelper.validate('   ---!!!  '), isNotNull);
      expect(SlugHelper.validate('Griya Hijau!'), isNull);
      expect(
        () => SlugHelper.requireValidSlug('---!!!'),
        throwsFormatException,
      );

      // ImageCompressor enforces dimension bounds & works inside Isolate.run.
      final img.Image wide = img.Image(width: 120, height: 40);
      img.fill(wide, color: img.ColorRgb8(16, 185, 129));
      final Uint8List widePng = Uint8List.fromList(img.encodePng(wide));
      expect(
        () => ImageCompressor.compressToJpeg(widePng, maxDimensionPx: 100),
        throwsFormatException,
      );
      final Uint8List asyncCompressed =
          await ImageCompressor.compressToJpegAsync(widePng);
      expect(img.decodeJpg(asyncCompressed), isNotNull);

      // Random UUID photo filename (2.2) matches Stage-1 SQL CHECK and is unique.
      final RegExp sqlPathPattern = RegExp(
        r'^properties/42/[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\.jpg$',
      );
      final String p1 = AdminRepository.generateRandomPhotoPath(42);
      final String p2 = AdminRepository.generateRandomPhotoPath(42);
      expect(sqlPathPattern.hasMatch(p1), isTrue);
      expect(sqlPathPattern.hasMatch(p2), isTrue);
      expect(p1, isNot(equals(p2)));
      expect(p1, isNot(endsWith('main.jpg')));

      // Flat RPC booking row parsing preserves customer_whatsapp for admin CRM.
      final BookingWithProperty rpcItem = BookingWithProperty.fromRpcJson(
        <String, dynamic>{
          'id': 11,
          'booking_code': 'BK-20261122-0123456789ABCDEF',
          'property_id': 1,
          'customer_name': 'Sari Kusuma',
          'customer_whatsapp': '6281234567890',
          'intent_type': 'book_unit',
          'payment_plan': 'kpr',
          'funnel_status': 'new',
          'property_title': 'Griya Hijau Residence',
          'property_slug': 'griya-hijau-residence',
          'property_category_name': 'Komplek Perumahan',
          'property_district': 'Kec. Sukamaju',
          'property_availability_status': 'booked',
        },
      );
      expect(rpcItem.booking.customerWhatsapp, '6281234567890');
      expect(rpcItem.propertyAvailabilityStatus, AvailabilityStatus.booked);

      // resolveImageUrl normalizes scheme and rejects unsafe protocols/paths.
      final AdminRepository demoRepo = AdminRepository(null);
      expect(
        demoRepo.resolveImageUrl('  HTTPS://cdn.example.com/photo.jpg  '),
        'https://cdn.example.com/photo.jpg',
      );
      expect(demoRepo.resolveImageUrl('HTTP://cdn.example.com/a.jpg'), isNull);
      expect(demoRepo.resolveImageUrl('javascript:alert(1)'), isNull);
      expect(demoRepo.resolveImageUrl('../secret.jpg'), isNull);

      // admin_notes limit <= 2000 chars.
      await expectLater(
        demoRepo.updateBooking(
          bookingId: 1,
          funnelStatus: FunnelStatus.contacted,
          adminNotes: 'x' * 2001,
        ),
        throwsArgumentError,
      );

      // EnvConfig.hasMapsApiKey stays false when MAPS_API_KEY is empty even if Supabase initialized.
      final bool prevSupabase = EnvConfig.isSupabaseInitialized;
      addTearDown(() => EnvConfig.isSupabaseInitialized = prevSupabase);
      EnvConfig.isSupabaseInitialized = true;
      expect(EnvConfig.hasMapsApiKey, isFalse);
    });

    testWidgets('Fail-closed release mode rejects offline demo mode and EnvConfig error renders blocker UI', (
      WidgetTester tester,
    ) async {
      final bool prevSupabase = EnvConfig.isSupabaseInitialized;
      final String? prevErr = EnvConfig.supabaseInitError;
      addTearDown(() {
        EnvConfig.isSupabaseInitialized = prevSupabase;
        EnvConfig.supabaseInitError = prevErr;
      });

      EnvConfig.isSupabaseInitialized = false;
      EnvConfig.supabaseInitError =
          'Gagal terhubung ke server autentikasi. Periksa koneksi internet Anda lalu coba lagi.';

      await tester.pumpWidget(
        const ProviderScope(
          key: ValueKey<String>('admin_release_fail_closed'),
          child: AdminApp(requireSupabase: true),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('admin_release_connectivity_error_screen')),
        findsOneWidget,
      );
      expect(find.byType(AdminLoginScreen), findsNothing);
      expect(find.textContaining('admin@rindangalam.id'), findsNothing);

      final AdminRepository strictRepo =
          AdminRepository(null, allowLocalSeeder: false);
      await expectLater(
        strictRepo.signInAdmin(
          email: 'admin@rindangalam.id',
          password: 'password123',
        ),
        throwsStateError,
      );
      await expectLater(
        strictRepo.loadDashboard(daysWindow: 7),
        throwsStateError,
      );
      await expectLater(strictRepo.getBookingsPage(), throwsStateError);
      await expectLater(strictRepo.getCategories(), throwsStateError);
    });

    testWidgets('Session listener redirects to login and clears PII when session is revoked via auth stream', (
      WidgetTester tester,
    ) async {
      final _SessionTestAdminRepository repo = _SessionTestAdminRepository(
        initialUser: const AdminSessionUser(
          id: 'admin-1',
          email: 'admin@rindangalam.id',
          role: 'admin',
        ),
      );
      addTearDown(repo.closeController);

      await tester.pumpWidget(
        ProviderScope(
          key: const ValueKey<String>('session_revoked_scope'),
          overrides: [adminRepositoryProvider.overrideWithValue(repo)],
          child: const AdminApp(requireSupabase: false),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Leads'));
      await tester.pumpAndSettle();
      expect(find.byType(AdminBookingsScreen), findsOneWidget);
      expect(find.text('Rina Marlina'), findsOneWidget);

      // Revoke session from GoTrue auth state stream.
      repo.emitAuthState(null);
      await tester.pumpAndSettle();

      expect(find.byType(AdminLoginScreen), findsOneWidget);
      expect(find.byType(AdminBookingsScreen), findsNothing);
      expect(find.text('Rina Marlina'), findsNothing);
      expect(repo.clearCacheCallCount, greaterThanOrEqualTo(1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Session listener revokes access, clears cache, and signs out when admin role is stripped', (
      WidgetTester tester,
    ) async {
      final _SessionTestAdminRepository repo = _SessionTestAdminRepository(
        initialUser: const AdminSessionUser(
          id: 'admin-2',
          email: 'admin@rindangalam.id',
          role: 'admin',
        ),
      );
      addTearDown(repo.closeController);

      await tester.pumpWidget(
        ProviderScope(
          key: const ValueKey<String>('role_lost_scope'),
          overrides: [adminRepositoryProvider.overrideWithValue(repo)],
          child: const AdminApp(requireSupabase: false),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AdminDashboardScreen), findsOneWidget);

      // Role changed from admin -> customer.
      repo.emitAuthState(
        const AdminSessionUser(
          id: 'admin-2',
          email: 'admin@rindangalam.id',
          role: 'customer',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AdminLoginScreen), findsOneWidget);
      expect(find.byType(AdminDashboardScreen), findsNothing);
      expect(repo.signOutCallCount, greaterThanOrEqualTo(1));
      expect(repo.clearCacheCallCount, greaterThanOrEqualTo(1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('signOut still clears session state, cache, and redirects even when network signOut fails', (
      WidgetTester tester,
    ) async {
      final _SessionTestAdminRepository repo = _SessionTestAdminRepository(
        initialUser: const AdminSessionUser(
          id: 'admin-3',
          email: 'admin@rindangalam.id',
          role: 'admin',
        ),
        throwOnSignOut: true,
      );
      addTearDown(repo.closeController);

      await tester.pumpWidget(
        ProviderScope(
          key: const ValueKey<String>('signout_network_fail_scope'),
          overrides: [adminRepositoryProvider.overrideWithValue(repo)],
          child: const AdminApp(requireSupabase: false),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Akun Admin'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keluar'));
      await tester.pumpAndSettle();

      expect(repo.signOutCallCount, 1);
      expect(repo.clearCacheCallCount, greaterThanOrEqualTo(1));
      expect(find.byType(AdminLoginScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('AdminSessionNotifier.initialize clears stale session when server verification rejects', () async {
      final _SessionTestAdminRepository repo = _SessionTestAdminRepository(
        initialUser: const AdminSessionUser(
          id: 'admin-4',
          email: 'admin@rindangalam.id',
          role: 'admin',
        ),
        verifiedServerUser: null,
      );
      final AdminSessionNotifier notifier = AdminSessionNotifier(repo);
      expect(notifier.isLoggedIn, isTrue);

      await notifier.initialize();
      expect(notifier.isLoggedIn, isFalse);
      expect(notifier.currentUser, isNull);
      expect(repo.clearCacheCallCount, 1);

      notifier.dispose();
      await repo.closeController();
    });

    testWidgets('CRM Bookings debounces search by 400ms, paginates via Load More, and guards admin_notes maxLength 2000', (
      WidgetTester tester,
    ) async {
      final _PaginatedSearchTestAdminRepository repo =
          _PaginatedSearchTestAdminRepository();

      final AdminBookingsPage page1 = await AdminRepository(null).getBookingsPage(
        limit: 2,
        offset: 0,
      );
      final AdminBookingsPage page2 = await AdminRepository(null).getBookingsPage(
        limit: 2,
        offset: 2,
      );
      expect(page1.items, hasLength(2));
      expect(page1.totalCount, 4);
      expect(page1.hasMore, isTrue);
      expect(page2.items, hasLength(2));
      expect(page2.hasMore, isFalse);

      await tester.pumpWidget(
        ProviderScope(
          key: const ValueKey<String>('crm_debounce_pagination_scope'),
          overrides: [adminRepositoryProvider.overrideWithValue(repo)],
          child: const AdminApp(requireSupabase: false),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Leads'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('admin_bookings_load_more')), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const Key('admin_bookings_load_more')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('admin_bookings_load_more')));
      await tester.pumpAndSettle();
      expect(repo.calls.last.offset, 1);

      repo.calls.clear();
      await tester.enterText(
        find.byKey(const Key('admin_bookings_search_input')),
        'Budi',
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(repo.calls, isEmpty);

      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();
      expect(repo.calls, hasLength(1));
      expect(repo.calls.single.keyword, 'Budi');
      expect(find.text('Budi Santoso'), findsOneWidget);

      await tester.tap(find.text('Budi Santoso'));
      await tester.pumpAndSettle();
      final TextField notesField = tester.widget<TextField>(
        find.byKey(const Key('admin_booking_notes_input')),
      );
      expect(notesField.maxLength, 2000);
    });

    testWidgets('Dashboard AppDropdown safely resets when selected trend property leaves top-10', (
      WidgetTester tester,
    ) async {
      final _ShiftingTopPropertiesAdminRepository repo =
          _ShiftingTopPropertiesAdminRepository();

      await tester.pumpWidget(
        ProviderScope(
          key: const ValueKey<String>('dashboard_dropdown_guard_scope'),
          overrides: [adminRepositoryProvider.overrideWithValue(repo)],
          child: const AdminApp(requireSupabase: false),
        ),
      );
      await tester.pumpAndSettle();

      final Finder dashboardScroll = find
          .descendant(
            of: find.byType(AdminDashboardScreen),
            matching: find.byType(Scrollable),
          )
          .first;

      final Finder trendDropdownFinder =
          find.byKey(const Key('admin_dashboard_trend_dropdown'));
      final Finder menuFinder = find.byKey(const Key('app_dropdown_menu'));

      await tester.scrollUntilVisible(
        trendDropdownFinder,
        300,
        scrollable: dashboardScroll,
      );
      await Scrollable.ensureVisible(
        tester.element(trendDropdownFinder),
        alignment: 0.2,
      );
      await tester.pumpAndSettle();
      await tester.tap(trendDropdownFinder);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: menuFinder,
          matching: find.text('Unit Top 101'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.widget<AppDropdown<int?>>(trendDropdownFinder).value,
        101,
      );

      // Switch period window so loadDashboard returns Unit Top 202 without 101.
      final Finder periodDropdownFinder =
          find.byKey(const Key('admin_dashboard_period_dropdown'));
      await tester.scrollUntilVisible(
        periodDropdownFinder,
        -300,
        scrollable: dashboardScroll,
      );
      await Scrollable.ensureVisible(
        tester.element(periodDropdownFinder),
        alignment: 0.2,
      );
      await tester.pumpAndSettle();
      await tester.tap(periodDropdownFinder);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: menuFinder,
          matching: find.text('30 hari terakhir'),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      await tester.scrollUntilVisible(
        trendDropdownFinder,
        300,
        scrollable: dashboardScroll,
      );
      await tester.ensureVisible(trendDropdownFinder);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final AppDropdown<int?> resetDropdown =
          tester.widget<AppDropdown<int?>>(trendDropdownFinder);
      expect(resetDropdown.value, isNull);
      expect(
        resetDropdown.items
            .map((AppDropdownItem<int?> item) => item.value),
        <int?>[null, 202],
      );
    });

    testWidgets('Property form uses AppDropdown below field with consistent menu position', (
      WidgetTester tester,
    ) async {
      await _signInAsAdmin(tester);

      await tester.tap(find.text('Properti'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('admin_add_property_fab')));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(AdminPropertyFormScreen),
          matching: find.byWidgetPredicate(
            (Widget widget) => widget is DropdownButton,
          ),
        ),
        findsNothing,
      );

      final Finder categoryDropdownFinder =
          find.byKey(const Key('admin_property_category_dropdown'));
      final Finder locationDropdownFinder =
          find.byKey(const Key('admin_property_location_dropdown'));

      expect(
        tester.widget<AppDropdown<int>>(categoryDropdownFinder),
        isA<AppDropdown<int>>(),
      );
      expect(
        tester.widget<AppDropdown<int>>(locationDropdownFinder),
        isA<AppDropdown<int>>(),
      );

      final Finder formScroll = find
          .descendant(
            of: find.byType(AdminPropertyFormScreen),
            matching: find.byType(Scrollable),
          )
          .first;

      await tester.scrollUntilVisible(
        locationDropdownFinder,
        300,
        scrollable: formScroll,
      );
      await Scrollable.ensureVisible(
        tester.element(locationDropdownFinder),
        alignment: 0.2,
      );
      await tester.pumpAndSettle();

      final Finder menuFinder = find.byKey(const Key('app_dropdown_menu'));

      await tester.tap(locationDropdownFinder);
      await tester.pumpAndSettle();

      final Rect fieldRect = tester.getRect(locationDropdownFinder);
      final Rect menuRect1 = tester.getRect(menuFinder);
      expect(menuRect1.top, greaterThanOrEqualTo(fieldRect.bottom));

      await tester.tap(
        find.descendant(
          of: menuFinder,
          matching: find.text('Kec. Bumi Asri, Bandung'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: locationDropdownFinder,
          matching: find.text('Kec. Bumi Asri, Bandung'),
        ),
        findsOneWidget,
      );

      await tester.tap(locationDropdownFinder);
      await tester.pumpAndSettle();

      final Rect menuRect2 = tester.getRect(menuFinder);
      expect(menuRect2.top, moreOrLessEquals(menuRect1.top, epsilon: 0.5));
    });
  });

  group('Stage-4 Android & Config Hardening (B4)', () {
    test('EnvConfig requires explicit dart-define on release and initializeAdminSupabase fails closed', () async {
      final bool prevInit = EnvConfig.isSupabaseInitialized;
      final String? prevErr = EnvConfig.supabaseInitError;
      addTearDown(() {
        EnvConfig.isSupabaseInitialized = prevInit;
        EnvConfig.supabaseInitError = prevErr;
      });

      expect(EnvConfig.supabaseUrl, isEmpty);
      expect(EnvConfig.supabaseAnonKey, isEmpty);
      expect(EnvConfig.hasSupabaseConfig, isFalse);
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
      final bool initialized = await initializeAdminSupabase(isRelease: true);
      expect(initialized, isFalse);
      expect(EnvConfig.isSupabaseInitialized, isFalse);
      expect(EnvConfig.supabaseInitError, contains('SUPABASE_URL'));
      expect(EnvConfig.supabaseInitError, contains('SUPABASE_ANON_KEY'));
    });

    test('SecureSupabaseLocalStorage & SecureGotrueAsyncStorage persist and fail closed on Keystore read errors', () async {
      expect(
        SecureSupabaseLocalStorage.sessionKeyForUrl(
          'https://rekqhpdaenzgnjvajquv.supabase.co',
        ),
        'sb-rekqhpdaenzgnjvajquv-auth-token',
      );
      expect(
        SecureSupabaseLocalStorage.sessionKeyForUrl(''),
        'SUPABASE_PERSIST_SESSION_KEY',
      );

      final _MemorySecureKeyValueStore store = _MemorySecureKeyValueStore();
      final SecureSupabaseLocalStorage localStorage =
          SecureSupabaseLocalStorage(
        persistSessionKey: 'sb-test-auth-token',
        store: store,
      );
      await localStorage.initialize();
      expect(await localStorage.hasAccessToken(), isFalse);
      expect(await localStorage.accessToken(), isNull);

      await localStorage.persistSession('{"access_token":"secret"}');
      expect(await localStorage.hasAccessToken(), isTrue);
      expect(await localStorage.accessToken(), '{"access_token":"secret"}');

      // Simulate corrupted Keystore ciphertext: fails closed and wipes stale entry.
      store.throwOnRead = true;
      expect(await localStorage.hasAccessToken(), isFalse);
      expect(store.values.containsKey('sb-test-auth-token'), isFalse);

      store.throwOnRead = false;
      await localStorage.persistSession('{"access_token":"secret2"}');
      store.throwOnRead = true;
      expect(await localStorage.accessToken(), isNull);
      expect(store.values.containsKey('sb-test-auth-token'), isFalse);

      store.throwOnRead = false;
      await localStorage.persistSession('{"access_token":"secret3"}');
      await localStorage.removePersistedSession();
      expect(await localStorage.hasAccessToken(), isFalse);

      final SecureGotrueAsyncStorage pkceStorage =
          SecureGotrueAsyncStorage(store: store);
      await pkceStorage.setItem(key: 'pkce-verifier', value: 'verifier-123');
      expect(await pkceStorage.getItem(key: 'pkce-verifier'), 'verifier-123');

      store.throwOnRead = true;
      expect(await pkceStorage.getItem(key: 'pkce-verifier'), isNull);
      expect(store.values.containsKey('pkce-verifier'), isFalse);

      store.throwOnRead = false;
      await pkceStorage.setItem(key: 'pkce-verifier', value: 'verifier-456');
      await pkceStorage.removeItem(key: 'pkce-verifier');
      expect(await pkceStorage.getItem(key: 'pkce-verifier'), isNull);
    });
  });
}

class _MemorySecureKeyValueStore implements SecureKeyValueStore {
  final Map<String, String> values = <String, String>{};
  bool throwOnRead = false;

  @override
  Future<bool> containsKey(String key) async {
    if (throwOnRead) {
      throw Exception('Simulated Keystore containsKey error');
    }
    return values.containsKey(key);
  }

  @override
  Future<String?> read(String key) async {
    if (throwOnRead) {
      throw Exception('Simulated Keystore decryption error');
    }
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

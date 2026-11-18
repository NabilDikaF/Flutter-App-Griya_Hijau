import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared/shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/env_config.dart';
import '../core/image_compressor.dart';
import 'admin_models.dart';

/// State sesi Admin untuk menjaga navigasi GoRouter (`Tugas 3.1`).
class AdminSessionNotifier extends ChangeNotifier {
  AdminSessionNotifier(this._repository);

  final AdminRepository _repository;

  AdminSessionUser? get currentUser => _repository.currentAdminUserSync();
  bool get isLoggedIn => currentUser?.isAdmin ?? false;

  Future<void> initialize() async {
    await _repository.ensureValidAdminSession();
    notifyListeners();
  }

  Future<AdminSessionUser> signIn({
    required String email,
    required String password,
  }) async {
    final AdminSessionUser user = await _repository.signInAdmin(
      email: email,
      password: password,
    );
    notifyListeners();
    return user;
  }

  Future<void> signOut() async {
    await _repository.signOut();
    notifyListeners();
  }
}

/// Repositori penuh Aplikasi Admin (Auth + Master + Properti + Foto + Booking + Dashboard).
/// Berkomunikasi dengan Supabase ketika diinisialisasi, atau memakai state in-memory
/// berbasis `SeedData` saat dijalankan di lingkungan pengujian/offline.
class AdminRepository {
  AdminRepository(this._client) {
    if (_client == null) {
      _initDemoState();
    }
  }

  final SupabaseClient? _client;
  final math.Random _random = math.Random();

  // State lokal untuk mode pengujian / fallback tanpa koneksi Supabase.
  AdminSessionUser? _demoUser;
  int _nextCategoryId = 100;
  int _nextLocationId = 100;
  int _nextPropertyId = 100;
  int _nextImageId = 500;
  late List<PropertyCategory> _demoCategories;
  late List<Location> _demoLocations;
  late List<Property> _demoProperties;
  late List<BookingWithProperty> _demoBookings;
  final Map<String, Uint8List> _localImageBytes = <String, Uint8List>{};

  void _initDemoState() {
    _demoCategories = List<PropertyCategory>.from(SeedData.categories);
    _demoLocations = List<Location>.from(SeedData.locations);
    _demoProperties = List<Property>.from(SeedData.properties);
    final DateTime now = DateTime.now();
    _demoBookings = <BookingWithProperty>[
      _wrapDemoBooking(
        Booking(
          id: 1,
          bookingCode: 'BK-20261114-A12B3',
          propertyId: 1,
          customerName: 'Rina Marlina',
          customerWhatsapp: '6281234567890',
          intentType: IntentType.surveyLocation,
          preferredSurveyDate: now.add(const Duration(days: 1, hours: 2)),
          confirmedSurveyDate: now.add(const Duration(days: 1, hours: 2)),
          customerNotes: 'Ingin lihat unit contoh dan akses jalan komplek.',
          funnelStatus: FunnelStatus.surveyScheduled,
          adminNotes: 'Sudah dikonfirmasi via WhatsApp untuk pukul 10.00 WIB.',
          createdAt: now.subtract(const Duration(hours: 4)),
        ),
      ),
      _wrapDemoBooking(
        Booking(
          id: 2,
          bookingCode: 'BK-20261114-C98D1',
          propertyId: 5,
          customerName: 'Budi Santoso',
          customerWhatsapp: '6285711223344',
          intentType: IntentType.bookUnit,
          paymentPlan: PaymentPlan.kpr,
          customerNotes: 'Mohon simulasi angsuran KPR tenor 15 tahun.',
          funnelStatus: FunnelStatus.newLead,
          createdAt: now.subtract(const Duration(hours: 2)),
        ),
      ),
      _wrapDemoBooking(
        Booking(
          id: 3,
          bookingCode: 'BK-20261113-E44F2',
          propertyId: 3,
          customerName: 'Siti Aminah',
          customerWhatsapp: '6282198765432',
          intentType: IntentType.surveyLocation,
          preferredSurveyDate: now.add(const Duration(days: 2, hours: 3)),
          confirmedSurveyDate: now.add(const Duration(days: 2, hours: 3)),
          funnelStatus: FunnelStatus.officeVisit,
          adminNotes: 'Lanjut konsultasi KPR di kantor pemasaran.',
          createdAt: now.subtract(const Duration(days: 1)),
        ),
      ),
      _wrapDemoBooking(
        Booking(
          id: 4,
          bookingCode: 'BK-20261112-G77H9',
          propertyId: 4,
          customerName: 'Hendra Wijaya',
          customerWhatsapp: '6281377889900',
          intentType: IntentType.bookUnit,
          paymentPlan: PaymentPlan.cashInstallment,
          funnelStatus: FunnelStatus.closedWon,
          adminNotes: 'Tanda jadi sudah diterima kantor.',
          createdAt: now.subtract(const Duration(days: 2)),
        ),
      ),
    ];
  }

  BookingWithProperty _wrapDemoBooking(Booking booking) {
    final Property? property = _findDemoProperty(booking.propertyId);
    return BookingWithProperty(
      booking: booking,
      propertyTitle: property?.title ?? 'Properti #${booking.propertyId}',
      propertySlug: property?.slug ?? '',
      propertyCategoryName: property?.category?.name ?? '',
      propertyDistrict: property?.location?.district ?? '',
      propertyAvailabilityStatus:
          property?.availabilityStatus ?? AvailabilityStatus.available,
    );
  }

  Property? _findDemoProperty(int propertyId) {
    for (final Property item in _demoProperties) {
      if (item.id == propertyId) return item;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Tugas 3.1 — Autentikasi & Role Guard
  // ---------------------------------------------------------------------------

  AdminSessionUser? currentAdminUserSync() {
    final SupabaseClient? client = _client;
    if (client == null) {
      return _demoUser;
    }
    final User? user = client.auth.currentUser;
    if (user == null) return null;
    final String role = user.appMetadata['role']?.toString() ?? '';
    if (role != 'admin') return null;
    return AdminSessionUser(
      id: user.id,
      email: user.email ?? 'admin@rindangalam.id',
      role: role,
    );
  }

  Future<AdminSessionUser?> ensureValidAdminSession() async {
    final SupabaseClient? client = _client;
    if (client == null) return _demoUser;
    final User? user = client.auth.currentUser;
    if (user == null) return null;
    final String role = user.appMetadata['role']?.toString() ?? '';
    if (role != 'admin') {
      await client.auth.signOut();
      return null;
    }
    return AdminSessionUser(
      id: user.id,
      email: user.email ?? '',
      role: role,
    );
  }

  Future<AdminSessionUser> signInAdmin({
    required String email,
    required String password,
  }) async {
    final String trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty || password.isEmpty) {
      throw const FormatException('Email dan kata sandi wajib diisi.');
    }

    final SupabaseClient? client = _client;
    if (client == null) {
      if (password.length < 6) {
        throw const FormatException('Email atau kata sandi salah.');
      }
      if (trimmedEmail.toLowerCase() != 'admin@rindangalam.id') {
        _demoUser = null;
        throw const AdminAccessDeniedException(
          'Akun ini tidak memiliki akses Admin.',
        );
      }
      _demoUser = AdminSessionUser(
        id: 'demo-admin',
        email: trimmedEmail,
        role: 'admin',
      );
      return _demoUser!;
    }

    try {
      final AuthResponse response = await client.auth.signInWithPassword(
        email: trimmedEmail,
        password: password,
      );
      final User? user = response.user;
      final String role = user?.appMetadata['role']?.toString() ?? '';
      if (user == null || role != 'admin') {
        await client.auth.signOut();
        throw const AdminAccessDeniedException(
          'Akun ini tidak memiliki akses Admin.',
        );
      }
      return AdminSessionUser(
        id: user.id,
        email: user.email ?? trimmedEmail,
        role: role,
      );
    } on AuthException catch (error) {
      final String lower = error.message.toLowerCase();
      if (lower.contains('invalid login credentials')) {
        throw Exception('Email atau kata sandi salah.');
      }
      throw Exception(error.message);
    }
  }

  Future<void> signOut() async {
    final SupabaseClient? client = _client;
    if (client == null) {
      _demoUser = null;
      return;
    }
    await client.auth.signOut();
  }

  // ---------------------------------------------------------------------------
  // Tugas 3.2 — CRUD Master Kategori & Daerah
  // ---------------------------------------------------------------------------

  Future<List<PropertyCategory>> getCategories() async {
    final SupabaseClient? client = _client;
    if (client == null) {
      return List<PropertyCategory>.unmodifiable(_demoCategories);
    }

    final List<dynamic> rows = await client
        .from('property_categories')
        .select()
        .order('id', ascending: true);
    return rows
        .whereType<Map<String, dynamic>>()
        .map(PropertyCategory.fromJson)
        .toList(growable: false);
  }

  Future<PropertyCategory> createCategory({
    required String name,
    required String slug,
    bool isActive = true,
  }) async {
    final SupabaseClient? client = _client;
    if (client == null) {
      final PropertyCategory created = PropertyCategory(
        id: _nextCategoryId++,
        name: name.trim(),
        slug: slug.trim(),
        isActive: isActive,
        createdAt: DateTime.now(),
      );
      _demoCategories.add(created);
      return created;
    }

    try {
      final Map<String, dynamic> row = await client
          .from('property_categories')
          .insert(<String, dynamic>{
            'name': name.trim(),
            'slug': slug.trim(),
            'is_active': isActive,
          })
          .select()
          .single();
      return PropertyCategory.fromJson(row);
    } on PostgrestException catch (error) {
      if (error.code == '23505') {
        throw Exception('Slug kategori "$slug" sudah digunakan.');
      }
      throw Exception(error.message);
    }
  }

  Future<PropertyCategory> updateCategory({
    required int id,
    required String name,
    required String slug,
    required bool isActive,
  }) async {
    final SupabaseClient? client = _client;
    if (client == null) {
      final int idx = _demoCategories.indexWhere((PropertyCategory c) => c.id == id);
      if (idx < 0) throw Exception('Kategori tidak ditemukan.');
      final PropertyCategory updated = PropertyCategory(
        id: id,
        name: name.trim(),
        slug: slug.trim(),
        isActive: isActive,
        createdAt: _demoCategories[idx].createdAt,
        updatedAt: DateTime.now(),
      );
      _demoCategories[idx] = updated;
      return updated;
    }

    try {
      final Map<String, dynamic> row = await client
          .from('property_categories')
          .update(<String, dynamic>{
            'name': name.trim(),
            'slug': slug.trim(),
            'is_active': isActive,
          })
          .eq('id', id)
          .select()
          .single();
      return PropertyCategory.fromJson(row);
    } on PostgrestException catch (error) {
      if (error.code == '23505') {
        throw Exception('Slug kategori "$slug" sudah digunakan.');
      }
      throw Exception(error.message);
    }
  }

  Future<void> deleteCategory(int id) async {
    final SupabaseClient? client = _client;
    if (client == null) {
      final bool used = _demoProperties.any(
        (Property p) => p.propertyCategoryId == id,
      );
      if (used) {
        throw Exception(
          'Kategori sedang dipakai oleh properti. Nonaktifkan statusnya saja.',
        );
      }
      _demoCategories.removeWhere((PropertyCategory c) => c.id == id);
      return;
    }

    try {
      await client.from('property_categories').delete().eq('id', id);
    } on PostgrestException catch (error) {
      if (error.code == '23503') {
        throw Exception(
          'Kategori sedang dipakai oleh properti. Nonaktifkan statusnya saja.',
        );
      }
      throw Exception(error.message);
    }
  }

  Future<List<Location>> getLocations() async {
    final SupabaseClient? client = _client;
    if (client == null) {
      return List<Location>.unmodifiable(_demoLocations);
    }

    final List<dynamic> rows = await client
        .from('locations')
        .select()
        .order('city', ascending: true)
        .order('district', ascending: true);
    return rows
        .whereType<Map<String, dynamic>>()
        .map(Location.fromJson)
        .toList(growable: false);
  }

  Future<Location> createLocation({
    required String city,
    required String district,
    required String slug,
  }) async {
    final SupabaseClient? client = _client;
    if (client == null) {
      final Location created = Location(
        id: _nextLocationId++,
        city: city.trim(),
        district: district.trim(),
        slug: slug.trim(),
        createdAt: DateTime.now(),
      );
      _demoLocations.add(created);
      return created;
    }

    try {
      final Map<String, dynamic> row = await client
          .from('locations')
          .insert(<String, dynamic>{
            'city': city.trim(),
            'district': district.trim(),
            'slug': slug.trim(),
          })
          .select()
          .single();
      return Location.fromJson(row);
    } on PostgrestException catch (error) {
      if (error.code == '23505') {
        throw Exception('Daerah atau slug "$slug" sudah terdaftar.');
      }
      throw Exception(error.message);
    }
  }

  Future<Location> updateLocation({
    required int id,
    required String city,
    required String district,
    required String slug,
  }) async {
    final SupabaseClient? client = _client;
    if (client == null) {
      final int idx = _demoLocations.indexWhere((Location l) => l.id == id);
      if (idx < 0) throw Exception('Daerah tidak ditemukan.');
      final Location updated = Location(
        id: id,
        city: city.trim(),
        district: district.trim(),
        slug: slug.trim(),
        createdAt: _demoLocations[idx].createdAt,
        updatedAt: DateTime.now(),
      );
      _demoLocations[idx] = updated;
      return updated;
    }

    try {
      final Map<String, dynamic> row = await client
          .from('locations')
          .update(<String, dynamic>{
            'city': city.trim(),
            'district': district.trim(),
            'slug': slug.trim(),
          })
          .eq('id', id)
          .select()
          .single();
      return Location.fromJson(row);
    } on PostgrestException catch (error) {
      if (error.code == '23505') {
        throw Exception('Daerah atau slug "$slug" sudah terdaftar.');
      }
      throw Exception(error.message);
    }
  }

  Future<void> deleteLocation(int id) async {
    final SupabaseClient? client = _client;
    if (client == null) {
      final bool used = _demoProperties.any((Property p) => p.locationId == id);
      if (used) {
        throw Exception(
          'Daerah sedang dipakai oleh properti dan tidak dapat dihapus.',
        );
      }
      _demoLocations.removeWhere((Location l) => l.id == id);
      return;
    }

    try {
      await client.from('locations').delete().eq('id', id);
    } on PostgrestException catch (error) {
      if (error.code == '23503') {
        throw Exception(
          'Daerah sedang dipakai oleh properti dan tidak dapat dihapus.',
        );
      }
      throw Exception(error.message);
    }
  }

  // ---------------------------------------------------------------------------
  // Tugas 3.3, 3.4, 3.5 — CRUD Properti & Foto Properti
  // ---------------------------------------------------------------------------

  Future<List<Property>> getAdminProperties() async {
    final SupabaseClient? client = _client;
    if (client == null) {
      return List<Property>.unmodifiable(_demoProperties);
    }

    final List<dynamic> rows = await client
        .from('properties')
        .select('*, property_categories(*), locations(*), property_images(*)')
        .order('id', ascending: false);
    return rows
        .whereType<Map<String, dynamic>>()
        .map(Property.fromJson)
        .toList(growable: false);
  }

  Future<Property?> getPropertyById(int id) async {
    final SupabaseClient? client = _client;
    if (client == null) {
      return _findDemoProperty(id);
    }

    final Map<String, dynamic>? row = await client
        .from('properties')
        .select('*, property_categories(*), locations(*), property_images(*)')
        .eq('id', id)
        .maybeSingle();
    return row != null ? Property.fromJson(row) : null;
  }

  /// Membuat properti baru. Payload memakai `PropertyInput` tanpa `views_count`.
  Future<Property> createProperty(PropertyInput input) async {
    final SupabaseClient? client = _client;
    if (client == null) {
      final PropertyCategory? cat = _demoCategories.cast<PropertyCategory?>().firstWhere(
            (PropertyCategory? c) => c?.id == input.propertyCategoryId,
            orElse: () => null,
          );
      final Location? loc = _demoLocations.cast<Location?>().firstWhere(
            (Location? l) => l?.id == input.locationId,
            orElse: () => null,
          );
      final Property created = Property(
        id: _nextPropertyId++,
        propertyCategoryId: input.propertyCategoryId,
        locationId: input.locationId,
        title: input.title,
        slug: input.slug,
        price: input.price,
        buildingArea: input.buildingArea,
        landArea: input.landArea,
        bedrooms: input.bedrooms,
        bathrooms: input.bathrooms,
        floors: input.floors,
        electricity: input.electricity,
        certificateType: input.certificateType,
        description: input.description,
        addressDetail: input.addressDetail,
        latitude: input.latitude,
        longitude: input.longitude,
        googleMapsUrl: input.googleMapsUrl,
        availabilityStatus: input.availabilityStatus,
        viewsCount: 0,
        isPublished: input.isPublished,
        createdAt: DateTime.now(),
        category: cat,
        location: loc,
      );
      _demoProperties.insert(0, created);
      return created;
    }

    try {
      final Map<String, dynamic> row = await client
          .from('properties')
          .insert(input.toJson())
          .select('*, property_categories(*), locations(*), property_images(*)')
          .single();
      return Property.fromJson(row);
    } on PostgrestException catch (error) {
      if (error.code == '23505') {
        throw Exception('Slug properti "${input.slug}" sudah digunakan.');
      }
      throw Exception(error.message);
    }
  }

  /// Memperbarui properti. Payload memakai `PropertyInput` tanpa `views_count`.
  Future<Property> updateProperty(int id, PropertyInput input) async {
    final SupabaseClient? client = _client;
    if (client == null) {
      final int idx = _demoProperties.indexWhere((Property p) => p.id == id);
      if (idx < 0) throw Exception('Properti tidak ditemukan.');
      final Property existing = _demoProperties[idx];
      final PropertyCategory? cat = _demoCategories.cast<PropertyCategory?>().firstWhere(
            (PropertyCategory? c) => c?.id == input.propertyCategoryId,
            orElse: () => existing.category,
          );
      final Location? loc = _demoLocations.cast<Location?>().firstWhere(
            (Location? l) => l?.id == input.locationId,
            orElse: () => existing.location,
          );
      final Property updated = Property(
        id: existing.id,
        propertyCategoryId: input.propertyCategoryId,
        locationId: input.locationId,
        title: input.title,
        slug: input.slug,
        price: input.price,
        buildingArea: input.buildingArea,
        landArea: input.landArea,
        bedrooms: input.bedrooms,
        bathrooms: input.bathrooms,
        floors: input.floors,
        electricity: input.electricity,
        certificateType: input.certificateType,
        description: input.description,
        addressDetail: input.addressDetail,
        latitude: input.latitude,
        longitude: input.longitude,
        googleMapsUrl: input.googleMapsUrl,
        availabilityStatus: input.availabilityStatus,
        viewsCount: existing.viewsCount,
        isPublished: input.isPublished,
        createdAt: existing.createdAt,
        updatedAt: DateTime.now(),
        category: cat,
        location: loc,
        images: existing.images,
      );
      _demoProperties[idx] = updated;
      _syncDemoPropertyInBookings(updated);
      return updated;
    }

    try {
      final Map<String, dynamic> row = await client
          .from('properties')
          .update(input.toJson())
          .eq('id', id)
          .select('*, property_categories(*), locations(*), property_images(*)')
          .single();
      return Property.fromJson(row);
    } on PostgrestException catch (error) {
      if (error.code == '23505') {
        throw Exception('Slug properti "${input.slug}" sudah digunakan.');
      }
      throw Exception(error.message);
    }
  }

  void _syncDemoPropertyInBookings(Property updated) {
    for (int i = 0; i < _demoBookings.length; i++) {
      if (_demoBookings[i].booking.propertyId == updated.id) {
        _demoBookings[i] = _demoBookings[i].copyWith(
          propertyAvailabilityStatus: updated.availabilityStatus,
        );
      }
    }
  }

  Future<void> updatePropertyAvailability(
    int id,
    AvailabilityStatus status,
  ) async {
    final SupabaseClient? client = _client;
    if (client == null) {
      final int idx = _demoProperties.indexWhere((Property p) => p.id == id);
      if (idx < 0) return;
      final Property updated = _cloneProperty(
        _demoProperties[idx],
        availabilityStatus: status,
      );
      _demoProperties[idx] = updated;
      _syncDemoPropertyInBookings(updated);
      return;
    }

    await client
        .from('properties')
        .update(<String, dynamic>{'availability_status': status.value})
        .eq('id', id);
  }

  Future<void> updatePropertyPublished(int id, bool isPublished) async {
    final SupabaseClient? client = _client;
    if (client == null) {
      final int idx = _demoProperties.indexWhere((Property p) => p.id == id);
      if (idx < 0) return;
      _demoProperties[idx] = _cloneProperty(
        _demoProperties[idx],
        isPublished: isPublished,
      );
      return;
    }

    await client
        .from('properties')
        .update(<String, dynamic>{'is_published': isPublished})
        .eq('id', id);
  }

  /// Menghapus properti bila belum memiliki booking; jika sudah pernah dibooking,
  /// menonaktifkan (`is_published = false`) sesuai aturan integritas data.
  Future<PropertyDeleteResult> deleteOrDeactivateProperty(int id) async {
    final SupabaseClient? client = _client;
    if (client == null) {
      final bool hasBooking = _demoBookings.any(
        (BookingWithProperty item) => item.booking.propertyId == id,
      );
      if (hasBooking) {
        await updatePropertyPublished(id, false);
        return const PropertyDeleteResult(
          wasDeactivatedInstead: true,
          message:
              'Properti memiliki riwayat booking, sehingga dinonaktifkan (disembunyikan) dari katalog.',
        );
      }
      _demoProperties.removeWhere((Property p) => p.id == id);
      return const PropertyDeleteResult(
        wasDeactivatedInstead: false,
        message: 'Properti berhasil dihapus.',
      );
    }

    final List<dynamic> existingBookings = await client
        .from('bookings')
        .select('id')
        .eq('property_id', id)
        .limit(1);

    if (existingBookings.isNotEmpty) {
      await updatePropertyPublished(id, false);
      return const PropertyDeleteResult(
        wasDeactivatedInstead: true,
        message:
            'Properti memiliki riwayat booking, sehingga dinonaktifkan (disembunyikan) dari katalog.',
      );
    }

    final List<dynamic> imgRows = await client
        .from('property_images')
        .select('image_path')
        .eq('property_id', id);
    final List<String> paths = imgRows
        .whereType<Map<String, dynamic>>()
        .map((Map<String, dynamic> row) => row['image_path'] as String? ?? '')
        .where((String path) => path.isNotEmpty)
        .toList(growable: false);

    if (paths.isNotEmpty) {
      try {
        await client.storage
            .from(CompanyConfig.propertyImagesBucket)
            .remove(paths);
      } catch (_) {
        // Berkas placeholder seeder mungkin belum ada di Storage.
      }
    }

    await client.from('properties').delete().eq('id', id);
    return const PropertyDeleteResult(
      wasDeactivatedInstead: false,
      message: 'Properti berhasil dihapus.',
    );
  }

  Future<PropertyImage> uploadPropertyPhoto({
    required int propertyId,
    required Uint8List rawBytes,
    required bool makePrimary,
    required int sortOrder,
  }) async {
    final Uint8List compressed = ImageCompressor.compressToJpeg(rawBytes);
    final String suffix = _random.nextInt(999999).toString().padLeft(6, '0');
    final String storagePath =
        'properties/$propertyId/${DateTime.now().millisecondsSinceEpoch}_$suffix.jpg';

    final SupabaseClient? client = _client;
    if (client == null) {
      final int idx =
          _demoProperties.indexWhere((Property p) => p.id == propertyId);
      if (idx < 0) throw Exception('Properti tidak ditemukan.');
      final Property existing = _demoProperties[idx];
      if (existing.images.length >= CompanyConfig.maxImagesPerProperty) {
        throw Exception(
          'Maksimal ${CompanyConfig.maxImagesPerProperty} foto per properti.',
        );
      }
      _localImageBytes[storagePath] = compressed;
      final bool willBePrimary = makePrimary || existing.images.isEmpty;
      final List<PropertyImage> updatedImages = existing.images
          .map(
            (PropertyImage img) => PropertyImage(
              id: img.id,
              propertyId: img.propertyId,
              imagePath: img.imagePath,
              isPrimary: willBePrimary ? false : img.isPrimary,
              sortOrder: img.sortOrder,
              createdAt: img.createdAt,
            ),
          )
          .toList();
      final PropertyImage inserted = PropertyImage(
        id: _nextImageId++,
        propertyId: propertyId,
        imagePath: storagePath,
        isPrimary: willBePrimary,
        sortOrder: sortOrder,
        createdAt: DateTime.now(),
      );
      updatedImages.add(inserted);
      _demoProperties[idx] = _copyPropertyWithImages(existing, updatedImages);
      return inserted;
    }

    final List<dynamic> currentRows = await client
        .from('property_images')
        .select('id, is_primary')
        .eq('property_id', propertyId);
    if (currentRows.length >= CompanyConfig.maxImagesPerProperty) {
      throw Exception(
        'Maksimal ${CompanyConfig.maxImagesPerProperty} foto per properti.',
      );
    }

    await client.storage.from(CompanyConfig.propertyImagesBucket).uploadBinary(
          storagePath,
          compressed,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: false,
          ),
        );

    final bool willBePrimary = makePrimary || currentRows.isEmpty;
    if (willBePrimary) {
      await client
          .from('property_images')
          .update(<String, dynamic>{'is_primary': false})
          .eq('property_id', propertyId)
          .eq('is_primary', true);
    }

    final Map<String, dynamic> insertedRow = await client
        .from('property_images')
        .insert(<String, dynamic>{
          'property_id': propertyId,
          'image_path': storagePath,
          'is_primary': willBePrimary,
          'sort_order': sortOrder,
        })
        .select()
        .single();
    return PropertyImage.fromJson(insertedRow);
  }

  Future<void> setPrimaryPhoto(int propertyId, int imageId) async {
    final SupabaseClient? client = _client;
    if (client == null) {
      final int idx =
          _demoProperties.indexWhere((Property p) => p.id == propertyId);
      if (idx < 0) return;
      final Property existing = _demoProperties[idx];
      final List<PropertyImage> updated = existing.images
          .map(
            (PropertyImage img) => PropertyImage(
              id: img.id,
              propertyId: img.propertyId,
              imagePath: img.imagePath,
              isPrimary: img.id == imageId,
              sortOrder: img.sortOrder,
              createdAt: img.createdAt,
            ),
          )
          .toList();
      _demoProperties[idx] = _copyPropertyWithImages(existing, updated);
      return;
    }

    await client
        .from('property_images')
        .update(<String, dynamic>{'is_primary': false})
        .eq('property_id', propertyId)
        .eq('is_primary', true);

    await client
        .from('property_images')
        .update(<String, dynamic>{'is_primary': true})
        .eq('id', imageId);
  }

  Future<void> reorderPropertyPhotos(
    int propertyId,
    List<PropertyImage> orderedImages,
  ) async {
    final SupabaseClient? client = _client;
    if (client == null) {
      final int idx =
          _demoProperties.indexWhere((Property p) => p.id == propertyId);
      if (idx < 0) return;
      final Property existing = _demoProperties[idx];
      final List<PropertyImage> updated = <PropertyImage>[
        for (int i = 0; i < orderedImages.length; i++)
          PropertyImage(
            id: orderedImages[i].id,
            propertyId: orderedImages[i].propertyId,
            imagePath: orderedImages[i].imagePath,
            isPrimary: orderedImages[i].isPrimary,
            sortOrder: i,
            createdAt: orderedImages[i].createdAt,
          ),
      ];
      _demoProperties[idx] = _copyPropertyWithImages(existing, updated);
      return;
    }

    for (int i = 0; i < orderedImages.length; i++) {
      await client
          .from('property_images')
          .update(<String, dynamic>{'sort_order': i})
          .eq('id', orderedImages[i].id);
    }
  }

  Future<void> deletePropertyPhoto(PropertyImage image) async {
    final SupabaseClient? client = _client;
    if (client == null) {
      _localImageBytes.remove(image.imagePath);
      final int idx = _demoProperties.indexWhere(
        (Property p) => p.id == image.propertyId,
      );
      if (idx < 0) return;
      final Property existing = _demoProperties[idx];
      final List<PropertyImage> remaining = existing.images
          .where((PropertyImage item) => item.id != image.id)
          .toList();
      if (image.isPrimary && remaining.isNotEmpty) {
        final PropertyImage first = remaining.first;
        remaining[0] = PropertyImage(
          id: first.id,
          propertyId: first.propertyId,
          imagePath: first.imagePath,
          isPrimary: true,
          sortOrder: first.sortOrder,
          createdAt: first.createdAt,
        );
      }
      _demoProperties[idx] = _copyPropertyWithImages(existing, remaining);
      return;
    }

    await client.from('property_images').delete().eq('id', image.id);
    try {
      await client.storage
          .from(CompanyConfig.propertyImagesBucket)
          .remove(<String>[image.imagePath]);
    } catch (_) {
      // Berkas placeholder seeder mungkin belum ada di Storage.
    }

    if (image.isPrimary) {
      final List<dynamic> remainingRows = await client
          .from('property_images')
          .select('id')
          .eq('property_id', image.propertyId)
          .order('sort_order', ascending: true)
          .order('id', ascending: true)
          .limit(1);
      final Map<String, dynamic>? first =
          remainingRows.whereType<Map<String, dynamic>>().firstOrNull;
      if (first != null) {
        await client
            .from('property_images')
            .update(<String, dynamic>{'is_primary': true})
            .eq('id', (first['id'] as num).toInt());
      }
    }
  }

  Property _copyPropertyWithImages(
    Property existing,
    List<PropertyImage> images,
  ) {
    final List<PropertyImage> sorted = List<PropertyImage>.from(images)
      ..sort((PropertyImage a, PropertyImage b) {
        if (a.isPrimary != b.isPrimary) return a.isPrimary ? -1 : 1;
        final int byOrder = a.sortOrder.compareTo(b.sortOrder);
        return byOrder != 0 ? byOrder : a.id.compareTo(b.id);
      });
    return _cloneProperty(existing, images: sorted);
  }

  Property _cloneProperty(
    Property existing, {
    AvailabilityStatus? availabilityStatus,
    bool? isPublished,
    List<PropertyImage>? images,
  }) {
    return Property(
      id: existing.id,
      propertyCategoryId: existing.propertyCategoryId,
      locationId: existing.locationId,
      title: existing.title,
      slug: existing.slug,
      price: existing.price,
      buildingArea: existing.buildingArea,
      landArea: existing.landArea,
      bedrooms: existing.bedrooms,
      bathrooms: existing.bathrooms,
      floors: existing.floors,
      electricity: existing.electricity,
      certificateType: existing.certificateType,
      description: existing.description,
      addressDetail: existing.addressDetail,
      latitude: existing.latitude,
      longitude: existing.longitude,
      googleMapsUrl: existing.googleMapsUrl,
      availabilityStatus: availabilityStatus ?? existing.availabilityStatus,
      viewsCount: existing.viewsCount,
      isPublished: isPublished ?? existing.isPublished,
      createdAt: existing.createdAt,
      updatedAt: DateTime.now(),
      category: existing.category,
      location: existing.location,
      images: images ?? existing.images,
    );
  }

  String? resolveImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.trim().isEmpty) return null;
    if (imagePath.startsWith('https://')) {
      return imagePath;
    }
    if (imagePath.startsWith('http://')) {
      return null;
    }
    final SupabaseClient? client = _client;
    if (client == null) return null;
    return client.storage
        .from(CompanyConfig.propertyImagesBucket)
        .getPublicUrl(imagePath);
  }

  Uint8List? getLocalImageBytes(String imagePath) => _localImageBytes[imagePath];

  // ---------------------------------------------------------------------------
  // Tugas 3.6 — CRM Booking
  // ---------------------------------------------------------------------------

  Future<List<BookingWithProperty>> getBookings({
    FunnelStatus? statusFilter,
    String keyword = '',
  }) async {
    final SupabaseClient? client = _client;
    final String lowerKeyword = keyword.trim().toLowerCase();

    List<BookingWithProperty> items;
    if (client == null) {
      items = List<BookingWithProperty>.from(_demoBookings)
        ..sort((BookingWithProperty a, BookingWithProperty b) {
          final DateTime aTime =
              a.booking.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final DateTime bTime =
              b.booking.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bTime.compareTo(aTime);
        });
    } else {
      final List<dynamic> rows = await client
          .from('bookings')
          .select(
            '*, properties(id, slug, title, availability_status, property_categories(name), locations(district))',
          )
          .order('created_at', ascending: false)
          .limit(200);
      items = rows
          .whereType<Map<String, dynamic>>()
          .map(BookingWithProperty.fromJson)
          .toList(growable: false);
    }

    return items.where((BookingWithProperty item) {
      if (statusFilter != null && item.booking.funnelStatus != statusFilter) {
        return false;
      }
      if (lowerKeyword.isNotEmpty) {
        final bool matchName =
            item.booking.customerName.toLowerCase().contains(lowerKeyword);
        final bool matchCode =
            item.booking.bookingCode.toLowerCase().contains(lowerKeyword);
        final bool matchWa =
            item.booking.customerWhatsapp.toLowerCase().contains(lowerKeyword);
        final bool matchProp =
            item.propertyTitle.toLowerCase().contains(lowerKeyword);
        return matchName || matchCode || matchWa || matchProp;
      }
      return true;
    }).toList(growable: false);
  }

  Future<BookingWithProperty?> getBookingById(int bookingId) async {
    final SupabaseClient? client = _client;
    if (client == null) {
      for (final BookingWithProperty item in _demoBookings) {
        if (item.booking.id == bookingId) return item;
      }
      return null;
    }

    final Map<String, dynamic>? row = await client
        .from('bookings')
        .select(
          '*, properties(id, slug, title, availability_status, property_categories(name), locations(district))',
        )
        .eq('id', bookingId)
        .maybeSingle();
    return row != null ? BookingWithProperty.fromJson(row) : null;
  }

  Future<BookingWithProperty> updateBooking({
    required int bookingId,
    required FunnelStatus funnelStatus,
    DateTime? confirmedSurveyDate,
    String? adminNotes,
  }) async {
    final String? cleanNotes =
        (adminNotes ?? '').trim().isEmpty ? null : adminNotes!.trim();
    final SupabaseClient? client = _client;

    if (client == null) {
      final int idx = _demoBookings.indexWhere(
        (BookingWithProperty item) => item.booking.id == bookingId,
      );
      if (idx < 0) throw Exception('Data booking tidak ditemukan.');
      final Booking old = _demoBookings[idx].booking;
      final Booking updated = Booking(
        id: old.id,
        bookingCode: old.bookingCode,
        propertyId: old.propertyId,
        customerName: old.customerName,
        customerWhatsapp: old.customerWhatsapp,
        intentType: old.intentType,
        preferredSurveyDate: old.preferredSurveyDate,
        confirmedSurveyDate: confirmedSurveyDate,
        paymentPlan: old.paymentPlan,
        customerNotes: old.customerNotes,
        funnelStatus: funnelStatus,
        adminNotes: cleanNotes,
        createdAt: old.createdAt,
        updatedAt: DateTime.now(),
      );
      _demoBookings[idx] = _demoBookings[idx].copyWith(booking: updated);
      return _demoBookings[idx];
    }

    final Map<String, dynamic> row = await client
        .from('bookings')
        .update(<String, dynamic>{
          'funnel_status': funnelStatus.value,
          'confirmed_survey_date': confirmedSurveyDate?.toUtc().toIso8601String(),
          'admin_notes': cleanNotes,
        })
        .eq('id', bookingId)
        .select(
          '*, properties(id, slug, title, availability_status, property_categories(name), locations(district))',
        )
        .single();
    return BookingWithProperty.fromJson(row);
  }

  // ---------------------------------------------------------------------------
  // Tugas 3.7 — Dashboard Riset Pasar & Popularitas
  // ---------------------------------------------------------------------------

  Future<AdminDashboardBundle> loadDashboard({
    required int daysWindow,
    int? trendPropertyId,
  }) async {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime from = today.subtract(Duration(days: daysWindow - 1));
    final String interval = daysWindow > 45 ? 'month' : 'day';

    final SupabaseClient? client = _client;
    if (client == null) {
      return _buildDemoDashboard(
        from: from,
        to: today,
        daysWindow: daysWindow,
        trendPropertyId: trendPropertyId,
      );
    }

    final String fromIso = _formatDateOnly(from);
    final String toIso = _formatDateOnly(today);

    final dynamic rawTop = await client.rpc(
      'admin_top_properties',
      params: <String, dynamic>{'p_limit': 10},
    );
    final dynamic rawTrend = await client.rpc(
      'admin_view_trend',
      params: <String, dynamic>{
        'p_property_id': trendPropertyId,
        'p_from': fromIso,
        'p_to': toIso,
        'p_interval': interval,
      },
    );
    final dynamic rawSearch = await client.rpc(
      'admin_search_stats',
      params: <String, dynamic>{
        'p_from': fromIso,
        'p_to': toIso,
        'p_limit': 10,
      },
    );

    final List<AdminPropertyTopItem> topProperties = rawTop is List
        ? rawTop
            .whereType<Map<String, dynamic>>()
            .map(AdminPropertyTopItem.fromJson)
            .toList(growable: false)
        : const <AdminPropertyTopItem>[];

    final List<AdminViewTrendPoint> viewTrend = rawTrend is List
        ? rawTrend
            .whereType<Map<String, dynamic>>()
            .map(AdminViewTrendPoint.fromJson)
            .toList(growable: false)
        : const <AdminViewTrendPoint>[];

    final List<AdminSearchStatItem> allSearchStats = rawSearch is List
        ? rawSearch
            .whereType<Map<String, dynamic>>()
            .map(AdminSearchStatItem.fromJson)
            .toList(growable: false)
        : const <AdminSearchStatItem>[];

    final List<dynamic> allViewsRows =
        await client.from('properties').select('views_count');
    int totalViews = 0;
    for (final dynamic row in allViewsRows) {
      if (row is Map<String, dynamic>) {
        totalViews += (row['views_count'] as num?)?.toInt() ?? 0;
      }
    }

    // Batas waktu WIB (+07:00) agar selaras dengan agregasi `Asia/Jakarta` di RPC.
    final DateTime startWib = DateTime.utc(from.year, from.month, from.day)
        .subtract(const Duration(hours: 7));
    final DateTime endWib = DateTime.utc(today.year, today.month, today.day + 1)
        .subtract(const Duration(hours: 7));
    final List<dynamic> searchRows = await client
        .from('search_logs')
        .select('id')
        .gte('searched_at', startWib.toIso8601String())
        .lt('searched_at', endWib.toIso8601String());

    final List<BookingWithProperty> allBookings = await getBookings();
    final List<BookingWithProperty> upcomingSurveys = allBookings
        .where(
          (BookingWithProperty b) =>
              b.booking.confirmedSurveyDate != null &&
              b.booking.funnelStatus != FunnelStatus.closedLost &&
              b.booking.funnelStatus != FunnelStatus.closedWon,
        )
        .take(5)
        .toList(growable: false);
    final int activeLeadsCount = allBookings
        .where(
          (BookingWithProperty b) =>
              b.booking.funnelStatus != FunnelStatus.closedWon &&
              b.booking.funnelStatus != FunnelStatus.closedLost,
        )
        .length;

    return AdminDashboardBundle(
      totalViews: totalViews,
      totalSearches: searchRows.length,
      activeLeadsCount: activeLeadsCount,
      scheduledSurveysCount: allBookings
          .where((BookingWithProperty b) => b.booking.confirmedSurveyDate != null)
          .length,
      topProperties: topProperties,
      viewTrend: viewTrend,
      locationStats: allSearchStats
          .where((AdminSearchStatItem item) => item.dimension == 'location')
          .toList(growable: false),
      categoryStats: allSearchStats
          .where((AdminSearchStatItem item) => item.dimension == 'category')
          .toList(growable: false),
      keywordStats: allSearchStats
          .where((AdminSearchStatItem item) => item.dimension == 'keyword')
          .toList(growable: false),
      upcomingSurveys: upcomingSurveys,
      recentBookings: allBookings.take(5).toList(growable: false),
      usingLocalSeeder: false,
    );
  }

  AdminDashboardBundle _buildDemoDashboard({
    required DateTime from,
    required DateTime to,
    required int daysWindow,
    required int? trendPropertyId,
  }) {
    final List<Property> sortedProps = List<Property>.from(_demoProperties)
      ..sort((Property a, Property b) => b.viewsCount.compareTo(a.viewsCount));
    final List<AdminPropertyTopItem> topProperties = sortedProps
        .take(10)
        .map(
          (Property p) => AdminPropertyTopItem(
            id: p.id,
            slug: p.slug,
            title: p.title,
            categoryName: p.category?.name ?? '',
            city: p.location?.city ?? 'Bandung',
            district: p.location?.district ?? '',
            viewsCount: p.viewsCount,
            availabilityStatus: p.availabilityStatus,
            isPublished: p.isPublished,
          ),
        )
        .toList(growable: false);

    final int totalViews = _demoProperties.fold<int>(
      0,
      (int sum, Property p) => sum + p.viewsCount,
    );

    final int bucketCount = daysWindow > 45 ? 3 : math.min(daysWindow, 14);
    final List<AdminViewTrendPoint> trendPoints = <AdminViewTrendPoint>[
      for (int i = 0; i < bucketCount; i++)
        AdminViewTrendPoint(
          bucketDate: daysWindow > 45
              ? DateTime(to.year, to.month - (bucketCount - 1 - i), 1)
              : to.subtract(Duration(days: bucketCount - 1 - i)),
          viewCount: _demoTrendValue(i, trendPropertyId),
        ),
    ];

    final List<AdminSearchStatItem> locationStats = const <AdminSearchStatItem>[
      AdminSearchStatItem(
        dimension: 'location',
        label: 'Kec. Sukamaju, Bandung',
        searchCount: 84,
        zeroResultCount: 4,
      ),
      AdminSearchStatItem(
        dimension: 'location',
        label: 'Kec. Mekar Jaya, Bandung',
        searchCount: 68,
        zeroResultCount: 6,
      ),
      AdminSearchStatItem(
        dimension: 'location',
        label: 'Kec. Bumi Asri, Bandung',
        searchCount: 52,
        zeroResultCount: 3,
      ),
      AdminSearchStatItem(
        dimension: 'location',
        label: 'Kec. Tanjung Baru, Bandung',
        searchCount: 37,
        zeroResultCount: 9,
      ),
      AdminSearchStatItem(
        dimension: 'location',
        label: 'Kec. Sari Indah, Bandung',
        searchCount: 29,
        zeroResultCount: 2,
      ),
    ];

    final List<AdminSearchStatItem> categoryStats = const <AdminSearchStatItem>[
      AdminSearchStatItem(
        dimension: 'category',
        label: 'Komplek Perumahan',
        searchCount: 196,
        zeroResultCount: 14,
      ),
      AdminSearchStatItem(
        dimension: 'category',
        label: 'Ruko',
        searchCount: 94,
        zeroResultCount: 6,
      ),
    ];

    final List<AdminSearchStatItem> keywordStats = const <AdminSearchStatItem>[
      AdminSearchStatItem(
        dimension: 'keyword',
        label: 'rumah 2 kamar',
        searchCount: 54,
        zeroResultCount: 0,
      ),
      AdminSearchStatItem(
        dimension: 'keyword',
        label: 'ruko 2 lantai',
        searchCount: 41,
        zeroResultCount: 0,
      ),
      AdminSearchStatItem(
        dimension: 'keyword',
        label: 'rumah dekat stasiun',
        searchCount: 28,
        zeroResultCount: 28,
      ),
      AdminSearchStatItem(
        dimension: 'keyword',
        label: 'cluster kolam renang',
        searchCount: 19,
        zeroResultCount: 19,
      ),
      AdminSearchStatItem(
        dimension: 'keyword',
        label: 'griya hijau',
        searchCount: 33,
        zeroResultCount: 0,
      ),
    ];

    final List<BookingWithProperty> upcomingSurveys = _demoBookings
        .where(
          (BookingWithProperty b) =>
              b.booking.confirmedSurveyDate != null &&
              b.booking.funnelStatus != FunnelStatus.closedLost &&
              b.booking.funnelStatus != FunnelStatus.closedWon,
        )
        .toList(growable: false);

    final int activeLeadsCount = _demoBookings
        .where(
          (BookingWithProperty b) =>
              b.booking.funnelStatus != FunnelStatus.closedWon &&
              b.booking.funnelStatus != FunnelStatus.closedLost,
        )
        .length;

    return AdminDashboardBundle(
      totalViews: totalViews,
      totalSearches: 290,
      activeLeadsCount: activeLeadsCount,
      scheduledSurveysCount: upcomingSurveys.length,
      topProperties: topProperties,
      viewTrend: trendPoints,
      locationStats: locationStats,
      categoryStats: categoryStats,
      keywordStats: keywordStats,
      upcomingSurveys: upcomingSurveys,
      recentBookings: _demoBookings.take(5).toList(growable: false),
      usingLocalSeeder: true,
    );
  }

  int _demoTrendValue(int index, int? propertyId) {
    final int base = propertyId == null ? 18 : 6 + (propertyId % 5) * 2;
    const List<int> wave = <int>[2, 5, 4, 8, 7, 11, 9, 6, 10, 12, 8, 14, 11, 15];
    return base + wave[index % wave.length];
  }

  String _formatDateOnly(DateTime d) {
    final String y = d.year.toString().padLeft(4, '0');
    final String m = d.month.toString().padLeft(2, '0');
    final String day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }
}

final Provider<AdminRepository> adminRepositoryProvider =
    Provider<AdminRepository>((Ref ref) {
  final SupabaseClient? client =
      EnvConfig.isSupabaseInitialized ? Supabase.instance.client : null;
  return AdminRepository(client);
});

final Provider<AdminSessionNotifier> adminSessionProvider =
    Provider<AdminSessionNotifier>((Ref ref) {
  final AdminSessionNotifier notifier = AdminSessionNotifier(
    ref.watch(adminRepositoryProvider),
  );
  ref.onDispose(notifier.dispose);
  return notifier;
});

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/env_config.dart';

/// Filter pencarian dan pengurutan untuk layar Katalog (`search_properties`).
class CatalogFilter {
  const CatalogFilter({
    this.keyword = '',
    this.categoryId,
    this.locationId,
    this.minPrice,
    this.maxPrice,
    this.status,
    this.sortBy = 'newest',
    this.limit = CompanyConfig.catalogPageSize,
    this.offset = 0,
  });

  final String keyword;
  final int? categoryId;
  final int? locationId;
  final int? minPrice;
  final int? maxPrice;
  final AvailabilityStatus? status;
  final String sortBy;
  final int limit;
  final int offset;

  int get activeSheetFilterCount {
    int count = 0;
    if (locationId != null) count++;
    if (minPrice != null || maxPrice != null) count++;
    if (status != null) count++;
    return count;
  }

  CatalogFilter copyWith({
    String? keyword,
    int? categoryId,
    bool clearCategory = false,
    int? locationId,
    bool clearLocation = false,
    int? minPrice,
    bool clearMinPrice = false,
    int? maxPrice,
    bool clearMaxPrice = false,
    AvailabilityStatus? status,
    bool clearStatus = false,
    String? sortBy,
    int? limit,
    int? offset,
  }) {
    return CatalogFilter(
      keyword: keyword ?? this.keyword,
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      locationId: clearLocation ? null : (locationId ?? this.locationId),
      minPrice: clearMinPrice ? null : (minPrice ?? this.minPrice),
      maxPrice: clearMaxPrice ? null : (maxPrice ?? this.maxPrice),
      status: clearStatus ? null : (status ?? this.status),
      sortBy: sortBy ?? this.sortBy,
      limit: limit ?? this.limit,
      offset: offset ?? this.offset,
    );
  }
}

/// Hasil pencarian katalog beserta total jumlah data yang cocok.
class CatalogSearchResult {
  const CatalogSearchResult({
    required this.items,
    required this.totalCount,
  });

  final List<PropertySummary> items;
  final int totalCount;
}

/// Data awal Customer App (kategori aktif, daerah, dan properti unggulan Beranda).
class CustomerBootstrapData {
  const CustomerBootstrapData({
    required this.categories,
    required this.locations,
    required this.featuredProperties,
    required this.usingLocalSeeder,
  });

  final List<PropertyCategory> categories;
  final List<Location> locations;
  final List<PropertySummary> featuredProperties;
  final bool usingLocalSeeder;
}

/// Hasil pencarian status booking customer beserta ringkasan properti terkait.
class CustomerBookingLookupResult {
  const CustomerBookingLookupResult({
    required this.booking,
    required this.propertyTitle,
    required this.propertySlug,
    required this.propertyPrice,
    required this.categoryName,
    required this.locationLabel,
    this.primaryImagePath,
  });

  final Booking booking;
  final String propertyTitle;
  final String propertySlug;
  final int propertyPrice;
  final String categoryName;
  final String locationLabel;
  final String? primaryImagePath;

  factory CustomerBookingLookupResult.fromRpcJson(Map<String, dynamic> json) {
    return CustomerBookingLookupResult(
      booking: Booking.fromJson(json),
      propertyTitle: json['property_title'] as String? ?? 'Properti',
      propertySlug: json['property_slug'] as String? ?? '',
      propertyPrice: (json['property_price'] as num?)?.toInt() ?? 0,
      categoryName: json['category_name'] as String? ?? '',
      locationLabel: json['location_label'] as String? ?? '',
      primaryImagePath: json['primary_image_path'] as String?,
    );
  }
}

/// Repositori data Customer App.
/// Menghubungi Supabase saat diinisialisasi, atau fallback ke `SeedData` hanya pada debug/test.
class CustomerRepository {
  const CustomerRepository(
    this._client, {
    this.allowLocalSeeder = !kReleaseMode,
  });

  final SupabaseClient? _client;
  final bool allowLocalSeeder;

  static final RegExp bookingCodePattern =
      RegExp(r'^BK-[0-9]{8}-[A-Z0-9]{5,16}$');
  static final RegExp whatsappPattern = RegExp(r'^628[0-9]{8,12}$');

  static final List<Booking> _sessionBookings = <Booking>[
    Booking(
      id: 1,
      bookingCode: 'BK-20261114-DEMO1',
      propertyId: 1,
      customerName: 'Rina Marlina',
      customerWhatsapp: '6281234567890',
      intentType: IntentType.surveyLocation,
      preferredSurveyDate: DateTime(2026, 11, 16, 10, 0),
      confirmedSurveyDate: DateTime(2026, 11, 16, 10, 0),
      funnelStatus: FunnelStatus.surveyScheduled,
      customerNotes: 'Ingin melihat rumah contoh bersama keluarga.',
      createdAt: DateTime(2026, 11, 14, 9, 0),
    ),
  ];

  bool get isUsingLocalSeeder => _client == null && allowLocalSeeder;

  void _assertLocalSeederAllowed() {
    if (!allowLocalSeeder) {
      throw StateError(
        'Layanan server belum terhubung. Periksa koneksi internet Anda lalu coba lagi.',
      );
    }
  }

  static bool isValidBookingCode(String raw) =>
      bookingCodePattern.hasMatch(raw.trim().toUpperCase());

  static bool isValidWhatsapp(String? raw) {
    final String? normalized = normalizeWhatsapp(raw);
    return normalized != null && whatsappPattern.hasMatch(normalized);
  }

  static String? normalizeWhatsapp(String? raw) {
    if (raw == null) return null;
    final String digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;
    if (digits.startsWith('08')) {
      return '62${digits.substring(1)}';
    }
    if (digits.startsWith('8')) {
      return '62$digits';
    }
    return digits;
  }

  Future<CustomerBootstrapData> loadBootstrap() async {
    final SupabaseClient? client = _client;
    if (client == null) {
      _assertLocalSeederAllowed();
      final List<PropertyCategory> activeCategories = SeedData.categories
          .where((PropertyCategory c) => c.isActive)
          .toList(growable: false);
      final List<PropertySummary> sorted = SeedData.properties
          .where(
            (Property p) => p.isPublished && (p.category?.isActive ?? false),
          )
          .map((Property p) => PropertySummary.fromProperty(p))
          .toList()
        ..sort(
          (PropertySummary a, PropertySummary b) =>
              b.viewsCount.compareTo(a.viewsCount),
        );
      return CustomerBootstrapData(
        categories: activeCategories,
        locations: SeedData.locations,
        featuredProperties: sorted.take(6).toList(growable: false),
        usingLocalSeeder: true,
      );
    }

    final List<dynamic> categoryRows = await client
        .from('property_categories')
        .select()
        .eq('is_active', true)
        .order('id', ascending: true);

    final List<dynamic> locationRows =
        await client.from('locations').select().order('district', ascending: true);

    final List<dynamic> propertyRows = await client
        .from('properties')
        .select('*, property_categories!inner(*), locations(*), property_images(*)')
        .eq('is_published', true)
        .eq('property_categories.is_active', true)
        .order('views_count', ascending: false)
        .limit(6);

    final List<PropertyCategory> categories = categoryRows
        .whereType<Map<String, dynamic>>()
        .map(PropertyCategory.fromJson)
        .where((PropertyCategory c) => c.isActive)
        .toList(growable: false);

    final List<Location> locations = locationRows
        .whereType<Map<String, dynamic>>()
        .map(Location.fromJson)
        .toList(growable: false);

    final List<PropertySummary> properties = propertyRows
        .whereType<Map<String, dynamic>>()
        .map(Property.fromJson)
        .where(
          (Property p) => p.isPublished && (p.category?.isActive ?? false),
        )
        .map((Property p) => PropertySummary.fromProperty(p))
        .toList(growable: false);

    return CustomerBootstrapData(
      categories: categories,
      locations: locations,
      featuredProperties: properties,
      usingLocalSeeder: false,
    );
  }

  Future<CatalogSearchResult> searchProperties(CatalogFilter filter) async {
    final SupabaseClient? client = _client;
    if (client == null) {
      _assertLocalSeederAllowed();
      return _searchSeedData(filter);
    }

    final String trimmed = filter.keyword.trim();
    final dynamic raw = await client.rpc(
      'search_properties',
      params: <String, dynamic>{
        'p_keyword': trimmed.isEmpty ? null : trimmed,
        'p_location_id': filter.locationId,
        'p_category_id': filter.categoryId,
        'p_min_price': filter.minPrice,
        'p_max_price': filter.maxPrice,
        'p_availability': filter.status?.value,
        'p_sort': filter.sortBy,
        'p_limit': filter.limit,
        'p_offset': filter.offset,
      },
    );

    final List<Map<String, dynamic>> rows = raw is List
        ? raw.whereType<Map<String, dynamic>>().toList(growable: false)
        : const <Map<String, dynamic>>[];

    final List<PropertySummary> items =
        rows.map(PropertySummary.fromJson).toList(growable: false);
    final int totalCount =
        items.isNotEmpty ? (items.first.totalCount ?? items.length) : 0;

    return CatalogSearchResult(items: items, totalCount: totalCount);
  }

  Future<Property?> getPropertyBySlug(String slug) async {
    final SupabaseClient? client = _client;
    if (client == null) {
      _assertLocalSeederAllowed();
      for (final Property property in SeedData.properties) {
        if (property.isPublished &&
            (property.category?.isActive ?? false) &&
            property.slug == slug) {
          return property;
        }
      }
      return null;
    }

    final Map<String, dynamic>? row = await client
        .from('properties')
        .select('*, property_categories!inner(*), locations(*), property_images(*)')
        .eq('slug', slug)
        .eq('is_published', true)
        .eq('property_categories.is_active', true)
        .maybeSingle();

    if (row == null) return null;
    final Property property = Property.fromJson(row);
    if (!property.isPublished || !(property.category?.isActive ?? false)) {
      return null;
    }
    return property;
  }

  Future<int?> recordPropertyView(int propertyId) async {
    final SupabaseClient? client = _client;
    if (client == null) {
      _assertLocalSeederAllowed();
      for (final Property property in SeedData.properties) {
        if (property.id == propertyId &&
            property.isPublished &&
            (property.category?.isActive ?? false)) {
          return property.viewsCount + 1;
        }
      }
      return null;
    }

    final dynamic result = await client.rpc(
      'record_property_view',
      params: <String, dynamic>{'p_property_id': propertyId},
    );
    return result is num ? result.toInt() : null;
  }

  Future<Booking> createBooking(BookingCreateInput input) async {
    final SupabaseClient? client = _client;
    if (client == null) {
      _assertLocalSeederAllowed();
      return Booking(
        id: 1,
        bookingCode: 'BK-20261114-DEMO1',
        propertyId: input.propertyId,
        customerName: input.customerName.trim(),
        customerWhatsapp: input.customerWhatsapp.trim(),
        intentType: input.intentType,
        preferredSurveyDate: input.preferredSurveyDate,
        paymentPlan: input.paymentPlan,
        customerNotes: input.customerNotes,
        funnelStatus: FunnelStatus.newLead,
        createdAt: DateTime.now(),
      );
    }

    try {
      final dynamic result = await client.rpc(
        'create_booking',
        params: input.toRpcParams(),
      );
      final String code = result?.toString() ?? '';
      if (code.isEmpty) {
        throw const FormatException('Kode booking tidak diterima dari server.');
      }
      return Booking(
        id: 0,
        bookingCode: code,
        propertyId: input.propertyId,
        customerName: input.customerName.trim(),
        customerWhatsapp: input.customerWhatsapp.trim(),
        intentType: input.intentType,
        preferredSurveyDate: input.preferredSurveyDate,
        paymentPlan: input.paymentPlan,
        customerNotes: input.customerNotes,
        funnelStatus: FunnelStatus.newLead,
        createdAt: DateTime.now(),
      );
    } on PostgrestException catch (error) {
      throw Exception(error.message);
    }
  }

  Future<List<CustomerBookingLookupResult>> checkBookingStatus({
    required String bookingCode,
    required String customerWhatsapp,
  }) async {
    final String cleanCode = bookingCode.trim().toUpperCase();
    final String? cleanWa = normalizeWhatsapp(customerWhatsapp);

    if (cleanCode.isEmpty || cleanWa == null) {
      throw ArgumentError(
        'Kode booking dan nomor WhatsApp wajib diisi.',
      );
    }
    if (!bookingCodePattern.hasMatch(cleanCode)) {
      throw ArgumentError(
        'Format kode booking tidak valid (contoh: BK-20261122-A1B2C3D4E5F60718).',
      );
    }
    if (!whatsappPattern.hasMatch(cleanWa)) {
      throw ArgumentError(
        'Format nomor WhatsApp tidak valid (gunakan awalan 08 atau 628, 11-15 digit).',
      );
    }

    final SupabaseClient? client = _client;
    if (client == null) {
      _assertLocalSeederAllowed();
      return _lookupSessionBookings(
        bookingCode: cleanCode,
        customerWhatsapp: cleanWa,
      );
    }

    try {
      final dynamic raw = await client.rpc(
        'check_booking_status',
        params: <String, dynamic>{
          'p_booking_code': cleanCode,
          'p_customer_whatsapp': cleanWa,
        },
      );
      final List<Map<String, dynamic>> rows = raw is List
          ? raw.whereType<Map<String, dynamic>>().toList(growable: false)
          : const <Map<String, dynamic>>[];

      return rows
          .map(CustomerBookingLookupResult.fromRpcJson)
          .toList(growable: false);
    } on PostgrestException catch (error) {
      throw Exception(error.message);
    }
  }

  List<CustomerBookingLookupResult> _lookupSessionBookings({
    required String bookingCode,
    required String customerWhatsapp,
  }) {
    final List<CustomerBookingLookupResult> matches =
        <CustomerBookingLookupResult>[];

    for (final Booking booking in _sessionBookings) {
      if (booking.bookingCode.toUpperCase() != bookingCode ||
          normalizeWhatsapp(booking.customerWhatsapp) != customerWhatsapp) {
        continue;
      }

      Property? property;
      for (final Property item in SeedData.properties) {
        if (item.id == booking.propertyId) {
          property = item;
          break;
        }
      }
      if (property == null ||
          !property.isPublished ||
          !(property.category?.isActive ?? false)) {
        continue;
      }

      final Booking sanitizedBooking = Booking(
        id: booking.id,
        bookingCode: booking.bookingCode,
        propertyId: booking.propertyId,
        customerName: booking.customerName,
        customerWhatsapp: '',
        intentType: booking.intentType,
        preferredSurveyDate: booking.preferredSurveyDate,
        confirmedSurveyDate: booking.confirmedSurveyDate,
        paymentPlan: booking.paymentPlan,
        customerNotes: booking.customerNotes,
        funnelStatus: booking.funnelStatus,
        adminNotes: null,
        createdAt: booking.createdAt,
        updatedAt: booking.updatedAt,
      );

      matches.add(
        CustomerBookingLookupResult(
          booking: sanitizedBooking,
          propertyTitle: property.title,
          propertySlug: property.slug,
          propertyPrice: property.price,
          categoryName: property.category?.name ?? '',
          locationLabel: property.location?.displayName ?? '',
          primaryImagePath: property.primaryImagePath,
        ),
      );
    }

    return matches.take(1).toList(growable: false);
  }

  String? resolveImageUrl(String? imagePath) {
    final String trimmed = (imagePath ?? '').trim();
    if (trimmed.isEmpty) return null;

    final Uri? parsed = Uri.tryParse(trimmed);
    if (parsed == null) return null;
    if (parsed.hasScheme) {
      if (parsed.scheme.toLowerCase() == 'https' &&
          parsed.host.isNotEmpty &&
          parsed.userInfo.isEmpty) {
        return parsed.toString();
      }
      return null;
    }

    if (trimmed.startsWith('/') ||
        trimmed.contains('..') ||
        trimmed.contains(':') ||
        trimmed.contains('\\')) {
      return null;
    }

    final SupabaseClient? client = _client;
    if (client == null) return null;
    return client.storage
        .from(CompanyConfig.propertyImagesBucket)
        .getPublicUrl(trimmed);
  }

  CatalogSearchResult _searchSeedData(CatalogFilter filter) {
    final String keyword = filter.keyword.trim().toLowerCase();
    final List<Property> filtered = SeedData.properties.where((Property p) {
      if (!p.isPublished) return false;
      if (!(p.category?.isActive ?? false)) return false;
      if (keyword.isNotEmpty) {
        final bool matchTitle = p.title.toLowerCase().contains(keyword);
        final bool matchAddr =
            (p.addressDetail ?? '').toLowerCase().contains(keyword);
        final bool matchDistrict =
            (p.location?.district ?? '').toLowerCase().contains(keyword);
        if (!matchTitle && !matchAddr && !matchDistrict) return false;
      }
      if (filter.categoryId != null &&
          p.propertyCategoryId != filter.categoryId) {
        return false;
      }
      if (filter.locationId != null && p.locationId != filter.locationId) {
        return false;
      }
      if (filter.minPrice != null && p.price < filter.minPrice!) {
        return false;
      }
      if (filter.maxPrice != null && p.price > filter.maxPrice!) {
        return false;
      }
      if (filter.status != null && p.availabilityStatus != filter.status) {
        return false;
      }
      return true;
    }).toList();

    filtered.sort((Property a, Property b) {
      switch (filter.sortBy) {
        case 'price_asc':
          return a.price.compareTo(b.price);
        case 'price_desc':
          return b.price.compareTo(a.price);
        default:
          return b.id.compareTo(a.id);
      }
    });

    final int total = filtered.length;
    final int start = math.min(filter.offset, total);
    final int end = math.min(start + filter.limit, total);
    final List<PropertySummary> items = filtered
        .sublist(start, end)
        .map((Property p) => PropertySummary.fromProperty(p, totalCount: total))
        .toList(growable: false);

    return CatalogSearchResult(items: items, totalCount: total);
  }
}

final Provider<CustomerRepository> customerRepositoryProvider =
    Provider<CustomerRepository>((Ref ref) {
  final SupabaseClient? client =
      EnvConfig.isSupabaseInitialized ? Supabase.instance.client : null;
  return CustomerRepository(client);
});

final FutureProvider<CustomerBootstrapData> customerBootstrapProvider =
    FutureProvider<CustomerBootstrapData>((Ref ref) {
  return ref.watch(customerRepositoryProvider).loadBootstrap();
});

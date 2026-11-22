import 'dart:math' as math;

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
/// Menghubungi Supabase saat diinisialisasi, atau fallback ke `SeedData` pada test/offline.
class CustomerRepository {
  const CustomerRepository(this._client);

  final SupabaseClient? _client;

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

  bool get isUsingLocalSeeder => _client == null;

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
      final List<PropertySummary> sorted =
          List<PropertySummary>.from(SeedData.publishedSummaries)
            ..sort(
              (PropertySummary a, PropertySummary b) =>
                  b.viewsCount.compareTo(a.viewsCount),
            );
      return CustomerBootstrapData(
        categories: SeedData.categories,
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
        .select('*, property_categories(*), locations(*), property_images(*)')
        .eq('is_published', true)
        .order('views_count', ascending: false)
        .limit(6);

    final List<PropertyCategory> categories = categoryRows
        .whereType<Map<String, dynamic>>()
        .map(PropertyCategory.fromJson)
        .toList(growable: false);

    final List<Location> locations = locationRows
        .whereType<Map<String, dynamic>>()
        .map(Location.fromJson)
        .toList(growable: false);

    final List<PropertySummary> properties = propertyRows
        .whereType<Map<String, dynamic>>()
        .map(Property.fromJson)
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
      for (final Property property in SeedData.properties) {
        if (property.isPublished && property.slug == slug) {
          return property;
        }
      }
      return null;
    }

    final Map<String, dynamic>? row = await client
        .from('properties')
        .select('*, property_categories(*), locations(*), property_images(*)')
        .eq('slug', slug)
        .eq('is_published', true)
        .maybeSingle();

    return row != null ? Property.fromJson(row) : null;
  }

  Future<int?> recordPropertyView(int propertyId) async {
    final SupabaseClient? client = _client;
    if (client == null) {
      for (final Property property in SeedData.properties) {
        if (property.id == propertyId && property.isPublished) {
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
      final Booking booking = Booking(
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
      _rememberSessionBooking(booking);
      return booking;
    } on PostgrestException catch (error) {
      throw Exception(error.message);
    }
  }

  void _rememberSessionBooking(Booking booking) {
    if (booking.bookingCode == 'BK-20261114-DEMO1') return;
    _sessionBookings.removeWhere(
      (Booking item) => item.bookingCode == booking.bookingCode,
    );
    _sessionBookings.insert(0, booking);
  }

  Future<List<CustomerBookingLookupResult>> checkBookingStatus({
    String? bookingCode,
    String? customerWhatsapp,
  }) async {
    final String trimmedCode = (bookingCode ?? '').trim().toUpperCase();
    final String? cleanCode = trimmedCode.isEmpty ? null : trimmedCode;
    final String? cleanWa = normalizeWhatsapp(customerWhatsapp);

    if (cleanCode == null && cleanWa == null) {
      throw ArgumentError(
        'Masukkan kode booking atau nomor WhatsApp untuk mengecek status.',
      );
    }

    final SupabaseClient? client = _client;
    if (client == null) {
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

      final List<CustomerBookingLookupResult> results = rows
          .map(CustomerBookingLookupResult.fromRpcJson)
          .toList(growable: true);

      // Gabungkan booking sesi ini hanya saat pencarian kode spesifik (hindari duplikat bermasker pada pencarian nomor WA).
      if (cleanCode != null) {
        final Set<String> returnedCodes = results
            .map((CustomerBookingLookupResult item) => item.booking.bookingCode)
            .toSet();
        for (final CustomerBookingLookupResult cached
            in _lookupSessionBookings(
              bookingCode: cleanCode,
              customerWhatsapp: cleanWa,
              excludeDemoFallback: true,
            )) {
          if (!returnedCodes.contains(cached.booking.bookingCode)) {
            results.add(cached);
          }
        }
      }
      return results;
    } on PostgrestException catch (error) {
      throw Exception(error.message);
    }
  }

  List<CustomerBookingLookupResult> _lookupSessionBookings({
    String? bookingCode,
    String? customerWhatsapp,
    bool excludeDemoFallback = false,
  }) {
    final List<CustomerBookingLookupResult> matches =
        <CustomerBookingLookupResult>[];

    for (final Booking booking in _sessionBookings) {
      if (excludeDemoFallback &&
          booking.bookingCode == 'BK-20261114-DEMO1') {
        continue;
      }
      if (bookingCode != null &&
          booking.bookingCode.toUpperCase() != bookingCode) {
        continue;
      }
      if (customerWhatsapp != null &&
          booking.customerWhatsapp != customerWhatsapp) {
        continue;
      }

      final Property property = SeedData.properties.firstWhere(
        (Property p) => p.id == booking.propertyId,
        orElse: () => SeedData.properties.first,
      );

      final Booking resultBooking = bookingCode != null
          ? booking
          : _maskBookingForPhoneLookup(booking);

      matches.add(
        CustomerBookingLookupResult(
          booking: resultBooking,
          propertyTitle: property.title,
          propertySlug: property.slug,
          propertyPrice: property.price,
          categoryName: property.category?.name ?? 'Properti',
          locationLabel: property.location?.displayName ?? 'Bandung',
          primaryImagePath: property.primaryImagePath,
        ),
      );
    }

    return matches.take(5).toList(growable: false);
  }

  static Booking _maskBookingForPhoneLookup(Booking booking) {
    final String trimmedName = booking.customerName.trim();
    final String maskedName =
        trimmedName.length <= 1 ? '***' : '${trimmedName[0]}***';
    final String wa = booking.customerWhatsapp;
    final String maskedWa = wa.length > 8
        ? '${wa.substring(0, 5)}****${wa.substring(wa.length - 3)}'
        : '****';
    return Booking(
      id: booking.id,
      bookingCode: 'BK-***********',
      propertyId: booking.propertyId,
      customerName: maskedName,
      customerWhatsapp: maskedWa,
      intentType: booking.intentType,
      preferredSurveyDate: booking.preferredSurveyDate,
      confirmedSurveyDate: booking.confirmedSurveyDate,
      paymentPlan: booking.paymentPlan,
      customerNotes: null,
      funnelStatus: booking.funnelStatus,
      adminNotes: booking.adminNotes,
      createdAt: booking.createdAt,
      updatedAt: booking.updatedAt,
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

  CatalogSearchResult _searchSeedData(CatalogFilter filter) {
    final String keyword = filter.keyword.trim().toLowerCase();
    final List<Property> filtered = SeedData.properties.where((Property p) {
      if (!p.isPublished) return false;
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

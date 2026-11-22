import 'package:shared/shared.dart';

/// Error khusus ketika akun terautentikasi tidak memiliki peran `admin`.
class AdminAccessDeniedException implements Exception {
  const AdminAccessDeniedException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Informasi pengguna Admin yang sedang aktif pada sesi login.
class AdminSessionUser {
  const AdminSessionUser({
    required this.id,
    required this.email,
    required this.role,
  });

  final String id;
  final String email;
  final String role;

  bool get isAdmin => role == 'admin';

  String get avatarInitial {
    final String trimmed = email.trim();
    if (trimmed.isEmpty) return 'A';
    return trimmed.substring(0, 1).toUpperCase();
  }
}

/// Item peringkat properti paling sering dilihat (`rpc('admin_top_properties')`).
class AdminPropertyTopItem {
  const AdminPropertyTopItem({
    required this.id,
    required this.slug,
    required this.title,
    required this.categoryName,
    required this.city,
    required this.district,
    required this.viewsCount,
    required this.availabilityStatus,
    required this.isPublished,
  });

  final int id;
  final String slug;
  final String title;
  final String categoryName;
  final String city;
  final String district;
  final int viewsCount;
  final AvailabilityStatus availabilityStatus;
  final bool isPublished;

  String get locationLabel => '$district, $city';

  factory AdminPropertyTopItem.fromJson(Map<String, dynamic> json) {
    return AdminPropertyTopItem(
      id: (json['id'] as num).toInt(),
      slug: json['slug'] as String,
      title: json['title'] as String,
      categoryName: json['category_name'] as String? ?? '',
      city: json['city'] as String? ?? '',
      district: json['district'] as String? ?? '',
      viewsCount: (json['views_count'] as num?)?.toInt() ?? 0,
      availabilityStatus: AvailabilityStatus.fromValue(
        json['availability_status'] as String? ?? 'available',
      ),
      isPublished: json['is_published'] as bool? ?? true,
    );
  }
}

/// Titik data grafik tren kunjungan (`rpc('admin_view_trend')`).
class AdminViewTrendPoint {
  const AdminViewTrendPoint({
    required this.bucketDate,
    required this.viewCount,
  });

  final DateTime bucketDate;
  final int viewCount;

  factory AdminViewTrendPoint.fromJson(Map<String, dynamic> json) {
    return AdminViewTrendPoint(
      bucketDate: DateTime.parse(json['bucket_date'] as String),
      viewCount: (json['view_count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Baris statistik pencarian per dimensi (`rpc('admin_search_stats')`).
class AdminSearchStatItem {
  const AdminSearchStatItem({
    required this.dimension,
    required this.label,
    required this.searchCount,
    required this.zeroResultCount,
  });

  final String dimension;
  final String label;
  final int searchCount;
  final int zeroResultCount;

  factory AdminSearchStatItem.fromJson(Map<String, dynamic> json) {
    return AdminSearchStatItem(
      dimension: json['dimension'] as String? ?? '',
      label: json['label'] as String? ?? '',
      searchCount: (json['search_count'] as num?)?.toInt() ?? 0,
      zeroResultCount: (json['zero_result_count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Model gabungan booking + ringkasan properti terkait untuk layar CRM Admin.
class BookingWithProperty {
  const BookingWithProperty({
    required this.booking,
    required this.propertyTitle,
    required this.propertySlug,
    required this.propertyCategoryName,
    required this.propertyDistrict,
    required this.propertyAvailabilityStatus,
  });

  final Booking booking;
  final String propertyTitle;
  final String propertySlug;
  final String propertyCategoryName;
  final String propertyDistrict;
  final AvailabilityStatus propertyAvailabilityStatus;

  factory BookingWithProperty.fromJson(Map<String, dynamic> json) {
    final Booking parsedBooking = Booking.fromJson(json);
    final Map<String, dynamic>? prop =
        json['properties'] as Map<String, dynamic>?;
    final Map<String, dynamic>? cat =
        prop?['property_categories'] as Map<String, dynamic>?;
    final Map<String, dynamic>? loc =
        prop?['locations'] as Map<String, dynamic>?;
    return BookingWithProperty(
      booking: parsedBooking,
      propertyTitle:
          prop?['title'] as String? ?? 'Properti #${parsedBooking.propertyId}',
      propertySlug: prop?['slug'] as String? ?? '',
      propertyCategoryName: cat?['name'] as String? ?? '',
      propertyDistrict: loc?['district'] as String? ?? '',
      propertyAvailabilityStatus: AvailabilityStatus.fromValue(
        prop?['availability_status'] as String? ?? 'available',
      ),
    );
  }

  /// Parser untuk hasil flat RPC `admin_list_bookings` dan `admin_upcoming_surveys`.
  factory BookingWithProperty.fromRpcJson(Map<String, dynamic> json) {
    final Booking parsedBooking = Booking.fromJson(json);
    return BookingWithProperty(
      booking: parsedBooking,
      propertyTitle: json['property_title'] as String? ??
          'Properti #${parsedBooking.propertyId}',
      propertySlug: json['property_slug'] as String? ?? '',
      propertyCategoryName: json['property_category_name'] as String? ?? '',
      propertyDistrict: json['property_district'] as String? ?? '',
      propertyAvailabilityStatus: AvailabilityStatus.fromValue(
        json['property_availability_status'] as String? ?? 'available',
      ),
    );
  }

  BookingWithProperty copyWith({
    Booking? booking,
    AvailabilityStatus? propertyAvailabilityStatus,
  }) {
    return BookingWithProperty(
      booking: booking ?? this.booking,
      propertyTitle: propertyTitle,
      propertySlug: propertySlug,
      propertyCategoryName: propertyCategoryName,
      propertyDistrict: propertyDistrict,
      propertyAvailabilityStatus:
          propertyAvailabilityStatus ?? this.propertyAvailabilityStatus,
    );
  }
}

/// Hasil paginasi CRM Leads Booking (`rpc('admin_list_bookings')`).
class AdminBookingsPage {
  const AdminBookingsPage({
    required this.items,
    required this.totalCount,
    required this.limit,
    required this.offset,
  });

  final List<BookingWithProperty> items;
  final int totalCount;
  final int limit;
  final int offset;

  bool get hasMore => offset + items.length < totalCount;
}

/// Hasil penghapusan / penonaktifan properti.
class PropertyDeleteResult {
  const PropertyDeleteResult({
    required this.wasDeactivatedInstead,
    required this.message,
  });

  final bool wasDeactivatedInstead;
  final String message;
}

/// Paket data Dashboard & Riset Pasar Admin (`Tugas 3.7`).
class AdminDashboardBundle {
  const AdminDashboardBundle({
    required this.totalViews,
    required this.totalSearches,
    required this.activeLeadsCount,
    required this.scheduledSurveysCount,
    required this.topProperties,
    required this.viewTrend,
    required this.locationStats,
    required this.categoryStats,
    required this.keywordStats,
    required this.upcomingSurveys,
    required this.recentBookings,
    required this.usingLocalSeeder,
  });

  final int totalViews;
  final int totalSearches;
  final int activeLeadsCount;
  final int scheduledSurveysCount;
  final List<AdminPropertyTopItem> topProperties;
  final List<AdminViewTrendPoint> viewTrend;
  final List<AdminSearchStatItem> locationStats;
  final List<AdminSearchStatItem> categoryStats;
  final List<AdminSearchStatItem> keywordStats;
  final List<BookingWithProperty> upcomingSurveys;
  final List<BookingWithProperty> recentBookings;
  final bool usingLocalSeeder;
}

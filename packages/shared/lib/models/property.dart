import 'enums.dart';
import 'location.dart';
import 'property_category.dart';
import 'property_image.dart';

/// Model lengkap properti untuk detail unit & manajemen admin (`properties`).
class Property {
  const Property({
    required this.id,
    required this.propertyCategoryId,
    required this.locationId,
    required this.title,
    required this.slug,
    required this.price,
    this.buildingArea,
    this.landArea,
    this.bedrooms,
    this.bathrooms,
    this.floors,
    this.electricity,
    this.certificateType,
    this.description,
    this.addressDetail,
    this.latitude,
    this.longitude,
    this.googleMapsUrl,
    required this.availabilityStatus,
    required this.viewsCount,
    required this.isPublished,
    this.createdAt,
    this.updatedAt,
    this.category,
    this.location,
    this.images = const <PropertyImage>[],
  });

  final int id;
  final int propertyCategoryId;
  final int locationId;
  final String title;
  final String slug;
  final int price;
  final int? buildingArea;
  final int? landArea;
  final int? bedrooms;
  final int? bathrooms;
  final int? floors;
  final String? electricity;
  final String? certificateType;
  final String? description;
  final String? addressDetail;
  final double? latitude;
  final double? longitude;
  final String? googleMapsUrl;
  final AvailabilityStatus availabilityStatus;
  final int viewsCount;
  final bool isPublished;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final PropertyCategory? category;
  final Location? location;
  final List<PropertyImage> images;

  String? get primaryImagePath {
    for (final PropertyImage image in images) {
      if (image.isPrimary) return image.imagePath;
    }
    return images.isNotEmpty ? images.first.imagePath : null;
  }

  factory Property.fromJson(Map<String, dynamic> json) {
    final Object? rawCategory = json['property_categories'];
    final Object? rawLocation = json['locations'];
    final Object? rawImages = json['property_images'];

    final List<PropertyImage> parsedImages = rawImages is List
        ? rawImages
            .whereType<Map<String, dynamic>>()
            .map(PropertyImage.fromJson)
            .toList()
        : const <PropertyImage>[];

    if (parsedImages.length > 1) {
      parsedImages.sort((PropertyImage a, PropertyImage b) {
        if (a.isPrimary != b.isPrimary) return a.isPrimary ? -1 : 1;
        final int byOrder = a.sortOrder.compareTo(b.sortOrder);
        return byOrder != 0 ? byOrder : a.id.compareTo(b.id);
      });
    }

    return Property(
      id: (json['id'] as num).toInt(),
      propertyCategoryId: (json['property_category_id'] as num).toInt(),
      locationId: (json['location_id'] as num).toInt(),
      title: json['title'] as String,
      slug: json['slug'] as String,
      price: (json['price'] as num).toInt(),
      buildingArea: (json['building_area'] as num?)?.toInt(),
      landArea: (json['land_area'] as num?)?.toInt(),
      bedrooms: (json['bedrooms'] as num?)?.toInt(),
      bathrooms: (json['bathrooms'] as num?)?.toInt(),
      floors: (json['floors'] as num?)?.toInt(),
      electricity: json['electricity'] as String?,
      certificateType: json['certificate_type'] as String?,
      description: json['description'] as String?,
      addressDetail: json['address_detail'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      googleMapsUrl: json['google_maps_url'] as String?,
      availabilityStatus: AvailabilityStatus.fromValue(
        json['availability_status'] as String? ?? 'available',
      ),
      viewsCount: (json['views_count'] as num?)?.toInt() ?? 0,
      isPublished: json['is_published'] as bool? ?? true,
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
      category: rawCategory is Map<String, dynamic>
          ? PropertyCategory.fromJson(rawCategory)
          : null,
      location: rawLocation is Map<String, dynamic>
          ? Location.fromJson(rawLocation)
          : null,
      images: parsedImages,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'property_category_id': propertyCategoryId,
      'location_id': locationId,
      'title': title,
      'slug': slug,
      'price': price,
      'building_area': buildingArea,
      'land_area': landArea,
      'bedrooms': bedrooms,
      'bathrooms': bathrooms,
      'floors': floors,
      'electricity': electricity,
      'certificate_type': certificateType,
      'description': description,
      'address_detail': addressDetail,
      'latitude': latitude,
      'longitude': longitude,
      'google_maps_url': googleMapsUrl,
      'availability_status': availabilityStatus.value,
      'views_count': viewsCount,
      'is_published': isPublished,
      if (createdAt != null) 'created_at': createdAt!.toUtc().toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toUtc().toIso8601String(),
    };
  }
}

/// Model ringkas properti untuk kartu Beranda & hasil RPC `search_properties`.
class PropertySummary {
  const PropertySummary({
    required this.id,
    required this.slug,
    required this.title,
    required this.price,
    this.buildingArea,
    this.landArea,
    this.bedrooms,
    this.bathrooms,
    required this.availabilityStatus,
    required this.viewsCount,
    required this.categoryName,
    required this.city,
    required this.district,
    this.primaryImagePath,
    this.totalCount,
  });

  final int id;
  final String slug;
  final String title;
  final int price;
  final int? buildingArea;
  final int? landArea;
  final int? bedrooms;
  final int? bathrooms;
  final AvailabilityStatus availabilityStatus;
  final int viewsCount;
  final String categoryName;
  final String city;
  final String district;
  final String? primaryImagePath;
  final int? totalCount;

  String get locationLabel => '$district, $city';

  factory PropertySummary.fromJson(Map<String, dynamic> json) {
    return PropertySummary(
      id: (json['id'] as num).toInt(),
      slug: json['slug'] as String,
      title: json['title'] as String,
      price: (json['price'] as num).toInt(),
      buildingArea: (json['building_area'] as num?)?.toInt(),
      landArea: (json['land_area'] as num?)?.toInt(),
      bedrooms: (json['bedrooms'] as num?)?.toInt(),
      bathrooms: (json['bathrooms'] as num?)?.toInt(),
      availabilityStatus: AvailabilityStatus.fromValue(
        json['availability_status'] as String? ?? 'available',
      ),
      viewsCount: (json['views_count'] as num?)?.toInt() ?? 0,
      categoryName: json['category_name'] as String? ??
          (json['property_categories'] as Map<String, dynamic>?)?['name']
              as String? ??
          '',
      city: json['city'] as String? ??
          (json['locations'] as Map<String, dynamic>?)?['city'] as String? ??
          '',
      district: json['district'] as String? ??
          (json['locations'] as Map<String, dynamic>?)?['district']
              as String? ??
          '',
      primaryImagePath: json['primary_image_path'] as String?,
      totalCount: (json['total_count'] as num?)?.toInt(),
    );
  }

  factory PropertySummary.fromProperty(Property property, {int? totalCount}) {
    return PropertySummary(
      id: property.id,
      slug: property.slug,
      title: property.title,
      price: property.price,
      buildingArea: property.buildingArea,
      landArea: property.landArea,
      bedrooms: property.bedrooms,
      bathrooms: property.bathrooms,
      availabilityStatus: property.availabilityStatus,
      viewsCount: property.viewsCount,
      categoryName: property.category?.name ?? '',
      city: property.location?.city ?? '',
      district: property.location?.district ?? '',
      primaryImagePath: property.primaryImagePath,
      totalCount: totalCount,
    );
  }
}

DateTime? _parseDateTime(Object? raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw;
  if (raw is String && raw.isNotEmpty) return DateTime.parse(raw);
  return null;
}

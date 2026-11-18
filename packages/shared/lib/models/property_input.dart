import 'enums.dart';
import 'property.dart';

/// Model input Admin untuk membuat atau memperbarui properti.
/// Sengaja TIDAK memiliki `viewsCount` / `views_count` agar selaras dengan
/// pembatasan hak kolom pada tabel `properties`.
class PropertyInput {
  const PropertyInput({
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
    this.availabilityStatus = AvailabilityStatus.available,
    this.isPublished = true,
  });

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
  final bool isPublished;

  factory PropertyInput.fromProperty(Property property) {
    return PropertyInput(
      propertyCategoryId: property.propertyCategoryId,
      locationId: property.locationId,
      title: property.title,
      slug: property.slug,
      price: property.price,
      buildingArea: property.buildingArea,
      landArea: property.landArea,
      bedrooms: property.bedrooms,
      bathrooms: property.bathrooms,
      floors: property.floors,
      electricity: property.electricity,
      certificateType: property.certificateType,
      description: property.description,
      addressDetail: property.addressDetail,
      latitude: property.latitude,
      longitude: property.longitude,
      googleMapsUrl: property.googleMapsUrl,
      availabilityStatus: property.availabilityStatus,
      isPublished: property.isPublished,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
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
      'is_published': isPublished,
    };
  }
}

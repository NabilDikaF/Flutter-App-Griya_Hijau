/// Model foto properti (`property_images`).
/// `imagePath` menyimpan path relatif di bucket Storage `property-images`.
class PropertyImage {
  const PropertyImage({
    required this.id,
    required this.propertyId,
    required this.imagePath,
    required this.isPrimary,
    required this.sortOrder,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final int propertyId;
  final String imagePath;
  final bool isPrimary;
  final int sortOrder;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory PropertyImage.fromJson(Map<String, dynamic> json) {
    return PropertyImage(
      id: (json['id'] as num).toInt(),
      propertyId: (json['property_id'] as num).toInt(),
      imagePath: json['image_path'] as String,
      isPrimary: json['is_primary'] as bool? ?? false,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'property_id': propertyId,
      'image_path': imagePath,
      'is_primary': isPrimary,
      'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt!.toUtc().toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toUtc().toIso8601String(),
    };
  }
}

DateTime? _parseDateTime(Object? raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw;
  if (raw is String && raw.isNotEmpty) return DateTime.parse(raw);
  return null;
}

/// Model daerah/lokasi properti (`locations`).
class Location {
  const Location({
    required this.id,
    required this.city,
    required this.district,
    required this.slug,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String city;
  final String district;
  final String slug;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get displayName => '$district, $city';

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      id: (json['id'] as num).toInt(),
      city: json['city'] as String,
      district: json['district'] as String,
      slug: json['slug'] as String,
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'city': city,
      'district': district,
      'slug': slug,
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

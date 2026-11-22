/// Model log kunjungan properti (`property_view_logs`, baca admin).
class PropertyViewLog {
  const PropertyViewLog({
    required this.id,
    required this.propertyId,
    this.ipAddress,
    this.userAgent,
    required this.viewedAt,
  });

  final int id;
  final int propertyId;
  final String? ipAddress;
  final String? userAgent;
  final DateTime viewedAt;

  factory PropertyViewLog.fromJson(Map<String, dynamic> json) {
    return PropertyViewLog(
      id: (json['id'] as num).toInt(),
      propertyId: (json['property_id'] as num).toInt(),
      ipAddress: json['ip_address'] as String?,
      userAgent: json['user_agent'] as String?,
      viewedAt: DateTime.parse(json['viewed_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'property_id': propertyId,
      'ip_address': ipAddress,
      'user_agent': userAgent,
      'viewed_at': viewedAt.toUtc().toIso8601String(),
    };
  }
}

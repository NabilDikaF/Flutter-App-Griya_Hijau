/// Model log pencarian properti (`search_logs`, baca admin).
class SearchLog {
  const SearchLog({
    required this.id,
    this.keyword,
    this.locationId,
    this.propertyCategoryId,
    required this.resultsCount,
    required this.searchedAt,
  });

  final int id;
  final String? keyword;
  final int? locationId;
  final int? propertyCategoryId;
  final int resultsCount;
  final DateTime searchedAt;

  factory SearchLog.fromJson(Map<String, dynamic> json) {
    return SearchLog(
      id: (json['id'] as num).toInt(),
      keyword: json['keyword'] as String?,
      locationId: (json['location_id'] as num?)?.toInt(),
      propertyCategoryId: (json['property_category_id'] as num?)?.toInt(),
      resultsCount: (json['results_count'] as num).toInt(),
      searchedAt: DateTime.parse(json['searched_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'keyword': keyword,
      'location_id': locationId,
      'property_category_id': propertyCategoryId,
      'results_count': resultsCount,
      'searched_at': searchedAt.toUtc().toIso8601String(),
    };
  }
}

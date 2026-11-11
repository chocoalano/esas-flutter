import '../../../../core/utils/json_parsers.dart';

class CompanyPolicy {
  const CompanyPolicy({
    required this.id,
    required this.number,
    required this.title,
    this.category,
    this.currentVersion,
    this.summary,
    this.effectiveDate,
    this.publishedAt,
  });

  factory CompanyPolicy.fromJson(Map<String, dynamic> json) {
    return CompanyPolicy(
      id: asInt(json['id']) ?? 0,
      number: asString(json['number']) ?? '',
      title: asString(json['title']) ?? '',
      category: asString(json['category']),
      currentVersion: asString(json['current_version']),
      summary: asString(json['summary']),
      effectiveDate: asString(json['effective_date']),
      publishedAt: asString(json['published_at']),
    );
  }

  final int id;
  final String number;
  final String title;
  final String? category;
  final String? currentVersion;
  final String? summary;
  final String? effectiveDate;
  final String? publishedAt;
}


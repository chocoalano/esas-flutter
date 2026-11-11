import '../../../../core/utils/json_parsers.dart';

class ItmsKnowledgeArticle {
  const ItmsKnowledgeArticle({
    required this.id,
    required this.title,
    this.summary,
    this.body,
    this.publishedAt,
  });

  factory ItmsKnowledgeArticle.fromJson(Map<String, dynamic> json) {
    return ItmsKnowledgeArticle(
      id: asInt(json['id']) ?? 0,
      title: asString(json['title']) ?? '',
      summary: asString(json['summary']),
      body: asString(json['body']),
      publishedAt: asString(json['published_at']),
    );
  }

  final int id;
  final String title;
  final String? summary;
  final String? body;
  final String? publishedAt;
}


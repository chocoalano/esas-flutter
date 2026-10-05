import 'package:esas/core/utils/json_parsers.dart';
import 'package:esas/features/profile/data/models/company.dart';

class Announcement {
  int? id;
  int? companyId;
  int? userId;
  String? title;
  bool? status;
  String? content;
  DateTime? createdAt;
  DateTime? updatedAt;
  Company? company;

  /// Who published it, by name. The list shows it beside the date.
  String? publishedBy;

  /// One line of the body, sent with list rows.
  ///
  /// [content] is absent from a list and present on a detail — a list of
  /// notices should not carry every notice in full — so a card that wants a
  /// snippet reads this and a screen that wants the notice reads [content].
  String? excerpt;

  Announcement({
    this.id,
    this.companyId,
    this.userId,
    this.title,
    this.status,
    this.content,
    this.createdAt,
    this.updatedAt,
    this.company,
    this.publishedBy,
    this.excerpt,
  });

  /// `content` is absent from the list and present on the detail, which is
  /// deliberate on the server's side: a list of notices should not carry every
  /// notice's body. A null here means "not asked for", not "empty".
  factory Announcement.fromJson(Map<String, dynamic> json) => Announcement(
    id: asInt(json["id"]),
    companyId: asInt(json["company_id"]),
    userId: asInt(json["user_id"]),
    title: asString(json["title"]),
    status: asBool(json["status"]),
    content: asString(json["content"]),
    publishedBy: asString(json["published_by"]),
    excerpt: asString(json["excerpt"]),
    createdAt: asDate(json["created_at"]),
    updatedAt: asDate(json["updated_at"]),
    company: json["company"] is Map
        ? Company.fromJson(asObject(json["company"]))
        : null,
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "company_id": companyId,
    "user_id": userId,
    "title": title,
    "status": status,
    "content": content,
    "created_at": createdAt?.toIso8601String(),
    "updated_at": updatedAt?.toIso8601String(),
    "company": company?.toJson(),
    "published_by": publishedBy,
    "excerpt": excerpt,
  };
}

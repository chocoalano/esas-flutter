import 'package:esas/app/data/Profile/company.m.dart';

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
  });

  factory Announcement.fromJson(Map<String, dynamic> json) => Announcement(
    id: json["id"],
    companyId: json["company_id"],
    userId: json["user_id"],
    title: json["title"],
    status: json["status"],
    content: json["content"],
    createdAt: json["created_at"] == null
        ? null
        : DateTime.parse(json["created_at"]),
    updatedAt: json["updated_at"] == null
        ? null
        : DateTime.parse(json["updated_at"]),
    company: json["company"] == null ? null : Company.fromJson(json["company"]),
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
  };
}

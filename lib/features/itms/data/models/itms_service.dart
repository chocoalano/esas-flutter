import '../../../../core/utils/json_parsers.dart';

class ItmsService {
  const ItmsService({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    this.category,
  });

  factory ItmsService.fromJson(Map<String, dynamic> json) {
    return ItmsService(
      id: asInt(json['id']) ?? 0,
      code: asString(json['code']) ?? '',
      name: asString(json['name']) ?? '',
      description: asString(json['description']),
      category: asString(json['category']),
    );
  }

  final int id;
  final String code;
  final String name;
  final String? description;
  final String? category;
}


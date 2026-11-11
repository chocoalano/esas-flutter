import '../../../../core/utils/json_parsers.dart';

class AiChatMessage {
  const AiChatMessage({
    required this.id,
    required this.role,
    required this.text,
    this.createdAt,
    this.sources = const [],
  });

  factory AiChatMessage.fromJson(Map<String, dynamic> json) {
    return AiChatMessage(
      id: asString(json['id']) ?? asString(json['message_id']) ?? '',
      role: asString(json['role']) ?? 'assistant',
      text: asString(json['text']) ?? '',
      createdAt: asString(json['created_at']),
      sources: asList(json['sources']).map((s) => asObject(s)).toList(),
    );
  }

  final String id;
  final String role;
  final String text;
  final String? createdAt;
  final List<Map<String, dynamic>> sources;

  bool get isUser => role.toLowerCase() == 'user';
  bool get isAssistant => !isUser;
}

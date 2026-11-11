import '../../../../core/utils/json_parsers.dart';
import 'ai_chat_message.dart';

class AiChatConversation {
  const AiChatConversation({
    required this.id,
    required this.title,
    this.createdAt,
    this.messages = const [],
  });

  factory AiChatConversation.fromJson(Map<String, dynamic> json) {
    return AiChatConversation(
      id: asString(json['id']) ?? asString(json['uuid']) ?? '',
      title:
          asString(json['title']) ?? asString(json['summary']) ?? 'Percakapan',
      createdAt: asString(json['created_at']),
      messages: asList(
        json['messages'],
      ).map((m) => AiChatMessage.fromJson(asObject(m))).toList(),
    );
  }

  final String id;
  final String title;
  final String? createdAt;
  final List<AiChatMessage> messages;
}

import '../../../../core/utils/json_parsers.dart';
import 'ai_chat_message.dart';

/// One chat turn's answer, as the server sends it: `ChatReply::toArray()`.
///
/// Its own type because it is not a message (AI-01). It names the
/// conversation the turn belongs to — `conversation_id` — and the message it
/// produced — `message_id` — and has no `id` at all. Reading it as a message
/// took the message id for the conversation id, and every second question went
/// to `/conversations/{a message id}/messages` and was a 404.
class AiChatReply {
  const AiChatReply({
    required this.conversationId,
    required this.message,
    required this.ok,
    this.error,
  });

  factory AiChatReply.fromJson(Map<String, dynamic> json) {
    final messageId = asString(json['message_id']) ?? '';

    return AiChatReply(
      conversationId: asString(json['conversation_id']),
      ok: asBool(json['ok']) ?? true,
      error: asString(json['error']),
      message: AiChatMessage.fromJson({
        ...json,
        'id': messageId,
        'role': 'assistant',
      }),
    );
  }

  /// The conversation this turn belongs to. Present on a failed turn too: a
  /// model that could not answer does not end the conversation.
  final String? conversationId;

  /// What to show. On a failed turn, the server's own sentence about it.
  final AiChatMessage message;

  final bool ok;

  /// A code from the server's closed set when [ok] is false.
  final String? error;
}

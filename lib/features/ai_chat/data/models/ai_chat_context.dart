import '../../../../core/utils/json_parsers.dart';

class AiChatContext {
  const AiChatContext({
    required this.assistantName,
    required this.opener,
    required this.suggestions,
    required this.maxMessageLength,
  });

  factory AiChatContext.fromJson(Map<String, dynamic> json) {
    return AiChatContext(
      assistantName: asString(json['assistant_name']) ?? 'ESAS Assistant',
      opener:
          asString(json['opener']) ??
          'Halo! Ada yang bisa saya bantu hari ini?',
      suggestions: asList(json['suggestions']).map((s) => '$s').toList(),
      maxMessageLength: asInt(json['max_message_length']) ?? 2000,
    );
  }

  final String assistantName;
  final String opener;
  final List<String> suggestions;
  final int maxMessageLength;
}

import 'package:esas/features/ai_chat/data/models/ai_chat_context.dart';
import 'package:esas/features/ai_chat/data/models/ai_chat_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AI Chat models test', () {
    test('parses ai chat context json correctly', () {
      final json = {
        'assistant_name': 'ESAS Copilot',
        'opener': 'Selamat pagi Budi, ada yang bisa dibantu?',
        'suggestions': ['Berapa sisa cuti saya?', 'Jadwal shift minggu ini'],
        'max_message_length': 1500,
      };

      final ctx = AiChatContext.fromJson(json);
      expect(ctx.assistantName, 'ESAS Copilot');
      expect(ctx.opener, 'Selamat pagi Budi, ada yang bisa dibantu?');
      expect(ctx.suggestions.length, 2);
      expect(ctx.suggestions.first, 'Berapa sisa cuti saya?');
      expect(ctx.maxMessageLength, 1500);
    });

    test('parses ai chat message json correctly and distinguishes roles', () {
      final userMsg = AiChatMessage.fromJson({
        'id': 'msg-1',
        'role': 'user',
        'text': 'Halo',
      });
      expect(userMsg.isUser, isTrue);
      expect(userMsg.isAssistant, isFalse);

      final assistantMsg = AiChatMessage.fromJson({
        'id': 'msg-2',
        'role': 'assistant',
        'text': 'Halo! Saya asisten ESAS.',
        'sources': [
          {'title': 'Buku Panduan SDM'}
        ],
      });
      expect(assistantMsg.isAssistant, isTrue);
      expect(assistantMsg.isUser, isFalse);
      expect(assistantMsg.sources.length, 1);
    });
  });
}


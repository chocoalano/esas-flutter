import 'dart:async';

import 'package:esas/core/config/api_routes.dart';
import 'package:esas/core/network/api_client.dart';
import 'package:esas/core/network/api_exception.dart';
import 'package:esas/features/ai_chat/data/repositories/ai_chat_repository.dart';
import 'package:esas/features/ai_chat/data/services/ai_chat_api_service.dart';
import 'package:esas/core/theme/app_theme.dart';
import 'package:esas/features/ai_chat/presentation/controllers/ai_chat_controller.dart';
import 'package:esas/features/ai_chat/presentation/views/ai_chat_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

class _Api extends Mock implements AiChatApiService {}

class _Client extends Mock implements ApiClient {}

/// What `POST /ai/chat/conversations` and `.../messages` answer:
/// `ChatReply::toArray()`. There is no `id`.
Map<String, dynamic> reply({
  String conversation = 'conv-1',
  String message = 'msg-1',
  bool ok = true,
  String text = 'Sisa cuti Anda 8 hari.',
}) => {
  'conversation_id': conversation,
  'message_id': message,
  'ok': ok,
  'text': text,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Api api;
  late AiChatController controller;

  setUp(() {
    Get.testMode = true;
    api = _Api();
    when(
      () => api.context(),
    ).thenAnswer((_) async => {'opener': 'Halo', 'suggestions': <String>[]});
    controller = AiChatController(repository: AiChatRepository(api));
  });

  tearDown(Get.reset);

  void startAnswers(Future<Map<String, dynamic>> Function() answer) => when(
    () => api.startConversation(
      any(),
      idempotencyKey: any(named: 'idempotencyKey'),
    ),
  ).thenAnswer((_) => answer());

  void messageAnswers(Future<Map<String, dynamic>> Function() answer) => when(
    () => api.sendMessage(
      any(),
      any(),
      idempotencyKey: any(named: 'idempotencyKey'),
    ),
  ).thenAnswer((_) => answer());

  // AI-01. The conversation id was read from `message_id`, so every second
  // message went to /conversations/{a message id}/messages and was a 404.
  test(
    'the second message continues the conversation, not the message',
    () async {
      startAnswers(() async => reply());
      messageAnswers(() async => reply(message: 'msg-2', text: 'Ya.'));

      await controller.sendUserMessage('Sisa cuti saya?');
      await controller.sendUserMessage('Benarkah?');

      verify(
        () => api.sendMessage(
          'conv-1',
          'Benarkah?',
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).called(1);
    },
  );

  test('a turn the model failed still belongs to its conversation', () async {
    startAnswers(
      () async => reply(ok: false, text: 'Asisten belum dapat menjawab.'),
    );
    messageAnswers(() async => reply(message: 'msg-2'));

    await controller.sendUserMessage('Halo');
    await controller.sendUserMessage('Lagi');

    expect(controller.messages.last.text, 'Sisa cuti Anda 8 hari.');
    verify(
      () => api.sendMessage(
        'conv-1',
        'Lagi',
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    ).called(1);
  });

  // AI-02. A reply that does not arrive in time may still have been written:
  // on the first message, with a conversation the app never learnt the id of.
  // Trying again must be the SAME request, so the server replays its answer
  // instead of opening a second conversation and answering twice.
  group('a message whose reply never arrived', () {
    // UAT review H9. "Kirim ulang" pressed while the first request was still
    // being answered: the server says 409 idempotency_in_progress. That has
    // a status, so it read as a final refusal and the offer vanished — and
    // asking again by hand paid for a second answer under a new key.
    test('a request still in progress can be asked for again', () async {
      startAnswers(
        () async => throw const ApiException(
          'Permintaan sebelumnya masih diproses.',
          status: 409,
          code: 'idempotency_in_progress',
        ),
      );

      await controller.sendUserMessage('Sisa cuti saya?');

      expect(controller.canRetry.value, isTrue);
    });

    test('is offered again, and again means the same request', () async {
      var attempt = 0;
      startAnswers(() async {
        attempt++;
        if (attempt == 1) {
          throw const ApiException('Koneksi terlalu lama.', code: 'timeout');
        }
        return reply();
      });

      await controller.sendUserMessage('Sisa cuti saya?');
      expect(controller.canRetry.value, isTrue);

      await controller.retryLastMessage();

      final keys = verify(
        () => api.startConversation(
          'Sisa cuti saya?',
          idempotencyKey: captureAny(named: 'idempotencyKey'),
        ),
      ).captured;
      expect(keys, hasLength(2));
      expect(keys.first, isNotNull);
      expect(keys.first, keys.last);
      expect(controller.canRetry.value, isFalse);
      // One question on screen, not two.
      expect(
        controller.messages.where((m) => m.text == 'Sisa cuti saya?'),
        hasLength(1),
      );
    });

    test('a new message gets a new request identity', () async {
      startAnswers(() async => reply());
      messageAnswers(() async => reply(message: 'msg-2'));

      await controller.sendUserMessage('Satu');
      await controller.sendUserMessage('Dua');

      final first = verify(
        () => api.startConversation(
          any(),
          idempotencyKey: captureAny(named: 'idempotencyKey'),
        ),
      ).captured.single;
      final second = verify(
        () => api.sendMessage(
          any(),
          any(),
          idempotencyKey: captureAny(named: 'idempotencyKey'),
        ),
      ).captured.single;
      expect(first, isNot(second));
    });
  });

  // AI-03. The kill switch answers 503 `{ok, error, text}` with no `message`,
  // so the person saw a generic server error instead of the server's sentence.
  test('a disabled assistant says so in the server\'s words', () async {
    startAnswers(
      () async => throw const ApiException(
        'Kesalahan server internal. Coba lagi nanti.',
        status: 503,
        body: {
          'ok': false,
          'error': 'configuration_error',
          'text': 'Asisten AI sedang dinonaktifkan untuk workspace ini.',
        },
      ),
    );

    await controller.sendUserMessage('Halo');

    expect(
      controller.messages.last.text,
      contains('Asisten AI sedang dinonaktifkan'),
    );
    expect(controller.canRetry.value, isFalse);
  });

  test(
    'the request carries its key and waits as long as the model may',
    () async {
      final client = _Client();
      when(
        () => client.postObject(
          any(),
          any(),
          headers: any(named: 'headers'),
          awaitsModel: any(named: 'awaitsModel'),
        ),
      ).thenAnswer((_) async => reply());

      await AiChatApiService(
        client,
      ).startConversation('Halo', idempotencyKey: 'k-1');

      final captured =
          verify(
                () => client.postObject(
                  ApiRoutes.aiChatConversations,
                  any(),
                  headers: captureAny(named: 'headers'),
                  awaitsModel: true,
                ),
              ).captured.single
              as Map<String, String>;
      expect(captured['Idempotency-Key'], 'k-1');
    },
  );

  test('a send while one is in flight is ignored', () async {
    final pending = Completer<Map<String, dynamic>>();
    startAnswers(() => pending.future);

    unawaited(controller.sendUserMessage('Satu'));
    await controller.sendUserMessage('Dua');
    pending.complete(reply());
    await Future<void>.delayed(Duration.zero);

    verify(
      () => api.startConversation(
        any(),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    ).called(1);
  });

  testWidgets('the screen offers to send it again', (tester) async {
    var attempt = 0;
    startAnswers(() async {
      attempt++;
      if (attempt == 1) {
        throw const ApiException('Koneksi terlalu lama.', code: 'timeout');
      }
      return reply();
    });
    Get.put(controller);

    await tester.pumpWidget(
      GetMaterialApp(theme: AppTheme.lightTheme, home: const AiChatView()),
    );
    await tester.pumpAndSettle();

    await controller.sendUserMessage('Sisa cuti saya?');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Kirim ulang'));
    await tester.pumpAndSettle();

    expect(find.text('Kirim ulang'), findsNothing);
    expect(find.text('Sisa cuti Anda 8 hari.'), findsOneWidget);
  });
}

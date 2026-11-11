import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/idempotency_key.dart';
import '../../../../core/utils/json_parsers.dart';
import '../../data/models/ai_chat_context.dart';
import '../../data/models/ai_chat_message.dart';
import '../../data/repositories/ai_chat_repository.dart';

class AiChatController extends GetxController {
  AiChatController({required AiChatRepository repository})
    : _repository = repository;

  final AiChatRepository _repository;

  final textController = TextEditingController();
  final scrollController = ScrollController();

  final isLoading = true.obs;
  final isSending = false.obs;
  final Rxn<ApiException> error = Rxn<ApiException>();

  final Rxn<AiChatContext> chatContext = Rxn<AiChatContext>();
  final RxList<AiChatMessage> messages = <AiChatMessage>[].obs;
  final RxnString activeConversationId = RxnString();

  @override
  void onInit() {
    super.onInit();
    loadContext();
  }

  @override
  void onClose() {
    textController.dispose();
    scrollController.dispose();
    super.onClose();
  }

  Future<void> loadContext() async {
    isLoading.value = true;
    error.value = null;

    try {
      final ctx = await _repository.context();
      chatContext.value = ctx;
      // Add welcome message from assistant
      messages.add(
        AiChatMessage(id: 'welcome', role: 'assistant', text: ctx.opener),
      );
    } on ApiException catch (e) {
      error.value = e;
    } catch (e) {
      error.value = ApiException(e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> sendUserMessage([String? presetText]) async {
    final text = (presetText ?? textController.text).trim();
    if (text.isEmpty || isSending.value) return;

    if (presetText == null) {
      textController.clear();
    }

    // A new question replaces any offer to resend the last one.
    _clearRetryOffer();

    messages.add(
      AiChatMessage(
        id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
        role: 'user',
        text: text,
        createdAt: DateTime.now().toIso8601String(),
      ),
    );
    _scrollToBottom();

    // One identity per question, kept for as long as the question might be
    // sent again (AI-02).
    await _send(text, IdempotencyKey.mint());
  }

  /// Whether the last question's answer never arrived and may be asked again.
  final RxBool canRetry = false.obs;

  _PendingTurn? _pending;

  /// Ask the last question again, as the same request.
  ///
  /// A reply that did not arrive may still have been written — on the first
  /// question, together with a conversation the app never learnt the id of.
  /// The same key makes the server replay that answer rather than open a
  /// second conversation and answer twice.
  Future<void> retryLastMessage() async {
    final pending = _pending;
    if (pending == null || isSending.value) return;

    messages.removeWhere((m) => m.id == pending.errorId);
    _clearRetryOffer();

    await _send(pending.text, pending.key);
  }

  Future<void> _send(String text, String key) async {
    isSending.value = true;

    try {
      final conversationId = activeConversationId.value;
      final reply = conversationId == null
          ? await _repository.startConversation(text, idempotencyKey: key)
          : await _repository.sendMessage(
              conversationId,
              text,
              idempotencyKey: key,
            );

      // The conversation, not the message (AI-01). Kept on a failed turn too:
      // a model that could not answer does not end the conversation.
      final continued = reply.conversationId;
      if (continued != null && continued.isNotEmpty) {
        activeConversationId.value = continued;
      }

      messages.add(reply.message);
    } on ApiException catch (e) {
      final errorId = 'err_${DateTime.now().microsecondsSinceEpoch}';

      messages.add(
        AiChatMessage(id: errorId, role: 'assistant', text: _failureText(e)),
      );

      // Only an answer that may exist is worth asking for again as the same
      // request. A refusal with a status is the server's final word.
      //
      // 409 idempotency_in_progress is not a final word either (UAT review
      // H9): the first request is still being answered, and asking again
      // under the same key collects that answer rather than paying for one.
      if (e.isTransportFailure || e.code == 'idempotency_in_progress') {
        _pending = _PendingTurn(text: text, key: key, errorId: errorId);
        canRetry.value = true;
      }
    } catch (_) {
      messages.add(
        AiChatMessage(
          id: 'err_${DateTime.now().microsecondsSinceEpoch}',
          role: 'assistant',
          text: 'Maaf, pesan belum dapat diproses. Coba lagi beberapa saat.',
        ),
      );
    } finally {
      isSending.value = false;
      _scrollToBottom();
    }
  }

  void _clearRetryOffer() {
    _pending = null;
    canRetry.value = false;
  }

  /// The server's own sentence when it sent one (AI-03).
  ///
  /// The assistant's refusals — switched off, not rolled out to this
  /// workspace — answer `{ok, error, text}` with no `message`, so the generic
  /// status line used to replace a sentence written for exactly this case.
  static String _failureText(ApiException error) {
    final text = asString(error.body['text']);

    if (text != null && text.isNotEmpty) return text;

    return 'Maaf, terjadi kendala: ${error.message}';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }
}

class _PendingTurn {
  const _PendingTurn({
    required this.text,
    required this.key,
    required this.errorId,
  });

  final String text;
  final String key;
  final String errorId;
}

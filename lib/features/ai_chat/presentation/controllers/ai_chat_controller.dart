import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/network/api_exception.dart';
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
        AiChatMessage(
          id: 'welcome',
          role: 'assistant',
          text: ctx.opener,
        ),
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

    // Append user message locally
    final userMsg = AiChatMessage(
      id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
      role: 'user',
      text: text,
      createdAt: DateTime.now().toIso8601String(),
    );
    messages.add(userMsg);
    _scrollToBottom();

    isSending.value = true;

    try {
      final AiChatMessage reply;
      if (activeConversationId.value == null) {
        reply = await _repository.startConversation(text);
        if (reply.id.isNotEmpty) {
          activeConversationId.value = reply.id;
        }
      } else {
        reply = await _repository.sendMessage(activeConversationId.value!, text);
      }

      messages.add(reply);
      _scrollToBottom();
    } on ApiException catch (e) {
      messages.add(
        AiChatMessage(
          id: 'err_${DateTime.now().millisecondsSinceEpoch}',
          role: 'assistant',
          text: 'Maaf, terjadi kendala: ${e.message}',
        ),
      );
      _scrollToBottom();
    } catch (e) {
      messages.add(
        AiChatMessage(
          id: 'err_${DateTime.now().millisecondsSinceEpoch}',
          role: 'assistant',
          text: 'Maaf, pesan belum dapat diproses. Coba lagi beberapa saat.',
        ),
      );
      _scrollToBottom();
    } finally {
      isSending.value = false;
    }
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


import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_palette.dart';
import '../../data/models/ai_chat_message.dart';
import '../controllers/ai_chat_controller.dart';

class AiChatView extends GetView<AiChatController> {
  const AiChatView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;

    return Scaffold(
      appBar: AppBar(
        title: Obx(() {
          final title =
              controller.chatContext.value?.assistantName ?? 'ESAS Copilot';
          return Text(title);
        }),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Obx(() {
                if (controller.isLoading.value) {
                  return const Center(
                    child: CircularProgressIndicator.adaptive(),
                  );
                }

                if (controller.error.value != null &&
                    controller.messages.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: palette.danger.foreground,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            controller.error.value!.message,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          ElevatedButton(
                            onPressed: controller.loadContext,
                            child: const Text('Coba Lagi'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView(
                  controller: controller.scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.md,
                  ),
                  children: [
                    for (final msg in controller.messages)
                      _MessageBubble(message: msg),
                    // The answer may have been written even though it never
                    // arrived; sending it again is the same request (AI-02).
                    if (controller.canRetry.value &&
                        !controller.isSending.value)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: controller.retryLastMessage,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Kirim ulang'),
                        ),
                      ),
                    if (controller.isSending.value)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: palette.surfaceSubtle,
                                borderRadius: AppRadii.lgAll,
                                border: Border.all(color: palette.borderSubtle),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Text(
                                    'Mengetik...',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: palette.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              }),
            ),

            // Suggestions bar
            Obx(() {
              final suggestions =
                  controller.chatContext.value?.suggestions ?? [];
              if (suggestions.isEmpty || controller.isSending.value) {
                return const SizedBox.shrink();
              }

              return Container(
                height: 40,
                margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    itemCount: suggestions.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: AppSpacing.xs),
                    itemBuilder: (context, index) {
                      final suggestion = suggestions[index];
                      return ActionChip(
                        label: Text(suggestion),
                        labelStyle: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                        backgroundColor: palette.brandSubtle,
                        side: BorderSide(color: palette.borderSubtle),
                        onPressed: () => controller.sendUserMessage(suggestion),
                      );
                    },
                  ),
              );
            }),

            // Input bar
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(top: BorderSide(color: palette.borderSubtle)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller.textController,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Tanyakan sesuatu pada asisten...',
                        hintStyle: theme.textTheme.bodyMedium?.copyWith(
                          color: palette.textMuted,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: AppRadii.xlAll,
                          borderSide: BorderSide(color: palette.borderSubtle),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: AppRadii.xlAll,
                          borderSide: BorderSide(color: palette.borderSubtle),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: AppRadii.xlAll,
                          borderSide: BorderSide(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      onSubmitted: (_) => controller.sendUserMessage(),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Obx(
                    () => IconButton.filled(
                      onPressed: controller.isSending.value
                          ? null
                          : () => controller.sendUserMessage(),
                      icon: const Icon(Icons.send_rounded),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final AiChatMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: palette.brandSubtle,
                borderRadius: AppRadii.mdAll,
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.auto_awesome,
                size: 18,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser
                    ? theme.colorScheme.primary
                    : palette.surfaceSubtle,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: isUser ? null : Border.all(color: palette.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: isUser
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Text(
                    message.text,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isUser
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  if (message.sources.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.tight),
                    Wrap(
                      spacing: 4,
                      children: [
                        for (final src in message.sources)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: palette.brandSubtle,
                              borderRadius: AppRadii.smAll,
                            ),
                            child: Text(
                              'Sumber: ${src['title'] ?? 'Dokumen'}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontSize: 10,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isUser) const SizedBox(width: AppSpacing.sm),
        ],
      ),
    );
  }
}

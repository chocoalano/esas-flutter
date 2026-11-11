import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/ui/components/app_card.dart';
import '../../data/models/approval_task.dart';
import '../controllers/unified_inbox_controller.dart';

class UnifiedInboxView extends GetView<UnifiedInboxController> {
  const UnifiedInboxView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kotak Masuk Persetujuan'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Filter chips
            Obx(
              () => Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    _filterChip('all', 'Semua (${controller.tasks.length})', theme, palette),
                    const SizedBox(width: AppSpacing.xs),
                    _filterChip('hrms', 'HRMS', theme, palette),
                    const SizedBox(width: AppSpacing.xs),
                    _filterChip('gams', 'GAMS', theme, palette),
                    const SizedBox(width: AppSpacing.xs),
                    _filterChip('itms', 'ITMS', theme, palette),
                  ],
                ),
              ),
            ),

            Expanded(
              child: Obx(() {
                if (controller.isLoading.value) {
                  return const Center(child: CircularProgressIndicator.adaptive());
                }

                if (controller.error.value != null) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: palette.danger.foreground),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            controller.error.value!.message,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          ElevatedButton(
                            onPressed: controller.loadTasks,
                            child: const Text('Coba Lagi'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final displayList = controller.filteredTasks;
                if (displayList.isEmpty) {
                  return Center(
                    child: Text(
                      'Tidak ada tugas atau permohonan persetujuan yang menunggu.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(color: palette.textMuted),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: controller.loadTasks,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    itemCount: displayList.length,
                    separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final task = displayList[index];
                      return _TaskCard(
                        task: task,
                        onApprove: () => controller.decideTask(
                          taskId: task.id,
                          decision: 'approved',
                        ),
                        onReject: () => _promptRejection(context, task),
                      );
                    },
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String key, String label, ThemeData theme, AppPalette palette) {
    final isSelected = controller.selectedFilter.value == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      labelStyle: theme.textTheme.labelSmall?.copyWith(
        color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      selectedColor: theme.colorScheme.primary,
      backgroundColor: palette.surfaceSubtle,
      side: BorderSide(color: palette.borderSubtle),
      onSelected: (_) => controller.selectedFilter.value = key,
    );
  }

  void _promptRejection(BuildContext context, ApprovalTask task) {
    final textController = TextEditingController();
    Get.defaultDialog(
      title: 'Tolak Pengajuan',
      content: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            Text('Berikan alasan penolakan untuk "${task.title}":'),
            const SizedBox(height: 8),
            TextField(
              controller: textController,
              decoration: const InputDecoration(
                hintText: 'Alasan penolakan...',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      textConfirm: 'Tolak',
      textCancel: 'Batal',
      confirmTextColor: Colors.white,
      onConfirm: () {
        final reason = textController.text.trim();
        if (reason.isEmpty) {
          Get.snackbar('Validasi', 'Alasan penolakan tidak boleh kosong');
          return;
        }
        Get.back();
        controller.decideTask(
          taskId: task.id,
          decision: 'rejected',
          note: reason,
        );
      },
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.onApprove,
    required this.onReject,
  });

  final ApprovalTask task;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;

    final IconData icon = task.isHrms
        ? Icons.badge_outlined
        : task.isGams
            ? Icons.home_repair_service_outlined
            : Icons.confirmation_number_outlined;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: palette.brandSubtle,
                  borderRadius: AppRadii.smAll,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 14, color: theme.colorScheme.primary),
                    const SizedBox(width: 4),
                    Text(
                      task.domainLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (task.createdAt != null)
                Text(
                  task.createdAt!.split('T').first,
                  style: theme.textTheme.labelSmall?.copyWith(color: palette.textMuted),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            task.title,
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            'Pemohon: ${task.requesterName}${task.requesterNip != null ? ' (${task.requesterNip})' : ''}',
            style: theme.textTheme.bodySmall?.copyWith(color: palette.textMuted),
          ),
          if (task.notes != null && task.notes!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.tight),
            Text(
              task.notes!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: onReject,
                icon: Icon(Icons.close, size: 16, color: palette.danger.foreground),
                label: Text('Tolak', style: TextStyle(color: palette.danger.foreground)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: palette.danger.foreground),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: onApprove,
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Setujui'),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


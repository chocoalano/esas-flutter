import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/ui/components/app_card.dart';
import '../../data/models/overtime_entry.dart';
import '../controllers/overtime_list_controller.dart';

class OvertimeListView extends GetView<OvertimeListController> {
  const OvertimeListView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Lembur'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        ),
      ),
      body: SafeArea(
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
                      onPressed: controller.loadOvertime,
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (controller.items.isEmpty) {
            return Center(
              child: Text(
                'Belum ada riwayat lembur yang tercatat.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: palette.textMuted,
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: controller.loadOvertime,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.lg,
              ),
              itemCount: controller.items.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final item = controller.items[index];
                return _OvertimeCard(item: item);
              },
            ),
          );
        }),
      ),
    );
  }
}

class _OvertimeCard extends StatelessWidget {
  const _OvertimeCard({required this.item});

  final OvertimeEntry item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;

    final AppTone tone = item.isApproved
        ? palette.success
        : item.isRejected
        ? palette.danger
        : palette.warning;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.date,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: tone.background,
                  borderRadius: AppRadii.mdAll,
                  border: Border.all(color: tone.border),
                ),
                child: Text(
                  item.statusLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: tone.foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Text(
                'Disetujui: ${item.hoursApproved} jam',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: palette.textMuted,
                ),
              ),
              if (item.hoursWorked != null) ...[
                Text(
                  ' • Realisasi: ${item.hoursWorked} jam',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
          if (item.reason != null && item.reason!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.tight),
            Text(item.reason!, style: theme.textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}

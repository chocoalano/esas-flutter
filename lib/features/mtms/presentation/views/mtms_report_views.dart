import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../../core/tenancy/workspace_clock.dart';
import '../../../../core/ui/components/app_badge.dart';
import '../../../../core/ui/components/app_button.dart';
import '../../../../core/ui/components/app_card.dart';
import '../../../../core/ui/components/app_empty_state.dart';
import '../../../../core/ui/components/app_error_state.dart';
import '../../../../core/ui/components/app_inline_notice.dart';
import '../../../../core/ui/components/app_input_decoration.dart';
import '../../../../core/ui/components/app_skeleton.dart';
import '../../../../core/ui/dialogs/app_snackbar.dart';
import '../../data/mtms_reports.dart';
import '../controllers/mtms_report_controllers.dart';
import '../routes/mtms_routes.dart';

AppBadgeTone _tone(String status) => switch (status) {
  'resolved' => AppBadgeTone.success,
  'rejected' || 'cancelled' => AppBadgeTone.danger,
  'duplicate' => AppBadgeTone.warning,
  'wo_linked' || 'approved' || 'triaged' => AppBadgeTone.brand,
  _ => AppBadgeTone.neutral,
};

String? _when(String? iso) {
  final instant = iso == null ? null : DateTime.tryParse(iso);
  if (instant == null) return null;
  final wall = WorkspaceClock.current.wallClock(instant);
  return '${DateFormat('d MMM yyyy, HH:mm', 'id_ID').format(wall)} '
      '${WorkspaceClock.current.abbreviation}';
}

/// The employee's damage reports and what became of them (FUNC-D02).
class MtmsReportListView extends GetView<MtmsReportListController> {
  const MtmsReportListView({super.key});

  Future<void> _report() async {
    final Object? number = await Get.toNamed(MtmsRoutes.reportCreate);
    if (number is String && number.isNotEmpty) {
      showSuccessSnackbar('Laporan $number terkirim.');
      await controller.load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Laporan Kerusakan')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _report,
        icon: const Icon(Icons.add),
        label: const Text('Lapor kerusakan'),
      ),
      body: Obx(() {
        final error = controller.error.value;

        if (controller.isLoading.value && controller.reports.isEmpty) {
          return const AppSkeletonPulse(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: AppSkeleton(height: 220),
            ),
          );
        }
        if (error != null && controller.reports.isEmpty) {
          return AppErrorState(
            title: error.isForbidden
                ? 'Tidak ada akses'
                : 'Gagal memuat laporan',
            message: error.message,
            onRetry: controller.load,
          );
        }
        if (controller.reports.isEmpty) {
          return AppEmptyState(
            icon: Icons.build_outlined,
            title: 'Belum ada laporan',
            message:
                'Laporkan mesin atau peralatan yang rusak; statusnya bisa '
                'Anda pantau di sini.',
            actionLabel: 'Lapor kerusakan',
            onAction: _report,
          );
        }

        return RefreshIndicator(
          onRefresh: controller.load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            children: [
              for (final report in controller.reports)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ReportCard(report: report),
                ),
              if (controller.hasMore.value)
                Center(
                  child: TextButton(
                    onPressed: controller.isLoadingMore.value
                        ? null
                        : controller.loadMore,
                    child: Text(
                      controller.isLoadingMore.value
                          ? 'Memuat…'
                          : 'Muat lebih banyak',
                    ),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report});

  final MtmsReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final equipment = [
      ?report.equipmentName,
      if (report.equipmentTag case final tag? when tag.isNotEmpty) '($tag)',
    ].join(' ');
    final rejection = report.rejectionReason?.trim();

    return Semantics(
      container: true,
      label:
          'Laporan ${report.number}, ${report.statusLabel}'
          '${report.workOrderNumber == null ? '' : ', perintah kerja ${report.workOrderNumber}'}',
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(report.number, style: theme.textTheme.labelMedium),
                AppBadge(label: report.statusLabel, tone: _tone(report.status)),
              ],
            ),
            if (equipment.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                equipment,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 4),
            Text(report.symptom, style: theme.textTheme.bodyMedium),
            if (report.workOrderNumber case final wo?) ...[
              const SizedBox(height: 6),
              Text(
                'Perintah kerja $wo'
                '${report.workOrderStatusLabel == null ? '' : ' • ${report.workOrderStatusLabel}'}',
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (rejection != null && rejection.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Alasan: $rejection', style: theme.textTheme.bodySmall),
            ],
            if (_when(report.createdAt) case final reportedAt?) ...[
              const SizedBox(height: 4),
              Text('Dilaporkan $reportedAt', style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

/// Filing a damage report (FUNC-D02).
class MtmsReportCreateView extends GetView<MtmsReportCreateController> {
  const MtmsReportCreateView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Lapor Kerusakan')),
      body: Obx(() {
        final loadError = controller.loadError.value;

        if (controller.isLoading.value) {
          return const AppSkeletonPulse(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: AppSkeleton(height: 260),
            ),
          );
        }
        if (loadError != null) {
          return AppErrorState(
            title: 'Gagal memuat daftar peralatan',
            message: loadError.message,
            onRetry: controller.loadEquipment,
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            if (controller.equipment.isEmpty)
              const AppInlineNotice(
                tone: AppNoticeTone.warning,
                message:
                    'Belum ada peralatan terdaftar. Hubungi tim maintenance.',
              )
            else
              DropdownButtonFormField<int>(
                initialValue: controller.equipmentId.value,
                isExpanded: true,
                decoration: appInputDecoration(
                  theme,
                  'Peralatan',
                  helperText: 'Pilih mesin atau peralatan yang bermasalah.',
                ),
                items: [
                  for (final item in controller.equipment)
                    DropdownMenuItem(value: item.id, child: Text(item.label)),
                ],
                onChanged: (id) => controller.equipmentId.value = id,
              ),
            const SizedBox(height: 12),
            TextField(
              controller: controller.symptomC,
              minLines: 3,
              maxLines: 6,
              maxLength: MtmsReportCreateController.symptomMax,
              decoration: appInputDecoration(
                theme,
                'Gejala kerusakan',
                helperText: 'Apa yang terjadi, sejak kapan, dan dampaknya.',
              ),
            ),
            const SizedBox(height: 4),
            DropdownButtonFormField<String>(
              initialValue: controller.severity.value,
              decoration: appInputDecoration(theme, 'Tingkat keparahan'),
              items: const [
                DropdownMenuItem(value: 'low', child: Text('Rendah')),
                DropdownMenuItem(value: 'normal', child: Text('Normal')),
                DropdownMenuItem(value: 'high', child: Text('Tinggi')),
                DropdownMenuItem(value: 'critical', child: Text('Kritis')),
              ],
              onChanged: (value) =>
                  controller.severity.value = value ?? 'normal',
            ),
            if (controller.error.value case final message?) ...[
              const SizedBox(height: 12),
              AppInlineNotice(message: message),
            ],
            const SizedBox(height: 16),
            AppButton(
              label: 'Kirim laporan',
              busy: controller.isSubmitting.value,
              onPressed:
                  controller.isSubmitting.value || controller.equipment.isEmpty
                  ? null
                  : () async {
                      final number = await controller.submit();
                      if (number != null) Get.back(result: number);
                    },
            ),
          ],
        );
      }),
    );
  }
}

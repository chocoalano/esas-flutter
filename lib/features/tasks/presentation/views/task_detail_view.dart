import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../../core/ui/components/app_badge.dart';
import '../../../../core/ui/components/app_button.dart';
import '../../../../core/ui/components/app_card.dart';
import '../../../../core/ui/components/app_error_state.dart';
import '../../../../core/ui/components/app_inline_notice.dart';
import '../../../../core/ui/components/app_skeleton.dart';
import '../../../../core/ui/dialogs/app_snackbar.dart';
import '../../data/models/field_task.dart';
import '../../data/models/task_action.dart';
import '../controllers/task_detail_controller.dart';
import 'my_tasks_view.dart';

/// One task: what and where, who assigned it, its steps, its history, and
/// exactly the actions the server allows the worker right now.
class TaskDetailView extends GetView<TaskDetailController> {
  const TaskDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(controller.domain.label)),
      body: Obx(() {
        final detail = controller.detail.value;
        final error = controller.error.value;

        if (controller.isLoading.value && detail == null) {
          return const AppSkeletonPulse(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: AppSkeleton(height: 220),
            ),
          );
        }

        if (error != null && detail == null || error?.status == 404) {
          return AppErrorState(
            title: error!.status == 404
                ? 'Tugas tidak tersedia'
                : error.isForbidden
                ? 'Tidak ada akses'
                : 'Gagal memuat tugas',
            message: error.status == 404
                ? 'Tugas ini tidak lagi ditugaskan kepada Anda.'
                : error.message,
            onRetry: error.status == 404 ? null : controller.load,
          );
        }

        if (detail == null) return const SizedBox.shrink();

        return RefreshIndicator(
          onRefresh: controller.load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _Header(detail: detail),
              if (controller.notice.value != null) ...[
                const SizedBox(height: 12),
                AppInlineNotice(
                  tone: controller.noticeIsConflict.value
                      ? AppNoticeTone.warning
                      : AppNoticeTone.danger,
                  message: controller.notice.value!,
                ),
              ],
              if (detail.steps.isNotEmpty) ...[
                const SizedBox(height: 16),
                _Steps(controller: controller, detail: detail),
              ],
              if (detail.labor.isNotEmpty) ...[
                const SizedBox(height: 16),
                _Labor(detail: detail),
              ],
              if (detail.report != null) ...[
                const SizedBox(height: 16),
                _Section(
                  title: 'Laporan pekerjaan',
                  child: Text(detail.report!),
                ),
              ],
              if (detail.verifiedAt != null) ...[
                const SizedBox(height: 16),
                _Section(
                  title: 'Hasil verifikasi',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Diverifikasi ${_format(detail.verifiedAt!)}'),
                      if (detail.verificationNote != null)
                        Text(detail.verificationNote!),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _History(detail: detail),
            ],
          ),
        );
      }),
      bottomNavigationBar: Obx(() {
        final actions = controller.actions;
        if (actions.isEmpty) return const SizedBox.shrink();

        return SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final action in actions)
                AppButton(
                  label: action.label,
                  busy: controller.submitting.value == action.key,
                  variant: action.isCompletion
                      ? AppButtonVariant.filled
                      : AppButtonVariant.outlined,
                  onPressed: controller.submitting.value != null
                      ? null
                      : () => _perform(context, action),
                ),
            ],
          ),
        );
      }),
    );
  }

  Future<void> _perform(BuildContext context, TaskAction action) async {
    String? input;
    if (action.needsInput) {
      input = await _askInput(context, action);
      if (input == null) return;
    }

    final done = await controller.run(action, input: input);
    if (done) {
      showSuccessSnackbar(
        action.isCompletion
            ? 'Laporan terkirim. Pekerjaan menunggu verifikasi.'
            : 'Tugas diperbarui.',
      );
    }
  }

  Future<String?> _askInput(BuildContext context, TaskAction action) {
    final text = TextEditingController();

    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.of(sheetContext).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              action.label,
              style: Theme.of(sheetContext).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: text,
              autofocus: true,
              minLines: 3,
              maxLines: 6,
              decoration: InputDecoration(
                labelText: action.inputLabel,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: text,
              builder: (_, value, _) => AppButton(
                label: 'Kirim',
                onPressed: value.text.trim().isEmpty
                    ? null
                    : () => Navigator.of(sheetContext).pop(value.text.trim()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.detail});

  final FieldTaskDetail detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final task = detail.task;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(task.number, style: theme.textTheme.labelMedium),
              AppBadge(label: task.statusLabel, tone: statusTone(task.status)),
            ],
          ),
          const SizedBox(height: 8),
          Text(task.title, style: theme.textTheme.titleMedium),
          if (detail.description != null) ...[
            const SizedBox(height: 8),
            Text(detail.description!),
          ],
          const SizedBox(height: 12),
          if (task.location != null)
            _Line(
              // ITMS sends the service here, not a place (UX-D13).
              task.domain == TaskDomain.itms ? 'Layanan' : 'Lokasi',
              task.location!,
            ),
          if (detail.equipment != null) _Line('Peralatan', detail.equipment!),
          if (detail.safetyClass != null)
            _Line('Keselamatan', detail.safetyClass!),
          if (detail.requestNumber != null)
            _Line('Laporan kerusakan', detail.requestNumber!),
          if (task.reviewHint != null)
            _Line('Tahap berikutnya', task.reviewHint!),
          if (task.priorityLabel != null)
            _Line('Prioritas', task.priorityLabel!),
          if (detail.requesterName != null)
            _Line('Pemohon', detail.requesterName!),
          if (detail.assignedBy != null)
            _Line('Ditugaskan oleh', detail.assignedBy!),
          if (detail.assignedAt != null)
            _Line('Ditugaskan', _format(detail.assignedAt!)),
          if (task.scheduledAt != null)
            _Line(task.dateLabel, _format(task.scheduledAt!)),
        ],
      ),
    );
  }
}

class _Steps extends StatelessWidget {
  const _Steps({required this.controller, required this.detail});

  final TaskDetailController controller;
  final FieldTaskDetail detail;

  @override
  Widget build(BuildContext context) {
    final complete = TaskAction(
      key: 'complete_task',
      label: 'Selesai',
      path: '',
    );

    return _Section(
      title: detail.task.domain == TaskDomain.mtms
          ? 'Langkah kerja'
          : 'Checklist',
      child: Column(
        children: [
          for (final step in detail.steps)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                step.isDone
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
              ),
              title: Text(step.description),
              subtitle: step.isMandatory ? const Text('Wajib') : null,
              trailing: !step.isDone && controller.canCompleteSteps
                  ? Obx(
                      () => AppButton(
                        label: 'Selesai',
                        variant: AppButtonVariant.text,
                        expand: false,
                        busy: controller.submitting.value == 'step:${step.id}',
                        onPressed: controller.submitting.value != null
                            ? null
                            : () => controller.run(complete, stepId: step.id),
                      ),
                    )
                  : null,
            ),
        ],
      ),
    );
  }
}

class _Labor extends StatelessWidget {
  const _Labor({required this.detail});

  final FieldTaskDetail detail;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Jam kerja saya',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final interval in detail.labor)
            _Line(
              interval.startedAt == null ? '-' : _format(interval.startedAt!),
              interval.isOpen
                  ? 'sedang berjalan'
                  : 's.d. ${_format(interval.endedAt!)}',
            ),
        ],
      ),
    );
  }
}

class _History extends StatelessWidget {
  const _History({required this.detail});

  final FieldTaskDetail detail;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Riwayat status',
      child: detail.history.isEmpty
          ? const Text('Belum ada riwayat.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final step in detail.history.reversed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step.label,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        if (step.at != null)
                          Text(
                            _format(step.at!),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        if (step.note != null) Text(step.note!),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

String _format(DateTime value) =>
    DateFormat('d MMM yyyy, HH:mm', 'id_ID').format(value);

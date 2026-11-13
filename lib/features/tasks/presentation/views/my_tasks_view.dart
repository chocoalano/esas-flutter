import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../../core/ui/components/app_badge.dart';
import '../../../../core/ui/components/app_card.dart';
import '../../../../core/ui/components/app_empty_state.dart';
import '../../../../core/ui/components/app_error_state.dart';
import '../../../../core/ui/components/app_inline_notice.dart';
import '../../../../core/ui/components/app_skeleton.dart';
import '../../data/models/field_task.dart';
import '../../data/models/task_action.dart';
import '../controllers/my_tasks_controller.dart';
import '../routes/tasks_routes.dart';

/// "Tugas Saya": every field task assigned to the worker, from each active
/// domain, in one list. Opening one goes to that domain's own lifecycle.
class MyTasksView extends GetView<MyTasksController> {
  const MyTasksView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tugas Saya')),
      body: Obx(() {
        if (controller.isLoading.value && controller.tasks.isEmpty) {
          return const _TaskListSkeleton();
        }

        if (controller.hasNoDomains) {
          return const AppEmptyState(
            icon: Icons.work_off_outlined,
            title: 'Belum ada modul operasional',
            message:
                'Perusahaan Anda belum mengaktifkan GA, IT, atau Maintenance.',
          );
        }

        if (controller.isAccessDenied) {
          return AppEmptyState(
            icon: Icons.lock_outline_rounded,
            title: 'Tidak ada akses tugas lapangan',
            message:
                'Akun Anda tidak memiliki peran petugas di modul yang aktif.',
            actionLabel: 'Muat ulang',
            onAction: controller.load,
          );
        }

        final blocking = controller.blockingError;
        if (blocking != null) {
          return AppErrorState(
            title: blocking.isTransportFailure
                ? 'Tidak dapat terhubung'
                : 'Gagal memuat tugas',
            message: blocking.message,
            onRetry: controller.load,
          );
        }

        final tasks = controller.visibleTasks;

        return RefreshIndicator(
          onRefresh: controller.load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              if (controller.domains.length > 1) _DomainFilter(controller),
              for (final domain in controller.partiallyFailed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppInlineNotice(
                    tone: AppNoticeTone.warning,
                    message:
                        '${domain.label} belum dapat dimuat. Tarik untuk mencoba lagi.',
                  ),
                ),
              if (tasks.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 48),
                  child: AppEmptyState(
                    icon: Icons.task_alt_rounded,
                    title: 'Tidak ada tugas',
                    message: 'Belum ada pekerjaan yang ditugaskan kepada Anda.',
                  ),
                )
              else
                for (final task in tasks)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TaskCard(task: task),
                  ),
            ],
          ),
        );
      }),
    );
  }
}

class _DomainFilter extends StatelessWidget {
  const _DomainFilter(this.controller);

  final MyTasksController controller;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(bottom: 12),
      child: Obx(
        () => Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: const Text('Semua'),
                selected: controller.filter.value == null,
                onSelected: (_) => controller.selectFilter(null),
              ),
            ),
            for (final domain in controller.domains)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(domain.label),
                  selected: controller.filter.value == domain,
                  onSelected: (_) => controller.selectFilter(domain),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One task in the list: number, kind, where, what, priority, status, when,
/// and whether it is waiting on the worker.
class TaskCard extends StatelessWidget {
  const TaskCard({super.key, required this.task});

  final FieldTask task;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final when = task.scheduledAt;

    final next = TaskAction.forTask(task).firstOrNull;

    return Semantics(
      button: true,
      label: [
        task.domain.label,
        task.number,
        task.title,
        'status ${task.statusLabel}',
        if (next != null) 'tindakan berikutnya ${next.label}',
      ].join(', '),
      excludeSemantics: true,
      child: AppCard(
        onTap: () => Get.toNamed(
          TasksRoutes.detail,
          arguments: {'domain': task.domain.name, 'id': task.id},
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppBadge(
                  label: task.domain.shortLabel,
                  tone: AppBadgeTone.brand,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    task.number,
                    style: theme.textTheme.labelMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              task.title,
              style: theme.textTheme.titleSmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (task.location != null) ...[
              const SizedBox(height: 4),
              Text(
                task.location!,
                style: theme.textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // In the wrapping row, so it never pushes the header off a
                // narrow screen at large text sizes.
                if (task.needsAction)
                  const AppBadge(
                    label: 'Perlu tindakan',
                    tone: AppBadgeTone.warning,
                  ),
                AppBadge(
                  label: task.statusLabel,
                  tone: statusTone(task.status),
                ),
                if (task.reviewHint != null)
                  AppBadge(label: task.reviewHint!, tone: AppBadgeTone.info),
                if (task.priorityLabel != null)
                  AppBadge(
                    label: 'Prioritas ${task.priorityLabel}',
                    tone: AppBadgeTone.neutral,
                  ),
                if (when != null)
                  Text(
                    '${task.dateLabel} ${DateFormat('d MMM yyyy, HH:mm', 'id_ID').format(when)}',
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
            if (next != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Berikutnya: ${next.label}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Status colour shared by the list and the detail screen.
AppBadgeTone statusTone(String status) => switch (status) {
  // Reported, not final: waiting on someone else (UX-D11).
  'completed' || 'resolved' || 'technically_completed' => AppBadgeTone.info,
  'verified' || 'restoration_verified' || 'closed' => AppBadgeTone.success,
  'on_hold' || 'waiting' || 'rework_required' => AppBadgeTone.warning,
  'cancelled' => AppBadgeTone.danger,
  'in_progress' => AppBadgeTone.brand,
  _ => AppBadgeTone.neutral,
};

class _TaskListSkeleton extends StatelessWidget {
  const _TaskListSkeleton();

  @override
  Widget build(BuildContext context) {
    return AppSkeletonPulse(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (var i = 0; i < 4; i++)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: AppSkeleton(height: 104),
            ),
        ],
      ),
    );
  }
}

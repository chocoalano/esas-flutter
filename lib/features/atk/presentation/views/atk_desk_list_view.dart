import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/ui/components/app_badge.dart';
import '../../../../core/ui/components/app_card.dart';
import '../../../../core/ui/components/app_empty_state.dart';
import '../../../../core/ui/components/app_error_state.dart';
import '../../data/models/atk_models.dart';
import '../controllers/atk_desk_list_controller.dart';
import '../routes/atk_routes.dart';
import 'atk_view_helpers.dart';

/// The message a GA-desk screen shows an account that may not use it.
const String atkDeskDeniedMessage = 'Anda tidak memiliki akses ke meja ATK';

/// "Meja ATK": the open ATK requests waiting on GA, oldest first.
class AtkDeskListView extends GetView<AtkDeskListController> {
  const AtkDeskListView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meja ATK')),
      body: Obx(() {
        final error = controller.error.value;

        if (controller.isLoading.value && controller.requests.isEmpty) {
          return const AtkListSkeleton();
        }

        // Not an error to retry: the account is not a GA officer.
        if (controller.isDenied) {
          return const AppEmptyState(
            icon: Icons.lock_outline_rounded,
            title: atkDeskDeniedMessage,
            message:
                'Meja ATK khusus petugas GA. Untuk meminta ATK, gunakan menu '
                'Permintaan ATK.',
          );
        }

        if (error != null && controller.requests.isEmpty) {
          return AppErrorState(
            title: 'Gagal memuat meja ATK',
            message: error.message,
            onRetry: controller.load,
          );
        }

        if (controller.requests.isEmpty) {
          return RefreshIndicator(
            onRefresh: controller.load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 48, 16, 24),
              children: const [
                AppEmptyState(
                  icon: Icons.task_alt_rounded,
                  title: 'Tidak ada permintaan terbuka',
                  message: 'Semua permintaan ATK sudah diproses.',
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: controller.load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              for (final request in controller.requests)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AtkDeskCard(request: request),
                ),
              if (controller.hasMore.value)
                AtkLoadMoreFooter(
                  isLoading: controller.isLoadingMore.value,
                  onPressed: controller.loadMore,
                  error: controller.loadMoreError.value,
                ),
            ],
          ),
        );
      }),
    );
  }
}

/// One request on the desk: who asked, what and how many, where, its status,
/// and whether it waits on the officer.
class AtkDeskCard extends StatelessWidget {
  const AtkDeskCard({super.key, required this.request});

  final AtkDeskRequest request;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final when = atkWhen(request.createdAt);
    final what = atkQuantityLine(
      request.itemName,
      request.quantity,
      request.unit,
    );

    return Semantics(
      button: true,
      label: [
        'Permintaan ATK ${request.number}',
        what,
        if (request.requesterName case final name?) 'dari $name',
        'status ${request.statusLabel}',
        if (request.needsAction) 'perlu tindakan',
        'Ketuk untuk melihat detail',
      ].join(', '),
      excludeSemantics: true,
      child: AppCard(
        onTap: () => Get.toNamed(AtkRoutes.deskDetail, arguments: request.id),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(request.number, style: theme.textTheme.labelMedium),
                AppBadge(
                  label: request.statusLabel,
                  tone: atkStatusTone(request.status),
                ),
                if (request.needsAction)
                  const AppBadge(
                    label: 'Perlu tindakan',
                    tone: AppBadgeTone.warning,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              what,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            if (request.requesterName case final name?)
              Text('Pemohon: $name', style: theme.textTheme.bodySmall),
            Text(
              'Ambil di ${request.locationName}',
              style: theme.textTheme.bodySmall,
            ),
            if (when != null)
              Text('Diajukan $when', style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

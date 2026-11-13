import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/ui/components/app_badge.dart';
import '../../../../core/ui/components/app_card.dart';
import '../../../../core/ui/components/app_empty_state.dart';
import '../../../../core/ui/components/app_error_state.dart';
import '../../../../core/ui/dialogs/app_snackbar.dart';
import '../../data/models/atk_models.dart';
import '../controllers/atk_request_list_controller.dart';
import '../routes/atk_routes.dart';
import 'atk_view_helpers.dart';

/// "Permintaan ATK Saya": every office-supply request the employee filed,
/// where it stands, and whether a handover waits on their confirmation.
class AtkRequestListView extends GetView<AtkRequestListController> {
  const AtkRequestListView({super.key});

  Future<void> _create() async {
    final Object? number = await Get.toNamed(AtkRoutes.create);
    if (number is String && number.isNotEmpty) {
      showSuccessSnackbar('Permintaan $number terkirim');
      await controller.load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Permintaan ATK Saya')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: const Text('Minta ATK'),
      ),
      body: Obx(() {
        final error = controller.error.value;

        if (controller.isLoading.value && controller.requests.isEmpty) {
          return const AtkListSkeleton();
        }

        if (error != null && controller.requests.isEmpty) {
          return AppErrorState(
            title: error.isForbidden
                ? 'Tidak ada akses'
                : 'Gagal memuat permintaan ATK',
            message: error.message,
            onRetry: controller.load,
          );
        }

        if (controller.requests.isEmpty) {
          return RefreshIndicator(
            onRefresh: controller.load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 48, 16, 96),
              children: [
                AppEmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: 'Belum ada permintaan ATK',
                  message:
                      'Minta alat tulis kantor ke tim GA; statusnya bisa Anda '
                      'pantau di sini.',
                  actionLabel: 'Minta ATK',
                  onAction: _create,
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: controller.load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            children: [
              for (final request in controller.requests)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AtkRequestCard(request: request),
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

/// One request: number and status, what and how many, where to pick it up,
/// what was handed over, and when it was asked.
class AtkRequestCard extends StatelessWidget {
  const AtkRequestCard({super.key, required this.request});

  final AtkRequest request;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final issued = atkIssuedLine(
      request.issuedQuantity,
      request.quantity,
      request.unit,
    );
    final when = atkWhen(request.createdAt);

    return Semantics(
      button: true,
      label: [
        'Permintaan ATK ${request.number}',
        atkQuantityLine(request.itemName, request.quantity, request.unit),
        'status ${request.statusLabel}',
        ?issued,
        if (request.awaitingReceipt) 'menunggu konfirmasi Anda',
        'Ketuk untuk melihat detail',
      ].join(', '),
      excludeSemantics: true,
      child: AppCard(
        onTap: () => Get.toNamed(AtkRoutes.detail, arguments: request.id),
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
                if (request.awaitingReceipt)
                  const AppBadge(
                    label: 'Menunggu konfirmasi Anda',
                    tone: AppBadgeTone.warning,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              atkQuantityLine(request.itemName, request.quantity, request.unit),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Ambil di ${request.locationName}',
              style: theme.textTheme.bodySmall,
            ),
            if (issued != null) ...[
              const SizedBox(height: 2),
              Text(issued, style: theme.textTheme.bodySmall),
            ],
            if (when != null) ...[
              const SizedBox(height: 2),
              Text('Diajukan $when', style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

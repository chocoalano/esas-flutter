import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/ui/components/app_badge.dart';
import '../../../../core/ui/components/app_card.dart';
import '../../../../core/ui/components/app_empty_state.dart';
import '../../../../core/ui/components/app_error_state.dart';
import '../../../../core/ui/components/app_skeleton.dart';
import '../controllers/itms_ticket_list_controller.dart';
import '../routes/itms_routes.dart';
import 'itms_ticket_view_helpers.dart';

/// Every IT ticket the employee raised, the solved ones too (FUNC-D04).
class ItmsTicketListView extends GetView<ItmsTicketListController> {
  const ItmsTicketListView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Tiket IT Saya')),
      body: Obx(() {
        final error = controller.error.value;

        if (controller.isLoading.value && controller.tickets.isEmpty) {
          return const AppSkeletonPulse(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: AppSkeleton(height: 220),
            ),
          );
        }

        if (error != null && controller.tickets.isEmpty) {
          return AppErrorState(
            title: error.isForbidden ? 'Tidak ada akses' : 'Gagal memuat tiket',
            message: error.message,
            onRetry: controller.load,
          );
        }

        if (controller.tickets.isEmpty) {
          return const AppEmptyState(
            icon: Icons.confirmation_number_outlined,
            title: 'Belum ada tiket',
            message: 'Tiket kendala IT yang Anda laporkan akan tampil di sini.',
          );
        }

        return RefreshIndicator(
          onRefresh: controller.load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              for (final ticket in controller.tickets)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Semantics(
                    button: true,
                    label:
                        'Tiket ${ticket.subject}, ${ticket.statusLabel}. '
                        'Ketuk untuk melihat detail.',
                    excludeSemantics: true,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Get.toNamed(
                        ItmsRoutes.ticketDetail,
                        arguments: ticket.id,
                      ),
                      child: AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  'TKT-${ticket.id}',
                                  style: theme.textTheme.labelMedium,
                                ),
                                AppBadge(
                                  label: ticket.statusLabel,
                                  tone: itmsStatusTone(ticket.status),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              ticket.subject,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              [
                                ticket.serviceName ?? 'IT Helpdesk',
                                ?itmsWhen(ticket.createdAt),
                              ].join(' • '),
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
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

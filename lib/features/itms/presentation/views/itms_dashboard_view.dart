import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/ui/components/app_card.dart';
import '../../../../core/ui/components/app_section_header.dart';
import '../controllers/itms_dashboard_controller.dart';
import '../routes/itms_routes.dart';

class ItmsDashboardView extends GetView<ItmsDashboardController> {
  const ItmsDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;

    return Scaffold(
      appBar: AppBar(
        title: const Text('IT Services (ITMS)'),
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
                    Icon(Icons.error_outline, size: 48, color: palette.danger.foreground),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      controller.error.value!.message,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ElevatedButton(
                      onPressed: controller.loadDashboard,
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: controller.loadDashboard,
            child: ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.lg,
              ),
              children: [
                // ── Helpdesk Tickets ──
                AppSectionHeader(
                  title: 'Tiket Bantuan IT',
                  subtitle: '${controller.tickets.length} tiket kendala aktif',
                  dense: true,
                  naturalCase: true,
                  trailing: TextButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Lapor'),
                    onPressed: () => Get.toNamed(ItmsRoutes.tickets),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (controller.tickets.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    child: Text(
                      'Tidak ada tiket kendala IT yang terbuka.',
                      style: theme.textTheme.bodySmall?.copyWith(color: palette.textMuted),
                    ),
                  )
                else
                  for (final ticket in controller.tickets.take(3))
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: AppCard(
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: palette.brandSubtle,
                                borderRadius: AppRadii.mdAll,
                              ),
                              alignment: Alignment.center,
                              child: Icon(Icons.confirmation_number_outlined, size: 18, color: theme.colorScheme.primary),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ticket.subject,
                                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    '${ticket.serviceName ?? 'IT Helpdesk'} • ${ticket.statusLabel}',
                                    style: theme.textTheme.bodySmall?.copyWith(color: palette.textMuted),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                const SizedBox(height: AppSpacing.xxl),

                // ── Service Catalog ──
                AppSectionHeader(
                  title: 'Katalog Layanan IT',
                  subtitle: '${controller.services.length} layanan mandiri tersedia',
                  dense: true,
                  naturalCase: true,
                ),
                const SizedBox(height: AppSpacing.sm),
                if (controller.services.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    child: Text(
                      'Katalog layanan IT belum dikonfigurasi.',
                      style: theme.textTheme.bodySmall?.copyWith(color: palette.textMuted),
                    ),
                  )
                else
                  for (final svc in controller.services.take(4))
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: AppCard(
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: palette.surfaceSubtle,
                                borderRadius: AppRadii.mdAll,
                              ),
                              alignment: Alignment.center,
                              child: Icon(Icons.inventory_2_outlined, size: 18, color: theme.colorScheme.primary),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    svc.name,
                                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    svc.category ?? svc.code,
                                    style: theme.textTheme.bodySmall?.copyWith(color: palette.textMuted),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                const SizedBox(height: AppSpacing.xxl),

                // ── Knowledge Base ──
                AppSectionHeader(
                  title: 'Panduan & Bantuan IT Mandiri',
                  subtitle: '${controller.articles.length} artikel swa-bantu',
                  dense: true,
                  naturalCase: true,
                ),
                const SizedBox(height: AppSpacing.sm),
                if (controller.articles.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    child: Text(
                      'Belum ada artikel panduan kendala IT.',
                      style: theme.textTheme.bodySmall?.copyWith(color: palette.textMuted),
                    ),
                  )
                else
                  for (final art in controller.articles.take(3))
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: AppCard(
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: palette.brandSubtle,
                                borderRadius: AppRadii.mdAll,
                              ),
                              alignment: Alignment.center,
                              child: Icon(Icons.menu_book_outlined, size: 18, color: theme.colorScheme.primary),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    art.title,
                                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  if (art.summary != null)
                                    Text(
                                      art.summary!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall?.copyWith(color: palette.textMuted),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
              ],
            ),
          );
        }),
      ),
    );
  }
}


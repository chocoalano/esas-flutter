import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/ui/components/app_card.dart';
import '../../../../core/ui/components/app_section_header.dart';
import '../controllers/itms_dashboard_controller.dart';
import '../routes/itms_routes.dart';

class _SectionError extends StatelessWidget {
  const _SectionError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 16,
            color: theme.palette.danger.foreground,
          ),
          const SizedBox(width: AppSpacing.tight),
          Expanded(
            child: Text(
              'Bagian ini belum dapat dimuat: $message',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.palette.danger.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
          // The page, not an open snackbar (as GAMS-04).
          onPressed: () => Navigator.of(context).maybePop(),
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
                  // Only open tickets, and "20+" when the one page read came
                  // back full — more may be behind it (ITMS-01).
                  subtitle:
                      '${controller.activeTickets.length}${controller.tickets.length >= ItmsDashboardController.pageSize ? '+' : ''} tiket kendala aktif',
                  dense: true,
                  naturalCase: true,
                  trailing: TextButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Lapor'),
                    // A form that files a ticket (ITMS-01); it used to open
                    // this same dashboard again.
                    onPressed: () async {
                      // Untyped: a named GetPage route is `GetPageRoute<dynamic>`,
                      // and `toNamed<bool>` fails the cast at runtime.
                      final Object? filed = await Get.toNamed(
                        ItmsRoutes.ticketCreate,
                      );
                      if (filed == true) await controller.loadDashboard();
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (controller.sectionErrors['tickets'] case final failed?)
                  _SectionError(message: failed.message)
                else if (controller.activeTickets.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                    child: Text(
                      'Tidak ada tiket kendala IT yang terbuka.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: palette.textMuted,
                      ),
                    ),
                  )
                else
                  for (final ticket in controller.activeTickets.take(3))
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      // Opens the ticket (FUNC-D04); the card used to be
                      // read-only.
                      child: InkWell(
                        borderRadius: AppRadii.mdAll,
                        onTap: () => Get.toNamed(
                          ItmsRoutes.ticketDetail,
                          arguments: ticket.id,
                        ),
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
                                child: Icon(
                                  Icons.confirmation_number_outlined,
                                  size: 18,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      ticket.subject,
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    Text(
                                      '${ticket.serviceName ?? 'IT Helpdesk'} • ${ticket.statusLabel}',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(color: palette.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                // Finished tickets and their outcome live one tap away
                // (FUNC-D04); they used to vanish once solved.
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => Get.toNamed(ItmsRoutes.ticketHistory),
                    child: const Text('Semua tiket saya'),
                  ),
                ),

                const SizedBox(height: AppSpacing.xxl),

                // ── Service Catalog ──
                AppSectionHeader(
                  title: 'Katalog Layanan IT',
                  subtitle:
                      '${controller.services.length} layanan mandiri tersedia',
                  dense: true,
                  naturalCase: true,
                ),
                const SizedBox(height: AppSpacing.sm),
                if (controller.sectionErrors['services'] case final failed?)
                  _SectionError(message: failed.message)
                else if (controller.services.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                    child: Text(
                      'Katalog layanan IT belum dikonfigurasi.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: palette.textMuted,
                      ),
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
                              child: Icon(
                                Icons.inventory_2_outlined,
                                size: 18,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    svc.name,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    svc.category ?? svc.code,
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
                if (controller.sectionErrors['articles'] case final failed?)
                  _SectionError(message: failed.message)
                else if (controller.articles.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                    child: Text(
                      'Belum ada artikel panduan kendala IT.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: palette.textMuted,
                      ),
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
                              child: Icon(
                                Icons.menu_book_outlined,
                                size: 18,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    art.title,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (art.summary != null)
                                    Text(
                                      art.summary!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(color: palette.textMuted),
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

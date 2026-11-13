import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/ui/components/app_card.dart';
import '../../../../core/ui/components/app_section_header.dart';
import '../controllers/gams_dashboard_controller.dart';
import '../../../../core/ui/dialogs/app_snackbar.dart';
import '../routes/gams_routes.dart';
import 'gams_request_tracking_views.dart';

class GamsDashboardView extends GetView<GamsDashboardController> {
  const GamsDashboardView({super.key});

  /// Open a create form, and reload when it comes back having filed
  /// something (UAT review H2). Untyped: a named GetPage route is
  /// `GetPageRoute<dynamic>`, and `toNamed<bool>` fails the cast at runtime.
  Future<void> _create(String route) async {
    final Object? filed = await Get.toNamed(route);
    if (filed == true) await controller.loadDashboard();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;

    return Scaffold(
      appBar: AppBar(
        title: const Text('General Affairs (GAMS)'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          // The page, not whatever overlay is on top of it (GAMS-04):
          // `Get.back()` closes an open snackbar first, so a section error
          // turned the first tap into a no-op.
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
                // ── Service Requests Section ──
                AppSectionHeader(
                  title: 'Permintaan Layanan Fasilitas',
                  subtitle:
                      '${GamsDashboardController.countLabel(controller.activeServiceRequests, loaded: controller.serviceRequests.length)} pengajuan aktif',
                  dense: true,
                  naturalCase: true,
                  trailing: TextButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Buat'),
                    onPressed: () => _create(GamsRoutes.serviceRequests),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                // A section that could not load says so, on its own (GAMS-02).
                if (controller.sectionErrors['serviceRequests']
                    case final failed?)
                  _SectionError(message: failed.message)
                else if (controller.serviceRequests.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                    child: Text(
                      'Belum ada permohonan layanan fasilitas yang diajukan.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: palette.textMuted,
                      ),
                    ),
                  )
                else
                  for (final req in controller.serviceRequests.take(3))
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      // Opens the request (FUNC-D05); rows were read-only.
                      child: InkWell(
                        borderRadius: AppRadii.mdAll,
                        onTap: () => Get.toNamed(
                          GamsRoutes.requestDetail,
                          arguments: req.id,
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
                                  Icons.home_repair_service_outlined,
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
                                      req.subject,
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    Text(
                                      '${req.number} • ${req.statusLabel}',
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
                // Older requests were out of reach beyond these three
                // (FUNC-D05).
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => Get.toNamed(GamsRoutes.requests),
                    child: const Text('Semua permintaan saya'),
                  ),
                ),

                const SizedBox(height: AppSpacing.xxl),

                // ── Space Reservations Section ──
                AppSectionHeader(
                  title: 'Reservasi Ruang Rapat',
                  subtitle:
                      '${GamsDashboardController.countLabel(controller.spaceReservations.length, loaded: controller.spaceReservations.length)} reservasi terbaru',
                  dense: true,
                  naturalCase: true,
                  trailing: TextButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Pesan'),
                    onPressed: () => _create(GamsRoutes.spaceReservations),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                // A section that could not load says so, on its own (GAMS-02).
                if (controller.sectionErrors['spaceReservations']
                    case final failed?)
                  _SectionError(message: failed.message)
                else if (controller.spaceReservations.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                    child: Text(
                      'Tidak ada jadwal penggunaan ruang pertemuan.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: palette.textMuted,
                      ),
                    ),
                  )
                else
                  for (final res in controller.spaceReservations.take(3))
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
                                Icons.meeting_room_outlined,
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
                                    res.spaceName ?? 'Ruang Rapat',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '${res.startAt.split('T').first} • ${res.status}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: palette.textMuted,
                                    ),
                                  ),
                                  // Withdraw it while the server allows (D-06).
                                  if (res.canCancel)
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: TextButton(
                                        onPressed: () async {
                                          final done =
                                              await confirmGamsCancellation(
                                                context,
                                                title:
                                                    'Batalkan reservasi ruang?',
                                                consequence:
                                                    'Ruang dilepas untuk pemohon lain.',
                                                reasonRequired: false,
                                                onCancel: (reason) =>
                                                    controller.cancelBooking(
                                                      vehicle: false,
                                                      id: res.id,
                                                      reason: reason,
                                                    ),
                                              );
                                          if (done) {
                                            showSuccessSnackbar(
                                              'Pembatalan berhasil.',
                                            );
                                          }
                                        },
                                        child: const Text('Batalkan'),
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

                // ── Vehicle Bookings Section ──
                AppSectionHeader(
                  title: 'Peminjaman Kendaraan',
                  subtitle:
                      '${GamsDashboardController.countLabel(controller.vehicleBookings.length, loaded: controller.vehicleBookings.length)} peminjaman terbaru',
                  dense: true,
                  naturalCase: true,
                  trailing: TextButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Pinjam'),
                    onPressed: () => _create(GamsRoutes.vehicleBookings),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                // A section that could not load says so, on its own (GAMS-02).
                if (controller.sectionErrors['vehicleBookings']
                    case final failed?)
                  _SectionError(message: failed.message)
                else if (controller.vehicleBookings.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                    child: Text(
                      'Belum ada peminjaman kendaraan operasional.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: palette.textMuted,
                      ),
                    ),
                  )
                else
                  for (final vb in controller.vehicleBookings.take(3))
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
                                Icons.directions_car_outlined,
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
                                    vb.vehicleName ?? 'Kendaraan Operasional',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '${vb.purpose} • ${vb.status}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: palette.textMuted,
                                    ),
                                  ),
                                  // Withdraw it while the server allows (D-06).
                                  if (vb.canCancel)
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: TextButton(
                                        onPressed: () async {
                                          final done = await confirmGamsCancellation(
                                            context,
                                            title:
                                                'Batalkan peminjaman kendaraan?',
                                            consequence:
                                                'Kendaraan dilepas untuk pemohon lain.',
                                            reasonRequired: false,
                                            onCancel: (reason) =>
                                                controller.cancelBooking(
                                                  vehicle: true,
                                                  id: vb.id,
                                                  reason: reason,
                                                ),
                                          );
                                          if (done) {
                                            showSuccessSnackbar(
                                              'Pembatalan berhasil.',
                                            );
                                          }
                                        },
                                        child: const Text('Batalkan'),
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

                // ── Visitor Passes Section ──
                AppSectionHeader(
                  title: 'Buku Tamu & Visitor Pass',
                  subtitle:
                      '${GamsDashboardController.countLabel(controller.visitorPasses.length, loaded: controller.visitorPasses.length)} tamu terbaru',
                  dense: true,
                  naturalCase: true,
                  trailing: TextButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Daftar'),
                    onPressed: () => _create(GamsRoutes.visitorPasses),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                // A section that could not load says so, on its own (GAMS-02).
                if (controller.sectionErrors['visits'] case final failed?)
                  _SectionError(message: failed.message)
                else if (controller.visitorPasses.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                    child: Text(
                      'Belum ada pra-pendaftaran tamu atau buku kunjungan.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: palette.textMuted,
                      ),
                    ),
                  )
                else
                  for (final vp in controller.visitorPasses.take(3))
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
                                Icons.badge_outlined,
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
                                    vp.visitorName,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '${vp.purpose} • ${vp.statusLabel}',
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
              ],
            ),
          );
        }),
      ),
    );
  }
}

/// A section that could not be loaded (GAMS-02).
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

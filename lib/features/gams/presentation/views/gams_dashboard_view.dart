import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/ui/components/app_card.dart';
import '../../../../core/ui/components/app_section_header.dart';
import '../controllers/gams_dashboard_controller.dart';
import '../routes/gams_routes.dart';

class GamsDashboardView extends GetView<GamsDashboardController> {
  const GamsDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;

    return Scaffold(
      appBar: AppBar(
        title: const Text('General Affairs (GAMS)'),
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
                // ── Service Requests Section ──
                AppSectionHeader(
                  title: 'Permintaan Layanan Fasilitas',
                  subtitle: '${controller.serviceRequests.length} pengajuan aktif',
                  dense: true,
                  naturalCase: true,
                  trailing: TextButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Buat'),
                    onPressed: () => Get.toNamed(GamsRoutes.serviceRequests),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (controller.serviceRequests.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    child: Text(
                      'Belum ada permohonan layanan fasilitas yang diajukan.',
                      style: theme.textTheme.bodySmall?.copyWith(color: palette.textMuted),
                    ),
                  )
                else
                  for (final req in controller.serviceRequests.take(3))
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
                              child: Icon(Icons.home_repair_service_outlined, size: 18, color: theme.colorScheme.primary),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    req.subject,
                                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    '${req.number} • ${req.statusLabel}',
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

                // ── Space Reservations Section ──
                AppSectionHeader(
                  title: 'Reservasi Ruang Rapat',
                  subtitle: '${controller.spaceReservations.length} reservasi tercatat',
                  dense: true,
                  naturalCase: true,
                  trailing: TextButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Pesan'),
                    onPressed: () => Get.toNamed(GamsRoutes.spaceReservations),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (controller.spaceReservations.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    child: Text(
                      'Tidak ada jadwal penggunaan ruang pertemuan.',
                      style: theme.textTheme.bodySmall?.copyWith(color: palette.textMuted),
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
                              child: Icon(Icons.meeting_room_outlined, size: 18, color: theme.colorScheme.primary),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    res.spaceName ?? 'Ruang Rapat',
                                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    '${res.startAt.split('T').first} • ${res.status}',
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

                // ── Vehicle Bookings Section ──
                AppSectionHeader(
                  title: 'Peminjaman Kendaraan',
                  subtitle: '${controller.vehicleBookings.length} peminjaman tercatat',
                  dense: true,
                  naturalCase: true,
                  trailing: TextButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Pinjam'),
                    onPressed: () => Get.toNamed(GamsRoutes.vehicleBookings),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (controller.vehicleBookings.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    child: Text(
                      'Belum ada peminjaman kendaraan operasional.',
                      style: theme.textTheme.bodySmall?.copyWith(color: palette.textMuted),
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
                              child: Icon(Icons.directions_car_outlined, size: 18, color: theme.colorScheme.primary),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    vb.vehicleName ?? 'Kendaraan Operasional',
                                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    '${vb.purpose} • ${vb.status}',
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

                // ── Visitor Passes Section ──
                AppSectionHeader(
                  title: 'Buku Tamu & Visitor Pass',
                  subtitle: '${controller.visitorPasses.length} tamu terdaftar',
                  dense: true,
                  naturalCase: true,
                  trailing: TextButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Daftar'),
                    onPressed: () => Get.toNamed(GamsRoutes.visitorPasses),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (controller.visitorPasses.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    child: Text(
                      'Belum ada pra-pendaftaran tamu atau buku kunjungan.',
                      style: theme.textTheme.bodySmall?.copyWith(color: palette.textMuted),
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
                              child: Icon(Icons.badge_outlined, size: 18, color: theme.colorScheme.primary),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    vp.visitorName,
                                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    '${vp.purpose} • ${vp.statusLabel}',
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


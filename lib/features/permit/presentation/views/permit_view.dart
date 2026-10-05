import 'package:esas/core/theme/app_dimens.dart';
import 'package:esas/core/theme/app_palette.dart';
import 'package:esas/core/theme/app_typography.dart';
import 'package:esas/core/ui/components/app_empty_state.dart';
import 'package:esas/core/ui/components/app_section_header.dart';
import 'package:esas/core/ui/components/app_skeleton.dart';
import 'package:esas/core/ui/components/custom_bottom_navbar.dart';
import 'package:esas/core/ui/dialogs/app_dialogs.dart';
import 'package:esas/features/permit/data/models/leave_type.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/permit_controller.dart';
import '../routes/permit_routes.dart';
import '../widgets/type_card_item.dart';

/// Daftar jenis perizinan yang bisa diajukan.
///
/// Judul halaman berada di dalam badan, bukan di `AppBar`, mengikuti pola yang
/// sama dengan beranda: judul yang bisa menggulir mengembalikan tinggi layar
/// kepada daftar begitu orang mulai memilih.
class PermitView extends GetView<PermitController> {
  const PermitView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        confirmExitApp(context);
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Obx(() {
            final bool loading = controller.isLoading.value;
            final List<LeaveType> leaveTypes = controller.leaveTypes;

            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.xl,
                AppSpacing.page,
                AppSpacing.bottomSafe,
              ),
              children: [
                const AppPageTitle(
                  title: 'Pengajuan',
                  subtitle:
                      'Pilih jenis perizinan untuk melihat riwayat dan '
                      'membuat pengajuan baru.',
                ),
                const SizedBox(height: AppSpacing.xxl),

                if (loading) ...[
                  const AppSectionHeader(title: 'Jenis perizinan'),
                  const AppSkeletonList(count: 5, padding: EdgeInsets.zero),
                ] else if (leaveTypes.isEmpty)
                  AppEmptyState(
                    icon: Icons.inbox_outlined,
                    title: 'Belum ada jenis perizinan',
                    message:
                        'Hubungi HR bila Anda seharusnya bisa mengajukan izin.',
                    actionLabel: 'Muat ulang',
                    onAction: controller.fetchLeaveTypes,
                  )
                else ...[
                  AppSectionHeader(
                    title: 'Jenis perizinan',
                    subtitle: _attachmentNote(leaveTypes),
                    // Angka tabular, sejajar dengan setiap angka lain di
                    // aplikasi ini, bukan huruf kecil yang kebetulan berupa
                    // bilangan.
                    trailing: Text(
                      '${leaveTypes.length}',
                      style: AppTypography.dataSmall(
                        color: theme.palette.textMuted,
                      ),
                    ),
                  ),
                  LeaveTypePanel(
                    children: [
                      for (final item in leaveTypes)
                        LeaveTypeRow(
                          item: item,
                          onTap: () =>
                              Get.toNamed(PermitRoutes.list, arguments: item),
                        ),
                    ],
                  ),
                ],
              ],
            );
          }),
        ),
        bottomNavigationBar: const CustomBottomNavBar(),
      ),
    );
  }

  /// Berapa jenis di daftar ini yang menuntut lampiran.
  ///
  /// Ditulis di kepala bagian, bukan hanya sebagai lencana per baris, karena
  /// pertanyaannya datang sebelum orang mulai membaca satu per satu: apakah
  /// saya perlu menyiapkan berkas dulu sebelum membuka formulir.
  static String? _attachmentNote(List<LeaveType> types) {
    final int withFile = types.where((t) => t.withFile).length;

    if (withFile == 0) return null;

    return '$withFile dari ${types.length} jenis menuntut lampiran.';
  }
}

import 'package:esas/core/theme/app_dimens.dart';
import 'package:esas/core/ui/components/app_empty_state.dart';
import 'package:esas/core/ui/components/app_skeleton.dart';
import 'package:esas/features/permit/data/models/leave_list.dart';
import 'package:esas/features/permit/presentation/widgets/permit_list_item.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/permit_list_controller.dart';
import '../routes/permit_routes.dart';

/// Riwayat pengajuan untuk satu jenis izin.
///
/// Tiga hal yang diperbaiki di sini selain warna dan jarak:
///
/// * Saat memuat halaman pertama, layar menampilkan kerangka kartu alih-alih
///   spinner di tengah. Bentuk daftar sudah terlihat sebelum datanya tiba, jadi
///   tidak ada lompatan tata letak.
/// * Tombol buat pengajuan memakai [FloatingActionButton.extended] dengan
///   label. Ikon "+" sendirian tidak memberi tahu apa yang akan dibuat.
/// * Keadaan kosong menawarkan aksi yang benar — membuat pengajuan — bukan
///   sekadar tombol muat ulang untuk daftar yang memang belum berisi apa pun.
class PermitListView extends GetView<PermitListController> {
  const PermitListView({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        Get.offAllNamed(PermitRoutes.permit);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Kembali',
            onPressed: () => Get.offAllNamed(PermitRoutes.permit),
          ),
          title: Obx(
            () => Text(
              controller.appBarTitle.value.isEmpty
                  ? 'Riwayat pengajuan'
                  : controller.appBarTitle.value,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          titleSpacing: 0,
        ),
        body: Obx(() {
          if (controller.isLoading.value && controller.permits.isEmpty) {
            return const Padding(
              padding: EdgeInsets.only(top: AppSpacing.lg),
              child: AppSkeletonList(count: 4, shape: AppSkeletonShape.permit),
            );
          }

          if (controller.permits.isEmpty) {
            return AppEmptyState(
              icon: Icons.description_outlined,
              title: 'Belum ada pengajuan',
              message:
                  'Riwayat untuk jenis izin ini masih kosong. Buat pengajuan '
                  'pertama Anda kapan saja.',
              actionLabel: 'Muat ulang',
              onAction: controller.resetAndFetch,
            );
          }

          return RefreshIndicator(
            onRefresh: controller.resetAndFetch,
            child: ListView.separated(
              controller: controller.scrollController,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.lg,
                AppSpacing.page,
                // Ruang bagi tombol mengambang supaya kartu terakhir tetap bisa
                // dibaca seluruhnya saat digulir sampai bawah.
                AppSpacing.huge + AppSpacing.xxl,
              ),
              itemCount:
                  controller.permits.length +
                  (controller.hasMore.value ? 1 : 0),
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) {
                if (index < controller.permits.length) {
                  final Permit permit = controller.permits[index];
                  return PermitListItem(permit: permit);
                }
                // Kerangka yang menyusul memakai bentuk baris pengajuan,
                // bukan bentuk baris umum: yang akan menggantikannya adalah
                // sebuah kartu pengajuan, dan kerangka yang tingginya meleset
                // membuat daftar melompat tepat saat orang sedang menggulir.
                return const Padding(
                  padding: EdgeInsets.only(top: AppSpacing.sm),
                  child: PermitSkeletonRow(),
                );
              },
            ),
          );
        }),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => Get.offAllNamed(
            PermitRoutes.create,
            arguments: controller.permitType.value,
          ),
          icon: const Icon(Icons.add_rounded, size: AppIconSizes.xl),
          label: const Text('Ajukan'),
        ),
      ),
    );
  }
}

import 'package:esas/core/config/asset_url.dart';
import 'package:esas/core/theme/app_dimens.dart';
import 'package:esas/core/ui/components/app_avatar.dart';
import 'package:esas/core/ui/components/app_badge.dart';
import 'package:esas/core/ui/components/app_card.dart';
import 'package:esas/core/ui/components/app_error_state.dart';
import 'package:esas/core/ui/components/app_record_field.dart';
import 'package:esas/core/ui/components/app_section_header.dart';
import 'package:esas/core/ui/components/app_skeleton.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/profile_tab_controllers.dart';

/// Catatan pribadi karyawan, sebagai panel baca.
///
/// Layar ini ada untuk satu tugas: karyawan membukanya dan membacakan sebuah
/// nilai — NIP, nomor identitas, alamat — kepada HR atau mengetikkannya ke
/// formulir lain. Karena itu setiap nilai di sini boleh disorot dan disalin,
/// yang berupa angka dirender tabular, dan tidak satu pun dipotong elipsis.
class ProfilePersonalView extends GetView<ProfilePersonalController> {
  const ProfilePersonalView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Informasi Personal'),
        centerTitle: true,
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const AppSkeletonList(
            count: 3,
            padding: EdgeInsets.all(AppSpacing.page),
          );
        }

        // Cabang gagal diperiksa sebelum apa pun digambar: catatan yang gagal
        // dimuat selalu juga berarti catatan kosong, dan layar yang menyajikan
        // kegagalan sebagai "data tidak ada" adalah kalimat keliru di HRMS.
        if (controller.errorMessage.isNotEmpty) {
          return AppErrorState(
            message: controller.errorMessage.value,
            onRetry: controller.setupProfile,
          );
        }

        final user = controller.userInfo.value;
        final String avatar = user.avatar ?? '';

        return RefreshIndicator(
          onRefresh: controller.setupProfile,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.lg,
              AppSpacing.page,
              AppSpacing.bottomSafe,
            ),
            children: [
              AppCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppAvatar(
                      userName: user.name ?? '',
                      imageUrl: avatar.isEmpty ? null : assetUrl(avatar),
                      size: 64,
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name ?? 'Nama tidak tersedia',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AppRecordField(
                            label: 'NIP',
                            value: user.nip ?? '',
                            mono: true,
                            selectable: true,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AppBadge(
                            label: user.status ?? '—',
                            tone: AppBadgeTone.brand,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              const AppSectionHeader(title: 'Detail pribadi', dense: true),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppRecordFieldPair(
                      first: AppRecordField(
                        label: 'Email',
                        value: user.email ?? '',
                        selectable: true,
                      ),
                      second: AppRecordField(
                        label: 'Telepon',
                        value: user.details?.phone ?? '',
                        mono: true,
                        selectable: true,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppRecordFieldPair(
                      first: AppRecordField(
                        label: 'Jenis kelamin',
                        value: user.details?.gender ?? '',
                      ),
                      second: AppRecordField(
                        label: 'Tanggal lahir',
                        value: controller.formattedJoinedDate,
                        mono: true,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppRecordFieldPair(
                      first: AppRecordField(
                        label: 'Tempat lahir',
                        value: user.details?.placebirth ?? '',
                      ),
                      second: AppRecordField(
                        label: 'Golongan darah',
                        value: user.details?.blood ?? '',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppRecordFieldPair(
                      first: AppRecordField(
                        label: 'Status pernikahan',
                        value: user.details?.maritalStatus ?? '',
                      ),
                      second: AppRecordField(
                        label: 'Agama',
                        value: user.details?.religion ?? '',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              const AppSectionHeader(title: 'Alamat', dense: true),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppRecordField(
                      label: 'Tipe identitas',
                      value: user.address?.identityType ?? '',
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    // Enam belas digit, tabular, bisa disalin, tanpa elipsis.
                    // Nomor identitas yang terpotong di layar adalah satu-
                    // satunya cara halaman ini bisa gagal sepenuhnya.
                    AppRecordField(
                      label: 'Nomor identitas',
                      value: user.address?.identityNumbers ?? '',
                      mono: true,
                      selectable: true,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppRecordField(
                      label: 'Alamat lengkap',
                      value: controller.fullAddress,
                      selectable: true,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppRecordField(
                      label: 'Alamat tinggal',
                      value: user.address?.residentialAddress ?? '',
                      selectable: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

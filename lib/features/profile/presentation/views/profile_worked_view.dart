import 'package:esas/core/theme/app_dimens.dart';
import 'package:esas/core/theme/app_palette.dart';
import 'package:esas/core/ui/components/app_card.dart';
import 'package:esas/core/ui/components/app_error_state.dart';
import 'package:esas/core/ui/components/app_record_field.dart';
import 'package:esas/core/ui/components/app_section_header.dart';
import 'package:esas/core/ui/components/app_skeleton.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/profile_tab_controllers.dart';

/// Catatan kepegawaian: perusahaan, kontrak, rekening, dan jalur persetujuan.
///
/// Empat kartu, satu ritme. Nilai yang berupa angka atau tanggal — tanggal
/// bergabung, nomor rekening, gaji pokok — dirender tabular dan bisa disalin,
/// karena inilah layar yang dibuka orang saat HR menanyakannya lewat telepon.
class ProfileWorkedView extends GetView<ProfileWorkedController> {
  const ProfileWorkedView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Info Pekerjaan'), centerTitle: true),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const AppSkeletonList(
            count: 4,
            padding: EdgeInsets.all(AppSpacing.page),
          );
        }

        if (controller.errorMessage.isNotEmpty) {
          return AppErrorState(
            message: controller.errorMessage.value,
            onRetry: controller.setupProfile,
          );
        }

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
              const AppSectionHeader(
                title: 'Informasi perusahaan',
                dense: true,
              ),
              _RecordCard(
                fields: [
                  AppRecordField(
                    label: 'Nama perusahaan',
                    value: controller.companyName,
                  ),
                  AppRecordField(
                    label: 'Departemen',
                    value: controller.departmentName,
                  ),
                  AppRecordField(
                    label: 'Posisi pekerjaan',
                    value: controller.jobPosition,
                  ),
                  AppRecordField(
                    label: 'Level pekerjaan',
                    value: controller.jobLevel,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),

              const AppSectionHeader(title: 'Detail pekerjaan', dense: true),
              _RecordCard(
                fields: [
                  AppRecordField(
                    label: 'Tanggal bergabung',
                    value: controller.joinDate,
                    mono: true,
                  ),
                  AppRecordField(
                    label: 'Tanggal tanda tangan',
                    value: controller.signDate,
                    mono: true,
                  ),
                  AppRecordField(
                    label: 'Tanggal resign',
                    value: controller.resignDate,
                    mono: true,
                  ),
                  AppRecordField(
                    label: 'Saldo cuti',
                    value: controller.saldoCutiLabel,
                    mono: true,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),

              const AppSectionHeader(
                title: 'Informasi bank & gaji',
                dense: true,
              ),
              _RecordCard(
                fields: [
                  AppRecordField(
                    label: 'Nama bank',
                    value: controller.bankName,
                  ),
                  AppRecordField(
                    label: 'Nomor rekening',
                    value: controller.bankNumber,
                    mono: true,
                    selectable: true,
                  ),
                  AppRecordField(
                    label: 'Pemegang rekening',
                    value: controller.bankHolder,
                    selectable: true,
                  ),
                  AppRecordField(
                    label: 'Gaji pokok',
                    value: controller.basicSalary,
                    mono: true,
                    selectable: true,
                  ),
                  AppRecordField(
                    label: 'Tipe pembayaran',
                    value: controller.paymentType,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),

              const AppSectionHeader(
                title: 'Informasi persetujuan',
                dense: true,
              ),
              _RecordCard(
                fields: [
                  AppRecordField(
                    label: 'Persetujuan line',
                    value: controller.approvalLine,
                  ),
                  AppRecordField(
                    label: 'Persetujuan manajer',
                    value: controller.approvalManager,
                  ),
                ],
              ),
            ],
          ),
        );
      }),
    );
  }
}

/// Sekumpulan bidang catatan di dalam satu kartu, dipisah garis 1px.
///
/// Garis pemisahnya yang membuat kartu ini terbaca sebagai tabel dan bukan
/// sebagai paragraf: mata menyusuri satu kolom label, bukan delapan blok teks.
class _RecordCard extends StatelessWidget {
  const _RecordCard({required this.fields});

  final List<AppRecordField> fields;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).palette;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < fields.length; i++) ...[
            if (i > 0) ...[
              const SizedBox(height: AppSpacing.md),
              Divider(height: 1, color: palette.borderSubtle),
              const SizedBox(height: AppSpacing.md),
            ],
            fields[i],
          ],
        ],
      ),
    );
  }
}

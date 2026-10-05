import 'package:esas/core/theme/app_dimens.dart';
import 'package:esas/core/ui/components/app_badge.dart';
import 'package:esas/core/ui/components/app_card.dart';
import 'package:esas/core/ui/components/app_empty_state.dart';
import 'package:esas/core/ui/components/app_error_state.dart';
import 'package:esas/core/ui/components/app_record_field.dart';
import 'package:esas/core/ui/components/app_skeleton.dart';
import 'package:esas/features/profile/data/models/family.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/profile_tab_controllers.dart';

/// Daftar anggota keluarga yang terdaftar di HR.
class ProfileFamilyView extends GetView<ProfileFamilyController> {
  const ProfileFamilyView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Info Keluarga'), centerTitle: true),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const AppSkeletonList(
            count: 3,
            padding: EdgeInsets.all(AppSpacing.page),
          );
        }

        if (controller.errorMessage.isNotEmpty) {
          return AppErrorState(
            message: controller.errorMessage.value,
            onRetry: controller.setupProfile,
          );
        }

        final List<Family> members =
            controller.userInfo.value.families ?? const <Family>[];

        if (members.isEmpty) {
          return AppEmptyState(
            icon: Icons.people_alt_outlined,
            title: 'Belum ada data keluarga',
            message:
                'Data keluarga diisi oleh HR. Hubungi HR bila ada anggota '
                'keluarga yang perlu didaftarkan.',
            actionLabel: 'Muat ulang',
            onAction: controller.setupProfile,
          );
        }

        return RefreshIndicator(
          onRefresh: controller.setupProfile,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.lg,
              AppSpacing.page,
              AppSpacing.bottomSafe,
            ),
            itemCount: members.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) => _FamilyCard(
              family: members[index],
              birthdate: controller.formatBirthdate(members[index].birthdate),
            ),
          ),
        );
      }),
    );
  }
}

/// Satu anggota keluarga: nama, hubungan, dan tiga bidang catatan.
class _FamilyCard extends StatelessWidget {
  const _FamilyCard({required this.family, required this.birthdate});

  final Family family;
  final String birthdate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  family.fullname ?? 'Nama tidak tersedia',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // Hubungan keluarga adalah atribut, bukan status, jadi lencananya
              // netral: nada berwarna di aplikasi ini dicadangkan untuk keadaan
              // yang bisa berubah menjadi baik atau buruk.
              Flexible(
                child: AppBadge(label: family.relationship ?? '—', dense: true),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AppRecordFieldPair(
            first: AppRecordField(
              label: 'Tanggal lahir',
              value: birthdate,
              mono: true,
            ),
            second: AppRecordField(
              label: 'Status pernikahan',
              value: family.maritalStatus ?? '',
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppRecordField(label: 'Pekerjaan', value: family.job ?? ''),
        ],
      ),
    );
  }
}

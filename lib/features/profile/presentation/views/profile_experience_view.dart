import 'package:esas/core/theme/app_dimens.dart';
import 'package:esas/core/theme/app_palette.dart';
import 'package:esas/core/ui/components/app_badge.dart';
import 'package:esas/core/ui/components/app_card.dart';
import 'package:esas/core/ui/components/app_empty_state.dart';
import 'package:esas/core/ui/components/app_error_state.dart';
import 'package:esas/core/ui/components/app_record_field.dart';
import 'package:esas/core/ui/components/app_skeleton.dart';
import 'package:esas/features/profile/data/models/workexp.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/profile_tab_controllers.dart';

/// Riwayat pengalaman kerja sebelum bergabung.
class ProfileExperienceView extends GetView<ProfileExperienceController> {
  const ProfileExperienceView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Info Pengalaman Kerja'),
        centerTitle: true,
      ),
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
            onRetry: controller.fetchWorkExperienceData,
          );
        }

        final List<WorkExperienceModel> experiences =
            controller.workExperiences;

        if (experiences.isEmpty) {
          return AppEmptyState(
            icon: Icons.work_outline_rounded,
            title: 'Belum ada pengalaman kerja',
            message:
                'Riwayat pekerjaan sebelumnya diisi oleh HR dari berkas '
                'lamaran Anda.',
            actionLabel: 'Muat ulang',
            onAction: controller.fetchWorkExperienceData,
          );
        }

        return RefreshIndicator(
          onRefresh: controller.fetchWorkExperienceData,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.lg,
              AppSpacing.page,
              AppSpacing.bottomSafe,
            ),
            itemCount: experiences.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (_, index) => _ExperienceCard(
              experience: experiences[index],
              period: controller.formatWorkPeriod(
                experiences[index].start,
                experiences[index].finish,
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _ExperienceCard extends StatelessWidget {
  const _ExperienceCard({required this.experience, required this.period});

  final WorkExperienceModel experience;
  final String period;

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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      experience.companyName,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      experience.position ?? 'Posisi tidak tersedia',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.palette.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (experience.certification) ...[
                const SizedBox(width: AppSpacing.sm),
                const Flexible(
                  child: AppBadge(
                    label: 'Bersertifikat',
                    tone: AppBadgeTone.success,
                    icon: Icons.workspace_premium_outlined,
                    dense: true,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AppRecordField(label: 'Periode', value: period, mono: true),
        ],
      ),
    );
  }
}

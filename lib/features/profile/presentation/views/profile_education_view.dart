import 'package:esas/core/theme/app_dimens.dart';
import 'package:esas/core/ui/components/app_badge.dart';
import 'package:esas/core/ui/components/app_card.dart';
import 'package:esas/core/ui/components/app_empty_state.dart';
import 'package:esas/core/ui/components/app_error_state.dart';
import 'package:esas/core/ui/components/app_record_field.dart';
import 'package:esas/core/ui/components/app_skeleton.dart';
import 'package:esas/features/profile/data/models/foeducation.dart';
import 'package:esas/features/profile/data/models/ineducation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/profile_tab_controllers.dart';

/// Riwayat pendidikan, formal dan informal, dalam dua tab.
class ProfileEducationView extends GetView<ProfileEducationController> {
  const ProfileEducationView({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Info Pendidikan'),
          centerTitle: true,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Formal'),
              Tab(text: 'Informal'),
            ],
          ),
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
              onRetry: controller.fetchEducationData,
            );
          }

          return TabBarView(
            children: [
              _EducationList(
                empty: 'Belum ada data pendidikan formal',
                onRetry: controller.fetchEducationData,
                items: [
                  for (final FormalEducation education
                      in controller.formalEducations)
                    _FormalCard(
                      education: education,
                      period: controller.formatEducationPeriod(
                        education.start,
                        education.finish,
                      ),
                    ),
                ],
              ),
              _EducationList(
                empty: 'Belum ada data pendidikan informal',
                onRetry: controller.fetchEducationData,
                items: [
                  for (final InformalEducationModel education
                      in controller.informalEducations)
                    _InformalCard(
                      education: education,
                      period: controller.formatEducationPeriod(
                        education.start,
                        education.finish,
                      ),
                    ),
                ],
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _EducationList extends StatelessWidget {
  const _EducationList({
    required this.items,
    required this.empty,
    required this.onRetry,
  });

  final List<Widget> items;
  final String empty;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return AppEmptyState(
        icon: Icons.school_outlined,
        title: empty,
        message: 'Riwayat pendidikan diisi oleh HR dari berkas kepegawaian.',
        actionLabel: 'Muat ulang',
        onAction: onRetry,
      );
    }

    return RefreshIndicator(
      onRefresh: onRetry,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          AppSpacing.lg,
          AppSpacing.page,
          AppSpacing.bottomSafe,
        ),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (_, index) => items[index],
      ),
    );
  }
}

/// Satu jenjang pendidikan formal.
///
/// Judulnya menyebut institusi SATU kali. Versi sebelumnya menuliskan
/// `'${education.institution} - ${education.institution}'`, jadi setiap kartu
/// membaca "SMK Negeri 1 - SMK Negeri 1" — sebuah nilai yang dijoin dengan
/// dirinya sendiri.
class _FormalCard extends StatelessWidget {
  const _FormalCard({required this.education, required this.period});

  final FormalEducation education;
  final String period;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            education.institution,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppRecordField(label: 'Jurusan', value: education.majors),
          const SizedBox(height: AppSpacing.lg),
          AppRecordFieldPair(
            first: AppRecordField(
              label: 'Nilai/IPK',
              value: education.score.toString(),
              mono: true,
            ),
            second: AppRecordField(label: 'Periode', value: period, mono: true),
          ),
        ],
      ),
    );
  }
}

/// Satu pelatihan atau kursus.
class _InformalCard extends StatelessWidget {
  const _InformalCard({required this.education, required this.period});

  final InformalEducationModel education;
  final String period;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  education.institution,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (education.certification) ...[
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

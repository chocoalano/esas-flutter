import 'package:esas/app/data/Profile/workexp.m.dart'; // Pastikan ini mendefinisikan WorkExperienceModel
import 'package:esas/app/modules/profile/profile_pages.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/profile_experience_controller.dart'; // Pastikan import controller ini benar

class ProfileExperienceView extends GetView<ProfileExperienceController> {
  const ProfileExperienceView({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          return;
        }
        Get.offAllNamed(ProfileRoutes.PROFILE);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Info Pengalaman Kerja',
          ), // Judul yang lebih deskriptif
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: () => Get.offAllNamed(ProfileRoutes.PROFILE),
          ),
        ),
        body: Obx(() {
          if (controller.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }

          if (controller.errorMessage.isNotEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: colorScheme.error,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      controller.errorMessage.value,
                      style: textTheme.bodyLarge?.copyWith(
                        color: colorScheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () =>
                          controller.fetchWorkExperienceData(), // Retry method
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            );
          }

          // Access the workExperiences list from the controller
          final List<WorkExperienceModel> workExperiences =
              controller.workExperiences;

          if (workExperiences.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.work_outline,
                    size: 60,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Belum ada data pengalaman kerja.', // Pesan spesifik untuk data kosong
                    style: textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () => controller.fetchWorkExperienceData(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Muat Ulang'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: workExperiences.length,
            itemBuilder: (context, index) {
              final WorkExperienceModel experience = workExperiences[index];
              return _WorkExperienceCard(
                experience: experience,
                controller: controller,
              );
            },
          );
        }),
      ),
    );
  }
}

// Reusable widget for displaying a single work experience entry
class _WorkExperienceCard extends StatelessWidget {
  final WorkExperienceModel experience;
  final ProfileExperienceController
  controller; // Pass controller for formatting

  const _WorkExperienceCard({
    required this.experience,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: colorScheme.outlineVariant.withAlpha(20),
          width: 0.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              experience.companyName,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              experience.position ?? 'Posisi Tidak Tersedia',
              style: textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Divider(color: colorScheme.outlineVariant.withAlpha(20)),
            const SizedBox(height: 8),
            _InfoTileContent(
              title: 'Periode',
              value: controller.formatWorkPeriod(
                experience.start,
                experience.finish,
              ),
            ),
            const SizedBox(height: 4),
            _InfoTileContent(
              title: 'Sertifikasi',
              value: controller.formatCertificationStatus(
                experience.certification,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Reusable widget for displaying a single info title-value pair
// (Can be shared across views for consistency)
class _InfoTileContent extends StatelessWidget {
  final String title;
  final String value;

  const _InfoTileContent({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: textTheme.bodySmall?.copyWith(color: Colors.grey)),
        const SizedBox(height: 4),
        Text(
          value,
          style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// lib/app/modules/profile/views/profile_education_view.dart

import 'package:esas/app/data/Profile/foeducation.m.dart'; // Make sure this defines FormalEducation
import 'package:esas/app/data/Profile/ineducation.m.dart'; // Make sure this defines InformalEducationModel
import 'package:esas/app/modules/profile/profile_pages.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/profile_education_controller.dart';

class ProfileEducationView extends GetView<ProfileEducationController> {
  const ProfileEducationView({super.key});

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
          title: const Text('Info Pendidikan'),
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
                      onPressed: () => controller
                          .fetchEducationData(), // Updated method call
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            );
          }

          return DefaultTabController(
            length: 2, // Two tabs: Formal and Informal
            child: Column(
              children: [
                Material(
                  color: colorScheme.surface,
                  child: TabBar(
                    tabs: const [
                      Tab(text: 'Formal'),
                      Tab(text: 'Informal'),
                    ],
                    labelColor: colorScheme.primary,
                    unselectedLabelColor: colorScheme.onSurfaceVariant,
                    indicatorColor: colorScheme.primary,
                    indicatorWeight: 3,
                    labelStyle: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    unselectedLabelStyle: textTheme.titleMedium,
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      // Formal Education Tab Content
                      _buildEducationList(
                        context,
                        educationList: controller.formalEducations,
                        isFormal: true,
                        controller: controller,
                        colorScheme: colorScheme,
                        textTheme: textTheme,
                        onRetry: controller.fetchEducationData,
                      ),
                      // Informal Education Tab Content
                      _buildEducationList(
                        context,
                        educationList: controller.informalEducations,
                        isFormal: false,
                        controller: controller,
                        colorScheme: colorScheme,
                        textTheme: textTheme,
                        onRetry: controller.fetchEducationData,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // Helper widget to build the list for both formal and informal education
  Widget _buildEducationList<T>(
    BuildContext context, {
    required List<T> educationList,
    required bool isFormal,
    required ProfileEducationController controller,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
    required VoidCallback onRetry,
  }) {
    if (educationList.isEmpty) {
      final String educationType = isFormal ? 'formal' : 'informal';
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.school_outlined,
              size: 60,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Belum ada data pendidikan $educationType.',
              style: textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
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
      itemCount: educationList.length,
      itemBuilder: (context, index) {
        if (isFormal) {
          return _FormalEducationCard(
            education: educationList[index] as FormalEducation,
            controller: controller,
          );
        } else {
          return _InformalEducationCard(
            education: educationList[index] as InformalEducationModel,
            controller: controller,
          );
        }
      },
    );
  }
}

// --- Formal Education Card (from previous version, slightly adjusted) ---
class _FormalEducationCard extends StatelessWidget {
  final FormalEducation education;
  final ProfileEducationController controller;

  const _FormalEducationCard({
    required this.education,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 1, // Adjusted elevation for subtle depth
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant.withAlpha(20),
          width: 0.5,
        ), // Added border
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${education.institution} - ${education.institution}',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            _InfoTileContent(
              title: 'Jurusan',
              value: education.majors, // Changed to 'major' as per model
            ),
            const SizedBox(height: 4),
            _InfoTileContent(
              title: 'Nilai/IPK',
              value: education.score
                  .toString(), // Changed to 'gpa' as per model
            ),
            const SizedBox(height: 4),
            _InfoTileContent(
              title: 'Periode',
              value: controller.formatEducationPeriod(
                education.start, // Changed to 'startDate' as per model
                education.finish, // Changed to 'endDate' as per model
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- NEW: Informal Education Card ---
class _InformalEducationCard extends StatelessWidget {
  final InformalEducationModel education;
  final ProfileEducationController controller;

  const _InformalEducationCard({
    required this.education,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 1, // Adjusted elevation
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant.withAlpha(20),
          width: 0.5,
        ), // Added border
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              education.institution,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            _InfoTileContent(
              title: 'Penyelenggara',
              value: education.institution,
            ),
            const SizedBox(height: 4),
            _InfoTileContent(
              title: 'Periode',
              value: controller.formatEducationPeriod(
                education.start, // Changed to 'startDate' as per model
                education.finish, // Changed to 'endDate' as per model
              ), // Assuming 'year' is int
            ),
            const SizedBox(height: 4),
            _InfoTileContent(
              title: 'Sertifikasi',
              value: (education.certification) ? 'Ya' : 'Tidak',
            ),
          ],
        ),
      ),
    );
  }
}

// Reusable widget for displaying a single info title-value pair (No change needed)
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

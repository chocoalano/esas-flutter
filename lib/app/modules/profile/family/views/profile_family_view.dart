import 'package:esas/app/data/Profile/family.m.dart';
import 'package:esas/app/modules/profile/profile_pages.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart'; // Untuk DateFormat

import '../controllers/profile_family_controller.dart';
// Pastikan model Family diimpor dari file yang benar

class ProfileFamilyView extends GetView<ProfileFamilyController> {
  const ProfileFamilyView({super.key});

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
          title: const Text('Info Keluarga'),
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
                          .setupProfile(), // Panggil setupProfile untuk retry
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            );
          }

          // Dapatkan daftar anggota keluarga dari objek User di controller
          final List<Family>? familyMembers =
              controller.userInfo.value.families;

          if (familyMembers == null || familyMembers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people_alt_outlined,
                    size: 60,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Belum ada data keluarga.',
                    style: textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () =>
                        controller.setupProfile(), // Muat ulang data
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
            itemCount: familyMembers.length,
            itemBuilder: (context, index) {
              final family = familyMembers[index];
              return _FamilyListItem(
                family: family,
              ); // Tidak perlu pass controller lagi
            },
          );
        }),
      ),
    );
  }
}

// Reusable widget for displaying a single family member's details
class _FamilyListItem extends StatelessWidget {
  final Family family;

  const _FamilyListItem({required this.family});

  // Helper untuk memformat tanggal lahir (pindahkan ke sini atau buat di controller jika sering dipakai)
  String _formatBirthdate(DateTime? date) {
    if (date == null) return '-';
    return DateFormat('dd MMMM yyyy').format(date);
  }

  // Helper widget for displaying a row with two info tiles
  Widget _buildInfoRow(
    BuildContext context, {
    required String title1,
    required String value1,
    required String title2,
    required String value2,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _InfoTileContent(title: title1, value: value1),
        ),
        if (title2.isNotEmpty) ...[
          const SizedBox(width: 16),
          Expanded(
            child: _InfoTileContent(title: title2, value: value2),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: colorScheme.outlineVariant.withAlpha(20),
          width: 0.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  family.fullname ?? 'Nama Tidak Tersedia',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    family.relationship ?? '-',
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              context,
              title1: 'Tanggal Lahir',
              value1: _formatBirthdate(
                family.birthdate,
              ), // Menggunakan helper internal
              title2: 'Status Pernikahan',
              value2: family.maritalStatus ?? '-',
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              context,
              title1: 'Pekerjaan',
              value1: family.job ?? '-',
              title2: '', // Tidak ada nilai kedua
              value2: '',
            ),
          ],
        ),
      ),
    );
  }
}

// Reusable widget for displaying a single info title-value pair
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

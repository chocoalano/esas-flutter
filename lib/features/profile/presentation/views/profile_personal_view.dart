import 'package:esas/app/modules/profile/profile_pages.dart';
import 'package:esas/utils/api_constants.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/profile_personal_controller.dart';

class ProfilePersonalView extends GetView<ProfilePersonalController> {
  const ProfilePersonalView({super.key});

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
          title: const Text('Informasi Personal'),
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
                          .setupSummaryAbsen(), // Corrected retry method call
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            );
          }

          final user = controller.userInfo.value;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize:
                  MainAxisSize.min, // <-- This is correct and necessary
              children: [
                // --- Bagian Atas: Avatar, Nama, NIP, Status ---
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: colorScheme.primary.withAlpha(20),
                          backgroundImage:
                              user.avatar != null && user.avatar!.isNotEmpty
                              ? NetworkImage("$baseImageUrl/${user.avatar!}")
                              : null,
                          child: user.avatar == null || user.avatar!.isEmpty
                              ? Icon(
                                  Icons.person,
                                  size: 50,
                                  color: colorScheme.primary,
                                )
                              : null,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          user.name ?? 'Nama Tidak Tersedia',
                          style: textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'NIP: ${user.nip ?? '-'}',
                          style: textTheme.bodyLarge?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Status: ${user.status ?? '-'}',
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const Divider(height: 32),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // --- Bagian Detail Pribadi ---
                Card(
                  color: colorScheme.surface,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Detail Pribadi',
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // _buildInfoRow already uses Expanded for horizontal distribution,
                        // but the _InfoTile itself should not be Expanded for vertical axis.
                        _buildInfoRow(
                          context,
                          title1: 'Email',
                          value1: user.email ?? '-',
                          title2: 'Telepon',
                          value2: user.details?.phone ?? '-',
                        ),
                        const SizedBox(height: 16),
                        _buildInfoRow(
                          context,
                          title1: 'Jenis Kelamin',
                          value1: user.details?.gender ?? '-',
                          title2: 'Tanggal Lahir',
                          value2: controller.formattedJoinedDate,
                        ),
                        const SizedBox(height: 16),
                        _buildInfoRow(
                          context,
                          title1: 'Tempat Lahir',
                          value1: user.details?.placebirth ?? '-',
                          title2: 'Golongan Darah',
                          value2: user.details?.blood ?? '-',
                        ),
                        const SizedBox(height: 16),
                        _buildInfoRow(
                          context,
                          title1: 'Status Pernikahan',
                          value1: user.details?.maritalStatus ?? '-',
                          title2: 'Agama',
                          value2: user.details?.religion ?? '-',
                        ),
                        const Divider(height: 32),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // --- Bagian Alamat ---
                Card(
                  color: colorScheme.surface,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Alamat',
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // These are directly inside the Column, they must not be Expanded.
                        _InfoTileContent(
                          // Use _InfoTileContent here
                          title: 'Tipe Identitas',
                          value: user.address?.identityType ?? '-',
                        ),
                        const SizedBox(height: 12),
                        _InfoTileContent(
                          // Use _InfoTileContent here
                          title: 'Nomor Identitas',
                          value: user.address?.identityNumbers ?? '-',
                        ),
                        const SizedBox(height: 12),
                        _InfoTileContent(
                          // Use _InfoTileContent here
                          title: 'Alamat Lengkap',
                          value: controller.fullAddress,
                        ),
                        const SizedBox(height: 12),
                        _InfoTileContent(
                          // Use _InfoTileContent here
                          title: 'Alamat Tinggal',
                          value: user.address?.residentialAddress ?? '-',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // --- Helper Widget for Info Row ---
  // This _buildInfoRow still uses _InfoTile (which has Expanded) but only for horizontal distribution.
  // The crucial part is that _InfoTile now gets its horizontal expansion from the Row.
  // The vertical bounds for the _InfoTileContent itself are naturally determined by its content.
  Widget _buildInfoRow(
    BuildContext context, {
    required String title1,
    required String value1,
    required String title2,
    required String value2,
  }) {
    return Row(
      children: [
        // Here, _InfoTile uses Expanded because it's directly in a Row,
        // and wants to take up half the horizontal space. This is correct.
        _InfoTile(title: title1, value: value1),
        const SizedBox(width: 16),
        _InfoTile(title: title2, value: value2),
      ],
    );
  }
}

// Renamed _InfoTile to _InfoTileContent to avoid confusion.
// This widget no longer has an Expanded wrapper. It just provides its content.
class _InfoTileContent extends StatelessWidget {
  final String title;
  final String value;

  const _InfoTileContent({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    // This widget itself doesn't contain an Expanded.
    // Its height is determined by its content (Text widgets).
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

// The original _InfoTile is kept, but it's only used within _buildInfoRow
// where it's wrapped by a Row which provides horizontal bounds for its Expanded children.
// This is to differentiate when it needs to expand horizontally versus when it just needs its content.
class _InfoTile extends StatelessWidget {
  final String title;
  final String value;

  const _InfoTile({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Expanded(
      // <-- This Expanded is fine because it's inside a Row (horizontal expansion)
      child: Column(
        // This Column now has a bounded width from the Expanded
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
      ),
    );
  }
}

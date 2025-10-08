import 'package:esas/app/modules/profile/profile_pages.dart';
import 'package:esas/app/widgets/views/custom_bottom_navbar.dart';
import 'package:esas/utils/api_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart'; // Ensure 'id_ID' locale data is loaded if used

import '../controllers/profile_controller.dart';

class ProfileView extends StatelessWidget {
  final ProfileController controller = Get.put(ProfileController());

  ProfileView({super.key});

  final List<ProfileMenuItem> menuItems = const [
    ProfileMenuItem(Icons.person_outline_rounded, 'Info Personal'),
    ProfileMenuItem(Icons.work_outline_rounded, 'Info Pekerjaan'),
    ProfileMenuItem(Icons.family_restroom_rounded, 'Info Keluarga'),
    ProfileMenuItem(Icons.school_outlined, 'Info Pendidikan'),
    ProfileMenuItem(Icons.history_edu_outlined, 'Info Pengalaman Kerja'),
    ProfileMenuItem(
      Icons.account_balance_wallet_outlined,
      'Info Payroll',
    ), // Changed icon for payroll
    ProfileMenuItem(Icons.lock_outline_rounded, 'Ubah Kata Sandi'),
    ProfileMenuItem(Icons.bug_report_outlined, 'Laporan Bug'),
    ProfileMenuItem(Icons.logout_rounded, 'Keluar', isLogout: true),
  ];

  @override
  Widget build(BuildContext context) {
    // Access Theme data once at the beginning of the build method
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          return;
        }
        // Tampilkan dialog konfirmasi saat tombol kembali ditekan
        showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Keluar Aplikasi'),
            content: const Text(
              'Apakah Anda yakin ingin keluar dari aplikasi?',
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.of(context).pop(false), // Tutup dialog
                child: const Text('Tidak'),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.of(context).pop(true), // Keluar dari aplikasi
                child: const Text('Ya'),
              ),
            ],
          ),
        ).then((value) {
          if (value == true) {
            SystemNavigator.pop();
          }
        });
      },
      child: Scaffold(
        appBar: AppBar(title: Text('Profil'), centerTitle: true),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Obx(() {
                    ImageProvider? backgroundImage;
                    Widget? childWidget;
                    final String avatarUrl = controller.avatar.value;

                    if (controller.pickedImageFile.value != null) {
                      // Use picked file if available
                      backgroundImage = FileImage(
                        controller.pickedImageFile.value!,
                      );
                    } else if (avatarUrl.isNotEmpty) {
                      // Use network image if avatar URL exists
                      final String fullImageUrl =
                          avatarUrl.startsWith(baseImageUrl)
                          ? avatarUrl
                          : "$baseImageUrl/$avatarUrl";
                      backgroundImage = NetworkImage(fullImageUrl);
                    } else {
                      // Fallback to default person icon if no avatar
                      childWidget = Icon(
                        Icons.person,
                        size: 50,
                        color: colorScheme.onPrimary, // Icon color from theme
                      );
                    }

                    return GestureDetector(
                      onTap: () => controller.pickImageFromGallery(),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircleAvatar(
                            radius: 45,
                            backgroundColor:
                                colorScheme.primary, // Use theme primary color
                            backgroundImage: backgroundImage,
                            onBackgroundImageError: (exception, stackTrace) {
                              debugPrint(
                                'Error loading avatar image: $exception',
                              );
                            },
                            child: childWidget,
                          ),
                          // Camera icon overlay for changing avatar
                          Positioned(
                            bottom: 4,
                            right: 4,
                            child: Container(
                              decoration: BoxDecoration(
                                color: colorScheme.scrim.withAlpha(20),
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                Icons.camera_alt_rounded, // Rounded camera icon
                                size: 18,
                                color: colorScheme
                                    .surface, // Color legible on scrim
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                  Obx(
                    () => Text(
                      controller.name.value,
                      style: textTheme.titleLarge?.copyWith(
                        color: colorScheme.onSurface, // Consistent text color
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Obx(
                    () => Text(
                      // Format date with 'id_ID' locale if available and needed
                      '${controller.status.value} • ${controller.jobTitle.value} • ${DateFormat('dd MMMM yyyy', 'id_ID').format(controller.joined.value)}',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme
                            .onSurfaceVariant, // Use secondary text color
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Performance Score Card
                  Container(
                    decoration: BoxDecoration(
                      color: colorScheme.primary, // Use theme primary color
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        // Add subtle shadow for depth
                        BoxShadow(
                          color: colorScheme.primary.withAlpha(20),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.star_rounded,
                          color: colorScheme.onPrimary,
                        ), // Star icon with onPrimary color
                        const SizedBox(width: 8),
                        Obx(
                          () => Text(
                            '${controller.points.toStringAsFixed(3)} Performa kehadiran',
                            style: textTheme.titleMedium?.copyWith(
                              color: colorScheme
                                  .onPrimary, // Text color on primary background
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Attendance Stats Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
              decoration: BoxDecoration(
                color: colorScheme
                    .surfaceContainer, // Use a container color for distinct background
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  // Add subtle shadow
                  BoxShadow(
                    color: colorScheme.shadow.withAlpha(20),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Obx(
                    () => _buildStatItem(
                      context,
                      'Total Terlambat',
                      controller.late.value,
                    ),
                  ),
                  Obx(
                    () => _buildStatItem(
                      context,
                      'Total absensi',
                      controller.attendance.value,
                    ),
                  ),
                  Obx(
                    () => _buildStatItem(
                      context,
                      'Total Normal',
                      controller.unlate.value,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Menu Items List
            ListView.separated(
              shrinkWrap: true,
              physics:
                  const NeverScrollableScrollPhysics(), // Prevent inner list from scrolling
              itemCount: menuItems.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: 8), // Spacing between list tiles
              itemBuilder: (context, index) {
                final item = menuItems[index];
                return Card(
                  elevation:
                      0, // Cards usually have elevation, but 0 makes it flat like a list item
                  margin: EdgeInsets
                      .zero, // No external margin, controlled by ListView.separated
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ), // Rounded corners for each menu item
                  color: colorScheme
                      .surface, // Background color for each menu item
                  child: InkWell(
                    // Add InkWell for tap feedback
                    onTap: () => _handleMenuTap(
                      context,
                      index,
                    ), // Pass context to _handleMenuTap
                    borderRadius: BorderRadius.circular(
                      12,
                    ), // Match card border radius
                    child: Padding(
                      // Add padding for better visual spacing inside the list tile
                      padding: const EdgeInsets.symmetric(
                        vertical: 4.0,
                        horizontal: 8.0,
                      ),
                      child: ListTile(
                        leading: Icon(
                          item.icon,
                          color: item.isLogout
                              ? colorScheme.error
                              : colorScheme.primary, // Themed colors for icons
                        ),
                        title: Text(
                          item.title,
                          style: item.isLogout
                              ? textTheme.bodyLarge?.copyWith(
                                  // Use bodyLarge for main menu text
                                  color: colorScheme
                                      .error, // Error color for logout
                                  fontWeight: FontWeight
                                      .w500, // Slightly bolder for importance
                                )
                              : textTheme.bodyLarge?.copyWith(
                                  color: colorScheme
                                      .onSurface, // Default text color
                                  fontWeight: FontWeight.normal,
                                ),
                        ),
                        trailing: Icon(
                          Icons.chevron_right_rounded, // Rounded chevron icon
                          color: colorScheme
                              .onSurfaceVariant, // Secondary icon color
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        bottomNavigationBar: const CustomBottomNavBar(),
      ),
    );
  }

  // Helper method for statistical items
  Widget _buildStatItem(BuildContext context, String title, int value) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Text(
          value.toString().padLeft(2, '0'),
          style: textTheme.headlineSmall?.copyWith(
            // Larger, bold value
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: textTheme.bodySmall?.copyWith(
            // Smaller, themed title
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  // Handle menu item taps
  void _handleMenuTap(BuildContext context, int index) {
    final item = menuItems[index];

    if (item.isLogout) {
      // Show confirmation dialog before logout
      Get.defaultDialog(
        title: "Konfirmasi Keluar",
        titleStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
        middleText: "Apakah Anda yakin ingin keluar dari akun?",
        middleTextStyle: Theme.of(context).textTheme.bodyLarge,
        backgroundColor: Theme.of(context).colorScheme.surface,
        radius: 12,
        confirm: ElevatedButton(
          onPressed: () {
            Get.back(); // Close dialog
            controller.logout(); // Perform logout
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
          child: const Text("Keluar"),
        ),
        cancel: OutlinedButton(
          onPressed: () => Get.back(), // Close dialog
          style: OutlinedButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
            side: BorderSide(color: Theme.of(context).colorScheme.outline),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
          child: const Text("Batal"),
        ),
      );
    } else {
      // Navigate based on menu item title
      switch (item.title) {
        case 'Info Personal':
          Get.toNamed(
            ProfileRoutes.PROFILE_PERSONAL,
          ); // Use Get.toNamed for pushing
          break;
        case 'Info Pekerjaan':
          Get.toNamed(ProfileRoutes.PROFILE_WORKED);
          break;
        case 'Info Keluarga':
          Get.toNamed(ProfileRoutes.PROFILE_FAMILY);
          break;
        case 'Info Pendidikan':
          Get.toNamed(ProfileRoutes.PROFILE_EDUCATION);
          break;
        case 'Info Pengalaman Kerja':
          Get.toNamed(ProfileRoutes.PROFILE_EXPERIENCE);
          break;
        case 'Info Payroll':
          Get.toNamed(ProfileRoutes.PROFILE_PAYROLL);
          break;
        case 'Ubah Kata Sandi':
          Get.toNamed(ProfileRoutes.PROFILE_CHANGE_PASSWORD);
          break;
        case 'Laporan Bug':
          Get.toNamed(ProfileRoutes.PROFILE_BUG_REPORT);
          break;
        default:
          debugPrint('Unhandled menu item: ${item.title}');
      }
    }
  }
}

// Helper class for menu items
class ProfileMenuItem {
  final IconData icon;
  final String title;
  final bool isLogout;

  const ProfileMenuItem(this.icon, this.title, {this.isLogout = false});
}

import 'package:esas/app/modules/home/controllers/home_controller.dart';
import 'package:esas/app/modules/home/views/widgets/announcement_carousel.dart';
import 'package:esas/app/modules/home/views/widgets/app_bar_content.dart';
import 'package:esas/app/modules/home/views/widgets/recent_activity.dart';
import 'package:esas/app/modules/home/views/widgets/summary_grid.dart';
import 'package:esas/app/routes/app_pages.dart';
import 'package:esas/app/widgets/controllers/theme_controller.dart';
import 'package:esas/app/widgets/views/custom_bottom_navbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

/// Main home view with AppBar background and dynamic headers
class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<ThemeController>(
      init: ThemeController(),
      builder: (themeController) {
        return PopScope(
          canPop: false, // Mencegah navigasi kembali secara default
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
            appBar: PreferredSize(
              preferredSize: const Size.fromHeight(60),
              child: Stack(
                children: [
                  // AppBar background logo
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0.1,
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: Image.asset('assets/images/logo-removebg.png'),
                      ),
                    ),
                  ),
                  // AppBar content
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: GetBuilder<HomeController>(
                        builder: (controller) => Obx(
                          () => AppBarContent(
                            themeController: themeController,
                            userName: controller.userName.value,
                            date: controller.currentDate.value,
                            userAvatarUrl: controller.userAvatarUrl.value,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            body: GetBuilder<HomeController>(
              builder: (controller) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      _AttendanceHeader(),
                      const SizedBox(height: 24),
                      SummaryGrid(controller: controller),
                      const SizedBox(height: 24),
                      _AnnouncementHeader(),
                      const SizedBox(height: 12),
                      AnnouncementCarousel(
                        controller: controller,
                        themeController: themeController,
                      ),
                      const SizedBox(height: 24),
                      _RecentActivityHeader(),
                      const SizedBox(height: 12),
                      RecentActivityList(controller: controller),
                      const SizedBox(height: 16),
                    ],
                  ),
                );
              },
            ),
            bottomNavigationBar: const CustomBottomNavBar(),
          ),
        );
      },
    );
  }
}

class _AttendanceHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Informasi Absensi',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        TextButton(
          onPressed: () => Get.offAllNamed(Routes.ATTENDANCE_LIST),
          child: Text(
            'Lihat riwayat',
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontSize: theme.textTheme.bodyMedium?.fontSize,
            ),
          ),
        ),
      ],
    );
  }
}

class _AnnouncementHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Pengumuman',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        TextButton(
          onPressed: () => Get.offAllNamed(Routes.ANNOUNCEMENT),
          child: Text(
            'Lihat lainnya',
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontSize: theme.textTheme.bodyMedium?.fontSize,
            ),
          ),
        ),
      ],
    );
  }
}

class _RecentActivityHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Aktivitas',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        TextButton(
          onPressed: () => Get.offAllNamed(Routes.ACTIVITY),
          child: Text(
            'Lihat lainnya',
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontSize: theme.textTheme.bodyMedium?.fontSize,
            ),
          ),
        ),
      ],
    );
  }
}

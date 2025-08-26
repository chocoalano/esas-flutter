import 'package:esas/app/data/announcement/list.m.dart';
import 'package:esas/app/modules/home/controllers/home_controller.dart';
import 'package:esas/app/routes/app_pages.dart';
import 'package:esas/app/widgets/controllers/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AnnouncementCarousel extends StatelessWidget {
  final HomeController controller;
  final ThemeController themeController;
  const AnnouncementCarousel({
    super.key,
    required this.controller,
    required this.themeController,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = themeController.isDarkMode;
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;

    return Obx(() {
      final announcements = controller.announcements;
      if (announcements.isEmpty) {
        return SizedBox(
          height: 160,
          child: Center(
            child: Text(
              'Tidak ada pengumuman',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        );
      }

      return SizedBox(
        height: 180,
        child: PageView.builder(
          key: ValueKey(isDark),
          itemCount: announcements.length,
          controller: PageController(viewportFraction: 1.1),
          itemBuilder: (context, index) {
            final Announcement item = announcements[index];
            // compute item width smaller than viewport
            final itemWidth = screenWidth / 1.1;
            return Center(
              child: SizedBox(
                width: itemWidth,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Material(
                    color: theme.colorScheme.surface,
                    elevation: 0,
                    child: InkWell(
                      onTap: () => Get.offAllNamed(
                        Routes.ANNOUNCEMENT_DETAIL,
                        arguments: item.id,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title ?? '',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: Text(
                                item.content!.replaceAll(
                                  RegExp(r'<[^>]*>'),
                                  '',
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface.withAlpha(
                                    180,
                                  ),
                                ),
                              ),
                            ),
                            Align(
                              alignment: Alignment.bottomRight,
                              child: TextButton(
                                onPressed: () => Get.offAllNamed(
                                  Routes.ANNOUNCEMENT_DETAIL,
                                  arguments: item.id,
                                ),
                                child: Text(
                                  'Lihat Detail',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
    });
  }
}

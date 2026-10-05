import 'package:esas/app/routes/app_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../controllers/announcement_controller.dart';

class AnnouncementView extends StatelessWidget {
  const AnnouncementView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(AnnouncementController());
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengumuman'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Get.offAllNamed(Routes.HOME),
        ),
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.lists.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.lists.isEmpty) {
          return Center(
            child: Text(
              'Belum ada pengumuman.',
              style: theme.textTheme.bodyMedium,
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: controller.resetAndFetch,
          child: ListView.builder(
            controller: controller.scrollController,
            itemCount: controller.lists.length + 1,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              if (index < controller.lists.length) {
                final announcement = controller.lists[index];
                return _buildAnnouncementCard(announcement, theme);
              } else {
                return Obx(() {
                  if (controller.isLoadMore.value) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  } else {
                    return const SizedBox();
                  }
                });
              }
            },
          ),
        );
      }),
    );
  }

  Widget _buildAnnouncementCard(dynamic announcement, ThemeData theme) {
    return InkWell(
      onTap: () =>
          Get.toNamed(Routes.ANNOUNCEMENT_DETAIL, arguments: announcement.id),
      child: Card(
        color: theme.colorScheme.surface,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                announcement.title ?? '(Tanpa Judul)',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Html(
                data: announcement.content ?? '',
                style: {
                  "body": Style(
                    margin: Margins.zero,
                    fontSize: FontSize.medium,
                    color: theme.textTheme.bodyMedium?.color,
                  ),
                },
                onLinkTap: (url, attributes, element) {
                  if (url == null) return;
                  final uri = Uri.tryParse(url);
                  if (uri != null) {
                    launchUrl(
                      uri,
                      mode: LaunchMode.externalApplication,
                    ).catchError((e) {
                      debugPrint('Gagal membuka URL: $url');
                      return false;
                    });
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

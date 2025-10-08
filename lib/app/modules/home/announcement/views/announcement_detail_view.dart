import 'package:esas/app/routes/app_pages.dart';
import 'package:esas/app/widgets/views/snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../controllers/announcement_detail_controller.dart';

class AnnouncementDetailView extends StatelessWidget {
  const AnnouncementDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(AnnouncementDetailController());
    final theme = Theme.of(context);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          return;
        }
        Get.offAllNamed(Routes.HOME);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Detail Pengumuman'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: () => Get.offAllNamed(Routes.HOME),
          ),
        ),
        body: Obx(() {
          if (controller.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }

          final announcement = controller.detail.value;
          if (announcement == null) {
            return const Center(child: Text("Detail tidak tersedia"));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  announcement.title ?? '(Tanpa Judul)',
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Html(
                  data: announcement.content ?? '',
                  onLinkTap: (url, attributes, element) async {
                    if (url == null) return;
                    final uri = Uri.tryParse(url);
                    if (uri != null) {
                      try {
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                      } catch (e) {
                        showErrorSnackbar('Gagal membuka URL: $url, error: $e');
                      }
                    }
                  },
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

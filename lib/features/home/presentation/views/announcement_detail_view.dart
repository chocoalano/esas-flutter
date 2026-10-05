import 'package:esas/core/theme/app_dimens.dart';
import 'package:esas/core/theme/app_palette.dart';
import 'package:esas/core/ui/components/app_error_state.dart';
import 'package:esas/core/ui/components/app_skeleton.dart';
import 'package:esas/core/utils/date_formatter.dart';
import 'package:esas/core/utils/string_utils.dart';
import 'package:esas/features/home/presentation/routes/home_routes.dart';
import 'package:esas/core/ui/dialogs/app_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../controllers/announcement_detail_controller.dart';

/// Satu pengumuman, dengan tata letak aslinya.
///
/// Tiga keadaan, seperti setiap layar lain di aplikasi ini: rangka selama
/// dimuat, keadaan galat dengan tombol coba lagi bila permintaannya gagal, dan
/// naskahnya bila ia sampai. Sebelumnya keadaan galat dan keadaan "belum
/// dimuat" sama-sama berakhir pada kalimat "Detail tidak tersedia" tanpa satu
/// pun jalan keluar selain menekan tombol kembali.
class AnnouncementDetailView extends GetView<AnnouncementDetailController> {
  const AnnouncementDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          return;
        }
        Get.offAllNamed(HomeRoutes.home);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pengumuman'),
          titleSpacing: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Kembali',
            onPressed: () => Get.offAllNamed(HomeRoutes.home),
          ),
        ),
        body: Obx(() {
          if (controller.isLoading.value) {
            return const _DetailSkeleton();
          }

          final announcement = controller.detail.value;

          if (announcement == null) {
            return AppErrorState(
              title: 'Pengumuman tidak termuat',
              message:
                  'Isi pengumuman ini belum sampai. Periksa koneksi Anda, '
                  'lalu coba lagi.',
              onRetry: controller.loadDetail,
            );
          }

          final List<String> meta = <String>[
            if (announcement.publishedBy != null) announcement.publishedBy!,
            if (announcement.createdAt != null)
              DateFormatter.timestamp(announcement.createdAt, 'd MMMM yyyy'),
          ];

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.lg,
              AppSpacing.page,
              AppSpacing.bottomSafe,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  // Helper yang sama dengan daftar dan kartu Beranda.
                  sentenceFromShout(announcement.title) ?? '(Tanpa judul)',
                  style: theme.textTheme.headlineSmall,
                ),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    meta.join(' • '),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: palette.textMuted,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                Divider(height: 1, color: palette.borderSubtle),
                const SizedBox(height: AppSpacing.lg),
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

/// Rangka satu naskah: judul, baris meta, lalu beberapa baris teks.
///
/// Bentuknya mengikuti apa yang akan menggantikannya, sehingga halaman tidak
/// melompat pada saat isinya mendarat — persis saat mata mulai membaca.
class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.lg,
        AppSpacing.page,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSkeleton(height: 22, width: 240),
          SizedBox(height: AppSpacing.md),
          AppSkeleton(height: 12, width: 160),
          SizedBox(height: AppSpacing.xxl),
          AppSkeleton(height: 12, width: double.infinity),
          SizedBox(height: AppSpacing.snug),
          AppSkeleton(height: 12, width: double.infinity),
          SizedBox(height: AppSpacing.snug),
          AppSkeleton(height: 12, width: double.infinity),
          SizedBox(height: AppSpacing.snug),
          AppSkeleton(height: 12, width: 200),
        ],
      ),
    );
  }
}

import 'package:esas/core/theme/app_dimens.dart';
import 'package:esas/core/theme/app_palette.dart';
import 'package:esas/core/ui/components/app_card.dart';
import 'package:esas/core/ui/components/app_empty_state.dart';
import 'package:esas/core/ui/components/app_skeleton.dart';
import 'package:esas/features/home/data/models/announcement.dart';
import 'package:esas/features/home/presentation/routes/home_routes.dart';
import 'package:esas/core/utils/date_formatter.dart';
import 'package:esas/core/utils/string_utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/announcement_controller.dart';

/// Daftar pengumuman.
///
/// Kartu di daftar ini sebelumnya merender isi HTML pengumuman secara penuh
/// lewat paket `flutter_html` — sebuah pengumuman sepanjang tiga paragraf
/// menghasilkan kartu setinggi layar, dan menggulir daftarnya berarti membaca
/// semuanya. Di sini isi dipotong menjadi cuplikan tiga baris; naskah lengkap
/// dengan tata letak aslinya tetap ada di halaman rincian.
class AnnouncementView extends GetView<AnnouncementController> {
  const AnnouncementView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Kembali',
          onPressed: () => Get.offAllNamed(HomeRoutes.home),
        ),
        title: const Text('Pengumuman'),
        titleSpacing: 0,
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.lists.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(top: AppSpacing.lg),
            child: AppSkeletonList(count: 4),
          );
        }

        if (controller.lists.isEmpty) {
          return const AppEmptyState(
            icon: Icons.campaign_outlined,
            title: 'Belum ada pengumuman',
            message: 'Pengumuman dari perusahaan akan muncul di sini.',
          );
        }

        return RefreshIndicator(
          onRefresh: controller.resetAndFetch,
          child: ListView.separated(
            controller: controller.scrollController,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.lg,
              AppSpacing.page,
              AppSpacing.bottomSafe,
            ),
            itemCount: controller.lists.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) {
              if (index < controller.lists.length) {
                return _AnnouncementCard(item: controller.lists[index]);
              }
              return Obx(
                () => controller.isLoadMore.value
                    ? const AppSkeletonRow(showLeading: false)
                    : const SizedBox.shrink(),
              );
            },
          ),
        );
      }),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({required this.item});

  final Announcement item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;

    // Sama seperti di carousel: endpoint daftar tidak mengirim badan
    // pengumuman, jadi null di sini berarti "tidak diminta". Barisnya dibangun
    // di sekitar judul, penerbit, dan tanggal — yang memang ada.
    // `excerpt` HARUS ikut melewati pembersih, bukan hanya `content`.
    // Ia dikirim server sebagai potongan HTML persis seperti badan
    // pengumumannya, jadi versi yang memakainya apa adanya mencetak
    // "&nbsp;BERIKUT LINK UNTUK MENGAKSES FILE TERSEBUT" ke layar — dan karena
    // `excerpt` lebih didahulukan, jalur yang bersih justru yang tidak pernah
    // terpakai pada baris daftar.
    final String? snippet =
        htmlToPlainText(item.excerpt) ?? htmlToPlainText(item.content);
    final String? meta = _metaLine(item);

    return AppCard(
      onTap: () =>
          Get.toNamed(HomeRoutes.announcementDetail, arguments: item.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppIconBox(icon: Icons.campaign_outlined, size: 34),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      // Judul yang datang HURUF KAPITAL SEMUA diturunkan di
                      // sini juga, dengan helper yang sama yang dipakai kartu
                      // di Beranda — satu judul tidak boleh dirender dalam dua
                      // bentuk di dua layar.
                      sentenceFromShout(item.title) ?? '(Tanpa judul)',
                      style: theme.textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (meta != null) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        meta,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: palette.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (snippet != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              snippet,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              // `Flexible`: pada 320dp dengan skala teks 1,5 kalimat ini lebih
              // lebar daripada kartunya. Ia membungkus, bukan meluap.
              Flexible(
                child: Text(
                  'Baca selengkapnya',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xxs),
              Icon(
                Icons.arrow_forward_rounded,
                size: AppIconSizes.sm,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String? _metaLine(Announcement item) {
    final parts = <String>[
      if (item.publishedBy != null) item.publishedBy!,
      if (item.createdAt != null)
        DateFormatter.timestamp(item.createdAt, 'd MMM yyyy'),
    ];

    return parts.isEmpty ? null : parts.join(' • ');
  }
}

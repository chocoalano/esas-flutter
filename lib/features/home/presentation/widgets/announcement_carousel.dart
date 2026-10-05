import 'package:esas/core/theme/app_dimens.dart';
import 'package:esas/core/theme/app_palette.dart';
import 'package:esas/core/ui/components/app_card.dart';
import 'package:esas/core/ui/components/app_inline_notice.dart';
import 'package:esas/core/ui/components/app_skeleton.dart';
import 'package:esas/core/ui/layout/app_breakpoints.dart';
import 'package:esas/core/utils/date_formatter.dart';
import 'package:esas/core/utils/string_utils.dart';
import 'package:esas/features/home/data/models/announcement.dart';
import 'package:esas/features/home/presentation/controllers/home_controller.dart';
import 'package:esas/features/home/presentation/routes/home_routes.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Pengumuman aktif, sebagai kartu yang bisa digeser.
///
/// Tiga hal yang membentuknya, dan ketiganya pernah salah:
///
/// * [PageController] dimiliki state, bukan dibuat ulang di setiap `build` —
///   versi sebelumnya mengembalikan posisi geser pengguna ke kartu pertama
///   setiap kali dasbor disegarkan.
/// * `viewportFraction` di bawah 1, sehingga tepi kartu berikutnya terlihat.
///   Itu satu-satunya petunjuk yang dibutuhkan orang untuk tahu deretan ini
///   bisa digeser, dan lebih jujur daripada sepasang panah.
/// * Tingginya ikut skala teks. Tinggi tetap 168px berarti pada setelan teks
///   besar cuplikannya dijepit sampai nyaris tidak ada, di layar milik orang
///   yang justru menaikkan skala teks supaya bisa membaca.
///
/// Menggeser adalah kompromi untuk kaca sempit, jadi ia berhenti begitu kacanya
/// tidak sempit lagi: di kelas ukuran dua kolom deretan ini menjadi tumpukan
/// kartu biasa, karena sebuah rel yang bisa digeser di kolom selebar 400dp
/// menyembunyikan isi yang sebetulnya muat.
class AnnouncementCarousel extends StatefulWidget {
  const AnnouncementCarousel({super.key, required this.controller});

  final HomeController controller;

  @override
  State<AnnouncementCarousel> createState() => _AnnouncementCarouselState();
}

class _AnnouncementCarouselState extends State<AnnouncementCarousel> {
  late final PageController _pageController = PageController(
    viewportFraction: 0.88,
  );
  int _current = 0;

  /// Berapa kartu yang digambar sekaligus ketika deretannya menjadi tumpukan.
  ///
  /// Tiga, bukan semuanya: bagian ini tetap tingkat ketiga halaman, dan sebuah
  /// tumpukan sepuluh pengumuman akan mengubahnya menjadi layar daftar yang
  /// sudah ada di balik tombol "Semua".
  static const int _stackedLimit = 3;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;

    // Tinggi dasar dikali skala teks yang sedang berlaku, dijepit supaya
    // setelan ekstrem tidak menghasilkan kartu setinggi layar.
    final double scale = (MediaQuery.textScalerOf(context).scale(14) / 14)
        .clamp(1.0, 1.6);
    final double height = 160 * scale;
    final bool stacked = AppLayout.of(context).twoColumn;

    return Obx(() {
      final HomeController controller = widget.controller;
      final List<Announcement> items = controller.announcements.toList();

      // Rangka lebih dulu. Sebuah daftar kosong yang percaya diri di atas
      // permintaan yang belum selesai adalah kebohongan yang paling mudah
      // dikirim sebuah dasbor.
      if (!controller.hasLoaded.value && controller.isLoading.value) {
        return AppSkeleton(
          height: height,
          width: double.infinity,
          borderRadius: AppRadii.xlAll,
        );
      }

      final bool failed = controller.announcementError.value != null;

      // Cabang galat mendahului cabang kosong. Kalau tidak, karyawan yang
      // koneksinya putus diberi tahu bahwa perusahaannya tidak mengumumkan
      // apa pun.
      if (items.isEmpty && failed) {
        return AppInlineNotice(
          message: 'Pengumuman belum dapat dimuat.',
          tone: AppNoticeTone.neutral,
          actionLabel: 'Coba lagi',
          onAction: () => controller.refreshDashboard(force: true),
        );
      }

      if (items.isEmpty) {
        return AppCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.lg,
          ),
          child: Row(
            children: <Widget>[
              Icon(
                Icons.campaign_outlined,
                size: AppIconSizes.lg,
                color: palette.textMuted,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'Belum ada pengumuman baru.',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        );
      }

      if (stacked) {
        final List<Announcement> shown = items
            .take(_stackedLimit)
            .toList(growable: false);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (int i = 0; i < shown.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(height: AppSpacing.md),
              SizedBox(
                height: height,
                child: _AnnouncementCard(item: shown[i]),
              ),
            ],
          ],
        );
      }

      return Column(
        children: <Widget>[
          SizedBox(
            height: height,
            child: PageView.builder(
              controller: _pageController,
              itemCount: items.length,
              padEnds: false,
              onPageChanged: (int i) => setState(() => _current = i),
              itemBuilder: (BuildContext context, int index) {
                return Padding(
                  padding: EdgeInsets.only(
                    right: index == items.length - 1 ? 0 : AppSpacing.md,
                  ),
                  child: _AnnouncementCard(item: items[index]),
                );
              },
            ),
          ),
          if (items.length > 1) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List<Widget>.generate(items.length, (int i) {
                final bool active = i == _current;

                return AnimatedContainer(
                  duration: AppDurations.fast,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 18 : 6,
                  height: 4,
                  decoration: BoxDecoration(
                    color: active ? palette.borderStrong : palette.trackSubtle,
                    borderRadius: AppRadii.pillAll,
                  ),
                );
              }),
            ),
          ],
        ],
      );
    });
  }
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({required this.item});

  final Announcement item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;

    // `content` absen dari daftar dan ada di detail — itu keputusan server, dan
    // benar: sebuah daftar pengumuman tidak boleh membawa badan setiap
    // pengumuman. Kartu ini karena itu dibangun di sekitar apa yang memang
    // dikirim daftar, dan membaca `excerpt` lebih dulu; membaca `content` saja
    // pernah membuat setiap kartu di beranda punya satu baris kosong.
    // `excerpt` HARUS ikut melewati pembersih, bukan hanya `content`.
    // Ia dikirim server sebagai potongan HTML persis seperti badan
    // pengumumannya, jadi versi yang memakainya apa adanya mencetak
    // "&nbsp;BERIKUT LINK UNTUK MENGAKSES FILE TERSEBUT" ke layar — dan karena
    // `excerpt` lebih didahulukan, jalur yang bersih justru yang tidak pernah
    // terpakai pada baris daftar.
    // Cuplikannya ikut diturunkan hurufnya, bukan hanya judulnya. Badan
    // pengumuman diketik di formulir admin yang sama, dan tangkapan layar
    // runtime memperlihatkan hasilnya: judul sudah rapi sementara dua baris di
    // bawahnya masih berteriak "BERIKUT LINK YANG BISA DI AKSES."
    final String? snippet = sentenceFromShout(
      htmlToPlainText(item.excerpt) ?? htmlToPlainText(item.content),
    );

    // Judul diturunkan dari HURUF KAPITAL SEMUA menjadi kalimat biasa. Server
    // mengirim "KEBIJAKAN JAM MASUK KERJA, IJIN TERLAMBAT, ..." dan kartu ini
    // dulu mencetaknya apa adanya pada ukuran judul.
    final String title = sentenceFromShout(item.title) ?? 'Tanpa judul';

    return AppCard(
      onTap: () =>
          Get.offAllNamed(HomeRoutes.announcementDetail, arguments: item.id),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: theme.textTheme.titleMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          // `Expanded` sendirian adalah penyebab kartu yang terlihat robek di
          // tangkapan layar: ia memberi batasan tinggi yang KETAT, jadi ketika
          // tiga baris cuplikan butuh lebih tinggi daripada sisa ruang, `Text`
          // tidak sempat ber-elipsis melainkan terpotong di tengah huruf pada
          // tepi kartu. `Align` meneruskan batasan longgar ke bawah, sehingga
          // pemotongannya kembali terjadi di batas baris — dengan elipsis, dan
          // terbaca sebagai keputusan alih-alih sebagai kerusakan.
          Expanded(
            child: snippet == null
                ? const SizedBox.shrink()
                : Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: Text(
                        snippet,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              Icon(
                Icons.person_outline_rounded,
                size: AppIconSizes.sm,
                color: palette.textMuted,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  _metaLine(item) ?? 'Pengumuman perusahaan',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: palette.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Penerbit dan tanggal, dipisahkan titik tengah. Bagian yang tidak ada
  /// dihilangkan, jadi tidak pernah muncul pemisah yang menggantung.
  static String? _metaLine(Announcement item) {
    final List<String> parts = <String>[
      // Nama penerbit, bukan sebagai kalimat: `sentenceFromShout` akan
      // menghasilkan "Tubagus angga dheviests" untuk tiga kata yang semuanya
      // nama diri.
      if (personName(item.publishedBy) != null) personName(item.publishedBy)!,
      if (item.createdAt != null)
        DateFormatter.timestamp(item.createdAt, 'd MMM yyyy'),
    ];

    return parts.isEmpty ? null : parts.join(' · ');
  }
}

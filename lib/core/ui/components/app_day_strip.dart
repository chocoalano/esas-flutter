import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_dimens.dart';
import '../../theme/app_palette.dart';

/// Strip tujuh hari: sederet sel bertone yang menjawab "minggu ini bagaimana?"
/// dalam satu tatapan.
///
/// Tujuh sel, bukan empat belas. Empat belas sel selebar sepuluh piksel adalah
/// grafik, dan grafik tidak bertahan di atas kaca tergores di bawah matahari
/// gerbang pabrik. Tujuh hari dengan sel yang benar-benar terlihat memberi
/// hampir seluruh nilai informasinya dengan tepi yang masih terbaca.
///
/// Setiap sel membawa garis 1px miliknya sendiri di samping isiannya. Itulah
/// yang membuat tepat-waktu, terlambat, dan alpa tetap bisa dibedakan pada
/// layar monokrom dan oleh mata yang tidak membedakan merah dari hijau — warna
/// tidak pernah menjadi pembawa makna tunggal di sini.
///
/// [summary] wajib dan dirender sebagai satu baris teks di bawah strip
/// (misalnya "5 hadir, 1 terlambat, 1 libur"). Ia juga menjadi satu-satunya
/// simpul semantik strip ini, sehingga pembaca layar mendapat kalimat, bukan
/// tujuh kotak tanpa nama.
class AppDayStrip extends StatelessWidget {
  const AppDayStrip({
    super.key,
    required this.days,
    required this.summary,
    this.dayCaptions,
    this.dayLabels,
    this.showSummary = true,
    this.cellHeight = 20,
    this.minCellWidth = 12,
    this.gap = 3,
  }) : assert(
         dayCaptions == null || dayCaptions.length == days.length,
         'Satu keterangan untuk satu sel, atau tidak sama sekali.',
       ),
       assert(
         dayLabels == null || dayLabels.length == days.length,
         'Satu label untuk satu sel, atau tidak sama sekali.',
       );

  /// Nada tiap hari, terurut dari yang paling lama ke hari ini. Hari tanpa data
  /// diisi `palette.neutral`.
  final List<AppTone> days;

  /// Ringkasan satu baris yang mendampingi strip. Bukan hiasan: ia yang membuat
  /// strip ini bukan pembawa makna tunggal.
  final String summary;

  /// Keterangan pendek di bawah tiap sel — biasanya nama hari yang disingkat.
  ///
  /// Tanpanya sebuah sel hanyalah posisi dalam sebuah baris, dan "mana yang
  /// hari Senin" harus dihitung mundur dari ujung kanan. Opsional supaya
  /// pemanggil yang barisnya bukan hari tetap terlayani.
  final List<String>? dayCaptions;

  /// Kalimat lengkap tiap sel untuk pembaca layar, misalnya
  /// "Senin 1 September, hadir".
  ///
  /// Bila diberikan, tiap sel menjadi simpul semantiknya sendiri dan strip
  /// berhenti menjadi satu simpul tunggal: ringkasan menjawab "minggu ini
  /// bagaimana", sedangkan label per sel menjawab "hari Rabu bagaimana" — dan
  /// pertanyaan kedua itu tidak bisa dijawab dari ringkasan.
  final List<String>? dayLabels;

  /// Boleh dimatikan hanya kalau pemanggil merender ringkasannya sendiri di
  /// tempat lain pada kartu yang sama.
  final bool showSummary;

  final double cellHeight;
  final double minCellWidth;

  /// Jarak antar sel. Tiga piksel berada di bawah tangga [AppSpacing] dengan
  /// sengaja: ini bukan jarak antar elemen, melainkan celah yang memisahkan
  /// tujuh bagian dari satu benda yang sama.
  final double gap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;
    final count = days.length;

    final List<String>? captions = dayCaptions;
    final List<String>? labels = dayLabels;

    Widget cell(int i) {
      final Widget block = Container(
        height: cellHeight,
        decoration: BoxDecoration(
          color: days[i].background,
          borderRadius: AppRadii.smAll,
          border: Border.all(color: days[i].border),
        ),
      );

      if (captions == null) return block;

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          block,
          SizedBox(height: AppSpacing.xs),
          Text(
            captions[i],
            style: theme.textTheme.labelSmall?.copyWith(
              color: palette.textMuted,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    final Widget strip = count == 0
        ? const SizedBox.shrink()
        : LayoutBuilder(
            builder: (context, constraints) {
              final totalGap = gap * (count - 1);
              final double cellWidth = constraints.hasBoundedWidth
                  ? math.max(
                      minCellWidth,
                      (constraints.maxWidth - totalGap) / count,
                    )
                  : minCellWidth;

              return Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < count; i++) ...[
                    if (i > 0) SizedBox(width: gap),
                    SizedBox(
                      width: cellWidth,
                      child: labels == null
                          ? ExcludeSemantics(child: cell(i))
                          : Semantics(
                              container: true,
                              label: labels[i],
                              child: ExcludeSemantics(child: cell(i)),
                            ),
                    ),
                  ],
                ],
              );
            },
          );

    return Semantics(
      container: true,
      label: summary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          strip,
          if (showSummary) ...[
            SizedBox(height: count == 0 ? 0 : AppSpacing.sm),
            // Dikecualikan, bukan dibiarkan: kalimatnya sudah menjadi label
            // wadah di atas, dan sebuah pembaca layar yang membacanya dua kali
            // adalah pembaca layar yang membuat orang berhenti memakainya.
            ExcludeSemantics(
              child: Text(
                summary,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: palette.textMuted,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

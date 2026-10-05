import 'package:flutter/material.dart';

import '../../theme/app_dimens.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_typography.dart';

/// Bar bersegmen untuk hitungan yang terbatas: dua dari tiga persetujuan, empat
/// dari dua belas hari cuti, tiga dari lima langkah yang sudah dilewati.
///
/// Hitungan terbatas adalah bentuk data paling umum di aplikasi ini, dan sebuah
/// bar terbaca lebih cepat daripada klausa "2 dari 3 persetujuan masuk". Yang
/// dibaca mata lebih dulu adalah berapa kotak yang tersisa, bukan kalimatnya.
///
/// Setiap segmen — terisi maupun belum — membawa garis 1px, jadi total
/// langkahnya tetap terhitung walau baru satu yang terisi. Angka monospace di
/// sampingnya adalah pasangan wajibnya: bar memberi bentuk, angka memberi nilai
/// persisnya, dan keduanya tetap terbaca tanpa warna.
class AppSegmentedProgress extends StatelessWidget {
  const AppSegmentedProgress({
    super.key,
    required this.total,
    required this.filled,
    this.tone,
    this.segmentWidth = 14,
    this.segmentHeight = 6,
    this.gap = AppSpacing.xs,
    this.showCount = true,
    this.semanticsLabel,
  });

  /// Jumlah seluruh segmen. Nol berarti tidak ada yang bisa digambar.
  final int total;

  /// Jumlah segmen yang sudah terisi; dipangkas ke rentang 0..[total].
  final int filled;

  /// Nada segmen yang terisi. Kosong berarti nada brand dari tema.
  final AppTone? tone;

  final double segmentWidth;
  final double segmentHeight;
  final double gap;

  /// Angka "2/3" di samping bar. Hanya dimatikan kalau pemanggil sudah
  /// menuliskan hitungannya di baris yang sama.
  final bool showCount;

  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;

    if (total <= 0) return const SizedBox.shrink();

    final int done = filled.clamp(0, total);
    // Segmen terisi memakai warna huruf nada, bukan isian tipisnya: pada kotak
    // setinggi enam piksel isian setipis itu tidak lagi terbaca sebagai isi.
    final Color fillColor = tone?.foreground ?? theme.colorScheme.primary;

    final Widget bar = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < total; i++) ...[
          if (i > 0) SizedBox(width: gap),
          Container(
            width: segmentWidth,
            height: segmentHeight,
            decoration: BoxDecoration(
              color: i < done ? fillColor : palette.trackSubtle,
              borderRadius: const BorderRadius.all(
                Radius.circular(AppRadii.xs),
              ),
              border: Border.all(
                color: i < done ? fillColor : palette.borderSubtle,
              ),
            ),
          ),
        ],
        if (showCount) ...[
          SizedBox(width: gap * 2),
          Text(
            '$done/$total',
            style: AppTypography.dataSmall(color: palette.textMuted),
          ),
        ],
      ],
    );

    return Semantics(
      container: true,
      label: semanticsLabel ?? '$done dari $total',
      child: ExcludeSemantics(child: bar),
    );
  }
}

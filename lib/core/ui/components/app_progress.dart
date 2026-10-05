import 'package:flutter/material.dart';

import '../../theme/app_dimens.dart';
import '../../theme/app_palette.dart';

/// Bar progres linear: satu nilai yang tidak pernah tampil tanpa skalanya.
///
/// Palung bar sengaja digambar sebagai permukaan bernilai — [AppPalette.trackSubtle]
/// di dalam garis 1px — bukan sebagai isian tembus pandang. Palung yang nyaris
/// tak terlihat membuat bar kehilangan alasan keberadaannya: mata tidak bisa
/// menilai "seberapa jauh" kalau ujung lintasannya tidak kelihatan.
///
/// Isian memakai [FractionallySizedBox], bukan pembagian `flex`. Pembagian flex
/// membulatkan nilai ke bilangan bulat, sehingga progres yang sangat kecil
/// dibulatkan menjadi nol dan bar tidak tergambar sama sekali — persis pada
/// nilai yang paling perlu dilihat orang.
class AppLinearProgress extends StatelessWidget {
  const AppLinearProgress({
    super.key,
    required this.value,
    this.label,
    this.showPercentage = true,
    this.height = 6,
    this.borderRadius = AppRadii.pillAll,
    this.accentColor,
  });

  /// Nilai progress (0.0 - 1.0)
  final double value;

  /// Label opsional di atas progress bar
  final String? label;

  /// Tampilkan persentase di samping bar
  final bool showPercentage;

  /// Tinggi bar
  final double height;

  /// Border radius
  final BorderRadius borderRadius;

  /// Warna custom (default: brand color)
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;
    final clampedValue = value.clamp(0.0, 1.0);
    final percent = (clampedValue * 100).round();
    final accentColor = this.accentColor ?? theme.colorScheme.primary;

    final Widget bar = TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: clampedValue),
      duration: AppDurations.slow,
      curve: AppMotion.standard,
      builder: (context, animated, _) {
        return Container(
          height: height,
          decoration: BoxDecoration(
            color: palette.trackSubtle,
            borderRadius: borderRadius,
            border: Border.all(color: palette.borderSubtle),
          ),
          clipBehavior: Clip.antiAlias,
          child: FractionallySizedBox(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: animated,
            heightFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                color: accentColor,
              ),
            ),
          ),
        );
      },
    );

    final Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  label!,
                  style: theme.textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (showPercentage)
                Text(
                  '$percent%',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: palette.textMuted,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        bar,
      ],
    );

    // Satu simpul semantik untuk satu nilai. Tanpa ini pembaca layar bertemu
    // label dan persentase sebagai dua potongan teks lepas, dan bar itu sendiri
    // sama sekali tidak diumumkan.
    return Semantics(
      container: true,
      label: label,
      value: '$percent persen',
      child: ExcludeSemantics(child: content),
    );
  }
}

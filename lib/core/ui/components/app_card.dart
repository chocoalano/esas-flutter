import 'package:flutter/material.dart';

import '../../theme/app_dimens.dart';
import '../../theme/app_palette.dart';

/// Permukaan dasar aplikasi: sebuah kotak berlatar `surface` dengan garis 1px.
///
/// Ini menggantikan campuran `Card`, `Container` berbayang, dan `Material`
/// berelevasi yang sebelumnya tersebar di layar-layar. Satu kelas berarti satu
/// radius, satu warna garis, dan satu perilaku sentuh — dan ketika salah satu
/// perlu berubah, ia berubah di satu tempat.
///
/// Umpan balik sentuh dibawa warna, bukan gerak: saat ditekan, isian naik satu
/// tingkat ke `surfaceRaised` dan garisnya menguat ke `borderStrong`. Tidak ada
/// transform skala — kartu di sini adalah baris data, dan baris data yang
/// mengkerut saat disentuh menggeser tetangganya. Sumber isyaratnya adalah
/// `InkWell.onHighlightChanged`, bukan `GestureDetector`, supaya awal gulir
/// membatalkan penekanan alih-alih melawan `ListView` di atasnya.
class AppCard extends StatefulWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.onTap,
    this.borderRadius = AppRadii.xlAll,
    this.color,
    this.borderColor,
    this.selected = false,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final BorderRadius borderRadius;
  final Color? color;
  final Color? borderColor;

  /// Menandai kartu sebagai pilihan yang sedang aktif: rim brand ditambah isian
  /// `brandSubtle`. Dipakai untuk pilihan aktif, bukan untuk sekadar menarik
  /// perhatian — dan sengaja satu definisi, supaya tiga alpha seleksi yang
  /// sudah saling menyimpang di layar punya satu tempat untuk pulang.
  final bool selected;

  final Clip clipBehavior;

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;

    final Color restFill =
        widget.color ??
        (widget.selected ? palette.brandSubtle : theme.colorScheme.surface);

    // Rim brand mengalahkan penegasan tekan: keadaan "terpilih" bertahan lebih
    // lama daripada satu ketukan, jadi ia yang tetap terbaca di bawah jari.
    final Color restBorder = widget.selected
        ? theme.colorScheme.primary
        : (widget.borderColor ?? palette.borderSubtle);

    final Color fill = _pressed ? palette.surfaceRaised : restFill;
    final Color border = widget.selected
        ? theme.colorScheme.primary
        : (_pressed ? palette.borderStrong : restBorder);

    final Widget content = Padding(
      padding: widget.padding,
      child: widget.child,
    );

    return AnimatedContainer(
      duration: AppDurations.fast,
      curve: AppMotion.standard,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: widget.borderRadius,
        border: Border.all(color: border),
      ),
      clipBehavior: widget.clipBehavior,
      child: widget.onTap == null
          ? content
          : Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: widget.onTap,
                onHighlightChanged: _setPressed,
                borderRadius: widget.borderRadius,
                child: content,
              ),
            ),
    );
  }
}

/// Ikon di dalam kotak bergaris — motif berulang di seluruh aplikasi.
///
/// Menggantikan `CircleAvatar` berlatar warna brand tembus pandang. Bentuk
/// persegi bersudut tumpul menyatu dengan sudut kartu di sekitarnya, sementara
/// lingkaran selalu terbaca sebagai avatar orang.
class AppIconBox extends StatelessWidget {
  const AppIconBox({
    super.key,
    required this.icon,
    this.size = 36,
    this.foreground,
    this.background,
    this.borderColor,
  });

  final IconData icon;
  final double size;
  final Color? foreground;
  final Color? background;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;
    final Color fg = foreground ?? theme.colorScheme.primary;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background ?? palette.brandSubtle,
        borderRadius: BorderRadius.circular(size / 3.6),
        border: Border.all(color: borderColor ?? fg.withValues(alpha: 0.22)),
      ),
      child: Icon(icon, size: size * 0.5, color: fg),
    );
  }
}

import 'package:flutter/material.dart';

import '../../theme/app_dimens.dart';
import '../../theme/app_palette.dart';

/// Bobot sebuah tombol. Satu layar hanya boleh punya satu [filled].
enum AppButtonVariant { filled, outlined, text }

/// Tombol aksi dengan keadaan sibuk.
///
/// Lima layar menyalin pola yang sama kata demi kata: `SizedBox(height: 48)`
/// membungkus `FilledButton`, dan di dalamnya sebuah `CircularProgressIndicator`
/// 18x18 yang MENGGANTIKAN labelnya selama pengiriman. Mengganti label adalah
/// kesalahan yang sesungguhnya di pola itu, bukan pengulangannya: tepat pada
/// detik seorang karyawan paling ingin tahu tombol mana yang barusan ia tekan,
/// tombol itu berhenti menyebut namanya sendiri, dan setiap alat bantu — dari
/// pembaca layar sampai berkas uji — kehilangan satu-satunya pegangannya.
///
/// Di sini label tetap dirender sebagai [Text] apa pun keadaannya, dan
/// indikator masuk di sampingnya, menempati slot yang sama dengan [icon].
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.variant = AppButtonVariant.filled,
    this.expand = true,
  });

  final String label;

  /// Null berarti tombol nonaktif. Saat [busy] bernilai true, tombol
  /// dinonaktifkan sendiri tanpa perlu pemanggil ikut menghitungnya.
  final VoidCallback? onPressed;

  /// Ikon di sisi kiri label. Digantikan indikator selama [busy].
  final IconData? icon;

  final bool busy;
  final AppButtonVariant variant;

  /// Selebar induknya. Nyaris selalu benar untuk aksi utama sebuah formulir;
  /// matikan bila tombol berdiri berdampingan dengan tombol lain dalam satu
  /// baris.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).palette;

    // Indikator mengambil warnanya dari gaya teks yang sudah diselesaikan
    // tombol, sehingga ia otomatis ikut ke warna nonaktif alih-alih menyala
    // dengan warna aktif di atas isian yang sudah redup.
    final Widget indicator = Builder(
      builder: (context) {
        return SizedBox(
          height: AppIconSizes.lg,
          width: AppIconSizes.lg,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: DefaultTextStyle.of(context).style.color,
            semanticsLabel: 'Sedang memproses',
          ),
        );
      },
    );

    final Widget? leading = busy
        ? indicator
        : (icon == null ? null : Icon(icon, size: AppIconSizes.lg));

    final Widget body = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (leading != null) ...[leading, const SizedBox(width: AppSpacing.sm)],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );

    final Size minimumSize = expand
        ? const Size.fromHeight(_minHeight)
        : const Size(0, _minHeight);
    final VoidCallback? effectiveOnPressed = busy ? null : onPressed;

    return switch (variant) {
      AppButtonVariant.filled => FilledButton(
        onPressed: effectiveOnPressed,
        style: FilledButton.styleFrom(minimumSize: minimumSize),
        child: body,
      ),
      AppButtonVariant.outlined => OutlinedButton(
        onPressed: effectiveOnPressed,
        style: OutlinedButton.styleFrom(minimumSize: minimumSize),
        child: body,
      ),
      AppButtonVariant.text => TextButton(
        onPressed: effectiveOnPressed,
        style: TextButton.styleFrom(
          minimumSize: minimumSize,
          disabledForegroundColor: palette.textMuted,
        ),
        child: body,
      ),
    };
  }

  /// Tinggi minimum aksi utama. Tidak pernah turun, sepadat apa pun layarnya.
  static const double _minHeight = 48;
}

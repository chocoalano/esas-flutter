import 'package:flutter/material.dart';

import '../../theme/app_dimens.dart';
import '../../theme/app_palette.dart';
import '../components/app_button.dart';

/// Nada kotak ikon sebuah dialog.
enum AppDialogTone { brand, danger, warning, info }

/// Bentuk baku SETIAP dialog aplikasi: kotak ikon, judul, kalimat penjelas,
/// isi opsional, dan baris aksi.
///
/// Sebelum ini ada lima bentuk dialog yang masing-masing menyusun `AlertDialog`
/// sendiri: judul rata tengah di satu tempat dan rata kiri di tempat lain,
/// aksi rata kanan di satu tempat dan selebar dialog di tempat lain, ikon
/// polos di satu tempat dan berkotak di tempat lain. Perbedaannya bukan
/// selera — setiap layar memperbaiki bug yang sama sendiri-sendiri, dan tiga
/// di antaranya tidak pernah memperbaikinya (lihat di bawah).
///
/// Yang dijamin bentuk ini, dan yang dulu hilang di sebagian dialog:
///
/// * **Bisa digulir.** Isi dibungkus gulir, sehingga dialog berisi kolom teks
///   tidak meluap saat keyboard naik atau skala teks 1,5 — `AlertDialog` tanpa
///   `scrollable: true` meluap dengan garis kuning-hitam persis pada kondisi
///   itu.
/// * **Tidak bisa ditutup selagi sibuk.** Selama [busy], tombol kembali dan
///   gestur tutup dimatikan. Dialog yang bisa ditutup di tengah permintaan
///   kehilangan galatnya sendiri, dan membuka jalan bagi pengiriman kedua.
/// * **Aksi sejajar di dua kolom sama lebar, dan menumpuk** (aksi utama di
///   atas) begitu skala teks membuat label tak muat berdampingan.
/// * **Warna dari tema.** Aksi destruktif memakai `ColorScheme.error`, bukan
///   teks putih tetap di atas warna brand: di mode gelap brand adalah hijau
///   terang dan teks putih di atasnya hanya 1,9:1.
///
/// Dibangun DI ATAS `AlertDialog`, bukan menggantikannya, supaya semantik rute
/// dialog, fokus, dan penutupan lewat barrier tetap milik framework.
class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    required this.title,
    required this.actions,
    this.message,
    this.content,
    this.icon,
    this.tone = AppDialogTone.brand,
    this.busy = false,
  });

  final String title;

  /// Satu-dua kalimat penjelas, rata tengah di bawah judul.
  final String? message;

  /// Isi tambahan di bawah [message]: biasanya sebuah formulir.
  final Widget? content;

  final IconData? icon;
  final AppDialogTone tone;

  /// Selama benar, dialog tidak bisa ditutup dengan tombol kembali.
  final bool busy;

  /// Aksi, dari yang paling tidak penting ke yang utama. Utama SELALU yang
  /// terakhir: di kanan pada baris, dan di paling atas pada tumpukan.
  ///
  /// Biasanya [AppButton]; lihat [AppDialog.button] untuk bentuk baku.
  final List<Widget> actions;

  /// Tombol baku di dalam dialog: label membungkus alih-alih terpotong, karena
  /// aksi yang tidak terbaca utuh adalah aksi yang tidak bisa dipastikan
  /// artinya.
  static Widget button({
    required String label,
    required VoidCallback? onPressed,
    bool primary = true,
    bool destructive = false,
    bool busy = false,
    IconData? icon,
  }) => AppButton(
    label: label,
    onPressed: onPressed,
    variant: primary ? AppButtonVariant.filled : AppButtonVariant.outlined,
    destructive: destructive,
    busy: busy,
    icon: icon,
    wrapLabel: true,
  );

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppPalette palette = theme.palette;

    final bool hasMessage = message != null && message!.isNotEmpty;

    return PopScope(
      canPop: !busy,
      child: AlertDialog(
        // Lihat catatan kelas: tanpa ini dialog berformulir meluap.
        scrollable: true,
        icon: icon == null ? null : _IconBox(icon: icon!, tone: tone),
        iconPadding: const EdgeInsets.only(top: AppSpacing.xxl),
        title: Text(title, textAlign: TextAlign.center),
        content: (hasMessage || content != null)
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (hasMessage)
                    Text(
                      message!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: palette.textMuted,
                      ),
                    ),
                  if (hasMessage && content != null)
                    const SizedBox(height: AppSpacing.lg),
                  ?content,
                ],
              )
            : null,
        actions: <Widget>[_ActionBar(actions: actions)],
      ),
    );
  }
}

/// Kotak ikon di atas judul: isian dan garis lembut dari nada dialognya.
class _IconBox extends StatelessWidget {
  const _IconBox({required this.icon, required this.tone});

  final IconData icon;
  final AppDialogTone tone;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppPalette palette = theme.palette;

    final Color ink;
    final Color fill;
    final Color line;

    switch (tone) {
      case AppDialogTone.brand:
        ink = theme.colorScheme.primary;
        fill = palette.brandSubtle;
        line = ink.withValues(alpha: 0.28);
      case AppDialogTone.danger:
        ink = palette.danger.foreground;
        fill = palette.danger.background;
        line = palette.danger.border;
      case AppDialogTone.warning:
        ink = palette.warning.foreground;
        fill = palette.warning.background;
        line = palette.warning.border;
      case AppDialogTone.info:
        ink = palette.info.foreground;
        fill = palette.info.background;
        line = palette.info.border;
    }

    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: AppRadii.xlAll,
        border: Border.all(color: line),
      ),
      child: Icon(icon, size: AppIconSizes.xxl - 2, color: ink),
    );
  }
}

/// Baris aksi: berdampingan sama lebar, atau bertumpuk dengan aksi utama di
/// atas bila skala teks membuat label tak muat sebaris.
class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.actions});

  final List<Widget> actions;

  /// Di atas skala ini label "Tetap di sini" / "Catat pengembalian" di dalam
  /// setengah lebar dialog mulai terbungkus tiga baris.
  static const double _stackAbove = 1.25;

  @override
  Widget build(BuildContext context) {
    if (actions.length <= 1) {
      return Row(
        children: <Widget>[for (final Widget a in actions) Expanded(child: a)],
      );
    }

    final bool stack =
        MediaQuery.textScalerOf(context).scale(14) / 14 > _stackAbove;

    if (stack) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (int i = actions.length - 1; i >= 0; i--) ...<Widget>[
            actions[i],
            if (i > 0) const SizedBox(height: AppSpacing.sm),
          ],
        ],
      );
    }

    return Row(
      children: <Widget>[
        for (int i = 0; i < actions.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: AppSpacing.md),
          Expanded(child: actions[i]),
        ],
      ],
    );
  }
}

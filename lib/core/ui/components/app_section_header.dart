import 'package:flutter/material.dart';

import '../../theme/app_dimens.dart';
import '../../theme/app_palette.dart';

/// Judul sebuah bagian, dengan aksi opsional di sisi kanan.
///
/// Judul ditulis sebagai micro-label: kapital, kecil, renggang, dan redup.
/// Bobotnya sengaja lebih ringan daripada isi di bawahnya — sebuah penanda
/// bagian bertugas mengelompokkan, bukan bersaing dengan data yang
/// dikelompokkannya.
///
/// Huruf kapital di sini menanggung dua beban sekaligus, jadi ia tidak pernah
/// menjadi pilihan pemanggil: ia adalah suara panel instrumen yang dituju
/// aplikasi ini, dan ia yang benar-benar memproduksi string seperti
/// "PENYESUAIAN SHIFT" — string yang tidak pernah ditulis di source dan
/// dipatok beberapa assertion di dua berkas uji.
class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.trailing,
    this.showDivider = false,
    this.dense = false,
    this.padding,
    this.naturalCase = false,
  });

  final String title;

  /// Satu kalimat penjelas di bawah judul. Opsional, dan sengaja tetap redup:
  /// bila kalimat itu perlu dibaca lebih dulu daripada datanya, ia bukan
  /// subtitle melainkan konten.
  final String? subtitle;

  final String? actionLabel;
  final VoidCallback? onAction;

  /// Dipakai bila sisi kanan bukan sekadar tombol teks.
  final Widget? trailing;

  /// Garis 1px di bawah judul, untuk bagian yang tidak berdiri di atas kartu.
  final bool showDivider;

  /// Merapatkan jarak ke konten di bawahnya. Tidak mengubah ukuran huruf dan
  /// tidak mengubah target sentuh aksinya.
  final bool dense;

  /// Menimpa jarak bawah baku bila sebuah layar butuh ritme lain.
  final EdgeInsetsGeometry? padding;

  /// Menulis judul apa adanya alih-alih dalam HURUF KAPITAL.
  ///
  /// Baku `false`, jadi setiap layar yang sudah ada tidak berubah satu piksel
  /// pun. Beranda menyalakannya: pada halaman dengan empat penanda bagian,
  /// kapital renggang terbaca administratif — seperti label pada formulir —
  /// dan itu bukan suara yang dituju layar unggulan produk ini.
  ///
  /// Sebuah bendera, bukan komponen kedua. Dua header yang berbeda hanya pada
  /// casing adalah dua tempat untuk memperbaiki hal yang sama.
  final bool naturalCase;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;

    Widget? action = trailing;
    if (action == null && actionLabel != null && onAction != null) {
      action = TextButton(
        onPressed: onAction,
        // Tema memberi tombol teks target 36dp karena kebanyakan dipakai di
        // dalam kalimat; di sini ia adalah afordans navigasi tersendiri, jadi
        // targetnya dinaikkan ke 48dp.
        style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(actionLabel!),
            const SizedBox(width: AppSpacing.xxs),
            const Icon(Icons.chevron_right_rounded, size: AppIconSizes.md),
          ],
        ),
      );
    }

    final Widget heading = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                naturalCase ? title : title.toUpperCase(),
                style: naturalCase
                    // Judul dalam huruf biasa butuh bobot dan ukuran yang lebih
                    // besar untuk memikul peran yang sama: kapital renggang
                    // menonjol karena BENTUKNYA, huruf biasa harus menonjol
                    // karena ukurannya.
                    ? theme.textTheme.titleMedium
                    : theme.textTheme.labelSmall?.copyWith(
                        color: palette.textMuted,
                      ),
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: palette.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (action != null) ...[const SizedBox(width: AppSpacing.sm), action],
      ],
    );

    return Padding(
      padding:
          padding ??
          EdgeInsets.only(bottom: dense ? AppSpacing.sm : AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          heading,
          if (showDivider) ...[
            SizedBox(height: dense ? AppSpacing.tight : AppSpacing.sm),
            Divider(height: 1, color: palette.borderSubtle),
          ],
        ],
      ),
    );
  }
}

/// Judul besar sebuah halaman, dipakai di dalam body alih-alih di app bar.
///
/// Judul yang mengalir bersama konten bisa ikut menggulir dan menyisakan lebih
/// banyak tinggi layar untuk data, sementara judul di app bar akan selamanya
/// memakan 56px teratas.
class AppPageTitle extends StatelessWidget {
  const AppPageTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.headlineMedium),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.tight),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.palette.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: AppSpacing.md),
          trailing!,
        ],
      ],
    );
  }
}

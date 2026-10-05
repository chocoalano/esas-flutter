import 'package:flutter/material.dart';

import '../../theme/app_dimens.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_typography.dart';

/// Satu bidang catatan: micro-label di atas, nilainya di bawah.
///
/// Lima berkas di tab Profil masing-masing menyimpan salinan widget ini dengan
/// nama `_InfoTile` atau `_InfoTileContent`, dan kelimanya memotong nilainya di
/// baris kedua dengan elipsis. Itu keputusan yang salah justru untuk layar ini:
/// Profil adalah layar yang dibuka karyawan untuk MEMBACAKAN angka kepada HR,
/// dan NIK 16 digit yang berakhir "…" adalah satu-satunya tugas layar itu yang
/// gagal. Karena itu di sini tidak ada `maxLines` dan tidak ada `overflow` —
/// nilai yang panjang membungkus ke baris berikutnya, dan kartunya tumbuh.
///
/// Dua pilihan lain menyusul dari sebab yang sama:
///
/// * [mono] untuk nilai yang berupa angka — NIK, nomor rekening, gaji pokok,
///   tanggal. Angka tabular berbaris lurus antar baris, jadi dua nomor rekening
///   yang berbeda satu digit terlihat berbeda.
/// * [selectable] untuk nilai yang perlu disalin. Menyalin nomor rekening ke
///   aplikasi bank mengalahkan mengetik ulang enam belas digit dari layar.
class AppRecordField extends StatelessWidget {
  const AppRecordField({
    super.key,
    required this.label,
    required this.value,
    this.mono = false,
    this.selectable = false,
    this.valueColor,
  });

  /// Nama bidang. Dirender sebagai micro-label kapital dalam `textMuted`,
  /// persis seperti judul bagian, supaya seluruh layar punya satu suara.
  final String label;

  final String value;

  /// Angka tabular, bukan huruf proporsional.
  final bool mono;

  /// Nilai yang bisa disorot dan disalin.
  final bool selectable;

  /// Menimpa warna nilai. Dipakai sangat jarang — sebuah bidang catatan bukan
  /// tempat status diumumkan.
  final Color? valueColor;

  /// Nilai kosong ditulis sebagai em dash, bukan sebagai baris hilang: bidang
  /// yang tidak diisi HR dan bidang yang tidak ada bedanya bagi karyawan.
  static const String _empty = '—';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;

    final String trimmed = value.trim();
    final bool blank = trimmed.isEmpty || trimmed == '-';
    final String shown = blank ? _empty : trimmed;

    final Color foreground =
        valueColor ?? (blank ? palette.textMuted : theme.colorScheme.onSurface);

    final TextStyle valueStyle = mono && !blank
        ? AppTypography.mono(color: foreground)
        : (theme.textTheme.bodyLarge ?? const TextStyle()).copyWith(
            color: foreground,
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(color: palette.textMuted),
        ),
        const SizedBox(height: AppSpacing.xs),
        // Nilai yang bisa disalin tetap dibangun sebagai `SelectableText` walau
        // isinya em dash, supaya tinggi baris tidak berubah saat data mendarat.
        if (selectable)
          SelectableText(shown, style: valueStyle)
        else
          Text(shown, style: valueStyle),
      ],
    );
  }
}

/// Dua bidang berdampingan, yang menumpuk begitu hurufnya membesar.
///
/// Dua kolom pada lebar 360dp cukup untuk sepasang nilai pendek, dan tidak
/// pernah cukup pada skala teks 1.5 — di sana "Status Pernikahan" saja sudah
/// tiga baris. Menumpuk adalah degradasi yang tetap terbaca; membungkus tidak.
class AppRecordFieldPair extends StatelessWidget {
  const AppRecordFieldPair({super.key, required this.first, this.second});

  final AppRecordField first;

  /// Boleh kosong: baris ganjil terakhir tetap memakai widget yang sama alih-
  /// alih memalsukan bidang kedua yang tidak ada.
  final AppRecordField? second;

  @override
  Widget build(BuildContext context) {
    final AppRecordField? second = this.second;

    if (second == null) {
      return first;
    }

    // Ambang yang sama dengan `AppDataRow`: begitu micro-label 11px tumbuh
    // melewati 14px, kolom berhenti muat.
    final bool stacked = MediaQuery.textScalerOf(context).scale(11) > 14;

    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          first,
          const SizedBox(height: AppSpacing.lg),
          second,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: first),
        const SizedBox(width: AppSpacing.lg),
        Expanded(child: second),
      ],
    );
  }
}

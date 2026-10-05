import 'package:flutter/material.dart';

import '../../theme/app_dimens.dart';
import '../../theme/app_palette.dart';

/// Dekorasi text field bersama.
///
/// Sekarang tipis: bentuk, radius, warna isian, dan warna garis semuanya sudah
/// ditetapkan oleh `inputDecorationTheme` di [AppTheme], jadi fungsi ini hanya
/// menyusun label, hint, dan ikon. Sebelumnya ia membangun ulang setiap sisi
/// border sendiri, yang berarti ada dua sumber kebenaran untuk penampilan
/// sebuah input.
///
/// Satu hal yang tidak diserahkan ke tema: baris helper selalu dipesan
/// tempatnya, lewat satu spasi sebagai nilai baku. Tanpa itu, setiap field yang
/// gagal validasi tumbuh satu baris 12px pada saat tombol kirim ditekan, dan
/// seluruh formulir di bawahnya bergeser turun — persis di detik ketika mata
/// sedang mencari kesalahan pertamanya.
InputDecoration appInputDecoration(
  ThemeData theme,
  String labelText, {
  String? hintText,
  Widget? suffixIcon,
  Widget? prefixIcon,
  String? helperText,
}) {
  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    // `??` dan bukan nilai baku parameter: pemanggil yang menyerahkan `null`
    // secara eksplisit juga harus tetap mendapat barisnya.
    helperText: helperText ?? ' ',
    suffixIcon: suffixIcon,
    prefixIcon: prefixIcon,
    // Label mengambang dipakai alih-alih label di dalam, supaya tinggi baris
    // input tidak berubah saat field mendapat fokus.
    floatingLabelBehavior: FloatingLabelBehavior.auto,
  );
}

/// Label di atas sebuah field, dengan penanda wajib opsional.
///
/// Sebagian besar formulir di aplikasi ini menulis labelnya sebagai `Text`
/// lepas di atas field. Ini menyeragamkan gayanya dan menjaga jaraknya tetap.
class AppFieldLabel extends StatelessWidget {
  const AppFieldLabel(this.label, {super.key, this.required = false});

  final String label;
  final bool required;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // `Flexible`: label wajib tetap terbaca utuh, jadi yang mengalah
          // adalah barisnya — sebuah label panjang membungkus ke baris kedua
          // alih-alih meluap di layar 320dp dengan skala teks 1,5. Tetap
          // sebuah `Text` biasa, bukan `Text.rich`, karena tes widget
          // formulir izin mencarinya dengan `find.text`.
          Flexible(
            child: Text(
              label,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          if (required)
            Text(
              ' *',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.palette.danger.foreground,
              ),
            ),
        ],
      ),
    );
  }
}

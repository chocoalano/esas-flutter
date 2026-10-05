import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_theme.dart';

/// Mewarnai bilah status dan bilah navigasi sistem agar menyatu dengan tema.
///
/// `statusBarIconBrightness` menyebut kecerahan *ikonnya*, bukan kecerahan
/// latar di belakangnya. Versi sebelumnya memasang `Brightness.dark` saat mode
/// gelap aktif — ikon gelap di atas latar gelap — sehingga jam dan indikator
/// baterai nyaris menghilang di bagian atas layar. Nilainya kini dibalik.
void applySystemUiOverlayStyle({required bool isDarkMode}) {
  final Brightness iconBrightness = isDarkMode
      ? Brightness.light
      : Brightness.dark;

  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      // iOS memakai properti tersendiri, dan artinya kebalikan dari milik
      // Android: ia menyebut kecerahan latar, bukan kecerahan ikon.
      statusBarBrightness: isDarkMode ? Brightness.dark : Brightness.light,
      statusBarIconBrightness: iconBrightness,
      systemNavigationBarColor: isDarkMode
          ? AppTheme.darkTheme.scaffoldBackgroundColor
          : AppTheme.lightTheme.scaffoldBackgroundColor,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: iconBrightness,
    ),
  );
}

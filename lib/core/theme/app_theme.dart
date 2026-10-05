import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_dimens.dart';
import 'app_palette.dart';
import 'app_typography.dart';

/// Tema aplikasi, dibangun dari token di `app_colors.dart` dan
/// `app_typography.dart`.
///
/// Prinsip yang dipegang di seluruh berkas ini:
///
/// * **Garis, bukan bayangan.** Setiap `elevation` bernilai nol dan setiap
///   permukaan dipisahkan dari latarnya oleh garis 1px. Bayangan pada latar
///   gelap hanya menghasilkan kabut, bukan kedalaman.
/// * **Satu aksen.** Hijau brand menandai apa yang bisa ditindak dan apa yang
///   sedang aktif. Sisanya netral. Ketika semuanya berwarna, tidak ada yang
///   menonjol.
/// * **Kroma tipis.** App bar memakai warna latar halaman, bukan warna
///   permukaan, sehingga bagian atas layar tidak terbaca sebagai balok terpisah
///   yang mengambang.
class AppTheme {
  const AppTheme._();

  static final ThemeData lightTheme = _build(Brightness.light);
  static final ThemeData darkTheme = _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    final ColorScheme scheme = isDark ? _darkScheme : _lightScheme;
    final AppPalette palette = isDark ? AppPalette.dark : AppPalette.light;
    final Color canvas = isDark ? AppColors.slate100 : AppColors.gray100;

    final TextTheme textTheme = AppTypography.textTheme(
      primary: scheme.onSurface,
      secondary: scheme.onSurfaceVariant,
      muted: palette.textMuted,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      canvasColor: canvas,
      textTheme: textTheme,
      extensions: <ThemeExtension<dynamic>>[palette],

      // Riak sentuh Material bawaan terlalu ramai untuk permukaan sepekat ini;
      // yang tersisa hanya perubahan warna latar yang halus. Sebelumnya baris
      // ini justru memasang InkSparkle — tinta shader paling rumit di M3, satu
      // fragment shader per ketukan pada armada Android murah — sehingga berkas
      // ini mendokumentasikan kebalikan dari yang dilakukannya.
      splashFactory: NoSplash.splashFactory,
      splashColor: scheme.onSurface.withValues(alpha: 0.04),
      highlightColor: scheme.onSurface.withValues(alpha: 0.03),

      appBarTheme: AppBarTheme(
        backgroundColor: canvas,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: AppSpacing.page,
        titleTextStyle: textTheme.titleLarge,
        // Hairline di kaki app bar menggantikan bayangan `scrolledUnder`, jadi
        // batas atas layar tetap terbaca saat konten menggulir di bawahnya.
        shape: Border(
          bottom: BorderSide(color: palette.borderSubtle, width: 1),
        ),
        iconTheme: IconThemeData(color: scheme.onSurfaceVariant, size: 22),
        actionsIconTheme: IconThemeData(
          color: scheme.onSurfaceVariant,
          size: 22,
        ),
      ),

      cardTheme: CardThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.xlAll,
          side: BorderSide(color: palette.borderSubtle),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: palette.borderSubtle,
        thickness: 1,
        space: 1,
      ),

      iconTheme: IconThemeData(color: scheme.onSurfaceVariant, size: 20),

      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xs,
        ),
        iconColor: scheme.onSurfaceVariant,
        titleTextStyle: textTheme.titleMedium,
        subtitleTextStyle: textTheme.bodySmall,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.lgAll),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surfaceSubtle,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md + 2,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: palette.textMuted),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        floatingLabelStyle: textTheme.labelMedium?.copyWith(
          color: scheme.primary,
        ),
        helperStyle: textTheme.bodySmall?.copyWith(color: palette.textMuted),
        errorStyle: textTheme.bodySmall?.copyWith(color: scheme.error),
        prefixIconColor: palette.textMuted,
        suffixIconColor: palette.textMuted,
        // Outline sebuah input adalah batas yang menyatakan keadaan, bukan
        // garis pengelompokan, jadi ia mengambil peran garis yang wajib lolos
        // 3:1 sendirian — inilah yang membuat pemisahan tiga peran garis nyata
        // dan bukan sekadar niat yang ditulis di berkas token.
        border: _inputBorder(palette.borderInteractive),
        enabledBorder: _inputBorder(palette.borderInteractive),
        disabledBorder: _inputBorder(palette.borderInteractive),
        // Fokus ditandai garis brand 1.5px, bukan 2px. Setengah piksel itu
        // membedakan "aktif" dari "berteriak".
        focusedBorder: _inputBorder(scheme.primary, width: 1.5),
        errorBorder: _inputBorder(scheme.error),
        focusedErrorBorder: _inputBorder(scheme.error, width: 1.5),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: _filledButtonStyle(scheme, textTheme, palette),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: _filledButtonStyle(scheme, textTheme, palette),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          backgroundColor: scheme.surface,
          disabledForegroundColor: palette.textMuted,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          side: BorderSide(color: palette.borderStrong),
          textStyle: textTheme.labelLarge,
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.mdAll),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.smAll),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: scheme.onSurfaceVariant,
          highlightColor: scheme.onSurface.withValues(alpha: 0.06),
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.mdAll),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.xlAll),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: palette.surfaceSubtle,
        selectedColor: palette.brandSubtle,
        side: BorderSide(color: palette.borderSubtle),
        labelStyle: textTheme.labelMedium!,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.smAll),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: scheme.surface,
        selectedItemColor: scheme.primary,
        unselectedItemColor: palette.textMuted,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: textTheme.labelSmall?.copyWith(letterSpacing: 0),
        unselectedLabelStyle: textTheme.labelSmall?.copyWith(letterSpacing: 0),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        showDragHandle: true,
        dragHandleColor: palette.borderStrong,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.xl),
          ),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.xlAll,
          side: BorderSide(color: palette.borderSubtle),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        actionTextColor: scheme.inversePrimary,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.lgAll),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearMinHeight: 2,
        circularTrackColor: palette.trackSubtle,
        linearTrackColor: palette.trackSubtle,
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: scheme.onSurface,
        unselectedLabelColor: palette.textMuted,
        labelStyle: textTheme.titleSmall,
        unselectedLabelStyle: textTheme.titleSmall,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: palette.borderSubtle,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),

      // Track sebuah switch menyatakan keadaan hidup/mati, jadi garisnya ikut
      // aturan yang sama dengan outline input.
      switchTheme: SwitchThemeData(
        trackOutlineColor: WidgetStatePropertyAll(palette.borderInteractive),
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: AppRadii.smAll,
        ),
        textStyle: textTheme.bodySmall?.copyWith(
          color: scheme.onInverseSurface,
        ),
      ),

      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: AppRadii.mdAll,
      borderSide: BorderSide(color: color, width: width),
    );
  }

  static ButtonStyle _filledButtonStyle(
    ColorScheme scheme,
    TextTheme textTheme,
    AppPalette palette,
  ) {
    return ElevatedButton.styleFrom(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      // Pasangan solid, bukan dua alpha bertumpuk. Komposisi lama
      // (onPrimary 0.6 di atas primary 0.35) mendarat di 1.55:1 pada mode gelap
      // dan 1.37:1 pada mode terang — tepat pada momen tombol kirim pengajuan
      // dinonaktifkan saat submit, ketika karyawan paling perlu tahu bahwa
      // ketukannya terdaftar. Yang sekarang: 5.49:1 dan 5.64:1.
      disabledBackgroundColor: palette.disabledFill,
      disabledForegroundColor: palette.onDisabled,
      elevation: 0,
      shadowColor: Colors.transparent,
      minimumSize: const Size(0, 44),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      textStyle: textTheme.labelLarge,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.mdAll),
    );
  }

  // -------------------------------------------------------------------------
  // Skema warna
  // -------------------------------------------------------------------------

  static const ColorScheme _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.brand700,
    onPrimary: Colors.white,
    primaryContainer: AppColors.brandSubtleLight,
    onPrimaryContainer: AppColors.brand800,
    secondary: Color(0xFF3E4C59),
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFEEF1F4),
    onSecondaryContainer: Color(0xFF1F2933),
    tertiary: AppColors.warningLight,
    onTertiary: Colors.white,
    tertiaryContainer: AppColors.warningLightBg,
    onTertiaryContainer: Color(0xFF6B3F00),
    error: AppColors.dangerLight,
    onError: Colors.white,
    errorContainer: AppColors.dangerLightBg,
    onErrorContainer: Color(0xFF7F1D1D),
    surface: AppColors.gray50,
    onSurface: AppColors.gray900,
    onSurfaceVariant: AppColors.gray800,
    surfaceContainerLowest: AppColors.gray50,
    surfaceContainerLow: AppColors.gray100,
    surfaceContainer: AppColors.gray200,
    surfaceContainerHigh: AppColors.gray300,
    surfaceContainerHighest: AppColors.gray400,
    outline: AppColors.gray600,
    outlineVariant: AppColors.gray500,
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: AppColors.slate200,
    onInverseSurface: AppColors.slate900,
    inversePrimary: AppColors.brand500,
    surfaceTint: Colors.transparent,
  );

  static const ColorScheme _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: AppColors.brand500,
    // Teks gelap di atas hijau brand — kontras 15:1, dan itulah cara Supabase
    // memakai warna ini pada tombol.
    onPrimary: AppColors.brand900,
    primaryContainer: AppColors.brandSubtleDark,
    onPrimaryContainer: AppColors.brand200,
    secondary: Color(0xFFC9CDD1),
    onSecondary: AppColors.slate200,
    secondaryContainer: AppColors.slate400,
    onSecondaryContainer: Color(0xFFE4E4E4),
    tertiary: AppColors.warningDark,
    onTertiary: Color(0xFF241800),
    tertiaryContainer: AppColors.warningDarkBg,
    onTertiaryContainer: Color(0xFFFFD48A),
    error: AppColors.dangerDark,
    onError: Color(0xFF2A0709),
    errorContainer: AppColors.dangerDarkBg,
    onErrorContainer: Color(0xFFFFB3B6),
    surface: AppColors.slate200,
    onSurface: AppColors.slate900,
    onSurfaceVariant: AppColors.slate800,
    surfaceContainerLowest: AppColors.slate50,
    surfaceContainerLow: Color(0xFF191919),
    surfaceContainer: AppColors.slate200,
    surfaceContainerHigh: AppColors.slate300,
    surfaceContainerHighest: AppColors.slate400,
    outline: AppColors.slate600,
    outlineVariant: AppColors.slate500,
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: Color(0xFFF2F2F2),
    onInverseSurface: AppColors.slate100,
    inversePrimary: AppColors.brand700,
    surfaceTint: Colors.transparent,
  );
}

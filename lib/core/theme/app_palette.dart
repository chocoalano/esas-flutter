import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Sepasang warna yang membentuk satu "nada" status: teks, isian, dan garis.
///
/// Lencana status di aplikasi ini tidak pernah berupa blok warna pekat. Ia
/// selalu isian sangat tipis, garis 1px yang sedikit lebih pekat, dan teks
/// berwarna penuh — pola yang sama yang membuat tabel Supabase tetap tenang
/// walau setiap barisnya berwarna.
@immutable
class AppTone {
  const AppTone({
    required this.foreground,
    required this.background,
    required this.border,
  });

  final Color foreground;
  final Color background;
  final Color border;

  static AppTone lerp(AppTone a, AppTone b, double t) {
    return AppTone(
      foreground: Color.lerp(a.foreground, b.foreground, t)!,
      background: Color.lerp(a.background, b.background, t)!,
      border: Color.lerp(a.border, b.border, t)!,
    );
  }
}

/// Peran warna yang tidak punya tempat di [ColorScheme].
///
/// `ColorScheme` Material tidak mengenal "border hairline", "teks redup", atau
/// "sukses". Menitipkan warna-warna itu ke slot yang salah — misalnya memakai
/// `tertiary` sebagai warna peringatan — adalah cara sebuah tema perlahan
/// kehilangan arti. Semuanya dikumpulkan di sini sebagai [ThemeExtension],
/// dan diambil lewat `Theme.of(context).palette`.
///
/// Setiap field yang ditambahkan di sini WAJIB muncul di lima tempat sekaligus:
/// konstruktor, [light], [dark], [copyWith], dan [lerp]. Melewatkan satu di
/// [lerp] adalah cara paling senyap merusak transisi tema — tidak ada yang
/// gagal saat kompilasi, hanya satu warna yang membeku di tengah animasi.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.borderSubtle,
    required this.borderStrong,
    required this.borderInteractive,
    required this.surfaceSubtle,
    required this.surfaceRaised,
    required this.textMuted,
    required this.brandAccent,
    required this.brandSubtle,
    required this.brandGlow,
    required this.trackSubtle,
    required this.dataInk,
    required this.skeletonFill,
    required this.overlayScrim,
    required this.onOverlay,
    required this.onOverlayMuted,
    required this.disabledFill,
    required this.onDisabled,
    required this.neutral,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
  });

  /// Garis 1px yang memisahkan kartu dari latarnya. Inti dari bahasa visual
  /// ini: kedalaman datang dari garis, bukan dari bayangan. Boleh berada di
  /// bawah 3:1 karena selalu ditopang selisih tingkat permukaan.
  final Color borderSubtle;

  /// Garis untuk elemen yang sedang aktif atau perlu ditegaskan.
  final Color borderStrong;

  /// Garis yang MENYATAKAN keadaan: outline input, fokus, terpilih, error, dan
  /// track switch. Wajib lolos 3:1 sendirian, tanpa isyarat cadangan —
  /// 3.67:1 di atas kartu gelap, 3.45:1 di atas kartu terang.
  final Color borderInteractive;

  /// Permukaan satu tingkat di bawah kartu — dasar input, baris bergaris.
  final Color surfaceSubtle;

  /// Permukaan satu tingkat di atas kartu — hover, kartu di dalam kartu.
  final Color surfaceRaised;

  /// Teks tersier: keterangan waktu, satuan, teks bantuan.
  final Color textMuted;

  /// Hijau brand penuh. Di mode terang warna ini terlalu terang untuk teks,
  /// jadi pakailah untuk isian dan indikator, bukan untuk huruf.
  final Color brandAccent;

  /// Isian hijau sangat tipis untuk latar ikon dan sorotan.
  final Color brandSubtle;

  /// Kilau hijau di balik panel protagonis — satu tingkat lebih lembut lagi
  /// daripada [brandSubtle], dan satu-satunya kedalaman non-garis yang
  /// diizinkan bahasa visual ini.
  ///
  /// Ia dipakai sebagai titik henti gradien, jadi sisi pudarnya WAJIB warna ini
  /// sendiri pada alpha nol, bukan `Colors.transparent`. Memudar ke
  /// `Colors.transparent` berarti memudar ke hitam transparan, dan tepi yang
  /// menggelap sebelum menghilang justru paling terlihat di mode terang.
  final Color brandGlow;

  /// Palung untuk bar progres dan garis dasar sparkline: satu tingkat di bawah
  /// isi bar, dan selalu di dalam outline [borderSubtle] supaya palung kosong
  /// tetap punya bentuk.
  final Color trackSubtle;

  /// Tinta seri data netral. Tanpa peran ini setiap grafik terpaksa
  /// membelanjakan satu-satunya hijau brand untuk data biasa, dan brand
  /// berhenti berarti "ini bisa ditindak".
  final Color dataInk;

  /// Isian blok skeleton. Sengaja tidak memakai [surfaceRaised]: di mode gelap
  /// permukaan itu hanya 1.10:1 di atas kartu, sehingga daftar yang sedang
  /// memuat terbaca sebagai daftar kosong.
  final Color skeletonFill;

  /// Kerudung di atas citra kamera. Bersama dua warna di bawahnya ia
  /// mengabaikan mode tema: yang menentukan kontras di sana adalah pemandangan
  /// kamera, bukan setelan pengguna.
  final Color overlayScrim;

  /// Teks utama di atas [overlayScrim].
  final Color onOverlay;

  /// Teks penunjang di atas [overlayScrim].
  final Color onOverlayMuted;

  /// Isian kontrol nonaktif, sudah dikomposisi. Pasangannya [onDisabled]
  /// memberi 5.49:1 di gelap dan 5.64:1 di terang.
  final Color disabledFill;

  /// Teks di atas [disabledFill].
  final Color onDisabled;

  final AppTone neutral;
  final AppTone success;
  final AppTone warning;
  final AppTone danger;
  final AppTone info;

  static const AppPalette light = AppPalette(
    borderSubtle: AppColors.gray500,
    borderStrong: AppColors.gray600,
    borderInteractive: AppColors.borderInteractiveLight,
    surfaceSubtle: AppColors.gray200,
    surfaceRaised: AppColors.gray300,
    textMuted: AppColors.gray700,
    brandAccent: AppColors.brand500,
    brandSubtle: AppColors.brandSubtleLight,
    brandGlow: AppColors.brandGlowLight,
    trackSubtle: AppColors.gray400,
    dataInk: AppColors.dataInkLight,
    skeletonFill: AppColors.skeletonLight,
    overlayScrim: AppColors.overlayScrim,
    onOverlay: AppColors.onOverlay,
    onOverlayMuted: AppColors.onOverlayMuted,
    disabledFill: AppColors.disabledFillLight,
    onDisabled: AppColors.onDisabledLight,
    neutral: AppTone(
      foreground: AppColors.gray800,
      background: AppColors.gray200,
      border: AppColors.gray500,
    ),
    success: AppTone(
      foreground: AppColors.successLight,
      background: AppColors.successLightBg,
      border: AppColors.successLightBorder,
    ),
    warning: AppTone(
      foreground: AppColors.warningLight,
      background: AppColors.warningLightBg,
      border: AppColors.warningLightBorder,
    ),
    danger: AppTone(
      foreground: AppColors.dangerLight,
      background: AppColors.dangerLightBg,
      border: AppColors.dangerLightBorder,
    ),
    info: AppTone(
      foreground: AppColors.infoLight,
      background: AppColors.infoLightBg,
      border: AppColors.infoLightBorder,
    ),
  );

  static const AppPalette dark = AppPalette(
    borderSubtle: AppColors.slate500,
    borderStrong: AppColors.slate600,
    borderInteractive: AppColors.borderInteractiveDark,
    surfaceSubtle: AppColors.slate50,
    surfaceRaised: AppColors.slate300,
    textMuted: AppColors.slate700,
    brandAccent: AppColors.brand500,
    brandSubtle: AppColors.brandSubtleDark,
    brandGlow: AppColors.brandGlowDark,
    trackSubtle: AppColors.slate400,
    dataInk: AppColors.dataInkDark,
    skeletonFill: AppColors.skeletonDark,
    overlayScrim: AppColors.overlayScrim,
    onOverlay: AppColors.onOverlay,
    onOverlayMuted: AppColors.onOverlayMuted,
    disabledFill: AppColors.disabledFillDark,
    onDisabled: AppColors.onDisabledDark,
    neutral: AppTone(
      foreground: AppColors.slate800,
      background: AppColors.slate300,
      border: AppColors.slate600,
    ),
    success: AppTone(
      foreground: AppColors.successDark,
      background: AppColors.successDarkBg,
      border: AppColors.successDarkBorder,
    ),
    warning: AppTone(
      foreground: AppColors.warningDark,
      background: AppColors.warningDarkBg,
      border: AppColors.warningDarkBorder,
    ),
    danger: AppTone(
      foreground: AppColors.dangerDark,
      background: AppColors.dangerDarkBg,
      border: AppColors.dangerDarkBorder,
    ),
    info: AppTone(
      foreground: AppColors.infoDark,
      background: AppColors.infoDarkBg,
      border: AppColors.infoDarkBorder,
    ),
  );

  @override
  AppPalette copyWith({
    Color? borderSubtle,
    Color? borderStrong,
    Color? borderInteractive,
    Color? surfaceSubtle,
    Color? surfaceRaised,
    Color? textMuted,
    Color? brandAccent,
    Color? brandSubtle,
    Color? brandGlow,
    Color? trackSubtle,
    Color? dataInk,
    Color? skeletonFill,
    Color? overlayScrim,
    Color? onOverlay,
    Color? onOverlayMuted,
    Color? disabledFill,
    Color? onDisabled,
    AppTone? neutral,
    AppTone? success,
    AppTone? warning,
    AppTone? danger,
    AppTone? info,
  }) {
    return AppPalette(
      borderSubtle: borderSubtle ?? this.borderSubtle,
      borderStrong: borderStrong ?? this.borderStrong,
      borderInteractive: borderInteractive ?? this.borderInteractive,
      surfaceSubtle: surfaceSubtle ?? this.surfaceSubtle,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      textMuted: textMuted ?? this.textMuted,
      brandAccent: brandAccent ?? this.brandAccent,
      brandSubtle: brandSubtle ?? this.brandSubtle,
      brandGlow: brandGlow ?? this.brandGlow,
      trackSubtle: trackSubtle ?? this.trackSubtle,
      dataInk: dataInk ?? this.dataInk,
      skeletonFill: skeletonFill ?? this.skeletonFill,
      overlayScrim: overlayScrim ?? this.overlayScrim,
      onOverlay: onOverlay ?? this.onOverlay,
      onOverlayMuted: onOverlayMuted ?? this.onOverlayMuted,
      disabledFill: disabledFill ?? this.disabledFill,
      onDisabled: onDisabled ?? this.onDisabled,
      neutral: neutral ?? this.neutral,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      info: info ?? this.info,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      borderInteractive: Color.lerp(
        borderInteractive,
        other.borderInteractive,
        t,
      )!,
      surfaceSubtle: Color.lerp(surfaceSubtle, other.surfaceSubtle, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      brandAccent: Color.lerp(brandAccent, other.brandAccent, t)!,
      brandSubtle: Color.lerp(brandSubtle, other.brandSubtle, t)!,
      brandGlow: Color.lerp(brandGlow, other.brandGlow, t)!,
      trackSubtle: Color.lerp(trackSubtle, other.trackSubtle, t)!,
      dataInk: Color.lerp(dataInk, other.dataInk, t)!,
      skeletonFill: Color.lerp(skeletonFill, other.skeletonFill, t)!,
      overlayScrim: Color.lerp(overlayScrim, other.overlayScrim, t)!,
      onOverlay: Color.lerp(onOverlay, other.onOverlay, t)!,
      onOverlayMuted: Color.lerp(onOverlayMuted, other.onOverlayMuted, t)!,
      disabledFill: Color.lerp(disabledFill, other.disabledFill, t)!,
      onDisabled: Color.lerp(onDisabled, other.onDisabled, t)!,
      neutral: AppTone.lerp(neutral, other.neutral, t),
      success: AppTone.lerp(success, other.success, t),
      warning: AppTone.lerp(warning, other.warning, t),
      danger: AppTone.lerp(danger, other.danger, t),
      info: AppTone.lerp(info, other.info, t),
    );
  }
}

/// Akses singkat ke [AppPalette] dari sebuah [ThemeData].
///
/// Tanpa ini setiap pemanggilan berbunyi
/// `Theme.of(context).extension<AppPalette>()!`, dan tanda seru itu tersebar di
/// seluruh lapisan tampilan. Fallback ke palet sesuai kecerahan menjaga widget
/// tetap bisa dirender di dalam `MaterialApp` uji yang tidak memasang ekstensi —
/// dua berkas uji widget mem-pump `GetMaterialApp` telanjang tanpa argumen
/// tema, jadi fallback ini menanggung beban dan tidak boleh dihapus.
extension AppPaletteAccess on ThemeData {
  AppPalette get palette =>
      extension<AppPalette>() ??
      (brightness == Brightness.dark ? AppPalette.dark : AppPalette.light);
}

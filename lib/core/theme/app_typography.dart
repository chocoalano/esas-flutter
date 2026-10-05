import 'package:flutter/material.dart';

/// Skala tipografi aplikasi.
///
/// Tiga keputusan yang membedakannya dari skala Material bawaan:
///
/// * Ukuran teks isi diturunkan (15/13.5/12 alih-alih 16/14/12). Layar-layar di
///   sini padat data, dan teks yang lebih kecil memberi ruang bernapas tanpa
///   harus membuang informasi.
/// * Judul diberi `letterSpacing` negatif. Pada ukuran besar, jarak huruf baku
///   terlihat renggang; merapatkannya membuat judul terbaca sebagai satu blok.
/// * [labelSmall] adalah "micro-label": kecil, tebal, dan renggang, dipakai
///   untuk penanda bagian dalam huruf kapital.
class AppTypography {
  const AppTypography._();

  /// Font monospace untuk angka, jam, dan nomor dokumen. Angka monospace tidak
  /// bergeser saat nilainya berubah, jadi jam yang berdetak tidak menggoyang
  /// tata letak di sekitarnya.
  ///
  /// Urutannya penting dan tidak boleh diacak. Tiga nama pertama hanya ada di
  /// perangkat Apple dan di sebagian ROM; pada Android stok ketiganya meleset,
  /// dan yang menyelamatkan barisan ini adalah entri terakhir. 'monospace'
  /// adalah nama keluarga generik yang dijamin ada di setiap perangkat Android,
  /// jadi daftar ini WAJIB selalu berakhir di sana — tanpa entri itu, angka
  /// tabular diam-diam jatuh ke font proporsional dan jam mulai bergoyang.
  /// Tidak ada aset font yang ikut dikirim; ini murni resolusi sistem.
  static const List<String> monoFallback = <String>[
    'SF Mono',
    'Menlo',
    'Roboto Mono',
    'monospace',
  ];

  static TextTheme textTheme({
    required Color primary,
    required Color secondary,
    required Color muted,
  }) {
    return TextTheme(
      displayLarge: TextStyle(
        fontSize: 40,
        height: 1.1,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.0,
        color: primary,
      ),
      displayMedium: TextStyle(
        fontSize: 34,
        height: 1.12,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
        color: primary,
      ),
      displaySmall: TextStyle(
        fontSize: 30,
        height: 1.15,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
        color: primary,
      ),
      headlineLarge: TextStyle(
        fontSize: 26,
        height: 1.2,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: primary,
      ),
      headlineMedium: TextStyle(
        fontSize: 22,
        height: 1.25,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: primary,
      ),
      headlineSmall: TextStyle(
        fontSize: 19,
        height: 1.3,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        color: primary,
      ),
      titleLarge: TextStyle(
        fontSize: 17,
        height: 1.35,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: primary,
      ),
      titleMedium: TextStyle(
        fontSize: 15,
        height: 1.4,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        color: primary,
      ),
      titleSmall: TextStyle(
        fontSize: 13.5,
        height: 1.4,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      bodyLarge: TextStyle(fontSize: 15, height: 1.5, color: primary),
      bodyMedium: TextStyle(fontSize: 13.5, height: 1.5, color: secondary),
      bodySmall: TextStyle(fontSize: 12, height: 1.45, color: secondary),
      labelLarge: TextStyle(
        fontSize: 14,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        color: primary,
      ),
      labelMedium: TextStyle(
        fontSize: 12.5,
        height: 1.2,
        fontWeight: FontWeight.w500,
        color: secondary,
      ),
      // Micro-label: dipakai dalam huruf kapital sebagai penanda bagian.
      //
      // `letterSpacing` diturunkan dari 0.6 ke 0.4. Pada kapital 11px, 0.6
      // membuat penanda bagian terbaca administratif — seperti label pada
      // formulir — dan itulah keluhan yang muncul saat halaman punya empat
      // penanda sekaligus. 0.4 tetap memberi kapital ruang bernapas yang
      // dibutuhkannya tanpa membuat judul terasa direnggangkan.
      labelSmall: TextStyle(
        fontSize: 11,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
        color: muted,
      ),
    );
  }

  /// Gaya angka monospace. Dipakai untuk jam absensi, nomor pengajuan, dan
  /// statistik — apa pun yang berupa nilai, bukan kalimat.
  ///
  /// [color] boleh dikosongkan; kalau begitu warnanya diwarisi dari gaya teks
  /// di sekitarnya, persis seperti [TextStyle] biasa.
  static TextStyle mono({
    Color? color,
    double fontSize = 15,
    FontWeight fontWeight = FontWeight.w600,
    double letterSpacing = -0.2,
  }) {
    return TextStyle(
      fontFamilyFallback: monoFallback,
      fontFeatures: const [FontFeature.tabularFigures()],
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      height: 1.2,
      color: color,
    );
  }

  /// Angka utama sebuah panel: satu nilai yang dibaca dari jauh, misalnya total
  /// hadir bulan ini atau durasi kerja berjalan.
  ///
  /// Ketiga langkah numerik di bawah ini membungkus [mono], dan itu disengaja:
  /// selama ada yang bisa menuliskan ukuran angka tanpa melewati sini,
  /// [FontFeature.tabularFigures] akan tetap bersifat opsional dan jam yang
  /// sama akan kembali dirender tiga ukuran berbeda di tiga layar.
  static TextStyle dataLarge({Color? color}) {
    return mono(
      color: color,
      fontSize: 28,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.8,
    );
  }

  /// Angka pendamping: jam masuk dan jam pulang di baris ledger, nilai pada
  /// baris detail.
  static TextStyle dataMedium({Color? color}) {
    return mono(
      color: color,
      fontSize: 20,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.4,
    );
  }

  /// Angka protagonis sebuah layar: satu nilai yang menjadi alasan layar itu
  /// dibuka, digambar sebesar yang masih sopan.
  ///
  /// Ukurannya diberikan pemanggil alih-alih dipatok di sini, karena yang
  /// menentukannya adalah ruang yang tersedia, bukan peran teksnya:
  /// `AppLayout.of(context).displaySize` mengecil pada ponsel lanskap di mana
  /// yang langka adalah tinggi. Itulah satu-satunya sumber angka yang sah untuk
  /// parameter ini — sebuah layar yang menuliskan ukurannya sendiri di tempat
  /// adalah layar yang akan menyimpang saat perangkat diputar.
  static TextStyle dataDisplay({Color? color, double fontSize = 44}) {
    return mono(
      color: color,
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      letterSpacing: -1.2,
    );
  }

  /// Angka sekunder: stempel waktu di garis waktu, hitungan pada bar bersegmen,
  /// satuan kecil di samping nilai utama.
  static TextStyle dataSmall({Color? color}) {
    return mono(
      color: color,
      fontSize: 13,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.1,
    );
  }
}

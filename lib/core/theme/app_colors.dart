import 'package:flutter/material.dart';

/// Ramp warna mentah untuk seluruh aplikasi.
///
/// Bahasa visualnya mengikuti pendekatan Supabase: satu ramp netral yang
/// panjang sebagai tulang punggung, satu warna brand hijau sebagai satu-satunya
/// aksen, dan warna status yang dipakai sangat hemat. Tidak ada gradient dan
/// tidak ada shadow — kedalaman dibentuk oleh garis pembatas setebal 1px dan
/// oleh selisih antar tingkat permukaan.
///
/// Kelas ini hanya menyimpan nilai. Peran semantik ("mana border", "mana teks
/// sekunder") ditetapkan di [AppTheme] dan `AppPalette`, supaya sebuah layar
/// tidak pernah menyebut kode heksadesimal secara langsung.
///
/// Setiap rasio kontras yang ditulis di komentar berkas ini dihitung dengan
/// rumus luminansi relatif WCAG 2.x, jadi pembaca berikutnya bisa memeriksanya
/// ulang tanpa harus percaya.
class AppColors {
  const AppColors._();

  // ---------------------------------------------------------------------
  // Brand — satu-satunya warna beraksen di dalam produk.
  //
  // Hijau brand dan hijau sukses adalah hijau yang sama; dulu keduanya dieja
  // ulang dengan nama berbeda (brand400 sama persis dengan successDark,
  // brand700 dengan successLight) dan ejaan kembar seperti itu pasti melenceng
  // pada perubahan pertama. Sekarang hanya ada satu nilai untuk setiap nada,
  // dan sisi status merujuk ke sisi brand secara eksplisit.
  // ---------------------------------------------------------------------
  static const Color brand200 = Color(0xFFB7F0D5);

  /// Hijau tanda tangan. Dipakai penuh di mode gelap (8.35:1 di atas kartu
  /// gelap #1E1E1E), dan sebagai isian tipis di mode terang — kontrasnya
  /// terhadap putih hanya 2.00:1, jadi tidak pernah untuk huruf di sana.
  static const Color brand500 = Color(0xFF3ECF8E);

  /// Hijau untuk teks dan tombol di mode terang: 5.35:1 terhadap putih, jadi
  /// lolos WCAG AA untuk teks berukuran normal (4.90:1 di atas kanvas terang).
  static const Color brand700 = Color(0xFF0F7A52);
  static const Color brand800 = Color(0xFF08553A);
  static const Color brand900 = Color(0xFF00291B);

  // ---------------------------------------------------------------------
  // Netral gelap — mode gelap adalah tampilan utama produk ini.
  //
  // Tangga ini sengaja dilebarkan. Sebelumnya lima tingkat dideklarasikan
  // tetapi kartu di atas kanvas hanya terukur 1.05:1, artinya tingkatannya ada
  // di berkas token dan tidak ada di layar. Sekarang setiap anak tangga
  // terukur sekitar 1.10:1, dan itulah yang membuat hairline di bawah 3:1 bisa
  // dipertahankan dengan jujur: tepi sebuah kartu dibawa DUA isyarat sekaligus,
  // garis dan selisih permukaan, bukan satu.
  // ---------------------------------------------------------------------
  static const Color slate50 = Color(0xFF161616); // sumur input, sheet
  static const Color slate100 = Color(0xFF141414); // latar halaman
  static const Color slate200 = Color(0xFF1E1E1E); // permukaan kartu
  static const Color slate300 = Color(0xFF262626); // kartu terangkat / hover
  static const Color slate400 = Color(0xFF2E2E2E); // permukaan tertinggi

  // Terukur: kanvas/kartu 1.11, kartu/terangkat 1.10, terangkat/tertinggi 1.11,
  // kartu/sumur 1.09. Teks utama tetap 14.24:1 di atas kartu baru.

  /// Hairline dekoratif: tepi kartu, divider, kaki app bar. 1.47:1 di atas
  /// kartu. Sengaja lemah — garis pengelompokan punya isyarat cadangan berupa
  /// selisih tingkat permukaan, jadi tidak perlu memenuhi 3:1.
  static const Color slate500 = Color(0xFF3A3A3A);

  /// Garis penegasan dan keadaan tertekan: 2.13:1 di atas kartu.
  static const Color slate600 = Color(0xFF525252);

  /// Teks redup. 6.07:1 di kanvas, 5.50:1 di kartu, 4.99:1 di permukaan
  /// terangkat, 4.48:1 di permukaan tertinggi. #8A8A8A ditolak karena jatuh ke
  /// 3.93:1 begitu naik ke tingkat tertinggi.
  static const Color slate700 = Color(0xFF949494);

  /// Teks sekunder: 8.04:1 di atas kartu. Ikut dinaikkan bersama teks redup,
  /// sebab kalau hanya lapisan redup yang naik, hierarkinya runtuh.
  static const Color slate800 = Color(0xFFB4B4B4);

  /// Teks utama: 14.24:1 di atas kartu, 15.74:1 di atas kanvas.
  static const Color slate900 = Color(0xFFEDEDED);

  // ---------------------------------------------------------------------
  // Netral terang. Mode ini yang benar-benar dipakai orang di gerbang pabrik
  // jam 06:50, jadi tangganya ikut dilebarkan satu langkah.
  // ---------------------------------------------------------------------
  static const Color gray50 = Color(0xFFFFFFFF); // permukaan kartu
  static const Color gray100 = Color(
    0xFFF4F5F7,
  ); // latar halaman (1.09 : kartu)
  static const Color gray200 = Color(
    0xFFF7F8F9,
  ); // permukaan lembut, isian input
  static const Color gray300 = Color(0xFFF1F3F5); // permukaan terangkat
  static const Color gray400 = Color(0xFFE9ECEF); // permukaan tertinggi, trough

  /// Hairline dekoratif mode terang: 1.38:1 di atas putih.
  static const Color gray500 = Color(0xFFD8DCE0);

  /// Garis penegasan mode terang: 1.69:1 di atas putih.
  static const Color gray600 = Color(0xFFC2C8CE);

  /// Teks redup. 5.10:1 di atas putih, 4.80:1 di atas isian input gray200,
  /// 4.67:1 di atas kanvas terang.
  static const Color gray700 = Color(0xFF6E6E6E);

  /// Teks sekunder: 8.32:1 di atas putih.
  static const Color gray800 = Color(0xFF4E4E4E);

  /// Teks utama: 17.93:1 di atas putih.
  static const Color gray900 = Color(0xFF171717);

  // ---------------------------------------------------------------------
  // Garis kontrol.
  //
  // WCAG 1.4.11 menuntut 3:1 untuk batas sebuah kontrol, sementara
  // menyeragamkan SEMUA garis ke 3:1 akan membuat setiap kartu tampak berkotak
  // dan membunuh bahasa hairline. Jadi peran garis dipisah tiga: dekoratif
  // (slate500/gray500), penegasan (slate600/gray600), dan yang di bawah ini —
  // batas yang menyatakan keadaan dan wajib lolos 3:1 sendirian: outline input,
  // fokus, terpilih, dan track switch.
  // ---------------------------------------------------------------------

  /// 3.67:1 di atas kartu, 4.06:1 di atas kanvas, 3.98:1 di atas sumur input,
  /// 3.33:1 di atas permukaan terangkat.
  static const Color borderInteractiveDark = Color(0xFF767676);

  /// 3.45:1 di atas putih, 3.25:1 di atas isian input gray200, 3.10:1 di atas
  /// permukaan terangkat.
  static const Color borderInteractiveLight = Color(0xFF8A8A8A);

  // ---------------------------------------------------------------------
  // Peran data dan keadaan yang sebelumnya ditemukan ulang di tiap layar.
  // ---------------------------------------------------------------------

  /// Tinta seri netral untuk sparkline dan bar: 8.04:1 di atas kartu gelap.
  static const Color dataInkDark = slate800;

  /// Tinta seri netral mode terang: 6.69:1 di atas putih, 6.13:1 di kanvas.
  static const Color dataInkLight = Color(0xFF5C5C5C);

  /// Isian skeleton mode gelap: 1.56:1 di atas kartu, cukup untuk terbaca
  /// sebagai daftar yang sedang memuat alih-alih daftar kosong.
  static const Color skeletonDark = Color(0xFF3E3E3E);

  /// Isian skeleton mode terang: 1.38:1 di atas putih.
  static const Color skeletonLight = gray500;

  /// Kerudung di atas citra kamera. Alpha 90% supaya pemandangan masih terasa
  /// hidup, tetapi teks di atasnya tetap aman: dikomposisi di atas bidang
  /// kamera paling terang sekalipun ia mendarat di #272727.
  static const Color overlayScrim = Color(0xE6101010);

  /// Teks di atas kerudung: 17.0:1 pada kamera gelap, 13.34:1 pada kamera
  /// paling terang.
  static const Color onOverlay = Color(0xFFF2F2F2);

  /// Teks penunjang di atas kerudung: 8.77:1 pada kamera gelap, 6.89:1 pada
  /// kamera paling terang.
  static const Color onOverlayMuted = Color(0xFFB0B0B0);

  // ---------------------------------------------------------------------
  // Status. Setiap status punya tiga nilai: teks, isian, garis.
  // ---------------------------------------------------------------------

  /// Sama persis dengan [brand700] — hijau sukses dan hijau brand adalah warna
  /// yang sama, dan itu ditulis sebagai alias supaya tidak pernah melenceng.
  static const Color successLight = brand700;
  static const Color successLightBg = Color(0xFFE7F6EF);
  static const Color successLightBorder = Color(0xFFBCE5D2);

  /// Saudara terang dari [brand500] untuk latar gelap: 8.98:1 di atas
  /// [successDarkBg].
  static const Color successDark = Color(0xFF4ADE9E);
  static const Color successDarkBg = Color(0xFF12291F);
  static const Color successDarkBorder = Color(0xFF1E4535);

  static const Color warningLight = Color(0xFF9A5B00);
  static const Color warningLightBg = Color(0xFFFDF3E3);
  static const Color warningLightBorder = Color(0xFFF3DDB4);
  static const Color warningDark = Color(0xFFFFB224);
  static const Color warningDarkBg = Color(0xFF2C2008);
  static const Color warningDarkBorder = Color(0xFF4A360D);

  static const Color dangerLight = Color(0xFFC5303A);
  static const Color dangerLightBg = Color(0xFFFDECEC);
  static const Color dangerLightBorder = Color(0xFFF4C6C6);
  static const Color dangerDark = Color(0xFFFF6369);
  static const Color dangerDarkBg = Color(0xFF2E1315);
  static const Color dangerDarkBorder = Color(0xFF4E1F22);

  static const Color infoLight = Color(0xFF1D64C6);

  /// Dinaikkan setengah langkah dari #EAF1FD. Nilai lama membawa `textMuted`
  /// (#6E6E6E) ke 4,49:1 — meleset dari 4,5:1 pada angka kedua di belakang
  /// koma, dan itu baru berarti sejak bidang nada dipakai sebagai latar panel
  /// penuh dan bukan hanya sebagai lencana selebar dua kata. Sekarang 4,57:1,
  /// dan warna teks nadanya sendiri (#1D64C6) 5,10:1.
  static const Color infoLightBg = Color(0xFFECF3FE);
  static const Color infoLightBorder = Color(0xFFC3D8F7);
  static const Color infoDark = Color(0xFF6AA6FF);
  static const Color infoDarkBg = Color(0xFF111E33);
  static const Color infoDarkBorder = Color(0xFF1F3559);

  // ---------------------------------------------------------------------
  // Isian hijau paling tipis. Nilainya identik dengan latar nada sukses; ini
  // ejaan tunggalnya, bukan ejaan keempat.
  // ---------------------------------------------------------------------
  static const Color brandSubtleLight = successLightBg;
  static const Color brandSubtleDark = successDarkBg;

  // ---------------------------------------------------------------------
  // Sorotan hijau paling tipis: satu tingkat LEBIH lembut daripada
  // `brandSubtle`, dan satu-satunya tempat pemakaiannya adalah kilau di balik
  // panel protagonis Beranda.
  //
  // Nilainya opaque, bukan beralpha, dan itu disengaja. Sebuah gradien yang
  // memudar ke `Colors.transparent` memudar ke HITAM transparan, jadi tepinya
  // menggelap sebelum menghilang — halo kotor yang paling terlihat justru di
  // mode terang. Yang benar adalah memudar ke warna ini sendiri pada alpha nol,
  // dan itu hanya mungkin kalau warnanya punya nama.
  // ---------------------------------------------------------------------

  /// 1.03:1 di atas putih — terbaca sebagai kehangatan, bukan sebagai bidang.
  static const Color brandGlowLight = Color(0xFFF2FBF7);

  /// 1.06:1 di atas kartu gelap. Sengaja selemah itu: di mode gelap sebuah
  /// kilau hijau yang terbaca sebagai bidang membuat teks di atasnya kehilangan
  /// kontras yang sudah dihitung.
  static const Color brandGlowDark = Color(0xFF162A20);

  // ---------------------------------------------------------------------
  // Keadaan nonaktif. Dulu dikomposisi dari dua alpha bertumpuk (onPrimary 0.6
  // di atas primary 0.35) dan hasilnya 1.55:1 di gelap, 1.37:1 di terang — pada
  // momen ketika karyawan paling perlu tahu ketukannya terdaftar. Sekarang
  // pasangan solid: 5.49:1 di gelap, 5.64:1 di terang.
  // ---------------------------------------------------------------------
  static const Color disabledFillDark = slate500;
  static const Color onDisabledDark = slate800;
  static const Color disabledFillLight = gray400;
  static const Color onDisabledLight = dataInkLight;
}

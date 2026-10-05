import 'package:flutter/widgets.dart';

import '../../theme/app_dimens.dart';

/// Ambang ukuran layar, ditulis satu kali untuk seluruh aplikasi.
///
/// Ini satu-satunya berkas yang boleh menyebutkan angka dp ambang. Selama
/// angkanya boleh ditulis di tempat, setiap layar akan memilih ambangnya
/// sendiri dan dua layar yang seharusnya berperilaku sama akan berpindah kelas
/// pada lebar yang berbeda — dan tidak ada satu pun tes yang bisa membuktikan
/// bahwa keduanya sudah menyimpang.
///
/// [medium] dan [expanded] sengaja meminjam Material 3 supaya tidak ada yang
/// perlu membela angka karangan sendiri di review berikutnya. [shortSide]
/// adalah angka lapangan: di bawah 600dp TINGGI, sebuah kolom setinggi penuh
/// tidak lagi muat, berapa pun lebarnya. [readingMax] adalah lebar baca
/// terjauh yang masih nyaman; di atas itu sisa lebar menjadi margin, bukan
/// kolom ketiga.
class AppBreakpoints {
  const AppBreakpoints._();

  /// Ambang LEBAR tempat tata letak dua kolom mulai masuk akal.
  static const double medium = 600;

  /// Ambang LEBAR tempat kolom boleh melebar dan isinya perlu dijepit.
  static const double expanded = 840;

  /// Ambang TINGGI. Di bawah ini layar terlalu pendek untuk memikul kolom
  /// setinggi penuh, dan itu berlaku sama untuk ponsel dalam lanskap maupun
  /// jendela pendek di desktop.
  static const double shortSide = 600;

  /// Lebar baca maksimum. Teks 13,5px yang membentang seribu piksel bukan lagi
  /// paragraf, melainkan garis.
  static const double readingMax = 1080;
}

/// Empat kelas ukuran, dan setiap kelas mengubah sesuatu yang nyata.
///
/// Kelas yang tidak mengubah apa pun adalah kelas yang akan dilanggar pertama
/// kali seseorang mengisinya, jadi daftar ini sengaja pendek.
enum AppLayoutClass {
  /// Lebar di bawah [AppBreakpoints.medium], orientasi apa pun: seluruh ponsel
  /// dalam potret, layar sampul foldable, dan ponsel dalam split-screen.
  compact,

  /// Cukup lebar untuk dua kolom tetapi terlalu pendek untuk memikulnya penuh:
  /// setiap ponsel dalam lanskap, dan tablet murah 1024x600.
  compactLandscape,

  /// Tablet 7–8 inci potret dan ponsel besar dalam split-screen vertikal.
  medium,

  /// Tablet 10 inci lanskap dan tablet 12 inci di kedua orientasi.
  expanded,
}

/// Nilai tata letak yang berlaku pada satu kelas ukuran.
///
/// Bentuknya record, bukan kelas, karena record punya kesetaraan struktural:
/// sebuah widget boleh menyimpan nilai ini dan membandingkannya di
/// `didChangeDependencies` untuk tahu apakah kelasnya benar-benar berubah atau
/// hanya ukurannya bergeser beberapa piksel.
typedef AppLayoutMetrics = ({
  /// Kelas ukuran yang sedang berlaku.
  AppLayoutClass layoutClass,

  /// Margin horizontal halaman. Diberikan ke [AppPageInset], bukan ke padding
  /// daftar, supaya satu bagian boleh menerobosnya.
  double pagePadding,

  /// Ukuran angka protagonis, yaitu langkah `AppTypography.dataDisplay`. Ia
  /// mengecil di [AppLayoutClass.compactLandscape] karena yang langka di sana
  /// adalah tinggi, bukan lebar.
  double displaySize,

  /// Jumlah kolom petak aksi cepat.
  int quickActionColumns,

  /// Jumlah ubin saldo cuti yang muat berdampingan.
  int leaveTiles,

  /// Lebar isi maksimum; `null` berarti isi boleh selebar apa pun yang
  /// tersedia.
  double? contentMaxWidth,

  /// Apakah isi halaman dipecah menjadi dua kolom.
  bool twoColumn,

  /// Apakah bagian protagonis boleh menerobos margin halaman dan menyentuh
  /// kedua tepi kaca. Hanya benar ketika tepi kolom memang tepi layar.
  bool heroBleeds,

  /// Apakah baris sekunder kepala halaman (tanggal) dilipat ke dalam baris
  /// utamanya. Benar hanya ketika tinggi layar yang langka.
  bool compactHeader,

  /// Apakah rincian yang bisa dibuka-tutup dibiarkan selalu terbuka. Benar
  /// ketika kolomnya memang punya ruang untuk menampungnya.
  bool detailsAlwaysOpen,
});

/// Cara bertanya "saya sedang di kelas ukuran yang mana" dari sebuah
/// [BuildContext].
///
/// Aturan rotasi dinyatakan di sini satu kali untuk seluruh aplikasi:
/// `MediaQuery.orientationOf` TIDAK PERNAH dibaca. Ia berbohong pada
/// split-screen, pada foldable, dan pada jendela desktop yang diseret sempit.
/// Orientasi hanya pernah berarti dua hal, dan dua angka itulah yang dipakai —
/// cukup LEBAR untuk dua kolom, dan cukup TINGGI untuk memikulnya.
///
/// Konsekuensi yang disengaja: tablet 10 inci yang diputar TIDAK berpindah
/// kelas, karena 1280x800 dan 800x1280 sama-sama lolos kedua ambang dan yang
/// berubah hanya lebar kolomnya. Ponsel yang diputar justru BERPINDAH kelas,
/// karena 915x412 melewati ambang lebar tetapi jatuh di bawah ambang tinggi.
class AppLayout {
  const AppLayout._();

  /// Nilai tata letak untuk ukuran layar yang sedang berlaku.
  ///
  /// Memakai `MediaQuery.sizeOf`, jadi pemanggilnya dibangun ulang ketika
  /// perangkat diputar atau foldable dilipat — dan itu memang yang diinginkan,
  /// tetapi widget yang menganimasikan sesuatu saat dibangun perlu tahu bahwa
  /// pembangunan ulang itu bukan data baru.
  static AppLayoutMetrics of(BuildContext context) =>
      resolve(MediaQuery.sizeOf(context));

  /// Versi murni dari [of]: memetakan sebuah [Size] ke nilai tata letaknya
  /// tanpa menyentuh pohon widget, supaya aturannya bisa diuji tanpa membangun
  /// satu widget pun.
  static AppLayoutMetrics resolve(Size size) {
    // Urutan cabang ini WAJIB. Cek tinggi berjalan SEBELUM cabang lebar mana
    // pun, karena tanpa itu ponsel dalam lanskap — 915dp lebar, 412dp tinggi —
    // akan diklasifikasikan sebagai tablet besar dan menerima tiga kolom di
    // layar setinggi 412dp.
    if (size.width >= AppBreakpoints.medium &&
        size.height < AppBreakpoints.shortSide) {
      return _compactLandscape;
    }

    if (size.width >= AppBreakpoints.expanded) return _expanded;
    if (size.width >= AppBreakpoints.medium) return _medium;
    return _compact;
  }

  /// Ponsel potret. Secara struktural sama dengan tata letak yang sudah
  /// berjalan hari ini, ditambah izin menerobos margin untuk satu bagian.
  static const AppLayoutMetrics _compact = (
    layoutClass: AppLayoutClass.compact,
    pagePadding: AppSpacing.page,
    displaySize: 44,
    // Empat, bukan tiga. Petak aksi cepat dulunya sebuah kartu penuh — garis,
    // radius, padding 16/20 — dan tiga di antaranya sudah memenuhi lebar 320dp.
    // Sekarang ia hanya kotak ikon 52px dengan satu label, jadi kolom keempat
    // muat, dan barisnya menjadi satu alih-alih dua.
    quickActionColumns: 4,
    leaveTiles: 3,
    contentMaxWidth: null,
    twoColumn: false,
    heroBleeds: true,
    compactHeader: false,
    detailsAlwaysOpen: false,
  );

  /// Ponsel dalam lanskap. Dua kolom karena lebarnya ada, angka protagonis
  /// mengecil dan kepala halaman merapat karena tingginya tidak ada.
  static const AppLayoutMetrics _compactLandscape = (
    layoutClass: AppLayoutClass.compactLandscape,
    pagePadding: AppSpacing.xxl,
    displaySize: 32,
    quickActionColumns: 4,
    leaveTiles: 3,
    contentMaxWidth: 900,
    twoColumn: true,
    heroBleeds: false,
    compactHeader: true,
    detailsAlwaysOpen: false,
  );

  /// Tablet 7–8 inci potret. 600–839dp sudah lebar baca yang sehat untuk dua
  /// kolom, jadi isinya tidak perlu dijepit.
  static const AppLayoutMetrics _medium = (
    layoutClass: AppLayoutClass.medium,
    pagePadding: AppSpacing.xxxl,
    displaySize: 52,
    quickActionColumns: 4,
    leaveTiles: 4,
    contentMaxWidth: null,
    twoColumn: true,
    heroBleeds: false,
    compactHeader: false,
    detailsAlwaysOpen: true,
  );

  /// Tablet besar. Isinya dijepit [AppBreakpoints.readingMax] dan sisa
  /// lebarnya menjadi margin, karena tidak ada hal ketiga di aplikasi ini yang
  /// layak satu kolom sendiri.
  static const AppLayoutMetrics _expanded = (
    layoutClass: AppLayoutClass.expanded,
    pagePadding: AppSpacing.xxxl,
    displaySize: 56,
    quickActionColumns: 4,
    leaveTiles: 4,
    contentMaxWidth: AppBreakpoints.readingMax,
    twoColumn: true,
    heroBleeds: false,
    compactHeader: false,
    detailsAlwaysOpen: true,
  );
}

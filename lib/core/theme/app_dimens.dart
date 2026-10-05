import 'package:flutter/widgets.dart';

/// Skala jarak. Setiap padding dan gap di dalam aplikasi mengambil nilai dari
/// sini, supaya ritme vertikal antar layar tetap sama.
///
/// Skalanya ditulis 4pt, tetapi yang benar-benar dipakai layar ternyata 2pt:
/// ada puluhan tempat yang menghitung sendiri `AppSpacing.sm - 2`,
/// `AppSpacing.xs + 2`, atau `AppSpacing.md - 2`. Aritmetika sebanyak itu
/// adalah cara sebuah sistem desain memberi tahu bahwa anak tangganya kurang,
/// jadi dua setengah langkah di antaranya diberi nama alih-alih terus dihitung
/// di tempat.
class AppSpacing {
  const AppSpacing._();

  static const double xxs = 2;
  static const double xs = 4;

  /// Setengah langkah antara [xs] dan [sm]: gap antar sel strip, jarak ikon ke
  /// labelnya di dalam lencana.
  static const double tight = 6;

  static const double sm = 8;

  /// Setengah langkah antara [sm] dan [md]: padding vertikal baris padat.
  static const double snug = 10;

  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 48;

  /// Margin horizontal baku sebuah halaman.
  static const double page = 20;

  /// Ruang di bawah konten yang bertetangga dengan bottom navigation bar,
  /// supaya elemen terakhir tidak menempel pada bilah navigasi.
  static const double bottomSafe = 32;
}

/// Radius sudut. Nilainya sengaja kecil: sudut 12px atau lebih besar membuat
/// kartu terasa "empuk", sementara bahasa visual ini ingin terasa presisi.
class AppRadii {
  const AppRadii._();

  static const double xs = 4;
  static const double sm = 6;
  static const double md = 8;
  static const double lg = 10;
  static const double xl = 12;
  static const double xxl = 16;
  static const double pill = 999;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius xxlAll = BorderRadius.all(Radius.circular(xxl));
  static const BorderRadius pillAll = BorderRadius.all(Radius.circular(pill));
}

/// Durasi animasi. Pendek dan konsisten; gerakan di sini bertugas menjelaskan
/// perubahan keadaan, bukan menghibur.
class AppDurations {
  const AppDurations._();

  static const Duration fast = Duration(milliseconds: 120);
  static const Duration normal = Duration(milliseconds: 200);

  /// Durasi untuk gerak yang membawa nilai, bukan sekadar transisi: hitungan
  /// naik pada kartu metrik dan pengisian bar progres.
  static const Duration slow = Duration(milliseconds: 320);

  static const Duration shimmer = Duration(milliseconds: 1400);

  /// Satu detak jam dinding. Dipakai penghitung durasi kerja berjalan, dan
  /// sengaja dinamai supaya tidak ada `Timer.periodic` yang memilih intervalnya
  /// sendiri.
  static const Duration tick = Duration(seconds: 1);
}

/// Ukuran ikon. Sebelum daftar ini ada, sekitar enam puluh pemakaian ikon
/// tersebar di dua belas nilai berbeda, dan ikon yang seharusnya sebaris
/// berakhir beda satu-dua piksel. Enam langkah ini menutup hampir semuanya.
class AppIconSizes {
  const AppIconSizes._();

  /// Titik status dan panah mikro di dalam lencana.
  static const double xs = 12;

  /// Ikon di dalam teks kecil, misalnya jam di baris meta.
  static const double sm = 14;

  /// Ukuran baku ikon di dalam baris daftar.
  static const double md = 16;

  /// Ikon aksi sekunder dan chevron.
  static const double lg = 18;

  /// Ikon tombol dan bilah navigasi.
  static const double xl = 20;

  /// Ikon utama sebuah keadaan kosong atau kotak ikon.
  static const double xxl = 24;
}

/// Kurva gerak. Sama seperti warna, kurva animasi tidak boleh dipilih per
/// tempat: gerak yang tidak sinkron terbaca sebagai aplikasi yang tersendat,
/// bukan sebagai variasi.
class AppMotion {
  const AppMotion._();

  /// Kurva baku untuk perubahan keadaan: cepat di awal, mendarat pelan.
  static const Curve standard = Curves.easeOutCubic;

  /// Untuk gerak yang perlu terbaca sebagai hasil sebuah tindakan — bar yang
  /// terisi, angka yang naik.
  static const Curve emphasized = Curves.easeOutQuint;

  /// Untuk elemen yang pergi. Keluar dipercepat, supaya ruangnya lekas
  /// diserahkan ke apa pun yang menggantikannya.
  static const Curve exit = Curves.easeInCubic;
}

import 'package:esas/core/network/api_exception.dart';

/// Mengapa sebuah panel Beranda gagal, sebagai fakta dan bukan sebagai kalimat.
///
/// Berkas ini dulu juga memuat sebuah widget pemberitahuan. Widget itu dihapus
/// bersama gelombang ketiga: kalimat kegagalan absensi sekarang digambar DI
/// DALAM panel protagonis, bukan menggantikannya, sehingga tidak ada lagi
/// pemanggil untuk sebuah kartu galat tersendiri. Yang tersisa adalah
/// klasifikasinya — dan itu memang bagian yang layak dipakai bersama.
///
/// Versi pertama kelas ini mencocokkan SUBSTRING bahasa Indonesia — `'masuk
/// kembali'`, `'kedaluwarsa'`, `'sebelum fitur'` — karena `HomeController`
/// menyimpan galat sebagai `Rxn<String>` dan membuang statusnya. Itu selalu
/// dimaksudkan sebagai penopang sementara: ia pecah pada hari pertama seseorang
/// memperbaiki tata bahasa sebuah pesan server, pada instalasi berbahasa lain,
/// dan pada backend yang menjawab 401 dengan kalimat yang tidak menyebut kata
/// "sesi".
///
/// Slot galatnya sekarang bertipe [ApiException], jadi yang dibaca di sini
/// adalah status HTTP. `401` adalah `401` di setiap instalasi, dalam setiap
/// bahasa, selamanya.
enum HomeFailureKind {
  /// Permintaan tidak pernah sampai: sinyal hilang, timeout, socket mati.
  network,

  /// Server menjawab, dan jawabannya rusak (5xx).
  server,

  /// Kredensialnya sudah tidak berlaku (401). Tidak akan pernah berhasil
  /// diulang.
  sessionExpired,

  /// Terautentikasi, tetapi permintaannya ditolak (403).
  ///
  /// **Ini TIDAK berarti fitur absensi dimatikan untuk karyawan ini.** Sebuah
  /// 403 pada `attendance/context` bisa berarti banyak hal, dan hampir semuanya
  /// urusan server: abilities token yang terlalu sempit (README gap G-3 —
  /// token dicetak dengan `['attendance']` saja, sehingga endpoint self-service
  /// ditolak sampai diperlebar), guard rute, kebijakan tenant, atau konfigurasi
  /// deployment.
  ///
  /// Satu-satunya pernyataan yang sah tentang kapabilitas karyawan adalah
  /// `attendance_enabled: false` di dalam respons yang BERHASIL. Menyimpulkan
  /// "fitur belum aktif untuk akun ini" dari sebuah status transport adalah
  /// mengarang fakta produk dari fakta jaringan — dan itulah yang membuat
  /// aplikasi memberi tahu karyawan yang absensinya jelas-jelas aktif bahwa
  /// absensinya tidak aktif.
  notPermitted,

  /// Sisanya. Kalimatnya netral dan aksinya "coba lagi".
  unknown,
}

/// Klasifikasikan sebuah kegagalan panel dari statusnya.
HomeFailureKind homeFailureKindOf(ApiException? error) {
  if (error == null) return HomeFailureKind.unknown;

  // Urutannya penting: sebuah kegagalan transport tidak punya status sama
  // sekali, jadi ia harus diperiksa sebelum cabang mana pun yang membaca angka.
  if (error.isTransportFailure) return HomeFailureKind.network;
  if (error.isUnauthenticated) return HomeFailureKind.sessionExpired;
  if (error.isForbidden) return HomeFailureKind.notPermitted;

  final int status = error.status ?? 0;

  if (status >= 500 && status < 600) return HomeFailureKind.server;

  return HomeFailureKind.unknown;
}

/// Jalan keluar yang benar-benar bisa menyelesaikan kegagalan ini.
enum HomeErrorRemedy {
  /// Bisa berhasil kalau diulang.
  retry,

  /// Tidak akan pernah berhasil dengan kredensial sekarang.
  signIn,

  /// Tidak ada yang bisa dilakukan orangnya. Jangan tawarkan tombol yang hanya
  /// bisa gagal.
  none,
}

HomeErrorRemedy homeErrorRemedyFor(ApiException? error) {
  return switch (homeFailureKindOf(error)) {
    HomeFailureKind.sessionExpired => HomeErrorRemedy.signIn,
    // 403 mendapat "Coba lagi", bukan "tidak ada tombol".
    //
    // Versi sebelumnya tidak menawarkan apa pun, dengan alasan bahwa mencoba
    // lagi pasti ditolak lagi. Alasan itu hanya benar kalau kita TAHU sebabnya
    // permanen, dan kita tidak tahu: penyebab paling mungkin adalah
    // konfigurasi server yang bisa berubah tanpa aplikasi ini dipasang ulang.
    // Tombol yang tidak merusak apa pun dan kadang berhasil lebih baik
    // daripada jalan buntu.
    //
    // Yang sengaja TIDAK ditawarkan di sini adalah "Masuk kembali": ia
    // mengakhiri sesi, dan mengeluarkan orang dari aplikasi untuk menebak
    // sebuah penolakan yang tidak dimengerti adalah kerusakan yang pasti demi
    // perbaikan yang belum tentu.
    _ => HomeErrorRemedy.retry,
  };
}

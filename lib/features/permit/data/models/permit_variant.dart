import '../../../../core/utils/app_logger.dart';

/// Apa yang diminta sebuah jenis izin selain tanggal dan alasan.
///
/// Sebagian besar jenis tidak meminta apa pun lagi. Dua jenis meminta: satu
/// membetulkan jam absensi pada hari yang sudah dijalani, satu memindahkan
/// orang dari shift yang dijadwalkan ke shift lain. Masing-masing membuka
/// fieldnya sendiri di formulir dan butuh penjelasannya sendiri di layar
/// penyetuju.
///
/// ## Mengapa ini ada
///
/// Aplikasi ini dulu mengenali keduanya lewat kunci primer: `permit_type_id`
/// 15 berarti penyesuaian jam, 16 berarti tukar shift. Itu data tenant yang
/// dibaca sebagai makna bisnis, dan ia hanya benar pada satu basis data —
/// yang barisnya kebetulan dihitung di sana. Perusahaan lain yang membuat
/// jenis izinnya sendiri akan mendapat id 15 dan 16 menunjuk apa pun yang
/// kebetulan dibuat kelima belas dan keenam belas, lalu karyawan yang butuh
/// tukar shift disuguhi formulir penyesuaian jam tanpa cara untuk tahu.
///
/// Maknanya kini dibawa oleh `permit_types.code`, sebuah kolom yang diisi
/// sengaja oleh perusahaan. Server bahkan sudah menghitungkan variannya dan
/// mengirimnya sebagai `variant`.
enum PermitVariant {
  /// Tanggal, jam, dan alasan. Tidak ada yang lain.
  general('general'),

  /// Membetulkan jam masuk atau jam pulang pada hari yang dijadwalkan.
  timeAdjustment('time_adjustment', code: 'TIME_ADJUSTMENT'),

  /// Memindahkan orang dari satu shift ke shift lain.
  shiftAdjustment('shift_adjustment', code: 'SHIFT_ADJUSTMENT');

  const PermitVariant(this.wire, {this.code});

  /// Nama varian ini pada kolom `variant` yang dikirim server.
  final String wire;

  /// Kode bisnis pada `permit_types.code` yang memilih varian ini. Null untuk
  /// varian yang memang tidak butuh kode.
  final String? code;

  /// Nama varian sebagaimana dibaca karyawan.
  String get label => switch (this) {
    PermitVariant.general => 'Izin biasa',
    PermitVariant.timeAdjustment => 'Penyesuaian jam',
    PermitVariant.shiftAdjustment => 'Penyesuaian shift',
  };

  bool get isTimeAdjustment => this == PermitVariant.timeAdjustment;
  bool get isShiftAdjustment => this == PermitVariant.shiftAdjustment;

  /// Kolom `permits` yang boleh diisi oleh varian ini.
  ///
  /// Disebutkan di sini, bukan di dalam controller, karena jawabannya
  /// dibutuhkan dua kali — saat pengajuan disusun dan saat pengajuan
  /// digambar — dan dua salinan akan berbeda pada suatu hari.
  List<String> get fields => switch (this) {
    PermitVariant.general => const [],
    PermitVariant.timeAdjustment => const ['timein_adjust', 'timeout_adjust'],
    PermitVariant.shiftAdjustment => const [
      'current_shift_id',
      'adjust_shift_id',
    ],
  };

  /// Varian dari nama yang dikirim server pada `variant`.
  static PermitVariant? fromWire(String? value) {
    if (value == null) return null;

    final normalized = value.trim().toLowerCase();

    for (final variant in PermitVariant.values) {
      if (variant.wire == normalized) return variant;
    }

    return null;
  }

  /// Varian dari kode bisnis pada `permit_types.code`.
  ///
  /// Kode yang tidak dikenal berarti [PermitVariant.general], bukan galat:
  /// perusahaan menamai jenis izinnya sendiri, dan `ANNUAL` adalah kode yang
  /// sah yang memang tidak membuka field tambahan. Dibandingkan tanpa
  /// memperhatikan besar-kecil huruf supaya perusahaan yang menulisnya dengan
  /// huruf kecil tidak diam-diam diberi formulir yang salah.
  static PermitVariant? fromCode(String? value) {
    if (value == null) return null;

    final normalized = value.trim().toUpperCase();

    if (normalized.isEmpty) return null;

    for (final variant in PermitVariant.values) {
      if (variant.code != null && variant.code == normalized) return variant;
    }

    return PermitVariant.general;
  }

  /// Varian sebuah jenis izin, dari yang paling berwenang ke yang paling
  /// terpaksa.
  ///
  /// 1. `variant` — server sudah memutuskannya dari kode.
  /// 2. `code` — perusahaan sudah mengisi kodenya, server belum diperbarui.
  /// 3. Id 15/16 — peninggalan, dan hanya untuk perusahaan yang belum
  ///    mengisi kode sama sekali.
  static PermitVariant resolve({String? variant, String? code, int? id}) {
    final fromServer = fromWire(variant);

    if (fromServer != null) return fromServer;

    final fromBusinessCode = fromCode(code);

    if (fromBusinessCode != null) return fromBusinessCode;

    return _legacyIdFallback(id);
  }

  /// Pemetaan id peninggalan, sementara, dan sudah usang.
  ///
  /// Dipakai hanya ketika jenis izin tidak membawa kode maupun varian — yaitu
  /// perusahaan yang backendnya belum mengisi `permit_types.code`. Begitu kode
  /// itu terisi, cabang ini tidak pernah tercapai lagi dan seluruh blok ini
  /// bisa dihapus tanpa mengganti apa pun yang lain.
  ///
  /// Pemakaiannya dicatat — hanya idnya, bukan data karyawan — supaya
  /// perpindahan itu bisa dilihat selesai, bukan diduga selesai.
  /// **USANG.** Id bukan makna bisnis. Hapus seluruh method ini begitu setiap
  /// tenant mengisi `permit_types.code`; tidak ada pemanggil lain selain
  /// [resolve], dan menghapusnya tidak mengubah apa pun yang lain.
  static PermitVariant _legacyIdFallback(int? id) {
    const legacyIds = <int, PermitVariant>{
      15: PermitVariant.timeAdjustment,
      16: PermitVariant.shiftAdjustment,
    };

    final variant = legacyIds[id];

    if (variant == null) return PermitVariant.general;

    AppLogger.warning(
      'Jenis izin $id memakai pemetaan id peninggalan karena tidak mengirim '
      'code maupun variant; isi permit_types.code untuk jenis ini.',
    );

    return variant;
  }
}

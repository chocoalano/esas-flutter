import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/json_parsers.dart';
import 'permit_variant.dart';

/// Satu jenis perizinan yang boleh diajukan dari handset ini.
///
/// ## Dua kosakata
///
/// Model ini membaca dua generasi kontrak sekaligus, dan itu disengaja.
///
/// Backend lama (`esas-erp-api-modulars`) punya tabel `permit_types` dengan
/// kolom `type`, `is_payed`, `with_file`, `show_mobile`. Backend baru punya
/// `leave_types` dengan `code`, `name`, `requires_attachment`, `is_active` —
/// tidak satu pun nama kolomnya sama. Aplikasi ini sedang berpindah di antara
/// keduanya (ADR-0006), jadi sebuah model yang hanya paham satu sisi akan
/// memulangkan daftar tanpa nama pada sisi yang lain. Itulah yang terjadi:
/// setiap baris membaca `json['type']`, kunci yang tidak pernah dikirim, jadi
/// seluruh daftar tampil sebagai "Jenis izin tanpa nama".
///
/// ## Yang sengaja tidak dipetakan
///
/// Skema baru tidak punya padanan untuk "dibayar". Yang paling mirip adalah
/// `deducts_balance` — apakah pengajuan mengurangi saldo cuti — dan itu
/// pertanyaan yang berbeda: cuti tahunan mengurangi saldo dan tetap dibayar,
/// izin tanpa upah tidak mengurangi saldo apa pun. Memetakan keduanya akan
/// memberi tahu karyawan bahwa izinnya dibayar padahal tidak.
///
/// Maka [isPayed] boleh bernilai null, dan antarmuka tidak menampilkan lencana
/// upah ketika server tidak mengatakannya. Kosong itu jujur; tebakan tidak.
class LeaveType {
  const LeaveType({
    required this.id,
    required this.type,
    required this.isPayed,
    required this.approveLine,
    required this.approveManager,
    required this.approveHr,
    required this.withFile,
    required this.showMobile,
    this.code,
    this.variant = PermitVariant.general,
    this.description,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  final int id;

  /// Nama yang dibaca karyawan saat memilih. Berasal dari `name` pada kontrak
  /// baru dan `type` pada yang lama.
  final String type;

  /// Null berarti server tidak mengatakannya — bukan berarti tidak dibayar.
  final bool? isPayed;

  final bool approveLine;
  final bool approveManager;
  final bool approveHr;
  final bool withFile;
  final bool showMobile;

  /// Kode pendek (`ANNUAL`, `SICK`). Hanya ada pada kontrak baru.
  final String? code;

  /// Formulir yang dibuka jenis ini, dan kolom yang boleh diisinya.
  ///
  /// Diputuskan sekali di sini — dari `variant` kiriman server, lalu [code],
  /// lalu pemetaan id peninggalan — supaya tidak ada layar yang perlu
  /// menghitungnya sendiri, apalagi membaca kunci primer untuk itu.
  final PermitVariant variant;

  /// Penjelasan aturan jenis cuti. Hanya ada pada kontrak baru.
  final String? description;

  // Nullable, dan itu perubahan yang disengaja. Ketiganya dulu bertipe
  // `DateTime` non-null yang diisi `DateTime.parse(json[...] as String)` —
  // melempar dua kali atas sebuah null: sekali pada cast, sekali pada parse.
  // Menggantinya dengan `DateTime.now()` akan lebih buruk lagi: tanggal keliru
  // yang tampak masuk akal, persis yang dilarang R-10.
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  /// Mengurai satu baris jenis perizinan dari kedua kontrak.
  ///
  /// Setiap field mencoba kunci kontrak baru lebih dulu, lalu yang lama. Bila
  /// tidak satu pun kunci nama dikenali, daftar kunci baris itu dicatat — nama
  /// kuncinya saja, bukan nilainya — supaya bentuk ketiga yang tak terduga
  /// bisa dilihat alih-alih diam-diam menjadi baris tanpa nama.
  factory LeaveType.fromJson(Map<String, dynamic> json) {
    final String? name =
        asString(json['name']) ??
        asString(json['type']) ??
        asString(json['title']);

    if (name == null) {
      AppLogger.warning(
        'Baris jenis perizinan tanpa nama yang dikenali; '
        'kunci yang dikirim server: ${json.keys.join(', ')}',
      );
    }

    return LeaveType(
      id: asInt(json['id']) ?? 0,
      // Nama yang jelas-jelas salah, bukan string kosong: baris yang cacat
      // harus terlihat oleh karyawan yang bisa melaporkannya ke HR, bukan
      // menghilang diam-diam dari daftar.
      type: name ?? 'Jenis izin tanpa nama',
      code: asString(json['code']),
      variant: PermitVariant.resolve(
        variant: asString(json['variant']),
        code: asString(json['code']),
        id: asInt(json['id']),
      ),
      description: asString(json['description']),

      // Tidak ada padanan di kontrak baru; lihat catatan kelas di atas.
      isPayed: asBool(json['is_payed']) ?? asBool(json['is_paid']),

      // Lampiran dan tampil-di-mobile punya padanan yang benar-benar setara.
      withFile:
          asBool(json['requires_file']) ??
          asBool(json['requires_attachment']) ??
          asBool(json['with_file']) ??
          false,
      showMobile:
          asBool(json['is_active']) ?? asBool(json['show_mobile']) ?? false,

      // Kontrak baru meringkas tiga tingkat persetujuan menjadi satu bendera.
      // Tidak ada layar yang membacanya; dipertahankan agar kontrak lama tidak
      // kehilangan informasi.
      approveLine:
          asBool(json['approve_line']) ??
          asBool(json['requires_approval']) ??
          false,
      approveManager:
          asBool(json['approve_manager']) ??
          asBool(json['requires_approval']) ??
          false,
      approveHr:
          asBool(json['approve_hr']) ??
          asBool(json['requires_approval']) ??
          false,

      createdAt: asDate(json['created_at']),
      updatedAt: asDate(json['updated_at']),
      deletedAt: asDate(json['deleted_at']),
    );
  }

  /// Ditulis dalam kosakata baru, dengan kunci lama ikut disertakan supaya
  /// hasilnya bisa dibaca kembali oleh kedua sisi.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': type,
      'type': type,
      'code': code,
      'variant': variant.wire,
      'description': description,
      'is_payed': isPayed,
      'approve_line': approveLine,
      'approve_manager': approveManager,
      'approve_hr': approveHr,
      'requires_attachment': withFile,
      'with_file': withFile,
      'is_active': showMobile,
      'show_mobile': showMobile,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }
}

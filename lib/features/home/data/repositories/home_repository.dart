import '../../../attendance/data/models/attendance_context.dart';
import '../../../../core/utils/json_parsers.dart';
import '../../../../features/auth/data/repositories/session_repository.dart';
import '../../../permit/data/models/leave_list.dart';
import '../models/activity_log.dart';
import '../models/announcement.dart';
import '../services/home_api_service.dart';

/// Jenis hari menurut kalender kerja server.
///
/// Ini jawaban yang HANYA server bisa berikan: ia memegang kalender hari libur,
/// pola kerja, dan cuti yang sudah disetujui. Sebuah aplikasi yang menebaknya
/// dari "tidak ada jadwal" akan menyebut hari raya sebagai hari kosong, dan
/// menyebut cuti yang sudah disetujui sebagai kelalaian.
///
/// `null` — yaitu [HomeDayType.unknown] tidak dipakai, field-nya memang nullable
/// — berarti server pada instalasi ini belum mengirim blok `day_context`. Itu
/// BUKAN kesalahan dan bukan hari kerja: layar kembali ke perilaku lama, yakni
/// menyimpulkan dari ada-tidaknya jadwal. Aplikasi ponsel hidup lebih lama
/// daripada satu rilis backend.
enum HomeDayType {
  /// Hari kerja biasa.
  workday,

  /// Hari libur pola kerja orang ini — akhir pekan, atau giliran liburnya.
  dayOff,

  /// Hari libur nasional atau libur perusahaan.
  holiday,

  /// Cuti/izin yang sudah disetujui untuk hari ini.
  leave,
}

/// Konteks hari ini: jenisnya, dan namanya bila ia punya nama.
class DayContext {
  const DayContext({required this.type, this.label, this.holidayName});

  final HomeDayType type;

  /// Kalimat siap tampil dari server, bila ada. Dipakai apa adanya karena
  /// server yang tahu bahasa tenant-nya; layar tidak pernah menerjemahkan kode.
  final String? label;

  /// Nama hari liburnya, misalnya "Hari Kemerdekaan Republik Indonesia".
  final String? holidayName;

  /// Baca blok `day_context`, atau `null` bila server belum mengirimnya.
  ///
  /// Ketat terhadap tipe dan longgar terhadap ejaan: `PUBLIC_HOLIDAY`,
  /// `public-holiday` dan `holiday` sama-sama diterima, karena penamaan enum
  /// backend belum final dan sebuah layar yang gagal membaca hari libur akan
  /// menyodorkan tombol absen pada hari raya.
  ///
  /// Tipe yang TIDAK dikenali menghasilkan `null`, bukan [HomeDayType.workday].
  /// Menebak "hari kerja" untuk nilai yang tidak dimengerti adalah cara paling
  /// cepat menampilkan ajakan absen pada hari orang tidak bekerja.
  static DayContext? fromJson(Object? raw) {
    if (raw is! Map) return null;

    final Map<String, dynamic> json = asObject(raw);
    final String key = (asString(json['type']) ?? '').toLowerCase().replaceAll(
      RegExp(r'[^a-z]'),
      '',
    );

    final HomeDayType? type = switch (key) {
      'workday' || 'work' || 'working' => HomeDayType.workday,
      'dayoff' || 'off' || 'rest' || 'weekly' => HomeDayType.dayOff,
      'holiday' || 'publicholiday' || 'nationalholiday' => HomeDayType.holiday,
      'leave' || 'approvedleave' || 'onleave' || 'permit' => HomeDayType.leave,
      _ => null,
    };

    if (type == null) return null;

    return DayContext(
      type: type,
      label: asString(json['label']),
      holidayName: asString(json['holiday_name']) ?? asString(json['name']),
    );
  }
}

/// Today's attendance and schedule, flattened for the dashboard.
///
/// Every field is nullable and stays nullable all the way to the screen. The
/// dashboard used to flatten "not clocked in yet" into the string `--:--` here,
/// which meant the panel above could no longer tell "belum absen" apart from
/// "sudah absen, jamnya tidak terbaca" — and drew both with equal confidence.
class DashboardTimes {
  const DashboardTimes({
    this.timeIn,
    this.timeOut,
    this.statusIn,
    this.statusOut,
    this.scheduleIn,
    this.scheduleOut,
    this.scheduleName,
    this.nextPresence,
    this.attendanceEnabled,
    this.dayContext,
    this.shift,
  });

  final String? timeIn;
  final String? timeOut;
  final String? statusIn;
  final String? statusOut;
  final String? scheduleIn;
  final String? scheduleOut;
  final String? scheduleName;

  /// Shift hari ini sebagaimana server mengirimkannya, lengkap dengan
  /// `spans_midnight` dan momen mulai/selesai yang sebenarnya. Dipakai layar
  /// untuk menulis "(+1 hari)" tanpa menebaknya dari dua string jam.
  final AttendanceShift? shift;

  /// Ketukan berikutnya menurut SERVER: `'in'`, `'out'`, atau `null` bila tidak
  /// ada lagi yang diharapkan hari ini.
  ///
  /// Ini jawaban yang sudah dikirim `attendance/context` di setiap pembukaan
  /// Beranda dan tidak pernah sekali pun dibaca. Menghitungnya sendiri dari
  /// "sudah ada `time_in`, berarti berikutnya pulang" benar untuk hari kerja
  /// biasa dan salah untuk semua yang lain — shift yang melewati tengah malam,
  /// baris yang lewat grace period, hari yang sudah ditutup pengajuan izin.
  /// `AttendanceDay` di server sudah menyelesaikan semuanya (README §0.5), jadi
  /// yang benar adalah membacanya, bukan menirunya.
  final String? nextPresence;

  /// Apakah akun ini boleh melakukan absensi sama sekali.
  ///
  /// `null` berarti server tidak mengatakannya, dan itu TIDAK sama dengan
  /// `false`: sebuah instalasi yang belum mengirim bendera ini tidak sedang
  /// melarang siapa pun. Layar memperlakukan `null` seperti `true` dan hanya
  /// menyembunyikan ajakan absen ketika jawabannya tegas `false` — aturan UI
  /// README: tombol yang hanya bisa gagal lebih buruk daripada tidak ada
  /// tombol, tetapi tombol yang hilang tanpa alasan lebih buruk lagi.
  final bool? attendanceEnabled;

  /// Jenis hari menurut kalender kerja server, `null` bila belum dikirim.
  final DayContext? dayContext;

  /// Apakah hari ini punya jadwal sama sekali.
  ///
  /// Dibedakan dari "jadwalnya gagal dimuat" oleh slot galat di controller:
  /// yang ini hanya berarti server menjawab, dan jawabannya kosong.
  bool get hasSchedule =>
      scheduleIn != null || scheduleOut != null || scheduleName != null;
}

/// Sisa cuti untuk satu jenis izin yang menyimpan saldo.
///
/// Hanya baris yang benar-benar terbaca yang menjadi sebuah [LeaveBalance]:
/// namanya harus berupa teks dan sisanya harus berupa angka. Baris yang tidak
/// memenuhi keduanya dilewati, karena "0 hari" yang sebetulnya berarti "tidak
/// terbaca" adalah jawaban yang salah pada layar yang dipakai orang untuk
/// memutuskan apakah ia bisa mengambil cuti.
class LeaveBalance {
  const LeaveBalance({
    required this.code,
    required this.label,
    required this.remaining,
    this.quota,
  });

  /// Kode mentah dari server, misalnya `ANNUAL`. Tidak pernah ditampilkan apa
  /// adanya — lapisan tampilan yang menerjemahkannya ke bahasa Indonesia.
  final String code;

  /// Nama yang dikirim server bila ada. Bisa sama dengan [code].
  final String label;

  final int remaining;

  /// Jatah setahun, bila server mengirimkannya. Sebuah sisa tanpa jatah adalah
  /// angka tanpa skala.
  final int? quota;
}

/// Ringkasan kehadiran satu bulan berjalan.
///
/// Hanya dua angka yang benar-benar dikirim server dibaca di sini —
/// `worked_days` dan `late_count` — dan yang ketiga diturunkan dari keduanya.
/// Itu keputusan yang sama yang sudah diambil `ProfileRepository`, dan ia
/// diambil dua kali dengan sengaja: sebuah angka "tepat waktu" yang ikut
/// dikirim server adalah angka ketiga yang bisa tidak sepakat dengan dua yang
/// lain.
class MonthSummary {
  const MonthSummary({required this.workedDays, required this.lateCount});

  final int workedDays;
  final int lateCount;

  /// Hari yang tidak terlambat. Tidak pernah negatif: sebuah bulan dengan lebih
  /// banyak keterlambatan daripada hari kerja adalah data yang rusak, dan
  /// jawaban yang benar untuknya adalah nol, bukan bilangan negatif di layar.
  int get onTimeDays => workedDays - lateCount < 0 ? 0 : workedDays - lateCount;

  /// Apakah ada yang layak digambar sama sekali. Sebuah bulan tanpa satu pun
  /// hari kerja tercatat — karyawan baru di hari pertama — lebih baik tidak
  /// menampilkan bagian ini daripada menampilkan tiga angka nol.
  bool get hasData => workedDays > 0;
}

/// Sebuah jawaban, kapan ia diterima, dan MILIK SIAPA.
///
/// Id pemiliknya ikut disimpan karena satu handset dipakai lebih dari satu
/// orang di pabrik: seorang karyawan keluar, karyawan berikutnya masuk, dan
/// tanpa pemeriksaan ini sisa cuti orang sebelumnya akan tergambar di Beranda
/// orang berikutnya sampai TTL-nya habis. Kedaluwarsa waktu saja tidak cukup —
/// yang salah bukan umurnya, melainkan pemiliknya.
class _Cached<T> {
  const _Cached(this.value, this.at, this.ownerId);

  final T value;
  final DateTime at;
  final int? ownerId;

  bool isUsableBy(int? currentOwner, DateTime now, Duration ttl) =>
      ownerId == currentOwner && now.difference(at) < ttl;
}

class HomeRepository {
  HomeRepository({
    required HomeApiService api,
    required SessionRepository session,
  }) : _api = api,
       _session = session;

  final HomeApiService _api;
  final SessionRepository _session;

  /// Berapa lama rekap bulanan boleh dipakai ulang.
  ///
  /// Ia satu-satunya jawaban di layar ini yang benar-benar bergerak lambat:
  /// `worked_days` dan `late_count` berubah paling banyak sekali sehari, dan
  /// TIDAK berubah karena seseorang menekan tab Beranda. Sebelum ada cache ini
  /// setiap ketukan tab menembakkan empat permintaan, yang di jaringan pabrik
  /// terasa sebagai layar yang selalu sedang memuat.
  ///
  /// Tiga jawaban lain sengaja tidak ikut, masing-masing dengan alasannya:
  /// absensi hari ini adalah alasan layar ini dibuka; pengumuman adalah
  /// satu-satunya kanal kabar mendadak; dan saldo cuti berubah karena tindakan
  /// di dalam aplikasi ini sendiri.
  ///
  /// Konsekuensi yang diterima: sesudah absen pulang, rekap bulanan bisa
  /// tertinggal satu hari selama paling lama sepuluh menit. Ia bagian paling
  /// sekunder di halaman, dan tarik-untuk-menyegarkan memaksanya seketika.
  static const Duration slowMovingTtl = Duration(minutes: 10);

  _Cached<MonthSummary>? _summary;

  /// Buang semua yang di-cache.
  void invalidate() {
    _summary = null;
  }

  /// Siapa yang sedang masuk. Kunci kepemilikan cache.
  int? get _ownerId => _session.user?.id;

  String get userName => _session.user?.name ?? 'Anonymous';

  String get userAvatar => _session.user?.avatar ?? '';

  /// Notifikasi belum dibaca yang terakhir diketahui, atau `null`.
  ///
  /// Dibaca dari sesi, BUKAN dari jaringan. Beranda tidak memanggil endpoint
  /// notifikasi dan tidak akan memanggilnya: satu permintaan HTTP untuk sebuah
  /// titik merah adalah harga yang salah, terutama di jaringan pabrik. Nilainya
  /// diisi payload sesi bila backend mengirim `unread_notification_count`, dan
  /// diperbarui layar notifikasi setiap kali ia memuat satu halaman.
  int? get unreadNotifications => _session.unreadNotifications;

  /// Today's clock, and the shift it is measured against.
  ///
  /// One request where there used to be two, because the server answers both in
  /// `attendance/context` - and it no longer takes an employee id. The old
  /// `/auth/current-attendance/{id}` asked the phone who was standing in front
  /// of it, which is a question no attendance system should accept an answer to.
  ///
  /// It also answers the schedule, so the dashboard asks once. The version this
  /// replaces called this same endpoint twice on every open — once for the
  /// clock and once for the shift it had just been told.
  Future<DashboardTimes> todayAttendance() async {
    final body = await _api.attendanceContext();
    final attendance = asObject(body['attendance']);

    // Melalui `AttendanceShift`, bukan pembacaan sendiri.
    //
    // Endpoint yang sama dulu diurai di dua tempat dengan aturan berbeda: layar
    // absensi membaca empat kunci, dasbor ini membaca tiga, dan tidak ada yang
    // membaca `spans_midnight`. Satu pengurai berarti satu jawaban.
    final shift = AttendanceShift.fromJson(body['schedule']);

    return DashboardTimes(
      timeIn: asString(attendance['time_in']),
      timeOut: asString(attendance['time_out']),
      statusIn: asString(attendance['status_in']),
      statusOut: asString(attendance['status_out']),
      scheduleIn: shift?.start,
      scheduleOut: shift?.end,
      scheduleName: shift?.name,
      shift: shift,
      nextPresence: _direction(body['next_presence']),
      attendanceEnabled: asBool(body['attendance_enabled']),
      // Blok tambahan yang backward-compatible: sebuah backend yang belum
      // mengirimnya menghasilkan `null`, dan layar kembali ke perilaku lama.
      dayContext: DayContext.fromJson(body['day_context']),
    );
  }

  /// `next_presence`, dinormalkan ke `'in'` / `'out'` / `null`.
  ///
  /// Dibaca longgar terhadap bentuk dan ketat terhadap nilai. Bendera ini
  /// pernah dikirim sebagai teks telanjang (`"in"`) dan pernah sebagai objek
  /// (`{"type": "in", ...}`), jadi keduanya diterima; apa pun yang tidak
  /// menghasilkan salah satu dari dua kata itu menjadi `null`, dan `null`
  /// membuat layar kembali menyimpulkan arah dari jamnya sendiri. Menebak arah
  /// yang salah lebih mahal daripada tidak tahu: ia menuliskan "Absen pulang"
  /// di depan orang yang belum absen masuk.
  static String? _direction(Object? raw) {
    final Object? value = raw is Map
        ? asObject(raw)['type'] ?? raw['direction']
        : raw;
    final String? text = asString(value)?.trim().toLowerCase();

    return (text == 'in' || text == 'out') ? text : null;
  }

  /// Sisa cuti per jenis izin yang menyimpan saldo.
  ///
  /// `HomeApiService.leaveBalance()` sudah ditulis dan sudah dirutekan ke
  /// `/me/leave-balance` sejak lama, dan tidak pernah dipanggil dari mana pun —
  /// sisa cuti adalah pertanyaan yang dibawa karyawan ke aplikasi ini dan
  /// jawabannya sudah dibayar setiap rilis.
  ///
  /// Pembacaannya sengaja longgar terhadap bentuk amplop dan ketat terhadap
  /// isinya: server boleh membungkus barisnya di `data`, di `balances`, atau
  /// mengirim array telanjang, tetapi sebuah baris hanya dihitung bila nama dan
  /// sisanya sama-sama terbaca.
  /// Sengaja TIDAK di-cache, walaupun ia terlihat seperti kandidat terbaiknya.
  ///
  /// Saldo cuti berubah karena sebuah tindakan DI DALAM aplikasi ini: seseorang
  /// mengajukan izin, lalu kembali ke Beranda. Sebuah jawaban berumur sepuluh
  /// menit akan menggambar saldo sebelum pengajuannya — dan ini persis angka
  /// yang dipakai orang untuk memutuskan apakah ia bisa mengambil cuti lagi.
  /// Satu permintaan lebih murah daripada satu angka yang salah di layar itu.
  Future<List<LeaveBalance>> leaveBalances({bool refresh = false}) async {
    final body = await _api.leaveBalance();

    final Object? envelope = body['balances'] ?? body['data'] ?? body;
    final rows = asPage(envelope);

    final balances = <LeaveBalance>[];

    for (final row in rows) {
      if (row is! Map) {
        continue;
      }

      final json = Map<String, dynamic>.from(row);
      final String? code = _text(json, const ['code', 'type', 'permit_type']);
      final String? name = _text(json, const [
        'label',
        'name',
        'type_name',
        'leave_type',
        'permit_type',
        'type',
      ]);
      final int? remaining = _number(json, const [
        'remaining',
        'balance',
        'sisa',
        'available',
        'remaining_days',
      ]);

      if (name == null || remaining == null) {
        continue;
      }

      balances.add(
        LeaveBalance(
          code: code ?? name,
          label: name,
          remaining: remaining,
          quota: _number(json, const [
            'quota',
            'total',
            'entitled',
            'allocated',
          ]),
        ),
      );
    }

    return balances;
  }

  /// Teks pertama yang benar-benar berupa teks.
  ///
  /// `asString` mengembalikan `toString()` untuk nilai apa pun yang bukan null,
  /// jadi sebuah objek relasi akan lolos sebagai `{id: 1, name: Cuti}` kalau
  /// tidak diperiksa tipenya lebih dulu. Objek dibaca `name`-nya.
  static String? _text(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final Object? value = json[key];

      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }

      if (value is Map) {
        final nested = asString(asObject(value)['name']);
        if (nested != null && nested.isNotEmpty) {
          return nested;
        }
      }
    }

    return null;
  }

  static int? _number(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final Object? value = json[key];

      if (value is num || value is String) {
        final parsed = asInt(value);
        if (parsed != null) {
          return parsed;
        }
      }
    }

    return null;
  }

  /// Kehadiran bulan berjalan.
  ///
  /// Tanpa argumen: server memakai bulan berjalan pada jam workspace, yang
  /// adalah satu-satunya bulan yang jawabannya tidak bisa diperdebatkan oleh
  /// ponsel yang zonanya melenceng.
  Future<MonthSummary> monthSummary({bool refresh = false}) async {
    final cached = _summary;

    if (!refresh &&
        cached != null &&
        cached.isUsableBy(_ownerId, DateTime.now(), slowMovingTtl)) {
      return cached.value;
    }

    final body = await _api.attendanceSummary();
    final summary = asObject(body['summary']);

    final value = MonthSummary(
      workedDays: asDouble(summary['worked_days'])?.round() ?? 0,
      lateCount: asInt(summary['late_count']) ?? 0,
    );

    _summary = _Cached<MonthSummary>(value, DateTime.now(), _ownerId);

    return value;
  }

  /// Tiga pengajuan terakhir, untuk "Aktivitas terbaru".
  ///
  /// Sengaja **tidak di-cache**, dengan alasan yang sama seperti saldo cuti: ia
  /// berubah karena tindakan DI DALAM aplikasi ini. Seseorang mengajukan izin
  /// lalu kembali ke Beranda, dan sebuah jawaban berumur sepuluh menit akan
  /// menggambar daftar tanpa pengajuan yang baru saja ia kirim — yaitu satu-
  /// satunya baris yang ia cari. Tidak ada mesin invalidasi yang perlu ditulis;
  /// tidak menyimpannya sudah cukup.
  Future<List<Permit>> recentPermits({int limit = 3}) async {
    final body = await _api.recentPermits(perPage: limit);

    return asModelList(asPage(body), Permit.fromJson).take(limit).toList();
  }

  Future<List<Announcement>> activeAnnouncements() async => asModelList(
    asPage(await _api.activeAnnouncements()),
    Announcement.fromJson,
  );

  Future<List<ActivityLog>> recentActivity() async =>
      asModelList(asPage(await _api.activity()), ActivityLog.fromJson);

  /// A page of notices.
  ///
  /// No `search`. The server does not offer one on this collection, and a
  /// parameter it ignores is worse than one that is absent: the screen looks
  /// like it filtered and did not.
  Future<List<Announcement>> announcements({
    required int page,
    required int perPage,
  }) async {
    final body = await _api.announcements(page: page, perPage: perPage);

    return asModelList(asPage(body), Announcement.fromJson);
  }

  /// One notice, with its body.
  ///
  /// The envelope is `announcement`; `data` is what the retired backend called
  /// it. Reading the wrong one fell through to the whole body and produced a
  /// notice with no title and no content.
  Future<Announcement> announcement(Object id) async {
    final body = await _api.announcement(id);

    return Announcement.fromJson(asObject(body['announcement']));
  }
}

import 'package:esas/core/tenancy/workspace_clock.dart';
import 'package:esas/core/utils/app_logger.dart';
import 'package:esas/core/utils/date_formatter.dart';
import 'package:get/get.dart';

import '../../../../core/network/api_exception.dart';
import '../../../permit/data/models/leave_list.dart';
import '../../data/models/announcement.dart';
import '../../data/repositories/home_repository.dart';
import '../../../auth/data/repositories/session_repository.dart';

/// Hari kerja hari ini, sebagai satu keadaan yang bisa disaklar.
///
/// Ia hidup di controller dan bukan di widget karena ia adalah kesimpulan
/// tentang DATA, bukan tentang tampilan: urutan cabangnya menentukan kalimat
/// mana yang dibaca karyawan jam 06:50, dan urutan itu harus bisa diuji tanpa
/// membangun satu widget pun.
///
/// Urutannya juga bukan selera. "Sudah absen" mendahului "gagal memuat", karena
/// sebuah jam masuk yang sudah sampai tetap benar walaupun permintaan yang
/// membawanya kemudian gagal disegarkan — dan memberi tahu orang bahwa
/// absensinya tidak terbaca padahal jamnya ada di layar adalah cara tercepat
/// membuat orang berhenti mempercayai layar ini.
enum HomeTodayState {
  /// Pembukaan dingin: belum ada apa pun, dan rangka yang digambar.
  loading,

  /// Permintaan absensi gagal dan tidak ada satu pun jam yang sempat sampai.
  ///
  /// Panel protagonis TETAP digambar untuk keadaan ini; jenis kegagalannya
  /// dibaca dari [ApiException] yang menyertainya. Beranda pernah mengganti
  /// seluruh panel dengan satu kalimat di sini, dan hasilnya adalah dasbor yang
  /// kehilangan jangkarnya justru pada saat sesuatu sedang salah.
  unavailable,

  /// Server menjawab dengan tegas bahwa akun ini tidak boleh mengabsen, dan
  /// tidak ada jadwal maupun ketukan yang bisa diceritakan.
  ///
  /// Ini BUKAN kegagalan. Tidak ada yang rusak, tidak ada yang perlu dicoba
  /// lagi, dan tidak ada yang salah dengan orangnya — jadi ia tidak pernah
  /// digambar dengan bahasa visual sebuah galat.
  attendanceDisabled,

  /// Hari libur pola kerja orang ini. Server yang mengatakannya.
  dayOff,

  /// Hari libur nasional atau libur perusahaan. Server yang mengatakannya.
  holiday,

  /// Cuti yang sudah disetujui untuk hari ini. Server yang mengatakannya.
  onLeave,

  /// Tidak ada jadwal, dan server tidak mengatakan hari apa ini.
  ///
  /// Ini keadaan CADANGAN, bukan sinonim hari libur: ia berlaku pada instalasi
  /// yang belum mengirim `day_context`, dan kalimatnya sengaja tidak mengklaim
  /// bahwa hari ini libur.
  noSchedule,

  /// Ada jadwal, belum ada ketukan.
  notClockedIn,

  /// Sudah absen masuk, belum absen pulang.
  working,

  /// Keduanya sudah tercatat.
  done,
}

/// Ketukan absen berikutnya, sebagai tipe dan bukan sebagai string.
///
/// `'in'` dan `'out'` adalah ejaan KAWAT, dan ejaan kawat berhenti di
/// repository. Selama ia merambat sampai widget, akan selalu ada layar yang
/// menuliskan `== 'out'` dengan huruf besar, atau membandingkannya dengan
/// `'clock_out'` ketika backend memperluas enum-nya, dan gagal diam-diam.
enum AttendancePunch {
  clockIn,
  clockOut;

  /// Baca ejaan kawat. Nilai yang tidak dikenali menjadi `null`, dan `null`
  /// berarti "tidak ada ketukan yang ditawarkan" — bukan "tebak sendiri".
  static AttendancePunch? parse(String? raw) {
    final String key = (raw ?? '').toLowerCase().replaceAll(
      RegExp(r'[^a-z]'),
      '',
    );

    return switch (key) {
      'in' || 'clockin' || 'checkin' => AttendancePunch.clockIn,
      'out' || 'clockout' || 'checkout' => AttendancePunch.clockOut,
      _ => null,
    };
  }
}

/// Keadaan Beranda.
///
/// Perubahan terbesar di sini bukan tampilan, melainkan kejujuran. Versi
/// sebelumnya menyimpan jam sebagai empat `SummaryCard` yang di-*seed* dengan
/// `--:--`, menulis `isLoading` di dua tempat dan tidak pernah membacanya di
/// mana pun. Akibatnya satu-satunya keadaan yang bisa digambar layar ini adalah
/// "sudah tahu": pembukaan dingin menampilkan `--:--`, "Belum Absen" merah, dan
/// dua keadaan kosong sekaligus — tiga pernyataan percaya diri tentang data
/// yang belum sampai.
///
/// Sekarang nilainya nullable, `isLoading` dibaca, dan setiap panel membawa
/// pesan galatnya sendiri sehingga layar bisa mengatakan "gagal memuat" alih-
/// alih "tidak ada".
class HomeController extends GetxController {
  HomeController({required HomeRepository repository})
    : _repository = repository;

  final HomeRepository _repository;
  Worker? _notificationCountWorker;
  Worker? _notificationRefreshWorker;

  /// Nomor urut penyegaran terakhir yang dimulai. Lihat [refreshDashboard].
  int _generation = 0;

  final userName = 'Anonymous'.obs;
  final userAvatarUrl = ''.obs;
  final currentDate = ''.obs;

  /// Notifikasi belum dibaca, `null` selama belum pernah diketahui.
  ///
  /// Dibaca ulang pada setiap penyegaran karena ia gratis — sumbernya sesi, dan
  /// sesi diperbarui layar notifikasi. Sebuah `null` di sini berarti lencananya
  /// tidak digambar sama sekali; nol yang dikarang akan berbohong setiap pagi.
  final Rxn<int> unreadNotifications = Rxn<int>();

  /// Sedang mengambil data. Dibaca layar, bukan sekadar ditulis.
  final isLoading = false.obs;

  /// Sudah pernah selesai sekali, apa pun hasilnya. Inilah yang membedakan
  /// pembukaan dingin (rangka) dari tarik-untuk-menyegarkan (data lama tetap
  /// terlihat sementara yang baru diambil).
  final hasLoaded = false.obs;

  /// Jam absen hari ini, `null` bila belum ada — bukan `--:--`.
  final Rxn<String> timeIn = Rxn<String>();
  final Rxn<String> timeOut = Rxn<String>();

  /// Kalimat status dari server ("Tepat waktu", "Terlambat 12 menit").
  final Rxn<String> statusIn = Rxn<String>();
  final Rxn<String> statusOut = Rxn<String>();

  /// Jadwal hari ini. Diambil sejak dulu dan tidak pernah digambar.
  final Rxn<String> scheduleIn = Rxn<String>();
  final Rxn<String> scheduleOut = Rxn<String>();
  final Rxn<String> shiftName = Rxn<String>();

  /// Ketukan berikutnya menurut server, sudah bertipe.
  final Rxn<AttendancePunch> nextPresence = Rxn<AttendancePunch>();

  /// Konteks hari ini menurut server, `null` bila backend belum mengirimnya.
  final Rxn<DayContext> dayContext = Rxn<DayContext>();

  /// Apakah akun ini boleh mengabsen. `null` berarti server tidak mengatakannya
  /// dan diperlakukan sebagai boleh — lihat [DashboardTimes.attendanceEnabled].
  final Rxn<bool> attendanceEnabled = Rxn<bool>();

  /// Apakah server sempat menjawab konteks hari ini pada pemuatan terakhir.
  ///
  /// Dipakai untuk membedakan dua hal yang sebelumnya tercampur: server yang
  /// menjawab `next_presence: null` — artinya tidak ada ketukan yang tersisa —
  /// dan server yang tidak menjawab sama sekali. Keduanya dulu sama-sama
  /// membuat layar menurunkan arahnya sendiri dari `time_in`/`time_out`, dan
  /// justru pada kasus pertama turunan itu bertentangan dengan jawaban server.
  final RxBool contextAnswered = false.obs;

  /// Ringkasan kehadiran bulan berjalan, `null` selama belum terbaca.
  final Rxn<MonthSummary> monthSummary = Rxn<MonthSummary>();

  /// Beberapa pengajuan terakhir. Kosong berarti belum ada, bukan gagal —
  /// kegagalannya ada di [activityError].
  final RxList<Permit> recentPermits = <Permit>[].obs;

  final RxList<Announcement> announcements = <Announcement>[].obs;
  final RxList<LeaveBalance> leaveBalances = <LeaveBalance>[].obs;

  /// Galat per panel. `null` berarti panel itu berhasil dimuat.
  ///
  /// Menyimpan [ApiException] dan bukan `String` adalah perbaikan yang sudah
  /// dituliskan sebagai catatan di `home_error_notice.dart` dan sekarang
  /// dikerjakan. Selama slot ini bertipe `String`, status HTTP-nya dibuang di
  /// `_load`, dan satu-satunya bukti yang tersisa untuk memilih jalan keluar
  /// adalah KALIMAT Indonesia dari server — sehingga layar terpaksa mencocokkan
  /// substring seperti `'masuk kembali'`. Itu pecah pada hari pertama seseorang
  /// memperbaiki tata bahasa sebuah pesan galat.
  ///
  /// Sekarang statusnya utuh sampai ke layar, dan `401` adalah `401`.
  final Rxn<ApiException> attendanceError = Rxn<ApiException>();
  final Rxn<ApiException> announcementError = Rxn<ApiException>();
  final Rxn<ApiException> leaveError = Rxn<ApiException>();
  final Rxn<ApiException> summaryError = Rxn<ApiException>();
  final Rxn<ApiException> activityError = Rxn<ApiException>();

  @override
  void onInit() {
    super.onInit();
    if (Get.isRegistered<SessionRepository>()) {
      final session = Get.find<SessionRepository>();
      _notificationCountWorker = ever(
        session.unreadNotificationCount,
        (count) => unreadNotifications.value = count,
      );
      _notificationRefreshWorker = ever(
        session.notificationRevision,
        (_) => refreshDashboard(force: true),
      );
    }

    userName.value = _repository.userName;
    userAvatarUrl.value = _repository.userAvatar;
    unreadNotifications.value = _repository.unreadNotifications;
    // The workspace's today, not the handset's. A phone an hour the wrong side
    // of midnight showed a date the attendance below it disagreed with.
    currentDate.value = DateFormatter.nowFormatted('EEEE, d MMMM yyyy');

    refreshDashboard();
  }

  @override
  void onClose() {
    _notificationCountWorker?.dispose();
    _notificationRefreshWorker?.dispose();
    super.onClose();
  }

  /// Sudah absen masuk hari ini.
  bool get hasCheckedIn => timeIn.value != null;

  /// Sudah absen pulang hari ini.
  bool get hasCheckedOut => timeOut.value != null;

  /// Berapa ketukan absen yang hari ini belum tercatat: 1 sebelum absen masuk,
  /// 1 lagi selama absen pulang belum ada, 0 setelah keduanya lengkap.
  int get openPunches {
    if (!hasCheckedIn) {
      return 1;
    }

    return hasCheckedOut ? 0 : 1;
  }

  /// Apakah hari ini punya jadwal yang bisa dijadikan pembanding.
  bool get hasSchedule =>
      scheduleIn.value != null ||
      scheduleOut.value != null ||
      shiftName.value != null;

  /// Hari kerja hari ini, sebagai satu nilai.
  ///
  /// Ini satu-satunya tempat kesimpulan itu diambil. Sebelumnya ia tersebar di
  /// empat widget yang masing-masing menyusun ulang cabangnya sendiri dari
  /// `timeIn`, `timeOut` dan `attendanceError` — dan ketiganya sempat tidak
  /// sepakat: panel utama menggambar "Belum Absen" merah pada saat yang sama
  /// strip di bawahnya menggambar em dash bertuliskan "absen tidak terbaca".
  HomeTodayState get todayState {
    if (!hasLoaded.value && isLoading.value) {
      return HomeTodayState.loading;
    }

    // Ketukan yang sudah tercatat mengalahkan galat: jam yang sudah sampai
    // tetap benar walaupun penyegaran berikutnya gagal.
    if (hasCheckedIn) {
      return hasCheckedOut ? HomeTodayState.done : HomeTodayState.working;
    }

    if (attendanceError.value != null) {
      return HomeTodayState.unavailable;
    }

    // Kapabilitas diperiksa SEBELUM jenis hari, tetapi SESUDAH jadwal di bawah
    // tidak — urutannya sengaja begini: kalau ada jadwal, hari ini tetap hari
    // kerja dan yang hilang cuma tombolnya, dan itu diurus `canPunchNow`.
    if (!hasSchedule && attendanceEnabled.value == false) {
      return HomeTodayState.attendanceDisabled;
    }

    // Sebuah hari yang PUNYA jadwal adalah hari kerja, apa pun kata kalender.
    // Orang yang dirosterkan pada hari raya tetap harus melihat shiftnya dan
    // tombolnya; menyembunyikan keduanya karena kalender berkata "libur" adalah
    // cara membuat orang yang benar-benar masuk kerja tidak bisa mengabsen.
    if (hasSchedule) {
      return HomeTodayState.notClockedIn;
    }

    return switch (dayContext.value?.type) {
      HomeDayType.holiday => HomeTodayState.holiday,
      HomeDayType.dayOff => HomeTodayState.dayOff,
      HomeDayType.leave => HomeTodayState.onLeave,
      // `workday` tanpa jadwal, dan instalasi yang belum mengirim
      // `day_context`, sama-sama jatuh ke sini: layar mengatakan bahwa tidak ada
      // jadwal, bukan bahwa hari ini libur.
      HomeDayType.workday || null => HomeTodayState.noSchedule,
    };
  }

  /// Arah ketukan berikutnya: `'in'`, `'out'`, atau `null` bila tidak ada lagi.
  ///
  /// Jawaban server dipakai apa adanya, **termasuk ketika jawabannya `null`**.
  /// `next_presence: null` bukan diam — itu jawaban, dan artinya hari ini sudah
  /// selesai. Layar ini dulu menurunkan arahnya sendiri dari `time_in` dan
  /// `time_out` setiap kali server menjawab `null`, sehingga tepat pada kasus
  /// itu ia menulis "Absen pulang" di atas hari yang menurut server sudah
  /// lengkap. Server melihat hari roster, shift yang melewati tengah malam, dan
  /// grace period; layar ini hanya melihat dua string jam.
  ///
  /// Turunan lokal hanya dipakai bila server memang tidak sempat menjawab —
  /// lihat [contextAnswered] — dan sengaja konservatif: tanpa jadwal dan tanpa
  /// ketukan, tidak ada arah yang bisa diklaim.
  AttendancePunch? get nextPunch {
    final AttendancePunch? fromServer = nextPresence.value;

    if (fromServer != null) {
      return fromServer;
    }

    if (contextAnswered.value) {
      return null;
    }

    return switch (todayState) {
      HomeTodayState.notClockedIn => AttendancePunch.clockIn,
      HomeTodayState.working => AttendancePunch.clockOut,
      _ => null,
    };
  }

  /// Apakah ajakan absen utama boleh digambar.
  ///
  /// Dua syarat, dan keduanya milik SERVER: akun ini boleh mengabsen, dan masih
  /// ada ketukan yang diharapkan hari ini. Sengaja tidak melihat [todayState] —
  /// kalimat di panel adalah narasi, sedangkan izin mengabsen adalah aturan
  /// bisnis, dan yang kedua tidak boleh disimpulkan dari yang pertama.
  bool get canPunchNow => canClock && nextPunch != null;

  /// Apakah ajakan absen boleh digambar sama sekali.
  ///
  /// Hanya `false` yang tegas dari server yang menyembunyikannya. `null` —
  /// instalasi yang belum mengirim bendera ini — berarti boleh.
  bool get canClock => attendanceEnabled.value != false;

  /// Keterlambatan hari ini dalam menit, `null` bila tidak terlambat atau tidak
  /// bisa dihitung.
  int? get lateMinutes {
    final int? diff = deltaMinutes(timeIn.value, scheduleIn.value);

    return (diff != null && diff > 0) ? diff : null;
  }

  /// Muat kelima panel Beranda.
  ///
  /// Kelimanya berjalan bersamaan dan masing-masing melaporkan kegagalannya
  /// sendiri ke slot galatnya, bukan ke sebuah toast. Empat toast berturut-turut
  /// saat sinyal pabrik hilang adalah cara memberi tahu orang bahwa aplikasinya
  /// rusak; keadaan galat di tempat panelnya adalah cara memberi tahu apa yang
  /// tidak sampai dan tombol untuk mencobanya lagi.
  /// [force] melewati cache repository untuk panel yang bergerak lambat.
  ///
  /// Dipakai tarik-untuk-menyegarkan dan tombol coba lagi — dua gestur yang
  /// artinya "saya tidak percaya angka di layar". Pemuatan otomatis saat layar
  /// dibuka TIDAK memaksa: berpindah tab bolak-balik bukan permintaan untuk
  /// menghitung ulang rekap bulanan.
  Future<void> refreshDashboard({bool force = false}) async {
    // Setiap penyegaran menerima nomor urut, dan hanya penyegaran TERBARU yang
    // boleh menulis. Tanpa ini urutan berikut menimpa data baru dengan data
    // lama, dan ia tidak jarang: pembukaan Beranda memulai permintaan di
    // `onInit`, dan tarik-untuk-menyegarkan tidak menunggunya —
    //
    //   A mulai (onInit)  →  pengguna menarik  →  B mulai  →  B selesai
    //   (layar benar)     →  A selesai belakangan  →  layar kembali ke data A.
    //
    // `RefreshIndicator` menahan tarikan KEDUA karena ia menunggu future-nya,
    // tetapi ia tidak tahu apa-apa tentang permintaan yang dimulai `onInit`.
    final int generation = ++_generation;

    // Gratis, dan karena itu dilakukan di sini: sumbernya sesi, bukan jaringan.
    unreadNotifications.value = _repository.unreadNotifications;

    isLoading.value = true;

    try {
      await Future.wait(<Future<void>>[
        _load(attendanceError, generation, () async {
          final times = await _repository.todayAttendance();

          if (_isStale(generation)) return;

          timeIn.value = _clock(times.timeIn);
          timeOut.value = _clock(times.timeOut);
          statusIn.value = _sentence(times.statusIn);
          statusOut.value = _sentence(times.statusOut);
          scheduleIn.value = _clock(times.scheduleIn);
          scheduleOut.value = _clock(times.scheduleOut);
          shiftName.value = _sentence(times.scheduleName);
          nextPresence.value = AttendancePunch.parse(times.nextPresence);
          attendanceEnabled.value = times.attendanceEnabled;
          dayContext.value = times.dayContext;
          contextAnswered.value = true;
        }),
        _load(announcementError, generation, () async {
          final rows = await _repository.activeAnnouncements();

          if (_isStale(generation)) return;

          announcements.assignAll(rows);
        }),
        _load(leaveError, generation, () async {
          final rows = await _repository.leaveBalances(refresh: force);

          if (_isStale(generation)) return;

          leaveBalances.assignAll(rows);
        }),
        _load(activityError, generation, () async {
          final rows = await _repository.recentPermits();

          if (_isStale(generation)) return;

          recentPermits.assignAll(rows);
        }),
        _load(summaryError, generation, () async {
          final summary = await _repository.monthSummary(refresh: force);

          if (_isStale(generation)) return;

          monthSummary.value = summary;
        }),
      ]);
    } finally {
      // Penyegaran yang sudah kedaluwarsa juga tidak boleh mematikan indikator
      // milik penyegaran yang masih berjalan.
      if (!_isStale(generation)) {
        isLoading.value = false;
        hasLoaded.value = true;
      }
    }
  }

  /// Apakah penyegaran bernomor [generation] sudah didahului yang lebih baru.
  bool _isStale(int generation) => generation != _generation;

  /// Jalankan satu panel, dan catat galatnya pada slot panel itu.
  ///
  /// Jalur galat lama menyusun pesannya dengan `'... (kode: \$statusCode)'` —
  /// `$` yang ter-escape, jadi pengguna diperlihatkan teks harfiah
  /// `$statusCode` (LOW-04). Pesan sekarang datang dari `ApiErrorMapper`, dan
  /// yang disimpan adalah pengecualiannya sendiri sehingga statusnya tidak
  /// hilang sebelum sampai ke layar.
  Future<void> _load(
    Rxn<ApiException> slot,
    int generation,
    Future<void> Function() run,
  ) async {
    try {
      await run();

      if (_isStale(generation)) return;

      slot.value = null;
    } on ApiException catch (error) {
      if (_isStale(generation)) return;

      // Dicatat, bukan hanya disimpan. Sebuah panel yang gagal menampilkan satu
      // kalimat yang sengaja tidak teknis kepada karyawan, dan tanpa baris ini
      // kalimat itu adalah SATU-SATUNYA jejak yang tersisa — sehingga sebuah
      // 403 dari abilities token (README G-3) tidak bisa dibedakan di lapangan
      // dari absensi yang memang dimatikan untuk orangnya, padahal keduanya
      // menuntut perbaikan di tempat yang sama sekali berbeda.
      //
      // `AppLogger` sudah meredaksi token, sandi, NIP dan FCM, jadi yang keluar
      // di sini adalah status dan kode mesin — bukan isi respons.
      AppLogger.warning(
        'Panel beranda gagal dimuat',
        data: <String, Object?>{
          'status': error.status,
          'code': error.code,
          'transport': error.isTransportFailure,
        },
      );

      slot.value = error;
    }
  }

  /// Jam dinding, dinormalkan ke `HH:mm`.
  ///
  /// Server mengirim `08:11`, `8:11`, atau `08:11:00` tergantung baris. Panel di
  /// atas menyusun kolom angka tabular, dan kolom itu hanya sejajar kalau
  /// lebarnya sama. Nilai yang tidak berbentuk jam dikembalikan apa adanya —
  /// menyembunyikan data yang tidak dikenali lebih buruk daripada
  /// menampilkannya — dan yang kosong menjadi `null`.
  static String? _clock(String? raw) {
    final text = raw?.trim();

    if (text == null || text.isEmpty || text == '-' || text == '--:--') {
      return null;
    }

    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(text);

    if (match == null) {
      return text;
    }

    final hour = match.group(1)!.padLeft(2, '0');

    return '$hour:${match.group(2)}';
  }

  /// Kalimat dari server, atau `null` bila ia sebetulnya kosong.
  static String? _sentence(String? raw) {
    final text = raw?.trim();

    if (text == null || text.isEmpty || text == '-' || text == '—') {
      return null;
    }

    return text;
  }

  /// Selisih menit sebuah jam terhadap jadwalnya, lewat jarak terpendek.
  ///
  /// Positif berarti lebih lambat daripada jadwal. Pembungkusan setengah hari
  /// ada karena shift yang melewati tengah malam: 23:58 terhadap jadwal 00:02
  /// adalah terlambat empat menit dan bukan lebih awal 1436 menit, dan versi
  /// tanpa pembungkusan inilah yang pernah menggambar `-23j 56m` di beranda.
  static int? deltaMinutes(String? actual, String? scheduled) {
    final int? a = minutesOfDay(actual);
    final int? s = minutesOfDay(scheduled);

    if (a == null || s == null) {
      return null;
    }

    int diff = a - s;

    if (diff > Duration.minutesPerDay ~/ 2) diff -= Duration.minutesPerDay;
    if (diff < -(Duration.minutesPerDay ~/ 2)) diff += Duration.minutesPerDay;

    return diff;
  }

  /// Selisih menit yang dibawa kembali ke dalam satu hari.
  static int wrapMinutes(int minutes) =>
      minutes < 0 ? minutes + Duration.minutesPerDay : minutes;

  /// Rentang menit sebagai teks Indonesia: `8j 11m`, `45m`, `9j`.
  static String spanLabel(int minutes) {
    final int hours = minutes ~/ 60;
    final int rest = minutes % 60;

    if (hours == 0) return '${rest}m';
    if (rest == 0) return '${hours}j';

    return '${hours}j ${rest}m';
  }

  /// Menit sejak tengah malam pada jam workspace.
  ///
  /// Dipakai penghitung durasi berjalan dan penanda posisi hari kerja, supaya
  /// keduanya tidak pernah membaca "sekarang" dari dua jam yang berbeda.
  static int nowMinutes() {
    final now = WorkspaceClock.current.now();

    return now.hour * 60 + now.minute;
  }

  /// Menit sejak tengah malam dari sebuah jam dinding, untuk aritmatika.
  ///
  /// Dipakai bersama oleh penghitung durasi dan selisih terhadap jadwal, supaya
  /// keduanya tidak pernah membaca jam yang sama dengan dua cara.
  static int? minutesOfDay(String? clock) {
    if (clock == null) {
      return null;
    }

    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(clock);

    if (match == null) {
      return null;
    }

    final hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);

    if (hour > 23 || minute > 59) {
      return null;
    }

    return hour * 60 + minute;
  }
}

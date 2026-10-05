import 'dart:async';

import 'package:esas/core/network/api_exception.dart';
import 'package:esas/features/home/data/models/announcement.dart';
import 'package:esas/features/permit/data/models/leave_list.dart';
import 'package:esas/features/home/data/repositories/home_repository.dart';
import 'package:esas/features/home/presentation/controllers/home_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockHomeRepository extends Mock implements HomeRepository {}

/// Kesimpulan yang diambil Beranda tentang hari ini, diuji tanpa satu widget pun.
///
/// Berkas ini ada karena kesimpulan itu dulunya TIDAK diambil di satu tempat:
/// empat widget masing-masing menyusun ulang cabangnya sendiri dari `timeIn`,
/// `timeOut` dan `attendanceError`, dan ketiganya sempat tidak sepakat di layar
/// yang sama. Sekarang cabangnya satu, dan urutannya dipatok di sini.
void main() {
  late _MockHomeRepository repository;

  HomeController subject() => HomeController(repository: repository);

  /// Controller dengan absensi yang sudah "mendarat", tanpa memanggil jaringan.
  HomeController loaded({
    String? timeIn,
    String? timeOut,
    String? scheduleIn = '08:00',
    String? scheduleOut = '17:00',
    String? shift = 'Pagi',
    String? nextPresence,
    DayContext? dayContext,
    bool? attendanceEnabled,
    String? attendanceError,
  }) {
    final controller = subject();

    controller.hasLoaded.value = true;
    controller.isLoading.value = false;
    controller.timeIn.value = timeIn;
    controller.timeOut.value = timeOut;
    controller.scheduleIn.value = scheduleIn;
    controller.scheduleOut.value = scheduleOut;
    controller.shiftName.value = shift;
    controller.nextPresence.value = AttendancePunch.parse(nextPresence);
    controller.dayContext.value = dayContext;
    controller.attendanceEnabled.value = attendanceEnabled;
    controller.attendanceError.value = attendanceError == null
        ? null
        : ApiException(attendanceError);

    return controller;
  }

  setUp(() {
    repository = _MockHomeRepository();

    when(() => repository.userName).thenReturn('Budi');
    when(() => repository.userAvatar).thenReturn('');
    when(
      () => repository.todayAttendance(),
    ).thenAnswer((_) async => const DashboardTimes());
    when(
      () => repository.activeAnnouncements(),
    ).thenAnswer((_) async => <Announcement>[]);
    when(
      () => repository.leaveBalances(refresh: any(named: 'refresh')),
    ).thenAnswer((_) async => <LeaveBalance>[]);
    when(
      () => repository.monthSummary(refresh: any(named: 'refresh')),
    ).thenAnswer((_) async => const MonthSummary(workedDays: 0, lateCount: 0));
    when(
      () => repository.recentPermits(limit: any(named: 'limit')),
    ).thenAnswer((_) async => <Permit>[]);
  });

  group('todayState', () {
    test('pembukaan dingin adalah memuat, bukan "belum absen"', () {
      final controller = subject();

      controller.isLoading.value = true;
      controller.hasLoaded.value = false;

      expect(controller.todayState, HomeTodayState.loading);
    });

    test('jadwal tanpa ketukan adalah belum absen', () {
      expect(loaded().todayState, HomeTodayState.notClockedIn);
    });

    test('sudah masuk dan belum pulang adalah sedang bekerja', () {
      expect(loaded(timeIn: '08:03').todayState, HomeTodayState.working);
    });

    test('kedua ketukan lengkap adalah selesai', () {
      expect(
        loaded(timeIn: '08:03', timeOut: '17:04').todayState,
        HomeTodayState.done,
      );
    });

    test('tanpa jadwal dan tanpa galat adalah hari tanpa jadwal', () {
      final controller = loaded(
        scheduleIn: null,
        scheduleOut: null,
        shift: null,
      );

      expect(controller.todayState, HomeTodayState.noSchedule);
    });

    test('galat tanpa satu pun jam yang sampai adalah belum tersedia', () {
      final controller = loaded(
        scheduleIn: null,
        scheduleOut: null,
        shift: null,
        attendanceError: 'Koneksi terputus.',
      );

      expect(controller.todayState, HomeTodayState.unavailable);
    });

    test('ketukan yang sudah tercatat mengalahkan galat penyegaran', () {
      // Sebuah jam masuk yang sudah sampai tetap benar walaupun penyegaran
      // berikutnya gagal; mengatakan "tidak terbaca" di atas jam yang terlihat
      // adalah cara tercepat membuat orang berhenti mempercayai layar ini.
      final controller = loaded(
        timeIn: '08:03',
        attendanceError: 'Koneksi terputus.',
      );

      expect(controller.todayState, HomeTodayState.working);
    });
  });

  group('nextPunch', () {
    test('jawaban server dipakai apa adanya', () {
      expect(loaded(nextPresence: 'out').nextPunch, AttendancePunch.clockOut);
    });

    test('server mengalahkan turunan lokal', () {
      // Server melihat hari roster, shift lintas tengah malam dan grace period;
      // layar hanya melihat dua string jam.
      final controller = loaded(timeIn: '08:03', nextPresence: 'in');

      expect(controller.nextPunch, AttendancePunch.clockIn);
    });

    test('tanpa jawaban server, arah diturunkan dari keadaan', () {
      expect(loaded().nextPunch, AttendancePunch.clockIn);
      expect(loaded(timeIn: '08:03').nextPunch, AttendancePunch.clockOut);
    });

    test('hari yang sudah selesai tidak menawarkan ketukan lagi', () {
      expect(loaded(timeIn: '08:03', timeOut: '17:04').nextPunch, isNull);
    });

    test('hari tanpa jadwal tidak menawarkan ketukan', () {
      final controller = loaded(
        scheduleIn: null,
        scheduleOut: null,
        shift: null,
      );

      expect(controller.nextPunch, isNull);
    });
  });

  group('canClock', () {
    test('bendera yang tidak dikirim server berarti boleh', () {
      expect(loaded().canClock, isTrue);
    });

    test('hanya false yang tegas yang menyembunyikan ajakan', () {
      expect(loaded(attendanceEnabled: false).canClock, isFalse);
      expect(loaded(attendanceEnabled: true).canClock, isTrue);
    });
  });

  group('lateMinutes', () {
    test('datang setelah jadwal menghasilkan menit keterlambatan', () {
      expect(loaded(timeIn: '08:11').lateMinutes, 11);
    });

    test('datang lebih awal bukan keterlambatan', () {
      expect(loaded(timeIn: '07:52').lateMinutes, isNull);
    });

    test('tepat waktu bukan keterlambatan', () {
      expect(loaded(timeIn: '08:00').lateMinutes, isNull);
    });

    test('tanpa jadwal tidak ada yang bisa dihitung', () {
      expect(loaded(timeIn: '08:11', scheduleIn: null).lateMinutes, isNull);
    });
  });

  group('aritmetika jam', () {
    test('selisih memilih jarak terpendek melewati tengah malam', () {
      // 23:58 terhadap jadwal 00:02 adalah terlambat empat menit, bukan lebih
      // awal 1436 menit.
      expect(HomeController.deltaMinutes('23:58', '00:02'), -4);
      expect(HomeController.deltaMinutes('00:02', '23:58'), 4);
    });

    test('durasi shift malam tidak negatif', () {
      expect(HomeController.wrapMinutes(6 * 60 - 22 * 60), 8 * 60);
    });

    test('rentang menit dibaca dalam bahasa Indonesia', () {
      expect(HomeController.spanLabel(45), '45m');
      expect(HomeController.spanLabel(540), '9j');
      expect(HomeController.spanLabel(491), '8j 11m');
    });
  });

  group('refreshDashboard', () {
    test('membaca ketukan berikutnya dan izin absen dari konteks', () async {
      when(() => repository.todayAttendance()).thenAnswer(
        (_) async => const DashboardTimes(
          timeIn: '08:03',
          scheduleIn: '08:00:00',
          scheduleOut: '17:00',
          scheduleName: 'Pagi',
          nextPresence: 'out',
          attendanceEnabled: true,
        ),
      );

      final controller = subject();
      await controller.refreshDashboard();

      expect(controller.nextPresence.value, AttendancePunch.clockOut);
      expect(controller.attendanceEnabled.value, isTrue);
      // Jam dinormalkan ke HH:mm supaya kolom angka tabular tetap sejajar.
      expect(controller.scheduleIn.value, '08:00');
    });

    test('satu panel yang gagal tidak menjatuhkan tiga lainnya', () async {
      when(
        () => repository.todayAttendance(),
      ).thenThrow(const ApiException('Koneksi terputus.'));
      when(() => repository.activeAnnouncements()).thenAnswer(
        (_) async => <Announcement>[Announcement(id: 1, title: 'Halo')],
      );
      when(
        () => repository.monthSummary(refresh: any(named: 'refresh')),
      ).thenAnswer(
        (_) async => const MonthSummary(workedDays: 21, lateCount: 3),
      );

      final controller = subject();
      await controller.refreshDashboard();

      expect(controller.attendanceError.value?.message, 'Koneksi terputus.');
      expect(controller.announcementError.value, isNull);
      expect(controller.announcements, hasLength(1));
      expect(controller.monthSummary.value?.workedDays, 21);
      expect(controller.hasLoaded.value, isTrue);
    });
  });

  group('MonthSummary', () {
    test('tepat waktu diturunkan, tidak diminta sebagai angka ketiga', () {
      const summary = MonthSummary(workedDays: 21, lateCount: 3);

      expect(summary.onTimeDays, 18);
      expect(summary.hasData, isTrue);
    });

    test(
      'lebih banyak terlambat daripada hari kerja tidak menjadi negatif',
      () {
        const summary = MonthSummary(workedDays: 2, lateCount: 5);

        expect(summary.onTimeDays, 0);
      },
    );

    test('bulan tanpa hari kerja tidak layak digambar', () {
      expect(const MonthSummary(workedDays: 0, lateCount: 0).hasData, isFalse);
    });
  });

  group('jenis hari', () {
    /// Hari tanpa jadwal, dengan konteks hari dari server.
    HomeController restDay(HomeDayType type, {String? holidayName}) => loaded(
      scheduleIn: null,
      scheduleOut: null,
      shift: null,
      dayContext: DayContext(type: type, holidayName: holidayName),
    );

    test('hari libur nasional dibedakan dari giliran libur', () {
      expect(restDay(HomeDayType.holiday).todayState, HomeTodayState.holiday);
      expect(restDay(HomeDayType.dayOff).todayState, HomeTodayState.dayOff);
    });

    test('cuti yang disetujui punya keadaannya sendiri', () {
      expect(restDay(HomeDayType.leave).todayState, HomeTodayState.onLeave);
    });

    test('backend tanpa day_context kembali ke perilaku lama', () {
      // Aplikasi ponsel hidup lebih lama daripada satu rilis backend: tidak
      // adanya blok ini bukan kesalahan, dan bukan pula hari libur.
      final controller = loaded(
        scheduleIn: null,
        scheduleOut: null,
        shift: null,
      );

      expect(controller.todayState, HomeTodayState.noSchedule);
    });

    test('jadwal mengalahkan kalender', () {
      // Orang yang dirosterkan pada hari raya tetap harus melihat shiftnya dan
      // tombolnya. Menyembunyikan keduanya karena kalender berkata "libur"
      // membuat orang yang benar-benar masuk kerja tidak bisa mengabsen.
      final controller = loaded(
        dayContext: const DayContext(type: HomeDayType.holiday),
      );

      expect(controller.todayState, HomeTodayState.notClockedIn);
      expect(controller.nextPunch, AttendancePunch.clockIn);
    });

    test('tipe yang tidak dikenali tidak ditebak sebagai hari kerja', () {
      // Menebak "hari kerja" untuk nilai yang tidak dimengerti adalah cara
      // tercepat menyodorkan tombol absen pada hari orang tidak bekerja.
      expect(DayContext.fromJson(const {'type': 'sesuatu_yang_baru'}), isNull);
      expect(DayContext.fromJson(null), isNull);
    });

    test('ejaan tipe dibaca longgar', () {
      expect(
        DayContext.fromJson(const {'type': 'PUBLIC_HOLIDAY'})?.type,
        HomeDayType.holiday,
      );
      expect(
        DayContext.fromJson(const {'type': 'day-off'})?.type,
        HomeDayType.dayOff,
      );
      expect(
        DayContext.fromJson(const {'type': 'approved_leave'})?.type,
        HomeDayType.leave,
      );
    });
  });

  group('shift lintas tengah malam', () {
    // 22:00 hari ini sampai 06:00 besok. Setiap angka di bawah ini pernah salah
    // pada versi yang memperlakukan jam sebagai bilangan dalam satu hari.
    const String start = '22:00';
    const String end = '06:00';

    test('durasi shift malam positif, bukan minus enam belas jam', () {
      final int? a = HomeController.minutesOfDay(start);
      final int? b = HomeController.minutesOfDay(end);

      expect(HomeController.wrapMinutes(b! - a!), 8 * 60);
      expect(HomeController.spanLabel(HomeController.wrapMinutes(b - a)), '8j');
    });

    test(
      'absen masuk 22:05 terlambat lima menit, bukan lebih awal seharian',
      () {
        expect(HomeController.deltaMinutes('22:05', start), 5);
      },
    );

    test('absen pulang 05:50 pulang awal sepuluh menit', () {
      expect(HomeController.deltaMinutes('05:50', end), -10);
    });

    test('sedang bekerja walau jam pulang lebih kecil daripada jam masuk', () {
      final controller = loaded(
        timeIn: '22:03',
        scheduleIn: start,
        scheduleOut: end,
        shift: 'Malam',
      );

      expect(controller.todayState, HomeTodayState.working);
      expect(controller.nextPunch, AttendancePunch.clockOut);
      expect(controller.lateMinutes, 3);
    });

    test('shift malam yang selesai tetap terbaca selesai', () {
      final controller = loaded(
        timeIn: '22:03',
        timeOut: '06:02',
        scheduleIn: start,
        scheduleOut: end,
        shift: 'Malam',
      );

      expect(controller.todayState, HomeTodayState.done);
      expect(controller.nextPunch, isNull);
    });
  });

  group('penyegaran yang saling mendahului', () {
    test('jawaban lama tidak menimpa jawaban baru', () async {
      // Urutan yang benar-benar terjadi: `onInit` memulai A, pengguna menarik
      // untuk menyegarkan sebelum A selesai, B selesai lebih dulu, lalu A
      // mendarat membawa data yang sudah basi.
      final slowFirst = Completer<DashboardTimes>();
      final fastSecond = Completer<DashboardTimes>();
      var call = 0;

      when(() => repository.todayAttendance()).thenAnswer((_) {
        call += 1;
        return call == 1 ? slowFirst.future : fastSecond.future;
      });

      final controller = subject();

      final Future<void> first = controller.refreshDashboard();
      final Future<void> second = controller.refreshDashboard();

      fastSecond.complete(
        const DashboardTimes(timeIn: '08:03', scheduleIn: '08:00'),
      );
      await second;

      expect(controller.timeIn.value, '08:03');

      // A mendarat belakangan membawa "belum absen".
      slowFirst.complete(const DashboardTimes(scheduleIn: '08:00'));
      await first;

      expect(
        controller.timeIn.value,
        '08:03',
        reason: 'penyegaran yang sudah didahului tidak boleh menulis',
      );
    });

    test(
      'penyegaran basi tidak mematikan indikator milik yang berjalan',
      () async {
        final slowFirst = Completer<DashboardTimes>();
        final pendingSecond = Completer<DashboardTimes>();
        var call = 0;

        when(() => repository.todayAttendance()).thenAnswer((_) {
          call += 1;
          return call == 1 ? slowFirst.future : pendingSecond.future;
        });

        final controller = subject();

        final Future<void> first = controller.refreshDashboard();
        final Future<void> second = controller.refreshDashboard();

        slowFirst.complete(const DashboardTimes());
        await first;

        expect(
          controller.isLoading.value,
          isTrue,
          reason: 'penyegaran kedua masih berjalan',
        );

        pendingSecond.complete(const DashboardTimes());
        await second;

        expect(controller.isLoading.value, isFalse);
      },
    );

    test('galat yang basi tidak menimpa keberhasilan yang baru', () async {
      final slowFailure = Completer<DashboardTimes>();
      final fastSuccess = Completer<DashboardTimes>();
      var call = 0;

      when(() => repository.todayAttendance()).thenAnswer((_) {
        call += 1;
        return call == 1 ? slowFailure.future : fastSuccess.future;
      });

      final controller = subject();

      final Future<void> first = controller.refreshDashboard();
      final Future<void> second = controller.refreshDashboard();

      fastSuccess.complete(const DashboardTimes(scheduleIn: '08:00'));
      await second;

      slowFailure.completeError(const ApiException('Koneksi terputus.'));
      await first;

      expect(controller.attendanceError.value, isNull);
    });
  });
}

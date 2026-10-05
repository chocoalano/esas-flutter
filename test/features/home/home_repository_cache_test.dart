import 'package:esas/features/auth/data/models/auth_user.dart';
import 'package:esas/features/auth/data/repositories/session_repository.dart';
import 'package:esas/features/home/data/repositories/home_repository.dart';
import 'package:esas/features/home/data/services/home_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockApi extends Mock implements HomeApiService {}

class _MockSession extends Mock implements SessionRepository {}

/// Berapa banyak permintaan yang benar-benar ditembakkan Beranda.
///
/// Sebelum ada cache ini, setiap ketukan tab "Beranda" menembakkan empat
/// permintaan — termasuk rekap bulanan yang berubah sekali sehari dan sisa cuti
/// yang berubah ketika sebuah pengajuan disetujui. Di jaringan pabrik itu
/// terasa sebagai layar yang selalu sedang memuat, dan tidak satu pun dari dua
/// angka itu berubah karena seseorang berpindah tab.
void main() {
  late _MockApi api;
  late _MockSession session;
  late HomeRepository repository;

  const Map<String, dynamic> balanceBody = <String, dynamic>{
    'data': <Map<String, dynamic>>[
      <String, dynamic>{
        'code': 'ANNUAL',
        'name': 'Cuti tahunan',
        'remaining': 8,
      },
    ],
  };

  const Map<String, dynamic> summaryBody = <String, dynamic>{
    'summary': <String, dynamic>{'worked_days': 21, 'late_count': 3},
  };

  void signInAs(int id) {
    when(() => session.user).thenReturn(
      AuthUser.fromJson(<String, dynamic>{'id': id, 'name': 'Orang $id'}),
    );
  }

  setUp(() {
    api = _MockApi();
    session = _MockSession();
    repository = HomeRepository(api: api, session: session);

    signInAs(7);
    when(() => api.leaveBalance()).thenAnswer((_) async => balanceBody);
    when(() => api.attendanceSummary()).thenAnswer((_) async => summaryBody);
  });

  group('panel yang bergerak lambat', () {
    test(
      'pembukaan kedua memakai jawaban yang sama, tanpa permintaan baru',
      () async {
        await repository.monthSummary();
        await repository.monthSummary();

        verify(() => api.attendanceSummary()).called(1);
      },
    );

    test('tarik-untuk-menyegarkan menembus cache', () async {
      // Gestur itu artinya "saya tidak percaya angka di layar", dan jawabannya
      // harus permintaan sungguhan.
      await repository.monthSummary();
      await repository.monthSummary(refresh: true);

      verify(() => api.attendanceSummary()).called(2);
    });

    test('nilainya tetap benar saat datang dari cache', () async {
      expect((await repository.monthSummary()).workedDays, 21);
      expect((await repository.monthSummary()).lateCount, 3);
    });
  });

  group('kepemilikan', () {
    test('karyawan berikutnya tidak melihat rekap karyawan sebelumnya', () async {
      // Satu handset dipakai lebih dari satu orang di pabrik. Kedaluwarsa waktu
      // saja tidak menutup ini: yang salah bukan umur jawabannya, melainkan
      // pemiliknya.
      await repository.monthSummary();

      signInAs(9);

      await repository.monthSummary();

      verify(() => api.attendanceSummary()).called(2);
    });

    test('invalidate membuang semuanya', () async {
      await repository.monthSummary();
      repository.invalidate();
      await repository.monthSummary();

      verify(() => api.attendanceSummary()).called(2);
    });
  });

  group('yang sengaja TIDAK di-cache', () {
    test('saldo cuti selalu ditanyakan ulang', () async {
      // Ia berubah karena tindakan DI DALAM aplikasi ini: seseorang mengajukan
      // izin, lalu kembali ke Beranda. Jawaban berumur sepuluh menit akan
      // menggambar saldo sebelum pengajuannya — persis angka yang dipakai orang
      // untuk memutuskan apakah ia bisa mengambil cuti lagi.
      await repository.leaveBalances();
      await repository.leaveBalances();

      verify(() => api.leaveBalance()).called(2);
    });

    test('absensi hari ini selalu ditanyakan ulang', () async {
      when(() => api.attendanceContext()).thenAnswer(
        (_) async => const <String, dynamic>{
          'attendance': <String, dynamic>{'time_in': '08:03'},
          'schedule': <String, dynamic>{'in': '08:00', 'out': '17:00'},
        },
      );

      await repository.todayAttendance();
      await repository.todayAttendance();

      // Ini alasan layarnya dibuka. Sebuah jawaban berumur sepuluh menit di
      // sini berarti seseorang yang baru saja mengabsen tetap melihat "belum
      // absen" sekembalinya dari pemindai.
      verify(() => api.attendanceContext()).called(2);
    });

    test('pengumuman selalu ditanyakan ulang', () async {
      when(
        () => api.activeAnnouncements(),
      ).thenAnswer((_) async => const <String, dynamic>{'data': <dynamic>[]});

      await repository.activeAnnouncements();
      await repository.activeAnnouncements();

      verify(() => api.activeAnnouncements()).called(2);
    });
  });
}

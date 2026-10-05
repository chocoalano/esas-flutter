import 'package:esas/core/network/api_exception.dart';
import 'package:esas/features/permit/data/models/leave_type.dart';
import 'package:esas/features/permit/data/models/schedule.dart';
import 'package:esas/features/permit/data/models/timework.dart';
import 'package:esas/features/permit/data/repositories/permit_repository.dart';
import 'package:esas/features/permit/presentation/controllers/permit_create_controller.dart';
import 'package:esas/features/permit/presentation/views/permit_create_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class _MockPermitRepository extends Mock implements PermitRepository {}

/// Formulir pengajuan izin, sebagaimana ia benar-benar dibangun dan divalidasi.
///
/// Dua kegagalan yang hanya terlihat dari sini, bukan dari unit test:
///
/// 1. `Form` di dalam `ListView` melepas field yang tergulir keluar layar, dan
///    field yang lepas ikut lepas dari `Form` — `validate()` melompatinya.
///    Tombol kirim menetap di kaki layar, jadi orang bisa menekannya tanpa
///    pernah menggulir, dan "Jam mulai wajib diisi" tidak pernah sempat
///    berbunyi.
/// 2. Memilih jadwal mengisi tanggal mulai dan selesai dengan hari yang sama,
///    lalu validator menuntut selesai *setelah* mulai. Izin sehari — bentuk
///    yang paling sering diajukan — mustahil dikirim.
void main() {
  setUpAll(() {
    initializeDateFormatting('id_ID');
    registerFallbackValue(<String, dynamic>{});
  });

  late _MockPermitRepository repository;
  late PermitCreateController controller;

  setUp(() {
    repository = _MockPermitRepository();

    when(
      () => repository.formData(
        from: any(named: 'from'),
        to: any(named: 'to'),
      ),
    ).thenAnswer(
      (_) async => PermitFormData(
        schedules: [
          Schedule.fromJson({
            'id': 8,
            'work_day': '2026-09-02',
            'shift': 'Pagi',
            'in': '08:00:00',
            'out': '17:00:00',
          }),
          Schedule.fromJson({'id': 9, 'work_day': '2026-09-03'}),
        ],
        shifts: [
          Timework.fromJson({
            'id': 3,
            'name': 'Pagi',
            'in': '07:00',
            'out': '15:00',
          }),
          Timework.fromJson({
            'id': 5,
            'name': 'Malam',
            'in': '23:00',
            'out': '07:00',
          }),
        ],
        from: DateTime(2026, 9, 2),
        to: DateTime(2026, 10, 2),
      ),
    );

    when(
      () => repository.create(
        fields: any(named: 'fields'),
        attachment: any(named: 'attachment'),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    ).thenAnswer((_) async => true);
  });

  tearDown(Get.reset);

  Future<void> pumpForm(WidgetTester tester, {required LeaveType type}) async {
    controller = PermitCreateController(repository: repository);
    Get.put<PermitCreateController>(controller);

    // Seperti yang diterima layar ini dari daftar jenis izin.
    controller.createType.value = type;
    controller.selectedPermitTypeId.value = type.id;

    await tester.pumpWidget(
      GetMaterialApp(
        locale: const Locale('id', 'ID'),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('id', 'ID')],
        home: const PermitCreateView(),
        getPages: [
          GetPage(name: '/permit/list', page: () => const SizedBox.shrink()),
        ],
      ),
    );

    await tester.pumpAndSettle();
  }

  /// Menekan tombol kirim, lalu membereskan sisa animasinya.
  ///
  /// Snackbar GetX memasang `AnimationController` di atas overlay dan menahan
  /// tickernya sampai ia menutup sendiri; sebuah tes yang selesai lebih dulu
  /// membuang overlay itu bersama ticker yang masih hidup.
  Future<void> submit(WidgetTester tester) async {
    await tester.tap(find.text('Kirim pengajuan'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    Get.closeAllSnackbars();
    await tester.pumpAndSettle();
  }

  Map<String, dynamic> lastFields() =>
      verify(
            () => repository.create(
              fields: captureAny(named: 'fields'),
              attachment: any(named: 'attachment'),
              idempotencyKey: any(named: 'idempotencyKey'),
            ),
          ).captured.last
          as Map<String, dynamic>;

  group('izin biasa', () {
    testWidgets('izin sehari bisa dikirim', (tester) async {
      await pumpForm(tester, type: _type(id: 4, code: 'ANNUAL'));

      // Jadwal pertama dipilihkan, jadi kedua tanggal berisi hari yang sama.
      expect(controller.startDateC.text, '2026-09-02');
      expect(controller.endDateC.text, '2026-09-02');

      controller.startTimeC.text = '08:00';
      controller.endTimeC.text = '17:00';

      await submit(tester);

      final fields = lastFields();
      expect(fields['start_date'], '2026-09-02');
      expect(fields['end_date'], '2026-09-02');
      expect(fields['start_time'], '08:00');
      // Tidak satu pun kolom penyesuaian ikut.
      expect(fields.containsKey('current_shift_id'), isFalse);
      expect(fields.containsKey('timein_adjust'), isFalse);
    });

    testWidgets('tanggal selesai sebelum tanggal mulai ditolak', (
      tester,
    ) async {
      await pumpForm(tester, type: _type(id: 4, code: 'ANNUAL'));

      controller.startTimeC.text = '08:00';
      controller.endTimeC.text = '17:00';
      // Keduanya di dalam jendela roster, jadi yang diuji memang urutannya dan
      // bukan batas rentang.
      controller.startDateC.text = '2026-09-10';
      controller.endDateC.text = '2026-09-05';

      await submit(tester);

      expect(find.text('Tidak boleh sebelum tanggal mulai'), findsOneWidget);
      verifyNever(
        () => repository.create(
          fields: any(named: 'fields'),
          attachment: any(named: 'attachment'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      );
    });

    testWidgets('field di luar layar tetap divalidasi', (tester) async {
      await pumpForm(tester, type: _type(id: 4, code: 'ANNUAL'));

      // Tanpa menggulir sama sekali: tombol kirim ada di kaki layar, dan
      // "Jam selesai" berada di bawah lipatan — ada di dalam pohon, tetapi
      // tidak bisa disentuh. Di dalam `ListView` ia tidak ada sama sekali, dan
      // itulah yang membuat validatornya dilewati.
      expect(find.text('Jam selesai'), findsOneWidget);
      expect(find.text('Jam selesai').hitTestable(), findsNothing);

      await submit(tester);

      // Validator field yang belum pernah terlihat tetap berbunyi.
      expect(find.text('Jam Selesai wajib diisi'), findsOneWidget);

      verifyNever(
        () => repository.create(
          fields: any(named: 'fields'),
          attachment: any(named: 'attachment'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      );
    });

    testWidgets('izin lintas tengah malam tidak ditolak', (tester) async {
      await pumpForm(tester, type: _type(id: 4, code: 'ANNUAL'));

      // Shift malam: berakhir pada jam yang lebih kecil, pada hari berikutnya.
      // Urutan jamnya sudah ditetapkan oleh tanggalnya.
      controller.endDateC.text = '2026-09-03';
      controller.startTimeC.text = '22:00';
      controller.endTimeC.text = '06:00';

      await submit(tester);

      final fields = lastFields();
      expect(fields['start_time'], '22:00');
      expect(fields['end_time'], '06:00');
      expect(fields['end_date'], '2026-09-03');
    });

    testWidgets('pada izin sehari, jam selesai harus setelah jam mulai', (
      tester,
    ) async {
      await pumpForm(tester, type: _type(id: 4, code: 'ANNUAL'));

      controller.startTimeC.text = '17:00';
      controller.endTimeC.text = '08:00';

      await submit(tester);

      expect(find.textContaining('Harus setelah 17:00'), findsOneWidget);
      verifyNever(
        () => repository.create(
          fields: any(named: 'fields'),
          attachment: any(named: 'attachment'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      );
    });

    testWidgets('tanggal di luar jendela roster ditolak di kedua ujungnya', (
      tester,
    ) async {
      await pumpForm(tester, type: _type(id: 4, code: 'ANNUAL'));

      controller.startTimeC.text = '08:00';
      controller.endTimeC.text = '17:00';

      // Jendela yang dijawab server: 2026-09-02 sampai 2026-10-02.
      expect(controller.earliestDate, DateTime(2026, 9, 2));
      expect(controller.latestDate, DateTime(2026, 10, 2));

      // Sehari sebelum hari paling awal.
      controller.startDateC.text = '2026-09-01';
      controller.endDateC.text = '2026-09-01';
      await submit(tester);
      expect(find.textContaining('Di luar jadwal kerja Anda'), findsWidgets);

      // Sehari setelah hari paling akhir.
      controller.startDateC.text = '2026-10-03';
      controller.endDateC.text = '2026-10-03';
      await submit(tester);
      expect(find.textContaining('Di luar jadwal kerja Anda'), findsWidgets);

      verifyNever(
        () => repository.create(
          fields: any(named: 'fields'),
          attachment: any(named: 'attachment'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      );
    });

    testWidgets('kedua ujung jendela roster sendiri diterima', (tester) async {
      await pumpForm(tester, type: _type(id: 4, code: 'ANNUAL'));

      controller.startTimeC.text = '08:00';
      controller.endTimeC.text = '17:00';
      controller.startDateC.text = '2026-09-02';
      controller.endDateC.text = '2026-10-02';

      await submit(tester);

      final fields = lastFields();
      expect(fields['start_date'], '2026-09-02');
      expect(fields['end_date'], '2026-10-02');
    });

    testWidgets('menekan kirim dua kali hanya mengirim satu pengajuan', (
      tester,
    ) async {
      await pumpForm(tester, type: _type(id: 4, code: 'ANNUAL'));

      controller.startTimeC.text = '08:00';
      controller.endTimeC.text = '17:00';

      // Ketukan kedua jatuh sebelum jawaban pertama datang. Tombolnya sudah
      // dinonaktifkan oleh `isSubmitting`, jadi ketukan itu tidak sampai ke
      // mana-mana.
      await tester.tap(find.text('Kirim pengajuan'));
      await tester.pump();
      await tester.tap(find.text('Kirim pengajuan'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 100));

      Get.closeAllSnackbars();
      await tester.pumpAndSettle();

      verify(
        () => repository.create(
          fields: any(named: 'fields'),
          attachment: any(named: 'attachment'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).called(1);
    });

    testWidgets('penolakan server dibacakan apa adanya kepada pengguna', (
      tester,
    ) async {
      when(
        () => repository.create(
          fields: any(named: 'fields'),
          attachment: any(named: 'attachment'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenThrow(
        const ApiException(
          'Tidak ada jadwal kerja pada tanggal itu. Hubungi HR untuk '
          'melengkapi jadwal Anda.',
          status: 409,
          code: 'permit_no_schedule',
        ),
      );

      await pumpForm(tester, type: _type(id: 4, code: 'ANNUAL'));
      controller.startTimeC.text = '08:00';
      controller.endTimeC.text = '17:00';

      await tester.tap(find.text('Kirim pengajuan'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Kalimat server, bukan "terjadi kesalahan" — dan bukan pula jejak
      // tumpukan atau isi jawaban mentah.
      expect(
        find.textContaining('Tidak ada jadwal kerja pada tanggal itu'),
        findsOneWidget,
      );

      Get.closeAllSnackbars();
      await tester.pumpAndSettle();
    });

    testWidgets('lampiran wajib menahan pengiriman', (tester) async {
      await pumpForm(tester, type: _type(id: 9, code: 'SICK', withFile: true));

      controller.startTimeC.text = '08:00';
      controller.endTimeC.text = '17:00';

      await submit(tester);

      verifyNever(
        () => repository.create(
          fields: any(named: 'fields'),
          attachment: any(named: 'attachment'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      );
    });
  });

  group('penyesuaian shift', () {
    testWidgets('varian dikenali dari kode, bukan dari id', (tester) async {
      // Id yang, pada pemetaan peninggalan, berarti "izin biasa".
      await pumpForm(tester, type: _type(id: 87, code: 'SHIFT_ADJUSTMENT'));

      expect(find.text('PENYESUAIAN SHIFT'), findsOneWidget);
      expect(find.text('Shift saat ini'), findsOneWidget);
      // Tidak dipilihkan; dulu keduanya terisi shift pertama.
      expect(controller.selectedCurrentShiftId.value, isNull);
      expect(controller.selectedAdjustShiftId.value, isNull);
    });

    testWidgets('kedua shift wajib diisi', (tester) async {
      await pumpForm(tester, type: _type(id: 87, code: 'SHIFT_ADJUSTMENT'));

      controller.startTimeC.text = '08:00';
      controller.endTimeC.text = '17:00';

      await submit(tester);

      expect(find.text('Shift saat ini wajib diisi'), findsOneWidget);
      verifyNever(
        () => repository.create(
          fields: any(named: 'fields'),
          attachment: any(named: 'attachment'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      );
    });

    testWidgets('shift tujuan tidak boleh sama dengan shift asal', (
      tester,
    ) async {
      await pumpForm(tester, type: _type(id: 87, code: 'SHIFT_ADJUSTMENT'));

      controller.startTimeC.text = '08:00';
      controller.endTimeC.text = '17:00';
      controller.selectedCurrentShiftId.value = 3;
      controller.selectedAdjustShiftId.value = 3;
      await tester.pumpAndSettle();

      await submit(tester);

      expect(
        find.text('Pilih shift yang berbeda dari shift saat ini'),
        findsOneWidget,
      );
    });
  });

  group('penyesuaian jam', () {
    testWidgets('varian dikenali dari kode meski idnya asing', (tester) async {
      await pumpForm(tester, type: _type(id: 52, code: 'TIME_ADJUSTMENT'));

      expect(find.text('Jam masuk penyesuaian'), findsOneWidget);
      expect(find.text('PENYESUAIAN SHIFT'), findsNothing);
    });

    testWidgets('jam pulang lebih awal dari jam masuk ditolak', (tester) async {
      await pumpForm(tester, type: _type(id: 52, code: 'TIME_ADJUSTMENT'));

      controller.startTimeC.text = '08:00';
      controller.endTimeC.text = '17:00';
      // Pasangan yang dulu lolos: perbandingan teks membaca 08:30 sebagai
      // "setelah" 08.45.
      controller.timeinAdjustC.text = '08.45';
      controller.timeoutAdjustC.text = '08.30';

      await submit(tester);

      expect(find.textContaining('Harus setelah 08:45'), findsOneWidget);
    });
  });

  group('kunci idempoten', () {
    testWidgets('percobaan ulang setelah kegagalan transport memakai kunci '
        'yang sama', (tester) async {
      var attempt = 0;

      when(
        () => repository.create(
          fields: any(named: 'fields'),
          attachment: any(named: 'attachment'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer((_) async {
        attempt += 1;

        if (attempt == 1) {
          // Jawaban hilang di jalan: permintaannya mungkin sudah tercatat.
          throw const ApiException('Tidak ada jawaban dari server.');
        }

        return true;
      });

      await pumpForm(tester, type: _type(id: 4, code: 'ANNUAL'));
      controller.startTimeC.text = '08:00';
      controller.endTimeC.text = '17:00';

      await submit(tester);
      await submit(tester);

      final keys = verify(
        () => repository.create(
          fields: any(named: 'fields'),
          attachment: any(named: 'attachment'),
          idempotencyKey: captureAny(named: 'idempotencyKey'),
        ),
      ).captured;

      expect(keys, hasLength(2));
      expect(keys.first, isNotNull);
      expect(keys.first, keys.last);
    });

    testWidgets('penolakan server 4xx memulai pengajuan baru', (tester) async {
      var attempt = 0;

      when(
        () => repository.create(
          fields: any(named: 'fields'),
          attachment: any(named: 'attachment'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer((_) async {
        attempt += 1;

        if (attempt == 1) {
          // Ditolak dengan sadar: tidak ada yang tercatat untuk diulang.
          throw const ApiException('Tanggal tidak punya jadwal.', status: 409);
        }

        return true;
      });

      await pumpForm(tester, type: _type(id: 4, code: 'ANNUAL'));
      controller.startTimeC.text = '08:00';
      controller.endTimeC.text = '17:00';

      await submit(tester);
      await submit(tester);

      final keys = verify(
        () => repository.create(
          fields: any(named: 'fields'),
          attachment: any(named: 'attachment'),
          idempotencyKey: captureAny(named: 'idempotencyKey'),
        ),
      ).captured;

      expect(keys, hasLength(2));
      expect(keys.first, isNot(keys.last));
    });
  });
}

LeaveType _type({required int id, String? code, bool withFile = false}) =>
    LeaveType.fromJson({
      'id': id,
      'name': 'Jenis $id',
      if (code != null) 'code': code,
      'requires_file': withFile,
    });

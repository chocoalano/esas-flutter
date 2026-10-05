import 'package:esas/features/permit/data/models/leave_list.dart';
import 'package:esas/features/permit/data/repositories/permit_repository.dart';
import 'package:esas/features/permit/presentation/controllers/permit_show_controller.dart';
import 'package:esas/features/permit/presentation/views/permit_show_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class _MockPermitRepository extends Mock implements PermitRepository {}

/// Apa yang dilihat penyetuju sebelum menekan Setujui.
///
/// Layar ini menampilkan periode, durasi, jam dan catatan untuk semua jenis
/// izin tanpa kecuali — jadi seorang atasan yang membuka permintaan tukar shift
/// menyetujui sesuatu yang tidak pernah ditampilkan kepadanya. Keempat kolom
/// penyesuaian sudah ada di dalam jawaban server sejak dulu; hanya tidak pernah
/// digambar.
void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  tearDown(Get.reset);

  Future<void> pumpDetail(WidgetTester tester, Permit permit) async {
    final controller = PermitShowController(
      repository: _MockPermitRepository(),
    );

    Get.put<PermitShowController>(controller);

    controller.permit.value = permit;
    controller.isLoading.value = false;

    await tester.pumpWidget(
      GetMaterialApp(
        locale: const Locale('id', 'ID'),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('id', 'ID')],
        home: const PermitShowView(),
      ),
    );

    await tester.pumpAndSettle();
  }

  group('penyesuaian shift', () {
    testWidgets('digambar sebagai nama dan jam, bukan dua id', (tester) async {
      await pumpDetail(
        tester,
        Permit.fromJson({
          'id': 1,
          'permit_numbers': 'PRM-1',
          'start_date': '2026-09-02',
          'end_date': '2026-09-02',
          'current_shift_id': 3,
          'adjust_shift_id': 5,
          'shift_from': {
            'id': 3,
            'name': 'Pagi',
            'in': '07:00:00',
            'out': '15:00:00',
          },
          'shift_to': {
            'id': 5,
            'name': 'Malam',
            'in': '23:00:00',
            'out': '07:00:00',
          },
          'permit_type': {
            'id': 87,
            'name': 'Tukar shift',
            'code': 'SHIFT_ADJUSTMENT',
            'variant': 'shift_adjustment',
          },
        }),
      );

      expect(find.text('PENYESUAIAN SHIFT'), findsOneWidget);
      expect(find.text('Pagi'), findsOneWidget);
      expect(find.text('Malam'), findsOneWidget);
      // Jamnya ikut: "Pagi → Malam" adalah keputusan yang berbeda dari
      // "07:00–15:00 → 23:00–07:00".
      expect(find.text('07:00 – 15:00'), findsOneWidget);
      expect(find.text('23:00 – 07:00'), findsOneWidget);
      // Dan tidak ada id yang bocor ke layar.
      expect(find.text('3'), findsNothing);
      expect(find.text('5'), findsNothing);
    });

    testWidgets('nama telanjang dari kontrak lama tetap terbaca', (
      tester,
    ) async {
      await pumpDetail(
        tester,
        Permit.fromJson({
          'id': 1,
          'permit_numbers': 'PRM-1',
          'current_shift_id': 3,
          'adjust_shift_id': 5,
          'current_shift': 'Pagi',
          'adjust_shift': 'Malam',
        }),
      );

      expect(find.text('Pagi'), findsOneWidget);
      expect(find.text('Malam'), findsOneWidget);
    });
  });

  group('penyesuaian jam', () {
    testWidgets('jam yang diminta ditampilkan tanpa detik', (tester) async {
      await pumpDetail(
        tester,
        Permit.fromJson({
          'id': 2,
          'permit_numbers': 'PRM-2',
          'start_date': '2026-09-02',
          'end_date': '2026-09-02',
          'timein_adjust': '08:00:00',
          'timeout_adjust': '17:30:00',
          'permit_type': {
            'id': 52,
            'name': 'Koreksi absensi',
            'code': 'TIME_ADJUSTMENT',
            'variant': 'time_adjustment',
          },
        }),
      );

      expect(find.text('PENYESUAIAN JAM'), findsOneWidget);
      expect(find.text('08:00'), findsOneWidget);
      expect(find.text('17:30'), findsOneWidget);
      expect(find.text('PENYESUAIAN SHIFT'), findsNothing);
    });

    testWidgets('jam yang tidak diminta ditulis kosong, bukan ditebak', (
      tester,
    ) async {
      await pumpDetail(
        tester,
        Permit.fromJson({
          'id': 3,
          'permit_numbers': 'PRM-3',
          'timein_adjust': '08:00:00',
          'permit_type': {
            'id': 52,
            'name': 'Koreksi absensi',
            'variant': 'time_adjustment',
          },
        }),
      );

      // Jam absensi yang berlaku sekarang tidak ada di dalam jawaban endpoint
      // ini, jadi tidak ada "jam semula" yang ditampilkan sebagai pembanding.
      expect(find.text('08:00'), findsOneWidget);
      expect(find.text('—'), findsWidgets);
    });
  });

  group('izin biasa', () {
    testWidgets('tidak menumbuhkan bagian penyesuaian apa pun', (tester) async {
      await pumpDetail(
        tester,
        Permit.fromJson({
          'id': 4,
          'permit_numbers': 'PRM-4',
          'start_date': '2026-09-02',
          'end_date': '2026-09-02',
          'permit_type': {
            'id': 4,
            'name': 'Cuti tahunan',
            'code': 'ANNUAL',
            'variant': 'general',
          },
        }),
      );

      expect(find.text('PENYESUAIAN JAM'), findsNothing);
      expect(find.text('PENYESUAIAN SHIFT'), findsNothing);
    });
  });
}

import 'package:esas/core/tenancy/workspace_clock.dart';
import 'package:esas/features/permit/data/models/schedule.dart';
import 'package:esas/features/permit/data/repositories/permit_repository.dart';
import 'package:esas/features/permit/presentation/controllers/permit_create_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:mocktail/mocktail.dart';

class _MockPermitRepository extends Mock implements PermitRepository {}

/// Tanggal yang dipilihkan formulir izin (FUNC-C02, audit UX 2026-11-12).
///
/// Jendela roster mencakup 30 hari ke belakang, jadi "jadwal pertama" bisa
/// sebulan lalu: formulir terbuka pada tanggal yang hampir tidak pernah
/// dimaksud. Dan mengubah tanggal mulai dulu membiarkan tanggal selesai di
/// belakangnya.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => initializeDateFormatting('id_ID'));

  tearDown(Get.reset);

  final format = DateFormat('yyyy-MM-dd');

  /// Hari ke-[offset] dari hari ini menurut jam workspace.
  String day(int offset) {
    final today = WorkspaceClock.current.today();

    return format.format(DateTime(today.year, today.month, today.day + offset));
  }

  Future<PermitCreateController> openWith(List<String> workDays) async {
    final repository = _MockPermitRepository();
    when(
      () => repository.formData(
        from: any(named: 'from'),
        to: any(named: 'to'),
      ),
    ).thenAnswer(
      (_) async => PermitFormData(
        schedules: [
          for (var i = 0; i < workDays.length; i++)
            Schedule.fromJson({'id': 100 + i, 'work_day': workDays[i]}),
        ],
      ),
    );

    final controller = PermitCreateController(repository: repository);
    controller.onInit();
    await Future<void>.delayed(Duration.zero);

    return controller;
  }

  test('formulir terbuka pada jadwal pertama mulai hari ini', () async {
    final controller = await openWith([day(-20), day(-1), day(0), day(2)]);

    expect(controller.selectedScheduleId.value, 102);
    expect(controller.startDateC.text, day(0));
    expect(controller.endDateC.text, day(0));
  });

  test('jadwal mendatang dipilihkan bila hari ini libur', () async {
    final controller = await openWith([day(-5), day(1), day(2)]);

    expect(controller.selectedScheduleId.value, 101);
    expect(controller.startDateC.text, day(1));
  });

  test('bila semua jadwal sudah lewat, jadwal pertama yang dipilihkan', () async {
    final controller = await openWith([day(-3), day(-2)]);

    expect(controller.selectedScheduleId.value, 100);
    expect(controller.startDateC.text, day(-3));
  });

  test('tanggal selesai ikut maju bila tanggal mulai melewatinya', () async {
    final controller = await openWith([day(0), day(1), day(3)]);

    controller.startDateC.text = day(3);

    expect(controller.selectedScheduleId.value, 102);
    expect(controller.endDateC.text, day(3));
    expect(controller.isSingleDay, isTrue);
  });

  test('rentang yang masih utuh tidak disentuh', () async {
    final controller = await openWith([day(0), day(1), day(3)]);

    controller.endDateC.text = day(5);
    controller.startDateC.text = day(1);

    expect(controller.endDateC.text, day(5));
    expect(controller.selectedScheduleId.value, 101);
  });
}

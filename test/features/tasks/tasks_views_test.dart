import 'package:esas/core/network/api_exception.dart';
import 'package:esas/features/tasks/data/models/field_task.dart';
import 'package:esas/features/tasks/data/repositories/tasks_repository.dart';
import 'package:esas/features/tasks/presentation/controllers/my_tasks_controller.dart';
import 'package:esas/features/tasks/presentation/controllers/task_detail_controller.dart';
import 'package:esas/features/tasks/presentation/views/my_tasks_view.dart';
import 'package:esas/features/tasks/presentation/views/task_detail_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class _Repo extends Mock implements TasksRepository {}

Future<void> _pump(WidgetTester tester, Widget view) async {
  await tester.pumpWidget(GetMaterialApp(home: view));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));
  setUp(() => Get.testMode = true);
  tearDown(Get.reset);

  testWidgets(
    'Tugas Saya shows the assigned tasks and marks what needs action',
    (tester) async {
      final repo = _Repo();
      when(() => repo.myTasks(any())).thenAnswer(
        (_) async => const TaskListResult(
          tasks: [
            FieldTask(
              domain: TaskDomain.gams,
              id: 1,
              number: 'WO-00000001',
              title: 'Bersihkan pantry',
              location: 'Gedung A',
              status: 'issued',
              statusLabel: 'Issued',
              allowedActions: ['accept'],
            ),
          ],
        ),
      );
      Get.put(MyTasksController(repository: repo, domains: [TaskDomain.gams]));

      await _pump(tester, const MyTasksView());

      expect(find.text('Bersihkan pantry'), findsOneWidget);
      expect(find.text('WO-00000001'), findsOneWidget);
      expect(find.text('Perlu tindakan'), findsOneWidget);
    },
  );

  testWidgets('no task is an empty state, and no field role is access denied', (
    tester,
  ) async {
    final repo = _Repo();
    when(
      () => repo.myTasks(any()),
    ).thenAnswer((_) async => const TaskListResult(tasks: []));
    Get.put(MyTasksController(repository: repo, domains: [TaskDomain.itms]));
    await _pump(tester, const MyTasksView());
    expect(find.text('Tidak ada tugas'), findsOneWidget);

    Get.reset();
    Get.testMode = true;
    final denied = _Repo();
    when(() => denied.myTasks(any())).thenAnswer(
      (_) async => const TaskListResult(
        tasks: [],
        failures: {TaskDomain.itms: ApiException('no', status: 403)},
      ),
    );
    Get.put(MyTasksController(repository: denied, domains: [TaskDomain.itms]));
    await _pump(tester, const MyTasksView());
    expect(find.text('Tidak ada akses tugas lapangan'), findsOneWidget);
  });

  testWidgets('a network failure offers a retry that loads again', (
    tester,
  ) async {
    final repo = _Repo();
    var calls = 0;
    when(() => repo.myTasks(any())).thenAnswer((_) async {
      calls++;
      return const TaskListResult(
        tasks: [],
        failures: {
          TaskDomain.mtms: ApiException('offline', code: 'network_unreachable'),
        },
      );
    });
    Get.put(MyTasksController(repository: repo, domains: [TaskDomain.mtms]));
    await _pump(tester, const MyTasksView());

    expect(find.text('Tidak dapat terhubung'), findsOneWidget);
    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();
    expect(calls, 2);
  });

  testWidgets('the detail shows only the actions the server allows', (
    tester,
  ) async {
    final repo = _Repo();
    when(() => repo.detail(TaskDomain.itms, 5)).thenAnswer(
      (_) async => const FieldTaskDetail(
        task: FieldTask(
          domain: TaskDomain.itms,
          id: 5,
          number: 'TKT-5',
          title: 'Laptop tidak menyala',
          status: 'in_progress',
          statusLabel: 'In Progress',
          allowedActions: ['progress', 'wait', 'resolve'],
        ),
        requesterName: 'Budi',
      ),
    );
    Get.put(
      TaskDetailController(repository: repo, domain: TaskDomain.itms, id: 5),
    );

    await _pump(tester, const TaskDetailView());

    expect(find.text('Catat Progres'), findsOneWidget);
    expect(find.text('Tunggu'), findsOneWidget);
    expect(find.text('Laporkan Selesai'), findsOneWidget);
    expect(find.text('Mulai Pekerjaan'), findsNothing);
    expect(find.text('Lanjutkan'), findsNothing);
    expect(find.text('Budi'), findsOneWidget);
  });

  testWidgets('a task no longer assigned to the worker says so', (
    tester,
  ) async {
    final repo = _Repo();
    when(
      () => repo.detail(TaskDomain.gams, 8),
    ).thenThrow(const ApiException('Not found', status: 404));
    Get.put(
      TaskDetailController(repository: repo, domain: TaskDomain.gams, id: 8),
    );

    await _pump(tester, const TaskDetailView());

    expect(find.text('Tugas tidak tersedia'), findsOneWidget);
  });

  testWidgets(
    'a long title on a narrow phone at double text size does not overflow, and the card reads as one sentence',
    (tester) async {
      tester.view.physicalSize = const Size(320 * 3, 640 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final repo = _Repo();
      when(() => repo.myTasks(any())).thenAnswer(
        (_) async => const TaskListResult(
          tasks: [
            FieldTask(
              domain: TaskDomain.gams,
              id: 2,
              number: 'WO-00000002',
              title:
                  'Bersihkan dan sanitasi seluruh toilet karyawan lantai dua sayap timur termasuk wastafel',
              location: 'Gedung Kantor Pusat Sayap Timur Lantai Dua',
              priority: 'urgent',
              status: 'issued',
              statusLabel: 'Issued',
              allowedActions: ['accept'],
            ),
          ],
        ),
      );
      Get.put(MyTasksController(repository: repo, domains: [TaskDomain.gams]));

      await tester.pumpWidget(
        GetMaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const MyTasksView(),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Berikutnya: Terima Tugas'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('tindakan berikutnya Terima Tugas')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'a waiting ITMS ticket offers to resume, record progress or resolve',
    (tester) async {
      final repo = _Repo();
      when(() => repo.detail(TaskDomain.itms, 6)).thenAnswer(
        (_) async => const FieldTaskDetail(
          task: FieldTask(
            domain: TaskDomain.itms,
            id: 6,
            number: 'TKT-6',
            title: 'VPN putus',
            status: 'waiting',
            statusLabel: 'Waiting',
            allowedActions: ['progress', 'resume', 'resolve'],
          ),
        ),
      );
      Get.put(
        TaskDetailController(repository: repo, domain: TaskDomain.itms, id: 6),
      );

      await _pump(tester, const TaskDetailView());

      expect(find.text('Lanjutkan'), findsOneWidget);
      expect(find.text('Catat Progres'), findsOneWidget);
      expect(find.text('Laporkan Selesai'), findsOneWidget);
      expect(
        find.textContaining('Catat progres terlebih dahulu'),
        findsNothing,
      );
    },
  );

  testWidgets('a verified report shows the verdict to the worker', (
    tester,
  ) async {
    final repo = _Repo();
    when(() => repo.detail(TaskDomain.gams, 4)).thenAnswer(
      (_) async => FieldTaskDetail(
        task: const FieldTask(
          domain: TaskDomain.gams,
          id: 4,
          number: 'WO-4',
          title: 'Pantry',
          status: 'verified',
          statusLabel: 'Verified',
        ),
        report: 'Pantry bersih',
        verificationNote: 'Sesuai standar',
        verifiedAt: DateTime(2026, 11, 12, 10),
      ),
    );
    Get.put(
      TaskDetailController(repository: repo, domain: TaskDomain.gams, id: 4),
    );

    await _pump(tester, const TaskDetailView());

    expect(find.text('Hasil verifikasi'), findsOneWidget);
    expect(find.text('Sesuai standar'), findsOneWidget);
    expect(find.text('Pantry bersih'), findsOneWidget);
  });
}

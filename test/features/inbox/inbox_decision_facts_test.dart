import 'package:esas/core/network/api_exception.dart';
import 'package:esas/core/theme/app_theme.dart';
import 'package:esas/features/inbox/data/models/approval_task.dart';
import 'package:esas/features/inbox/data/repositories/inbox_repository.dart';
import 'package:esas/features/inbox/presentation/controllers/unified_inbox_controller.dart';
import 'package:esas/features/inbox/presentation/views/unified_inbox_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

class _Repo extends Mock implements InboxRepository {}

/// UX-A08 / UX-D18 / FUNC-D19. Approvers decided without the facts, one tap
/// approved, a failed rejection lost its reason, and a gate pass offered a
/// rejection GAMS does not have.
void main() {
  setUp(() => Get.testMode = true);
  tearDown(Get.reset);

  final leave = ApprovalTask.fromJson({
    'id': 'hrms_permit_7',
    'title': 'Cuti tahunan',
    'requester_name': 'Budi',
    'can_decide': true,
    'can_reject': true,
    'facts': [
      {'label': 'Tanggal', 'value': '20 Nov 2026 – 21 Nov 2026'},
      {'label': 'Durasi', 'value': '2 hari'},
    ],
    'detail': {'route': '/permit/show', 'id': 7},
  });
  final gatePass = ApprovalTask.fromJson({
    'id': 'gams_gatepass_3',
    'title': 'Gate Pass GP-00000003',
    'requester_name': 'Gudang A',
    'can_decide': true,
    'can_reject': false,
    'facts': [
      {'label': 'Barang', 'value': 'Laptop untuk servis'},
    ],
  });

  Future<_Repo> openInbox(WidgetTester tester, List<ApprovalTask> tasks) async {
    final repo = _Repo();
    when(() => repo.tasks()).thenAnswer((_) async => tasks);

    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(body: Text('BERANDA')),
        getPages: [
          GetPage(name: '/inbox', page: () => const UnifiedInboxView()),
        ],
      ),
    );
    Get.put(UnifiedInboxController(repository: repo));
    Get.toNamed<void>('/inbox');
    await tester.pumpAndSettle();
    return repo;
  }

  void decideAnswers(
    _Repo repo,
    Future<Map<String, dynamic>> Function() reply,
  ) {
    when(
      () => repo.decideTask(
        taskId: any(named: 'taskId'),
        decision: any(named: 'decision'),
        note: any(named: 'note'),
      ),
    ).thenAnswer((_) => reply());
  }

  test('the server\'s facts, rejection and detail link are read', () {
    expect(leave.facts.map((f) => f.label), ['Tanggal', 'Durasi']);
    expect(leave.detailRoute, '/permit/show');
    expect(leave.detailId, 7);
    expect(gatePass.canReject, isFalse);
  });

  testWidgets('the card shows the facts, and approving asks first', (
    tester,
  ) async {
    final repo = await openInbox(tester, [leave]);
    decideAnswers(repo, () async => <String, dynamic>{});

    expect(find.text('Durasi: 2 hari'), findsOneWidget);
    expect(find.text('Lihat detail'), findsOneWidget);

    await tester.tap(find.text('Setujui').first);
    await tester.pumpAndSettle();
    expect(find.text('Setujui pengajuan?'), findsOneWidget);
    verifyNever(
      () => repo.decideTask(
        taskId: any(named: 'taskId'),
        decision: any(named: 'decision'),
        note: any(named: 'note'),
      ),
    );

    await tester.tap(find.text('Setujui').last);
    await tester.pumpAndSettle();
    verify(
      () => repo.decideTask(taskId: 'hrms_permit_7', decision: 'approved'),
    ).called(1);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('a rejection that fails keeps the dialog and the reason', (
    tester,
  ) async {
    final repo = await openInbox(tester, [leave]);
    decideAnswers(
      repo,
      () async => throw const ApiException('Server sibuk', status: 503),
    );

    await tester.tap(find.text('Tolak').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Kuota cuti habis');
    await tester.tap(find.text('Tolak').last);
    await tester.pumpAndSettle();

    expect(find.text('Tolak Pengajuan'), findsOneWidget);
    expect(find.text('Kuota cuti habis'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('a gate pass offers no rejection GAMS cannot record', (
    tester,
  ) async {
    await openInbox(tester, [gatePass]);

    expect(find.text('Barang: Laptop untuk servis'), findsOneWidget);
    expect(find.text('Tolak'), findsNothing);
    expect(find.text('Setujui'), findsOneWidget);
  });
}

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

/// UAT review H1 / H8. The INBOX-01 fix closed the reject dialog with
/// `Get.back(closeOverlays: true)` — which pops until no dialog is open and
/// then pops once more, so every rejection also closed the inbox. And the app
/// bar's `Get.back()` only closed the decision snackbar on the first tap.
void main() {
  setUp(() => Get.testMode = true);
  tearDown(Get.reset);

  Future<_Repo> openInbox(WidgetTester tester) async {
    final repo = _Repo();
    when(() => repo.tasks()).thenAnswer(
      (_) async => [
        ApprovalTask.fromJson({
          'id': 't1',
          'title': 'Cuti Budi',
          'requester_name': 'Budi',
          'can_decide': true,
        }),
      ],
    );
    when(
      () => repo.decideTask(
        taskId: any(named: 'taskId'),
        decision: any(named: 'decision'),
        note: any(named: 'note'),
      ),
    ).thenAnswer((_) async => <String, dynamic>{});

    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.lightTheme,
        initialRoute: '/home',
        getPages: [
          GetPage(name: '/home', page: () => const Scaffold(body: Text('BERANDA'))),
          GetPage(name: '/inbox', page: () => const UnifiedInboxView()),
        ],
      ),
    );
    Get.put(UnifiedInboxController(repository: repo));
    Get.toNamed<void>('/inbox');
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets('rejecting closes the dialog, not the inbox', (tester) async {
    final repo = await openInbox(tester);

    await tester.tap(find.text('Tolak').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Kuota habis');
    await tester.tap(find.text('Tolak').last);
    await tester.pumpAndSettle();

    verify(
      () => repo.decideTask(
        taskId: 't1',
        decision: 'rejected',
        note: 'Kuota habis',
      ),
    ).called(1);
    expect(find.text('Tolak Pengajuan'), findsNothing);
    expect(find.byType(UnifiedInboxView), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('back leaves the inbox even with a snackbar showing', (
    tester,
  ) async {
    await openInbox(tester);
    Get.snackbar('Berhasil', 'Keputusan terkirim', duration: const Duration(seconds: 30));
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    expect(find.byType(UnifiedInboxView), findsNothing);
    expect(find.text('BERANDA'), findsOneWidget);

    await tester.pump(const Duration(seconds: 31));
    await tester.pumpAndSettle();
  });
}

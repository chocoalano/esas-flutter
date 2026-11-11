import 'dart:async';

import 'package:esas/features/inbox/data/repositories/inbox_repository.dart';
import 'package:esas/features/inbox/presentation/controllers/unified_inbox_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

class _Repo extends Mock implements InboxRepository {}

/// INBOX-01. A double tap on "Setujui" sent two decisions; where the same
/// person also held the next tier, the second answered that tier too.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => Get.testMode = true);
  tearDown(Get.reset);

  test('a second decision while the first is in flight is not sent', () async {
    final repo = _Repo();
    final pending = Completer<Map<String, dynamic>>();
    when(
      () => repo.decideTask(
        taskId: any(named: 'taskId'),
        decision: any(named: 'decision'),
        note: any(named: 'note'),
      ),
    ).thenAnswer((_) => pending.future);
    final controller = UnifiedInboxController(repository: repo);

    final first = controller.decideTask(taskId: 't1', decision: 'approved');
    final second = controller.decideTask(taskId: 't1', decision: 'approved');

    expect(await second, isFalse);
    pending.complete(<String, dynamic>{});
    await first;

    verify(
      () => repo.decideTask(
        taskId: any(named: 'taskId'),
        decision: any(named: 'decision'),
        note: any(named: 'note'),
      ),
    ).called(1);
  });
}

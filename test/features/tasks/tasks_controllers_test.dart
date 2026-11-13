import 'dart:async';

import 'package:esas/core/network/api_exception.dart';
import 'package:esas/features/tasks/data/models/field_task.dart';
import 'package:esas/features/tasks/data/models/task_action.dart';
import 'package:esas/features/tasks/data/repositories/tasks_repository.dart';
import 'package:esas/features/tasks/presentation/controllers/my_tasks_controller.dart';
import 'package:esas/features/tasks/presentation/controllers/task_detail_controller.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

class _Repo extends Mock implements TasksRepository {}

FieldTask _task(TaskDomain domain, int id, {List<String> actions = const []}) =>
    FieldTask(
      domain: domain,
      id: id,
      number: '#$id',
      title: 'Tugas $id',
      status: 'issued',
      statusLabel: 'Issued',
      lockVersion: 1,
      allowedActions: actions,
    );

FieldTaskDetail _detail(String status, List<String> actions, {int lock = 1}) =>
    FieldTaskDetail(
      task: FieldTask(
        domain: TaskDomain.gams,
        id: 9,
        number: 'WO-9',
        title: 'Pantry',
        status: status,
        statusLabel: status,
        lockVersion: lock,
        allowedActions: actions,
      ),
    );

const _complete = TaskAction(
  key: 'complete',
  label: 'Laporkan Selesai',
  path: 'complete',
  inputField: 'completion_notes',
  inputLabel: 'Laporan',
  isCompletion: true,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => Get.testMode = true);
  tearDown(Get.reset);

  group('MyTasksController', () {
    test(
      'filters by domain on the handset only among tasks the server returned',
      () async {
        final repo = _Repo();
        when(() => repo.myTasks(any())).thenAnswer(
          (_) async => TaskListResult(
            tasks: [
              _task(TaskDomain.gams, 1, actions: ['accept']),
              _task(TaskDomain.itms, 2),
            ],
          ),
        );
        final c = MyTasksController(
          repository: repo,
          domains: TaskDomain.values,
        );
        await c.load();

        expect(c.visibleTasks, hasLength(2));
        c.selectFilter(TaskDomain.itms);
        expect(c.visibleTasks.map((t) => t.id), [2]);
        expect(c.needsActionCount, 1);
      },
    );

    test(
      'every domain refusing with 403 is access denied, not an error',
      () async {
        final repo = _Repo();
        when(() => repo.myTasks(any())).thenAnswer(
          (_) async => const TaskListResult(
            tasks: [],
            failures: {
              TaskDomain.gams: ApiException('no', status: 403),
              TaskDomain.itms: ApiException('no', status: 403),
            },
          ),
        );
        final c = MyTasksController(
          repository: repo,
          domains: [TaskDomain.gams, TaskDomain.itms],
        );
        await c.load();

        expect(c.isAccessDenied, isTrue);
        expect(c.blockingError, isNull);
      },
    );

    test(
      'a network failure of every domain is a retryable error; one failing domain is a notice',
      () async {
        final repo = _Repo();
        when(() => repo.myTasks(any())).thenAnswer(
          (_) async => const TaskListResult(
            tasks: [],
            failures: {
              TaskDomain.gams: ApiException(
                'offline',
                code: 'network_unreachable',
              ),
            },
          ),
        );
        final allFail = MyTasksController(
          repository: repo,
          domains: [TaskDomain.gams],
        );
        await allFail.load();
        expect(allFail.blockingError?.isTransportFailure, isTrue);

        final partial = MyTasksController(
          repository: repo,
          domains: [TaskDomain.gams, TaskDomain.itms],
        );
        await partial.load();
        expect(partial.blockingError, isNull);
        expect(partial.partiallyFailed, [TaskDomain.gams]);
      },
    );
  });

  group('TaskDetailController', () {
    late _Repo repo;
    final keys = <String>[];

    setUp(() {
      repo = _Repo();
      keys.clear();
      when(
        () => repo.detail(TaskDomain.gams, 9),
      ).thenAnswer((_) async => _detail('in_progress', ['hold', 'complete']));
    });

    void answer(List<Object> outcomes) {
      var call = 0;
      when(
        () => repo.act(
          TaskDomain.gams,
          9,
          any(),
          any(),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer((invocation) async {
        keys.add(invocation.namedArguments[#idempotencyKey] as String);
        final outcome = outcomes[call++];
        if (outcome is ApiException) throw outcome;
        return outcome as FieldTaskDetail;
      });
    }

    test(
      'a retry after a lost answer reuses the same key, and the task is read back',
      () async {
        answer([
          const ApiException('timeout', code: 'timeout'),
          _detail('completed', []),
        ]);
        final c = TaskDetailController(
          repository: repo,
          domain: TaskDomain.gams,
          id: 9,
        );
        await c.load();

        expect(await c.run(_complete, input: 'Selesai'), isFalse);
        expect(c.notice.value, contains('belum pasti'));
        verify(() => repo.detail(TaskDomain.gams, 9)).called(2);

        expect(await c.run(_complete, input: 'Selesai'), isTrue);
        expect(keys, hasLength(2));
        expect(keys.first, keys.last);
        expect(c.detail.value!.task.status, 'completed');
      },
    );

    test('a changed report is a new action with a new key', () async {
      answer([
        const ApiException('timeout', code: 'timeout'),
        _detail('completed', []),
      ]);
      final c = TaskDetailController(
        repository: repo,
        domain: TaskDomain.gams,
        id: 9,
      );
      await c.load();

      await c.run(_complete, input: 'Versi pertama');
      await c.run(_complete, input: 'Versi diperbaiki');

      expect(keys.first, isNot(keys.last));
    });

    test('a conflict reloads the task and says the status changed', () async {
      answer([const ApiException('stale', status: 409, code: 'STALE_VERSION')]);
      final c = TaskDetailController(
        repository: repo,
        domain: TaskDomain.gams,
        id: 9,
      );
      await c.load();

      expect(await c.run(_complete, input: 'x'), isFalse);
      expect(c.noticeIsConflict.value, isTrue);
      verify(() => repo.detail(TaskDomain.gams, 9)).called(2);
    });

    test(
      'a domain validation error is shown as the server worded it',
      () async {
        answer([
          const ApiException(
            'Checklist wajib belum lengkap.',
            status: 422,
            code: 'CHECKLIST_INCOMPLETE',
          ),
        ]);
        final c = TaskDetailController(
          repository: repo,
          domain: TaskDomain.gams,
          id: 9,
        );
        await c.load();

        await c.run(_complete, input: 'x');
        expect(c.notice.value, 'Checklist wajib belum lengkap.');
      },
    );

    test(
      'the stale-screen guard sends the lock version the screen showed',
      () async {
        answer([_detail('completed', [])]);
        final c = TaskDetailController(
          repository: repo,
          domain: TaskDomain.gams,
          id: 9,
        );
        await c.load();

        await c.run(_complete, input: 'Selesai');

        final body =
            verify(
                  () => repo.act(
                    TaskDomain.gams,
                    9,
                    'complete',
                    captureAny(),
                    idempotencyKey: any(named: 'idempotencyKey'),
                  ),
                ).captured.single
                as Map<String, dynamic>;
        expect(body, {'completion_notes': 'Selesai', 'lock_version': 1});
      },
    );
  });

  test('coming back to the app reloads the list', () async {
    final repo = _Repo();
    when(
      () => repo.myTasks(any()),
    ).thenAnswer((_) async => const TaskListResult(tasks: []));
    final c = MyTasksController(repository: repo, domains: [TaskDomain.gams]);
    await c.load();

    c.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(Duration.zero);

    verify(() => repo.myTasks(any())).called(2);
  });

  test('a second tap while an action is in flight sends nothing', () async {
    final repo = _Repo();
    final pending = Completer<FieldTaskDetail>();
    when(
      () => repo.detail(TaskDomain.gams, 9),
    ).thenAnswer((_) async => _detail('in_progress', ['complete']));
    when(
      () => repo.act(
        TaskDomain.gams,
        9,
        any(),
        any(),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    ).thenAnswer((_) => pending.future);
    final c = TaskDetailController(
      repository: repo,
      domain: TaskDomain.gams,
      id: 9,
    );
    await c.load();

    final first = c.run(_complete, input: 'Selesai');
    expect(await c.run(_complete, input: 'Selesai'), isFalse);
    pending.complete(_detail('completed', []));
    expect(await first, isTrue);

    verify(
      () => repo.act(
        TaskDomain.gams,
        9,
        any(),
        any(),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    ).called(1);
  });

  test(
    'a permission revoked mid-task says so and reloads the allowed actions',
    () async {
      final repo = _Repo();
      when(
        () => repo.detail(TaskDomain.gams, 9),
      ).thenAnswer((_) async => _detail('in_progress', ['complete']));
      when(
        () => repo.act(
          TaskDomain.gams,
          9,
          any(),
          any(),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenThrow(
        const ApiException('denied', status: 403, code: 'PERMISSION_DENIED'),
      );
      final c = TaskDetailController(
        repository: repo,
        domain: TaskDomain.gams,
        id: 9,
      );
      await c.load();

      expect(await c.run(_complete, input: 'x'), isFalse);
      expect(c.notice.value, 'Anda tidak berhak melakukan tindakan ini.');
      verify(() => repo.detail(TaskDomain.gams, 9)).called(2);
    },
  );
}

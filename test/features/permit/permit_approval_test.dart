import 'dart:async';

import 'package:esas/core/network/api_exception.dart';
import 'package:esas/core/tenancy/workspace_clock.dart';
import 'package:esas/features/permit/data/models/leave_list.dart';
import 'package:esas/features/permit/data/repositories/permit_repository.dart';
import 'package:esas/features/permit/presentation/controllers/permit_show_controller.dart';
import 'package:esas/features/permit/presentation/views/permit_show_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

class _Repo extends Mock implements PermitRepository {}

/// The approval chain as `PermitController::approvals()` sends it.
Permit permitWith(List<Map<String, dynamic>> approvals) => Permit.fromJson({
  'id': 42,
  'permit_numbers': 'PRM-42',
  'start_date': '2026-11-12',
  'end_date': '2026-11-12',
  'permit_type': {'id': 1, 'name': 'Cuti tahunan'},
  'approvals': approvals,
});

Map<String, dynamic> tier(
  int id,
  String type,
  int user,
  String? decision, {
  bool current = false,
}) => {
  'id': id,
  'permit_id': 42,
  'user_id': user,
  'user_type': type,
  'user_approve': decision,
  'is_current': current,
};

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  late _Repo repo;
  late PermitShowController controller;

  setUp(() {
    Get.testMode = true;
    repo = _Repo();
    when(() => repo.currentUserId).thenReturn(7);
    controller = PermitShowController(repository: repo);
  });

  tearDown(Get.reset);

  void detailIs(Permit permit) {
    when(() => repo.detail(any())).thenAnswer((_) async => permit);
  }

  // The way the screen opens: no permit yet, then the detail arrives.
  Future<void> open(Permit permit) async {
    detailIs(permit);
    controller = PermitShowController(repository: repo);
    controller.permitId.value = 42;
    controller.onInit();
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  // PRMT-04. The same person often holds two tiers — line and manager in a
  // small company. Their first row is the one they already answered; the one
  // the request is waiting on is the second.
  group('who may decide', () {
    test(
      'the tier the server says is current, not the first of mine',
      () async {
        await open(
          permitWith([
            tier(1, 'line', 7, 'y'),
            tier(2, 'manager', 7, 'w', current: true),
            tier(3, 'hr', 9, null),
          ]),
        );

        expect(controller.canApprove.value, isTrue);
        expect(controller.myApproval.value?.id, 2);
      },
    );

    test('nobody else\'s current tier', () async {
      await open(
        permitWith([
          tier(1, 'line', 7, 'y'),
          tier(2, 'manager', 9, 'w', current: true),
        ]),
      );

      expect(controller.canApprove.value, isFalse);
      // What this person did is still shown.
      expect(controller.myApproval.value?.userApprove, 'y');
    });
  });

  // PRMT-01. One decision is one request. A double tap or a retry after a
  // timeout used to mint a new Idempotency-Key each time — and the server,
  // which answers whatever tier is waiting, could take the second as this same
  // person's decision on the NEXT tier.
  group('sending a decision', () {
    setUp(() async {
      await open(
        permitWith([
          tier(1, 'line', 7, 'w', current: true),
          tier(2, 'manager', 7, null),
        ]),
      );
    });

    void answers(Future<void> Function() reply) => when(
      () => repo.approve(
        permitId: any(named: 'permitId'),
        approve: any(named: 'approve'),
        notes: any(named: 'notes'),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    ).thenAnswer((_) => reply());

    List<dynamic> keysSent() => verify(
      () => repo.approve(
        permitId: any(named: 'permitId'),
        approve: any(named: 'approve'),
        notes: any(named: 'notes'),
        idempotencyKey: captureAny(named: 'idempotencyKey'),
      ),
    ).captured;

    test('a second tap while the first is in flight sends nothing', () async {
      final pending = Completer<void>();
      answers(() => pending.future);

      unawaited(controller.submitApproval(approve: true));
      expect(controller.isSubmitting.value, isTrue);
      unawaited(controller.submitApproval(approve: true));

      pending.complete();
      await Future<void>.delayed(Duration.zero);

      expect(keysSent(), hasLength(1));
    });

    test('a retry after no answer is the same request', () async {
      var attempt = 0;
      answers(() async {
        attempt++;
        if (attempt == 1) {
          throw const ApiException('Koneksi terlalu lama.', code: 'timeout');
        }
      });

      await controller.submitApproval(approve: true);
      await controller.submitApproval(approve: true);

      final keys = keysSent();
      expect(keys, hasLength(2));
      expect(keys.first, isNotNull);
      expect(keys.first, keys.last);
    });

    test('a different decision is a different request', () async {
      answers(
        () async =>
            throw const ApiException('Koneksi terlalu lama.', code: 'timeout'),
      );

      await controller.submitApproval(approve: true);
      await controller.submitApproval(approve: false, notes: 'Kuota habis');

      final keys = keysSent();
      expect(keys.first, isNot(keys.last));
    });

    test('a request still in progress keeps its key', () async {
      var attempt = 0;
      answers(() async {
        attempt++;
        if (attempt == 1) {
          throw const ApiException(
            'Masih diproses.',
            status: 409,
            code: 'idempotency_in_progress',
          );
        }
      });

      await controller.submitApproval(approve: true);
      await controller.submitApproval(approve: true);

      final keys = keysSent();
      expect(keys.first, keys.last);
    });

    test('a decided request lets go of its key', () async {
      answers(() async {});

      await controller.submitApproval(approve: true);
      // Detail reloaded and, say, the next tier is now this person's.
      await open(
        permitWith([
          tier(1, 'line', 7, 'y'),
          tier(2, 'manager', 7, 'w', current: true),
        ]),
      );
      await controller.submitApproval(approve: true);

      final keys = keysSent();
      expect(keys.first, isNot(keys.last));
    });
  });

  testWidgets('both buttons wait while a decision is in flight', (
    tester,
  ) async {
    // Real async: `open` waits on microtasks the widget test's fake clock
    // would never run.
    await tester.runAsync(
      () => open(permitWith([tier(1, 'line', 7, 'w', current: true)])),
    );
    Get.put<PermitShowController>(controller);
    controller.isSubmitting.value = true;

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
    await tester.pump();

    final approve = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Setujui'),
        matching: find.byWidgetPredicate((w) => w is FilledButton),
      ),
    );
    final reject = tester.widget<OutlinedButton>(
      find.ancestor(
        of: find.text('Tolak'),
        matching: find.byWidgetPredicate((w) => w is OutlinedButton),
      ),
    );
    expect(approve.onPressed, isNull);
    expect(reject.onPressed, isNull);
  });

  // PRMT-12. `updated_at` arrives as an instant with an offset; parsing it
  // yields a UTC DateTime, and formatting that drew the UTC wall clock — a
  // decision at 06:30 WIB on the 12th read "11 Nov · 23:30".
  testWidgets('a decision is timed on the workspace clock', (tester) async {
    final previous = WorkspaceClock.current;
    addTearDown(() => WorkspaceClock.current = previous);
    WorkspaceClock.current = WorkspaceClock.fromJson({
      'name': 'Asia/Jakarta',
      'abbreviation': 'WIB',
      'offset_minutes': 420,
    });

    await tester.runAsync(
      () => open(
        permitWith([
          {
            ...tier(1, 'line', 9, 'y'),
            'updated_at': '2026-11-11T23:30:00+00:00',
          },
          tier(2, 'manager', 7, 'w', current: true),
        ]),
      ),
    );
    Get.put<PermitShowController>(controller);

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
    await tester.pump();

    expect(find.textContaining('12 Nov 2026 · 06:30'), findsOneWidget);
    expect(find.textContaining('23:30'), findsNothing);
  });
}

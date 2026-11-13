import 'dart:async';

import 'package:esas/features/auth/data/models/device_status.dart';
import 'package:esas/features/auth/data/repositories/device_proof_gate.dart';
import 'package:esas/features/auth/data/repositories/device_proof_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepository extends Mock implements DeviceProofRepository {}

/// ADR-D §9 option c: proof before the attendance flow, one automatic re-proof
/// on 403 `DEVICE_PROOF_REQUIRED`, and nothing at all while the server does
/// not ask for it.
void main() {
  late _MockRepository repository;
  late DateTime now;
  late DeviceProofGate gate;

  final proven = DeviceStatus(
    proofRequired: true,
    enrollmentAvailable: true,
    keyEnrolled: true,
    proofValidUntil: DateTime.utc(2026, 11, 13, 10, 10),
  );

  void deviceIs(DeviceStatus? device) =>
      when(() => repository.current).thenReturn(device);

  void proofAnswers(Future<DeviceStatus?> Function() answer) =>
      when(() => repository.prove()).thenAnswer((_) => answer());

  setUp(() {
    repository = _MockRepository();
    now = DateTime.utc(2026, 11, 13, 10);
    gate = DeviceProofGate(repository: repository, now: () => now);
    when(() => repository.userKey).thenReturn(7);
    when(() => repository.keystoreAvailable()).thenAnswer((_) async => true);
  });

  group('today\'s behaviour is untouched', () {
    test('no device object: ready, nothing asked', () async {
      deviceIs(null);

      expect(gate.evaluate().status, DeviceGateStatus.ready);
      expect((await gate.ensureReady()).status, DeviceGateStatus.ready);
      verifyNever(() => repository.prove());
    });

    test('flag off (no proof, no enrolment): ready, nothing asked', () async {
      deviceIs(
        const DeviceStatus(
          isRegisteredDevice: false,
          canRecordAttendance: false,
          attendanceBlock: AttendanceBlock.deviceNotRegistered,
        ),
      );

      expect((await gate.ensureReady()).status, DeviceGateStatus.ready);
      verifyNever(() => repository.prove());
      verifyNever(() => repository.refreshStatus());
    });
  });

  group('enrolment open but not required', () {
    const pilot = DeviceStatus(enrollmentAvailable: true);

    test('is offered, and can be deferred for this person', () {
      deviceIs(pilot);

      expect(gate.evaluate().status, DeviceGateStatus.offerEnrollment);

      gate.deferEnrollment();

      expect(gate.evaluate().status, DeviceGateStatus.ready);
    });

    test('a deferral does not carry over to the next person', () {
      deviceIs(pilot);
      gate.deferEnrollment();

      when(() => repository.userKey).thenReturn(8);

      expect(gate.evaluate().status, DeviceGateStatus.offerEnrollment);
    });

    test('an enrolled phone is simply ready', () {
      deviceIs(
        const DeviceStatus(enrollmentAvailable: true, keyEnrolled: true),
      );

      expect(gate.evaluate().status, DeviceGateStatus.ready);
    });
  });

  group('proof required', () {
    test('without a key: not enrolled, nothing proven', () async {
      deviceIs(
        const DeviceStatus(
          proofRequired: true,
          enrollmentAvailable: true,
          attendanceBlock: AttendanceBlock.deviceNotEnrolled,
        ),
      );

      expect((await gate.ensureReady()).status, DeviceGateStatus.notEnrolled);
      verifyNever(() => repository.prove());
    });

    test('a window with more than the margin left is used as is', () async {
      deviceIs(proven);
      now = proven.proofValidUntil!.subtract(const Duration(minutes: 5));

      expect((await gate.ensureReady()).status, DeviceGateStatus.ready);
      verifyNever(() => repository.prove());
    });

    test('a window nearly gone is proven again before entry', () async {
      deviceIs(proven);
      now = proven.proofValidUntil!.subtract(const Duration(minutes: 3));
      proofAnswers(() async => proven);

      expect(gate.evaluate().status, DeviceGateStatus.needsProof);
      expect((await gate.ensureReady()).status, DeviceGateStatus.ready);
      verify(() => repository.prove()).called(1);
    });

    test('no window at all is proven', () async {
      deviceIs(
        const DeviceStatus(
          proofRequired: true,
          keyEnrolled: true,
          attendanceBlock: AttendanceBlock.deviceProofRequired,
        ),
      );
      proofAnswers(() async => proven);

      expect((await gate.ensureReady()).status, DeviceGateStatus.ready);
      verify(() => repository.prove()).called(1);
    });

    test('the server saying proof is required wins over the clock', () {
      deviceIs(
        DeviceStatus(
          proofRequired: true,
          keyEnrolled: true,
          proofValidUntil: now.add(const Duration(minutes: 9)),
          attendanceBlock: AttendanceBlock.deviceProofRequired,
        ),
      );

      expect(gate.evaluate().status, DeviceGateStatus.needsProof);
    });

    test('concurrent entries share one proof', () async {
      deviceIs(proven);
      now = proven.proofValidUntil!;
      final pending = Completer<DeviceStatus?>();
      proofAnswers(() => pending.future);

      final first = gate.ensureReady();
      final second = gate.ensureReady();
      pending.complete(proven);

      expect((await first).status, DeviceGateStatus.ready);
      expect((await second).status, DeviceGateStatus.ready);
      verify(() => repository.prove()).called(1);
    });
  });

  group('a phone that could never hold a key (Putaran 7, J4)', () {
    setUp(
      () => when(
        () => repository.keystoreAvailable(),
      ).thenAnswer((_) async => false),
    );

    test(
      'is told at the door instead of being sent to HR for a code',
      () async {
        deviceIs(
          const DeviceStatus(
            proofRequired: true,
            enrollmentAvailable: true,
            attendanceBlock: AttendanceBlock.deviceNotEnrolled,
          ),
        );

        final decision = await gate.ensureReady();

        expect(decision.status, DeviceGateStatus.keyUnavailable);
        expect(decision.failure, DeviceProofFailure.keyUnsupported);
      },
    );

    test('an optional offer is simply not made: attendance as today', () async {
      deviceIs(const DeviceStatus(enrollmentAvailable: true));

      expect((await gate.ensureReady()).status, DeviceGateStatus.ready);
    });

    test('nothing is asked of the keystore when the flag is off', () async {
      deviceIs(null);

      expect((await gate.ensureReady()).status, DeviceGateStatus.ready);
      verifyNever(() => repository.keystoreAvailable());
    });
  });

  group('error codes map to what the person can do', () {
    for (final (failure, status) in [
      // From a proof: this phone had a key the server no longer holds —
      // released by HR.
      (DeviceProofFailure.notEnrolled, DeviceGateStatus.recovery),
      (DeviceProofFailure.sessionEnded, DeviceGateStatus.sessionEnded),
      (DeviceProofFailure.proofInvalid, DeviceGateStatus.recovery),
      (DeviceProofFailure.keyMissing, DeviceGateStatus.recovery),
      (DeviceProofFailure.keyUnavailable, DeviceGateStatus.keyUnavailable),
      (DeviceProofFailure.keyUnsupported, DeviceGateStatus.keyUnavailable),
      (DeviceProofFailure.offline, DeviceGateStatus.offline),
      (DeviceProofFailure.disabled, DeviceGateStatus.ready),
      (DeviceProofFailure.challengeExpired, DeviceGateStatus.failed),
      (DeviceProofFailure.rateLimited, DeviceGateStatus.failed),
      (DeviceProofFailure.failed, DeviceGateStatus.failed),
    ]) {
      test('${failure.name} → ${status.name}', () async {
        deviceIs(proven);
        now = proven.proofValidUntil!;
        when(() => repository.prove()).thenThrow(DeviceProofException(failure));

        final decision = await gate.ensureReady();

        expect(decision.status, status);
        expect(decision.failure, failure);
      });
    }
  });

  group('403 DEVICE_PROOF_REQUIRED from an attendance call', () {
    setUp(() {
      deviceIs(proven);
      proofAnswers(() async => proven);
    });

    test('is proven again once', () async {
      expect((await gate.reproveAfterRefusal()).status, DeviceGateStatus.ready);
      verify(() => repository.prove()).called(1);
    });

    test('a second refusal is not proven again automatically', () async {
      await gate.reproveAfterRefusal();

      final second = await gate.reproveAfterRefusal();

      expect(second.status, DeviceGateStatus.failed);
      verify(() => repository.prove()).called(1);
    });

    test('a recorded clock earns the next refusal its own re-proof', () async {
      await gate.reproveAfterRefusal();
      gate.resetRetryBudget();

      await gate.reproveAfterRefusal();

      verify(() => repository.prove()).called(2);
    });

    test('a new entry into attendance starts a new budget', () async {
      now = proven.proofValidUntil!.subtract(const Duration(minutes: 9));
      await gate.reproveAfterRefusal();
      await gate.ensureReady();

      await gate.reproveAfterRefusal();

      verify(() => repository.prove()).called(2);
    });

    test('a re-proof that could not reach the server is not spent', () async {
      when(
        () => repository.prove(),
      ).thenThrow(const DeviceProofException(DeviceProofFailure.offline));

      expect(
        (await gate.reproveAfterRefusal()).status,
        DeviceGateStatus.offline,
      );

      proofAnswers(() async => proven);

      expect((await gate.reproveAfterRefusal()).status, DeviceGateStatus.ready);
    });

    test('a lost key after enrolment is a recovery', () async {
      when(
        () => repository.prove(),
      ).thenThrow(const DeviceProofException(DeviceProofFailure.proofInvalid));

      expect(
        (await gate.reproveAfterRefusal()).status,
        DeviceGateStatus.recovery,
      );
    });
  });

  group('refresh', () {
    test('asks the server, then decides', () async {
      deviceIs(
        const DeviceStatus(
          proofRequired: true,
          enrollmentAvailable: true,
          attendanceBlock: AttendanceBlock.deviceNotEnrolled,
        ),
      );
      when(
        () => repository.refreshStatus(),
      ).thenAnswer((_) async => const DeviceStatus());

      expect((await gate.refresh()).status, DeviceGateStatus.notEnrolled);
      verify(() => repository.refreshStatus()).called(1);
    });

    test('offline stays offline', () async {
      deviceIs(proven);
      when(
        () => repository.refreshStatus(),
      ).thenThrow(const DeviceProofException(DeviceProofFailure.offline));

      expect((await gate.refresh()).status, DeviceGateStatus.offline);
    });

    test('a 401 while asking is the session ending, not a retry', () async {
      deviceIs(proven);
      when(
        () => repository.refreshStatus(),
      ).thenThrow(const DeviceProofException(DeviceProofFailure.sessionEnded));

      expect((await gate.refresh()).status, DeviceGateStatus.sessionEnded);
      verifyNever(() => repository.prove());
    });

    test('the flag switched off on the server opens attendance', () async {
      deviceIs(proven);
      when(
        () => repository.refreshStatus(),
      ).thenThrow(const DeviceProofException(DeviceProofFailure.disabled));

      expect((await gate.refresh()).status, DeviceGateStatus.ready);
    });
  });
}

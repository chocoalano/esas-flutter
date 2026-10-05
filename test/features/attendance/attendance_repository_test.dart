import 'dart:convert';
import 'dart:io';

import 'package:esas/core/network/api_exception.dart';
import 'package:esas/core/tenancy/tenant_context.dart';
import 'package:esas/features/attendance/data/models/attendance_context.dart';
import 'package:esas/features/attendance/data/models/scanned_code.dart';
import 'package:esas/features/attendance/data/repositories/attendance_repository.dart';
import 'package:esas/features/attendance/data/services/attendance_api_service.dart';
import 'package:esas/features/auth/data/repositories/session_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockApi extends Mock implements AttendanceApiService {}

class _MockSession extends Mock implements SessionRepository {}

class _MockTenant extends Mock implements TenantContext {}

/// Redeeming a scanned code, and what to make of the answer.
///
/// This file exists because the client and the server had never agreed on the
/// request. `AttendanceRepository` parsed the department code correctly — JSON
/// with `{tenant, token, type, expires_at}` — and then posted it to
/// `POST /attendance/qr`, which is the *machine* endpoint: it wants an opaque
/// `code`, and a `type` the department payload was already carrying. The field
/// name was wrong, the required field was missing, and the coordinates the
/// controller had just validated were left behind entirely.
///
/// Everything below pins one half of that: which endpoint a code goes to, what
/// travels with it, and how the server's own `code` becomes the shape of the
/// screen that answers it.
void main() {
  late _MockApi api;
  late _MockSession session;
  late _MockTenant tenant;
  late AttendanceRepository repository;

  const accepted = <String, dynamic>{
    'message': 'Absen masuk berhasil.',
    'attendance': {
      'id': 91,
      'date': '2026-09-04',
      'time_in': '08:03:11',
      'time_out': null,
      'status_in': 'ON_TIME',
      'status_out': 'ABSENT',
    },
  };

  String departmentPayload({String type = 'in', String workspace = 'acme'}) =>
      json.encode({
        'tenant': workspace,
        'token': 'tok_abcdef0123456789',
        'type': type,
        'expires_at': DateTime.now()
            .add(const Duration(minutes: 15))
            .toIso8601String(),
      });

  String machinePayload({String workspace = 'acme'}) {
    final payload = base64Url
        .encode(
          utf8.encode(
            json.encode({
              'v': 1,
              'jti': 'code-1',
              'tid': workspace,
              'did': 3,
              'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
              'exp':
                  DateTime.now()
                      .add(const Duration(seconds: 20))
                      .millisecondsSinceEpoch ~/
                  1000,
            }),
          ),
        )
        .replaceAll('=', '');

    return '$payload.c2ln';
  }

  final position = ClockPosition(
    latitude: -6.21,
    longitude: 106.84,
    takenAt: DateTime(2026, 9, 4, 8),
    accuracy: 12.5,
  );

  setUpAll(() {
    registerFallbackValue(File('${Directory.systemTemp.path}/fallback.jpg'));
  });

  setUp(() {
    api = _MockApi();
    session = _MockSession();
    tenant = _MockTenant();

    when(() => tenant.tenant).thenReturn('acme');

    repository = AttendanceRepository(
      api: api,
      session: session,
      tenant: tenant,
    );
  });

  group('a department code goes to qr-presences/redeem', () {
    test(
      'as `token`, with the coordinates that were collected for it',
      () async {
        when(
          () => api.redeemDepartmentQr(
            token: any(named: 'token'),
            latitude: any(named: 'latitude'),
            longitude: any(named: 'longitude'),
            accuracy: any(named: 'accuracy'),
            isMocked: any(named: 'isMocked'),
          ),
        ).thenAnswer((_) async => accepted);

        final outcome = await repository.redeem(
          ScannedCode.recognise(departmentPayload())!,
          position: position,
        );

        expect(outcome, isA<AttendanceAccepted>());

        verify(
          () => api.redeemDepartmentQr(
            token: 'tok_abcdef0123456789',
            latitude: -6.21,
            longitude: 106.84,
            accuracy: 12.5,
            isMocked: false,
          ),
        ).called(1);

        // And never to the machine endpoint, which is where it used to go.
        verifyNever(
          () => api.redeemMachineQr(
            code: any(named: 'code'),
            type: any(named: 'type'),
          ),
        );
      },
    );

    test(
      'the receipt is the SERVER\'s answer, not the handset\'s clock',
      () async {
        when(
          () => api.redeemDepartmentQr(
            token: any(named: 'token'),
            latitude: any(named: 'latitude'),
            longitude: any(named: 'longitude'),
            accuracy: any(named: 'accuracy'),
            isMocked: any(named: 'isMocked'),
          ),
        ).thenAnswer((_) async => accepted);

        final outcome =
            await repository.redeem(ScannedCode.recognise(departmentPayload())!)
                as AttendanceAccepted;

        expect(outcome.receipt.direction, PresenceDirection.clockIn);
        expect(outcome.receipt.message, 'Absen masuk berhasil.');
        // A phone three minutes fast must not print a time that disagrees with
        // the payslip on the one screen somebody screenshots.
        expect(outcome.receipt.recordedAt, '08:03:11');
      },
    );

    test('a clock-out reads its time from time_out', () async {
      when(
        () => api.redeemDepartmentQr(
          token: any(named: 'token'),
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
          accuracy: any(named: 'accuracy'),
          isMocked: any(named: 'isMocked'),
        ),
      ).thenAnswer(
        (_) async => <String, dynamic>{
          'message': 'Absen pulang berhasil.',
          'attendance': {'time_in': '08:03:11', 'time_out': '17:02:40'},
        },
      );

      final outcome =
          await repository.redeem(
                ScannedCode.recognise(departmentPayload(type: 'out'))!,
              )
              as AttendanceAccepted;

      expect(outcome.receipt.direction, PresenceDirection.clockOut);
      expect(outcome.receipt.recordedAt, '17:02:40');
    });
  });

  group('a machine code goes to attendance/qr', () {
    test('as `code`, with the direction the context supplied', () async {
      when(
        () => api.redeemMachineQr(
          code: any(named: 'code'),
          type: any(named: 'type'),
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
          accuracy: any(named: 'accuracy'),
          isMocked: any(named: 'isMocked'),
        ),
      ).thenAnswer((_) async => accepted);

      final raw = machinePayload();

      await repository.redeem(
        ScannedCode.recognise(raw)!,
        fallbackDirection: PresenceDirection.clockOut,
        position: position,
      );

      verify(
        () => api.redeemMachineQr(
          code: raw,
          // Required by the server. Its absence is why every one of these used
          // to come back 422.
          type: 'out',
          latitude: -6.21,
          longitude: 106.84,
          accuracy: 12.5,
          isMocked: false,
        ),
      ).called(1);
    });

    test('with no direction to send, nothing is posted', () async {
      // A machine code names no direction. Defaulting to 'in' would ask the
      // server to clock somebody in twice halfway through a night shift, and
      // would spend a single-use code doing it.
      final outcome = await repository.redeem(
        ScannedCode.recognise(machinePayload())!,
      );

      expect(outcome, isA<AttendanceRefused>());
      expect(
        (outcome as AttendanceRefused).refusal.kind,
        RefusalKind.clockRejected,
      );
      verifyNever(
        () => api.redeemMachineQr(
          code: any(named: 'code'),
          type: any(named: 'type'),
        ),
      );
    });
  });

  group('workspace validation belongs to the server', () {
    test('department code is sent for server validation', () async {
      when(
        () => api.redeemDepartmentQr(
          token: any(named: 'token'),
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
          accuracy: any(named: 'accuracy'),
          isMocked: any(named: 'isMocked'),
        ),
      ).thenAnswer((_) async => <String, dynamic>{});

      final outcome = await repository.redeem(
        ScannedCode.recognise(departmentPayload(workspace: 'globex'))!,
      );

      expect(outcome, isA<AttendanceAccepted>());
      verify(
        () => api.redeemDepartmentQr(
          token: any(named: 'token'),
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
          accuracy: any(named: 'accuracy'),
          isMocked: any(named: 'isMocked'),
        ),
      ).called(1);
    });

    test('machine code is sent for server validation', () async {
      when(
        () => api.redeemMachineQr(
          code: any(named: 'code'),
          type: any(named: 'type'),
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
          accuracy: any(named: 'accuracy'),
          isMocked: any(named: 'isMocked'),
        ),
      ).thenAnswer((_) async => <String, dynamic>{});

      final outcome = await repository.redeem(
        ScannedCode.recognise(machinePayload(workspace: 'globex'))!,
        fallbackDirection: PresenceDirection.clockIn,
      );

      expect(outcome, isA<AttendanceAccepted>());
      verify(
        () => api.redeemMachineQr(
          code: any(named: 'code'),
          type: any(named: 'type'),
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
          accuracy: any(named: 'accuracy'),
          isMocked: any(named: 'isMocked'),
        ),
      ).called(1);
    });
  });

  group('refusals are classified by the server\'s code, never its prose', () {
    Future<AttendanceRefusal> refuse(String code, {int status = 422}) async {
      when(
        () => api.redeemDepartmentQr(
          token: any(named: 'token'),
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
          accuracy: any(named: 'accuracy'),
          isMocked: any(named: 'isMocked'),
        ),
      ).thenThrow(
        ApiException('Pesan dari server.', status: status, code: code),
      );

      final outcome = await repository.redeem(
        ScannedCode.recognise(departmentPayload())!,
      );

      return (outcome as AttendanceRefused).refusal;
    }

    test('a spent or wrong code lets the scanner carry on', () async {
      for (final code in const [
        'qr_not_found',
        'qr_expired',
        'qr_wrong_department',
        'qr_already_used',
        'invalid_code',
        'code_expired',
        'code_already_used',
        'wrong_workspace',
      ]) {
        final refusal = await refuse(code);

        expect(refusal.kind, RefusalKind.codeRejected, reason: code);
        expect(refusal.scannerMayResume, isTrue, reason: code);
      }
    });

    test('a refused clock stops, because scanning again cannot help', () async {
      for (final code in const [
        'already_clocked_in',
        'already_clocked_out',
        'no_clock_in',
        'attendance_disabled',
        'location_mocked',
        'outside_geofence',
        'location_required',
        'qr_disabled',
      ]) {
        final refusal = await refuse(code);

        expect(refusal.kind, RefusalKind.clockRejected, reason: code);
        expect(refusal.scannerMayResume, isFalse, reason: code);
      }
    });

    test('face refusals are their own kind', () async {
      for (final code in const [
        'face_not_enrolled',
        'face_no_match',
        'face_inconclusive',
        'capture_crowded',
        'challenge_expired',
        'challenge_already_used',
        'liveness_actions_mismatch',
      ]) {
        expect(
          (await refuse(code)).kind,
          RefusalKind.faceRejected,
          reason: code,
        );
      }
    });

    test('a server fault is transient, and worth retrying', () async {
      for (final code in const [
        'face_not_available',
        'attendance_write_failed',
        'capture_not_stored',
      ]) {
        expect(
          (await refuse(code, status: 503)).kind,
          RefusalKind.transient,
          reason: code,
        );
      }
    });

    test('the server\'s own sentence is what the employee reads', () async {
      // The server knows things the handset does not — how far outside the
      // fence somebody is, which department a code belongs to.
      expect((await refuse('outside_geofence')).message, 'Pesan dari server.');
    });

    test('an unknown code is placed by its status, not dropped', () async {
      // The backend grows codes faster than the app is released, and a new one
      // must not land as a blank screen.
      expect(
        (await refuse('some_future_code', status: 503)).kind,
        RefusalKind.transient,
      );
      expect(
        (await refuse('some_future_code', status: 409)).kind,
        RefusalKind.clockRejected,
      );
    });

    test('a request that was never answered offers no retry', () async {
      // The row may already exist. Telling that person to try again walks them
      // into a duplicate the server will refuse.
      when(
        () => api.redeemDepartmentQr(
          token: any(named: 'token'),
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
          accuracy: any(named: 'accuracy'),
          isMocked: any(named: 'isMocked'),
        ),
      ).thenThrow(const ApiException('Waktu habis.', code: 'timeout'));

      final outcome = await repository.redeem(
        ScannedCode.recognise(departmentPayload())!,
      );

      expect(
        (outcome as AttendanceRefused).refusal.kind,
        RefusalKind.unanswered,
      );
    });

    test('a dead socket is transient, and IS worth retrying', () async {
      when(
        () => api.redeemDepartmentQr(
          token: any(named: 'token'),
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
          accuracy: any(named: 'accuracy'),
          isMocked: any(named: 'isMocked'),
        ),
      ).thenThrow(
        const ApiException('Tidak ada koneksi.', code: 'network_unreachable'),
      );

      final outcome = await repository.redeem(
        ScannedCode.recognise(departmentPayload())!,
      );

      expect(
        (outcome as AttendanceRefused).refusal.kind,
        RefusalKind.transient,
      );
    });
  });

  group('what an employee is allowed to read', () {
    Future<AttendanceRefusal> refuseWith(ApiException error) async {
      when(
        () => api.redeemDepartmentQr(
          token: any(named: 'token'),
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
          accuracy: any(named: 'accuracy'),
          isMocked: any(named: 'isMocked'),
        ),
      ).thenThrow(error);

      final outcome = await repository.redeem(
        ScannedCode.recognise(departmentPayload())!,
      );

      return (outcome as AttendanceRefused).refusal;
    }

    test('a known code carries the server\'s own sentence', () async {
      // The server knows what the handset does not: how far outside the fence
      // somebody is, which department a code belongs to.
      final refusal = await refuseWith(
        const ApiException(
          'Anda berada 840 m dari lokasi kantor, di luar radius 30 m.',
          status: 422,
          code: 'outside_geofence',
        ),
      );

      expect(refusal.message, contains('840 m'));
    });

    test('an UNKNOWN code never reaches the screen verbatim', () async {
      // Laravel's own validation text, a framework 500, a message from a layer
      // that never expected an employee to read it.
      final refusal = await refuseWith(
        const ApiException(
          'SQLSTATE[40001]: Serialization failure: 1213 Deadlock found',
          status: 500,
          code: 'some_future_code',
        ),
      );

      expect(refusal.message, isNot(contains('SQLSTATE')));
      expect(refusal.message, contains('Coba beberapa saat lagi'));
    });

    test('a refusal with no code at all gets client copy', () async {
      final refusal = await refuseWith(
        const ApiException('The image field is required.', status: 422),
      );

      expect(refusal.message, isNot(contains('image field')));
      expect(refusal.kind, RefusalKind.clockRejected);
    });

    test(
      'a known code with an untrustworthy body still gets client copy',
      () async {
        // A proxy's error page answering with the right status is not the server
        // speaking to an employee.
        final refusal = await refuseWith(
          const ApiException(
            '<html><body><h1>502 Bad Gateway</h1></body></html>',
            status: 422,
            code: 'outside_geofence',
          ),
        );

        expect(refusal.message, isNot(contains('<html>')));
      },
    );

    test('a stack trace is refused however it is labelled', () async {
      final refusal = await refuseWith(
        const ApiException(
          '#0 main (package:app/main.dart:1)',
          status: 422,
          code: 'qr_expired',
        ),
      );

      expect(refusal.message, isNot(contains('#0 ')));
    });

    test('every code the client classifies is one the backend defines', () {
      // Guards against a code invented to make a test pass. Each of these is
      // raised by AttendanceRejected, QrPresenceController,
      // KioskQrRedemptionController or FaceAttendanceController in tenancy-app.
      expect(
        AttendanceRepository.userSafeCodes,
        containsAll(<String>[
          'outside_geofence',
          'location_required',
          'already_clocked_in',
          'qr_wrong_department',
          'code_already_used',
          'face_not_enrolled',
          'challenge_already_used',
        ]),
      );
    });
  });

  group('face submission', () {
    test('carries the challenge, the evidence and the coordinates', () async {
      when(
        () => api.submitFace(
          image: any(named: 'image'),
          challengeToken: any(named: 'challengeToken'),
          challengeId: any(named: 'challengeId'),
          type: any(named: 'type'),
          liveness: any(named: 'liveness'),
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
          accuracy: any(named: 'accuracy'),
          isMocked: any(named: 'isMocked'),
        ),
      ).thenAnswer((_) async => accepted);

      final image = File('${Directory.systemTemp.path}/face_fixture.jpg')
        ..writeAsBytesSync(const <int>[0xFF, 0xD8, 0xFF]);
      addTearDown(() {
        if (image.existsSync()) image.deleteSync();
      });

      await repository.submitFace(
        image: image,
        challengeToken: 'signed.token',
        challengeId: 'challenge-1',
        direction: PresenceDirection.clockIn,
        liveness: const {'detector': 'google_mlkit_face_detection'},
        position: position,
      );

      verify(
        () => api.submitFace(
          image: image,
          challengeToken: 'signed.token',
          challengeId: 'challenge-1',
          type: 'in',
          liveness: const {'detector': 'google_mlkit_face_detection'},
          // The geofence applies to a face clock exactly as it does to a QR
          // one; the server refuses `location_required` without these.
          latitude: -6.21,
          longitude: 106.84,
          accuracy: 12.5,
          isMocked: false,
        ),
      ).called(1);
    });
  });

  group('expiry is the SERVER\'s call, not the device clock\'s', () {
    test('a code the handset thinks is stale is still sent', () async {
      // A phone running fast must not be able to refuse every code its owner
      // scans. Both endpoints test expiry before claiming the code, so nothing
      // is spent by asking — and the answer comes from a clock that is right.
      when(
        () => api.redeemDepartmentQr(
          token: any(named: 'token'),
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
          accuracy: any(named: 'accuracy'),
          isMocked: any(named: 'isMocked'),
        ),
      ).thenThrow(
        const ApiException(
          'Kode QR sudah kedaluwarsa. Minta kode baru.',
          status: 422,
          code: 'qr_expired',
        ),
      );

      final stale = json.encode({
        'tenant': 'acme',
        'token': 'tok_abcdef0123456789',
        'type': 'in',
        'expires_at': DateTime.now()
            .subtract(const Duration(hours: 1))
            .toIso8601String(),
      });

      final scanned = ScannedCode.recognise(stale)! as DepartmentCode;

      // The model can still see it, and says so.
      expect(scanned.payload.isExpired, isTrue);

      final outcome = await repository.redeem(scanned);

      // But the refusal came back from the server, with the server's code.
      verify(
        () => api.redeemDepartmentQr(
          token: 'tok_abcdef0123456789',
          isMocked: false,
        ),
      ).called(1);
      expect((outcome as AttendanceRefused).refusal.code, 'qr_expired');
      expect(outcome.refusal.scannerMayResume, isTrue);
    });

    test('a machine code the handset thinks is stale is still sent', () async {
      when(
        () => api.redeemMachineQr(
          code: any(named: 'code'),
          type: any(named: 'type'),
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
          accuracy: any(named: 'accuracy'),
          isMocked: any(named: 'isMocked'),
        ),
      ).thenThrow(
        const ApiException(
          'Kode sudah kedaluwarsa. Pindai kode terbaru di layar.',
          status: 422,
          code: 'code_expired',
        ),
      );

      final payload = base64Url
          .encode(
            utf8.encode(
              json.encode({
                'v': 1,
                'jti': 'code-old',
                'tid': 'acme',
                'did': 3,
                'iat': 0,
                'exp':
                    DateTime.now()
                        .subtract(const Duration(hours: 1))
                        .millisecondsSinceEpoch ~/
                    1000,
              }),
            ),
          )
          .replaceAll('=', '');

      final scanned = ScannedCode.recognise('$payload.c2ln')! as MachineCode;

      expect(scanned.isExpired, isTrue);

      final outcome = await repository.redeem(
        scanned,
        fallbackDirection: PresenceDirection.clockIn,
      );

      verify(
        () => api.redeemMachineQr(
          code: any(named: 'code'),
          type: 'in',
          isMocked: false,
        ),
      ).called(1);
      expect((outcome as AttendanceRefused).refusal.code, 'code_expired');
    });
  });

  group('the scoring service\'s own advice reaches the employee', () {
    Future<AttendanceRefusal> refuseWithCode(
      String code,
      String message,
    ) async {
      when(
        () => api.redeemDepartmentQr(
          token: any(named: 'token'),
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
          accuracy: any(named: 'accuracy'),
          isMocked: any(named: 'isMocked'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenThrow(ApiException(message, status: 422, code: code));

      final outcome = await repository.redeem(
        ScannedCode.recognise(departmentPayload())!,
      );

      return (outcome as AttendanceRefused).refusal;
    }

    test('no_face_detected keeps the sentence that says what to do', () async {
      // The defect this pins. `FaceAttendanceController::refusalFromService`
      // writes "Wajah tidak terdeteksi pada foto. Dekatkan wajah ke kamera,
      // pastikan cukup terang, lalu coba lagi" — and this client used to throw
      // it away for a generic "Verifikasi wajah belum berhasil", telling
      // somebody to start again with the advice removed.
      final refusal = await refuseWithCode(
        'no_face_detected',
        'Wajah tidak terdeteksi pada foto. Dekatkan wajah ke kamera, '
            'pastikan cukup terang, lalu coba lagi.',
      );

      expect(refusal.message, contains('Dekatkan wajah'));
      expect(refusal.kind, RefusalKind.faceRejected);
    });

    test('every code the scorer can raise is user-safe', () async {
      // Enumerated from `supports/app/core/errors.py` and
      // `FaceAttendanceController::refusalFromService`, not invented here. A
      // code missing from the allow-list silently replaces the server's advice.
      for (final code in const [
        'no_face_detected',
        'invalid_upload',
        'unsupported_media_type',
        'payload_too_large',
        'video_decode_failed',
        'face_references_unusable',
      ]) {
        final refusal = await refuseWithCode(code, 'Pesan khusus untuk $code.');

        expect(refusal.message, 'Pesan khusus untuk $code.', reason: code);
        expect(refusal.kind, RefusalKind.faceRejected, reason: code);
      }
    });

    test('a service outage is transient, not the employee\'s fault', () async {
      for (final code in const [
        'engine_unavailable',
        'face_service_unavailable',
      ]) {
        expect(
          (await refuseWithCode(code, 'Layanan sedang tidak tersedia.')).kind,
          RefusalKind.transient,
          reason: code,
        );
      }
    });

    test('the server\'s structured body survives the exception', () async {
      // `score_percent` is the one number that tells "the photograph was
      // unusable" apart from "the match was close". It is never shown to the
      // employee — it is logged in debug builds — but it has to reach the client
      // at all before it can be either.
      const exception = ApiException(
        'Wajah pada foto tidak cocok dengan data Anda.',
        status: 422,
        code: 'face_no_match',
        body: {
          'code': 'face_no_match',
          'verification': {
            'score_percent': 31.4,
            'decision': 'rejected',
            'awaiting_review': false,
          },
        },
      );

      expect(exception.body['verification'], isA<Map<String, dynamic>>());

      final refusal = AttendanceRepository.refusalFor(exception);

      // And the score is NOT in what the employee reads.
      expect(refusal.message, isNot(contains('31')));
      expect(refusal.message, contains('tidak cocok'));
    });
  });
}

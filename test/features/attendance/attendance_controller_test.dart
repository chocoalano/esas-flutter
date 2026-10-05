import 'dart:convert';
import 'dart:async';

import 'package:esas/core/network/api_exception.dart';
import 'package:esas/core/services/camera_permission_service.dart';
import 'package:esas/core/services/location_service.dart';
import 'package:esas/core/storage/local_storage.dart';
import 'package:esas/features/attendance/data/models/attendance_context.dart';
import 'package:esas/features/attendance/data/models/scanned_code.dart';
import 'package:esas/features/attendance/data/repositories/attendance_repository.dart';
import 'package:esas/features/attendance/presentation/controllers/attendance_controller.dart';
import 'package:esas/features/auth/data/models/auth_user.dart';
import 'package:esas/features/auth/data/repositories/session_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepository extends Mock implements AttendanceRepository {}

class _MockLocation extends Mock implements LocationService {}

class _MockSession extends Mock implements SessionRepository {}

class _MockStorage extends Mock implements LocalStorage {}

class _MockPermission extends Mock implements CameraPermissionService {}

/// A scanner that records what it was asked to do and touches no platform.
///
/// The real `MobileScannerController` reaches a method channel the moment
/// anything subscribes to it, which is why the controller takes a factory: a
/// class that could not be substituted here could not be tested at all, and the
/// camera lifecycle is the half of this screen most worth pinning.
class _FakeScanner extends ValueNotifier<MobileScannerState>
    implements MobileScannerController {
  _FakeScanner() : super(const MobileScannerState.uninitialized());

  int starts = 0;
  int pauses = 0;
  int stops = 0;
  bool disposed = false;

  @override
  Future<void> start({CameraFacing? cameraDirection}) async {
    starts++;
    value = value.copyWith(isInitialized: true, isRunning: true);
  }

  @override
  Future<void> stop() async {
    stops++;
    value = value.copyWith(isRunning: false);
  }

  @override
  Future<void> pause() async {
    pauses++;
    value = value.copyWith(isRunning: false);
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    super.dispose();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockRepository repository;
  late _MockLocation location;
  late _MockSession session;
  late _MockStorage storage;
  late _MockPermission permission;
  late _FakeScanner scanner;

  String departmentPayload({String type = 'in'}) => json.encode({
    'tenant': 'acme',
    'token': 'tok_1',
    'type': type,
    'expires_at': DateTime.now()
        .add(const Duration(minutes: 15))
        .toIso8601String(),
  });

  BarcodeCapture capture(String raw) =>
      BarcodeCapture(barcodes: [Barcode(rawValue: raw)]);

  AttendanceContext contextOf({
    bool? attendanceEnabled = true,
    bool? qrEnabled,
    bool? faceEnabled,
    bool faceEnrolled = false,
    String? nextPresence = 'in',
    bool locationRequired = false,
    double? radius,
  }) => AttendanceContext(
    attendanceEnabled: attendanceEnabled,
    qrEnabled: qrEnabled,
    faceEnabled: faceEnabled,
    faceEnrolled: faceEnrolled,
    nextPresence: PresenceDirection.parse(nextPresence),
    geofence: AttendanceGeofence(
      required_: locationRequired,
      latitude: locationRequired ? -6.2 : null,
      longitude: locationRequired ? 106.8 : null,
      radiusMetres: radius,
    ),
  );

  AttendanceController build() => AttendanceController(
    repository: repository,
    location: location,
    session: session,
    storage: storage,
    camera: permission,
    scannerFactory: () => scanner,
  );

  /// Bring a controller up the way GetX does, and let `loadContext` finish.
  Future<AttendanceController> boot() async {
    final controller = build()..onInit();

    await pumpEventQueue();

    return controller;
  }

  setUpAll(() {
    registerFallbackValue(
      DepartmentCode(
        // Any ScannedCode will do; mocktail only needs a type to fall back to.
        (ScannedCode.recognise(
                  json.encode({'tenant': 'acme', 'token': 't', 'type': 'in'}),
                )!
                as DepartmentCode)
            .payload,
      ),
    );
  });

  setUp(() {
    repository = _MockRepository();
    location = _MockLocation();
    session = _MockSession();
    storage = _MockStorage();
    permission = _MockPermission();
    scanner = _FakeScanner();

    when(() => repository.context()).thenAnswer((_) async => contextOf());
    when(
      () => permission.status(),
    ).thenAnswer((_) async => CameraPermission.granted);
    when(
      () => permission.request(),
    ).thenAnswer((_) async => CameraPermission.granted);
    when(() => storage.read<bool>(any())).thenReturn(null);
    when(() => session.user).thenReturn(null);
    // Every screen now asks for a fix — required or not — because where a clock
    // happened is part of the record. A test that says nothing about location
    // gets a refusal, which is silent when no fence applies.
    when(() => location.currentPosition()).thenAnswer(
      (_) async => const LocationRejected(LocationFailure.unavailable),
    );
  });

  group('method availability comes from the server, never from the UI', () {
    test('an unenrolled employee cannot select the face method', () async {
      final controller = await boot();

      expect(controller.faceStatus, MethodStatus.notEnrolled);
      expect(controller.qrStatus, MethodStatus.available);

      await controller.switchTo(AttendanceMethod.face);

      // Refused, rather than switching to a screen that can only apologise.
      expect(controller.mode.value, AttendanceMethod.qr);
    });

    test('an enrolled employee can', () async {
      when(
        () => repository.context(),
      ).thenAnswer((_) async => contextOf(faceEnrolled: true));

      final controller = await boot();

      expect(controller.faceStatus, MethodStatus.available);

      await controller.switchTo(AttendanceMethod.face);

      expect(controller.mode.value, AttendanceMethod.face);
    });

    test('attendance_enabled: false withholds both methods', () async {
      when(() => repository.context()).thenAnswer(
        (_) async => contextOf(attendanceEnabled: false, faceEnrolled: true),
      );

      final controller = await boot();

      expect(controller.qrStatus, MethodStatus.accountDisabled);
      expect(controller.faceStatus, MethodStatus.accountDisabled);
      expect(controller.canCapture, isFalse);
    });

    test(
      'a server that never sent the flag is not forbidding anybody',
      () async {
        when(
          () => repository.context(),
        ).thenAnswer((_) async => contextOf(attendanceEnabled: null));

        final controller = await boot();

        expect(controller.qrStatus, MethodStatus.available);
      },
    );

    test('face mode is dropped if the context says it is not enrolled', () async {
      // Reached by switching first and reloading after — an enrolment can lapse
      // between two visits, and the screen must not stay on a mode the server
      // has just withdrawn.
      when(
        () => repository.context(),
      ).thenAnswer((_) async => contextOf(faceEnrolled: true));

      final controller = await boot();
      await controller.switchTo(AttendanceMethod.face);
      expect(controller.mode.value, AttendanceMethod.face);

      when(() => repository.context()).thenAnswer((_) async => contextOf());
      await controller.loadContext();

      expect(controller.mode.value, AttendanceMethod.qr);
    });
  });

  group('the intent line reads from what the server already sent', () {
    test('names the clock that is owed', () async {
      final controller = await boot();

      expect(controller.intentLine, 'Absen masuk');
    });

    test('adds the shift when the roster has one', () async {
      when(() => repository.context()).thenAnswer(
        (_) async => AttendanceContext(
          attendanceEnabled: true,
          nextPresence: PresenceDirection.clockOut,
          shift: const AttendanceShift(
            name: 'Shift Pagi',
            start: '08:00:00',
            end: '17:00:00',
          ),
        ),
      );

      final controller = await boot();

      expect(controller.intentLine, 'Absen pulang · Shift Pagi 08:00–17:00');
    });

    test('says nothing at all when the server said nothing', () async {
      when(
        () => repository.context(),
      ).thenThrow(const ApiException('Tidak ada koneksi.'));

      final controller = build()..onInit();
      await pumpEventQueue();

      // No invented subtitle. The header falls back to "Absensi" alone.
      expect(controller.intentLine, isNull);
    });
  });

  group('location is asked for only where the company checks it', () {
    test(
      'a workspace with no geofence reads a position but is never gated by it',
      () async {
        // The behaviour changed deliberately: the coordinates belong on the
        // attendance record even where the company does not check them. What must
        // not change is that nothing here can block a clock.
        final controller = await boot();
        await pumpEventQueue();

        expect(controller.locationStatus.value, LocationStatus.notRequired);
        expect(controller.canCapture, isTrue);
        expect(controller.locationBlock.value, isNull);
        verify(() => location.currentPosition()).called(1);
      },
    );

    test('a geofenced workspace inside the radius is ready', () async {
      when(
        () => repository.context(),
      ).thenAnswer((_) async => contextOf(locationRequired: true, radius: 50));
      when(() => location.currentPosition()).thenAnswer(
        (_) async => LocationSuccess(
          Position(
            latitude: -6.2,
            longitude: 106.8,
            timestamp: DateTime.now(),
            accuracy: 8,
            altitude: 0,
            altitudeAccuracy: 0,
            heading: 0,
            headingAccuracy: 0,
            speed: 0,
            speedAccuracy: 0,
          ),
        ),
      );
      when(
        () => location.distanceBetween(
          fromLatitude: any(named: 'fromLatitude'),
          fromLongitude: any(named: 'fromLongitude'),
          toLatitude: any(named: 'toLatitude'),
          toLongitude: any(named: 'toLongitude'),
        ),
      ).thenReturn(12);

      final controller = await boot();

      expect(controller.locationStatus.value, LocationStatus.ready);
      expect(controller.canCapture, isTrue);
    });

    test('outside the radius warns, and lets the server decide', () async {
      when(
        () => repository.context(),
      ).thenAnswer((_) async => contextOf(locationRequired: true, radius: 30));
      when(() => location.currentPosition()).thenAnswer(
        (_) async => LocationSuccess(
          Position(
            latitude: -6.3,
            longitude: 106.9,
            timestamp: DateTime.now(),
            accuracy: 8,
            altitude: 0,
            altitudeAccuracy: 0,
            heading: 0,
            headingAccuracy: 0,
            speed: 0,
            speedAccuracy: 0,
          ),
        ),
      );
      when(
        () => location.distanceBetween(
          fromLatitude: any(named: 'fromLatitude'),
          fromLongitude: any(named: 'fromLongitude'),
          toLatitude: any(named: 'toLatitude'),
          toLongitude: any(named: 'toLongitude'),
        ),
      ).thenReturn(840);

      final controller = await boot();

      // The handset says what it thinks and stops there.
      //
      // It used to refuse the capture outright, on the reasoning that a
      // single-use QR should not be spent on a clock that would be rejected.
      // But the server widens the radius by an accuracy allowance this app is
      // never sent, so the local test is strictly harsher than the decision it
      // was predicting — and the case it got wrong was somebody standing
      // legitimately at the edge of the fence, locked out with no way to reach
      // the server that would have said yes.
      expect(controller.locationStatus.value, LocationStatus.outsideFence);
      expect(controller.distanceMeters.value, 840);
      expect(controller.canCapture, isTrue);
    });

    test('each refusal keeps its own cause', () async {
      for (final (failure, expected) in <(LocationFailure, LocationBlock)>[
        (LocationFailure.serviceDisabled, LocationBlock.gpsOff),
        (LocationFailure.permissionDenied, LocationBlock.permissionDenied),
        (
          LocationFailure.permissionDeniedForever,
          LocationBlock.permissionPermanent,
        ),
        (LocationFailure.mocked, LocationBlock.mocked),
        (LocationFailure.unavailable, LocationBlock.unreadable),
      ]) {
        when(() => repository.context()).thenAnswer(
          (_) async => contextOf(locationRequired: true, radius: 30),
        );
        when(
          () => location.currentPosition(),
        ).thenAnswer((_) async => LocationRejected(failure));

        final controller = await boot();

        expect(controller.locationBlock.value, expected, reason: '$failure');
      }
    });
  });

  group('camera permission — the state decides the button', () {
    test('never asked reads as askable, not as permanently denied', () async {
      when(
        () => permission.status(),
      ).thenAnswer((_) async => CameraPermission.askable);

      final controller = await boot();

      expect(controller.scannerState.value, ScannerState.permissionAskable);
      expect(scanner.starts, 0);
    });

    test('a permanent denial is told apart from a first refusal', () async {
      when(
        () => permission.status(),
      ).thenAnswer((_) async => CameraPermission.permanentlyDenied);

      final controller = await boot();

      expect(controller.scannerState.value, ScannerState.permissionPermanent);
    });

    test('a policy restriction is neither of the two', () async {
      when(
        () => permission.status(),
      ).thenAnswer((_) async => CameraPermission.restricted);

      final controller = await boot();

      expect(controller.scannerState.value, ScannerState.permissionRestricted);
    });

    test('granting after a prompt starts the camera', () async {
      when(
        () => permission.status(),
      ).thenAnswer((_) async => CameraPermission.askable);

      final controller = await boot();
      expect(scanner.starts, 0);

      when(
        () => permission.status(),
      ).thenAnswer((_) async => CameraPermission.granted);
      await controller.requestCameraPermission();
      await pumpEventQueue();

      expect(scanner.starts, 1);
      expect(controller.scannerState.value, ScannerState.ready);
    });

    test('a device with no camera does not blame a permission', () async {
      final controller = await boot();

      controller.reportScannerFailure(
        const MobileScannerException(
          errorCode: MobileScannerErrorCode.unsupported,
        ),
      );

      // The simulator case, and the one the old screen got most wrong: it told
      // somebody to check an izin they had already granted.
      expect(controller.scannerState.value, ScannerState.unsupported);
    });

    test('a generic failure is a failure, not a permission problem', () async {
      final controller = await boot();

      controller.reportScannerFailure(
        const MobileScannerException(
          errorCode: MobileScannerErrorCode.genericError,
        ),
      );

      expect(controller.scannerState.value, ScannerState.failed);
    });
  });

  group('camera lifecycle', () {
    test('the camera opens only for the QR method', () async {
      when(
        () => repository.context(),
      ).thenAnswer((_) async => contextOf(faceEnrolled: true));

      final controller = await boot();
      expect(scanner.starts, 1);

      await controller.switchTo(AttendanceMethod.face);

      // Privacy and battery: the rear camera is handed back the moment the QR
      // panel is no longer the one on screen.
      expect(scanner.stops, greaterThanOrEqualTo(1));
      expect(scanner.value.isRunning, isFalse);

      await controller.switchTo(AttendanceMethod.qr);
      await pumpEventQueue();

      expect(scanner.starts, 2);
    });

    test('backgrounding stops it; returning starts it again', () async {
      final controller = await boot();
      expect(scanner.starts, 1);

      controller.didChangeAppLifecycleState(AppLifecycleState.paused);
      await pumpEventQueue();
      expect(scanner.value.isRunning, isFalse);

      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await pumpEventQueue();

      expect(scanner.starts, 2);
      expect(scanner.value.isRunning, isTrue);
    });

    test('repeated retries never open a second session', () async {
      final controller = await boot();

      for (var attempt = 0; attempt < 5; attempt++) {
        await controller.retryCamera();
        await pumpEventQueue();
      }

      // One controller for the life of the screen, and `start` is a no-op while
      // one is already starting — the leak this is guarding is a handset that
      // holds five camera sessions after five taps of "Coba lagi".
      expect(scanner.disposed, isFalse);
      expect(controller.scannerState.value, ScannerState.ready);
    });

    test('closing the screen hands the camera back', () async {
      final controller = await boot();

      controller.onClose();
      await pumpEventQueue();

      expect(scanner.stops, greaterThanOrEqualTo(1));
      expect(scanner.value.isRunning, isFalse);
      expect(scanner.disposed, isTrue);
    });

    test('does not reopen after the screen starts closing', () async {
      final controller = await boot();

      controller.onClose();
      await controller.loadContext();
      await pumpEventQueue();

      expect(scanner.starts, 1);
      expect(scanner.disposed, isTrue);
    });
  });

  group('scanning', () {
    test('a code that is not ours does not stop the scanner', () async {
      final controller = await boot();

      await controller.onDetect(capture('https://example.com'));

      expect(controller.stage.value, CaptureStage.idle);
      expect(controller.refusal.value?.kind, RefusalKind.unrecognised);
      verifyNever(
        () => repository.redeem(
          any(),
          fallbackDirection: any(named: 'fallbackDirection'),
          position: any(named: 'position'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      );
    });

    test('the same code in ten frames is submitted ONCE', () async {
      // The camera delivers the same code ten times a second. Without a guard
      // set before the first await, each delivery spends a single-use code and
      // every one after the first answers `code_already_used`.
      final completer = <Future<AttendanceOutcome>>[];

      when(
        () => repository.redeem(
          any(),
          fallbackDirection: any(named: 'fallbackDirection'),
          position: any(named: 'position'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer((_) {
        final future = Future<AttendanceOutcome>.delayed(
          const Duration(milliseconds: 30),
          () => const AttendanceAccepted(
            AttendanceReceipt(
              direction: PresenceDirection.clockIn,
              message: 'Absen masuk berhasil.',
              recordedAt: '08:03:11',
            ),
          ),
        );

        completer.add(future);

        return future;
      });

      final controller = await boot();
      final raw = departmentPayload();

      // Fired without awaiting, exactly as the camera fires them.
      for (var frame = 0; frame < 10; frame++) {
        unawaited(controller.onDetect(capture(raw)));
      }

      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(completer, hasLength(1));
      verify(
        () => repository.redeem(
          any(),
          fallbackDirection: any(named: 'fallbackDirection'),
          position: any(named: 'position'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).called(1);
    });

    test('the scanner is paused before the request goes out', () async {
      when(
        () => repository.redeem(
          any(),
          fallbackDirection: any(named: 'fallbackDirection'),
          position: any(named: 'position'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer(
        (_) async => const AttendanceAccepted(
          AttendanceReceipt(
            direction: PresenceDirection.clockIn,
            message: 'Absen masuk berhasil.',
          ),
        ),
      );

      final controller = await boot();
      final before = scanner.pauses;

      await controller.onDetect(capture(departmentPayload()));

      expect(scanner.pauses, greaterThan(before));
    });

    test('success is the server\'s answer, and it persists', () async {
      when(
        () => repository.redeem(
          any(),
          fallbackDirection: any(named: 'fallbackDirection'),
          position: any(named: 'position'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer(
        (_) async => const AttendanceAccepted(
          AttendanceReceipt(
            direction: PresenceDirection.clockIn,
            message: 'Absen masuk berhasil.',
            recordedAt: '08:03:11',
          ),
        ),
      );

      final controller = await boot();

      await controller.onDetect(capture(departmentPayload()));

      expect(controller.stage.value, CaptureStage.succeeded);
      expect(controller.receipt.value?.recordedAt, '08:03:11');
      // It stays until the employee closes it. A three-second toast fired
      // alongside a route transition is a shorter acknowledgement than the time
      // it takes somebody to lower their phone.
      expect(controller.receipt.value, isNotNull);
    });

    test('a rejected code waits for an explicit retry', () async {
      when(
        () => repository.redeem(
          any(),
          fallbackDirection: any(named: 'fallbackDirection'),
          position: any(named: 'position'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer(
        (_) async => const AttendanceRefused(
          AttendanceRefusal(
            kind: RefusalKind.codeRejected,
            message: 'Kode QR sudah kedaluwarsa. Minta kode baru.',
            code: 'qr_expired',
          ),
        ),
      );

      final controller = await boot();

      await controller.onDetect(capture(departmentPayload()));
      await pumpEventQueue();

      expect(controller.stage.value, CaptureStage.refused);
      expect(controller.refusal.value?.code, 'qr_expired');
      expect(scanner.value.isRunning, isFalse);

      await controller.retryCapture();

      expect(controller.stage.value, CaptureStage.idle);
      expect(scanner.value.isRunning, isTrue);
    });

    test(
      'a rejected CLOCK stops, because scanning again cannot help',
      () async {
        when(
          () => repository.redeem(
            any(),
            fallbackDirection: any(named: 'fallbackDirection'),
            position: any(named: 'position'),
            idempotencyKey: any(named: 'idempotencyKey'),
          ),
        ).thenAnswer(
          (_) async => const AttendanceRefused(
            AttendanceRefusal(
              kind: RefusalKind.clockRejected,
              message: 'Anda berada 840 m dari lokasi kantor.',
              code: 'outside_geofence',
            ),
          ),
        );

        final controller = await boot();

        await controller.onDetect(capture(departmentPayload()));

        expect(controller.stage.value, CaptureStage.refused);
        expect(scanner.value.isRunning, isFalse);
      },
    );

    test('nothing is scanned while a submission is in flight', () async {
      when(
        () => repository.redeem(
          any(),
          fallbackDirection: any(named: 'fallbackDirection'),
          position: any(named: 'position'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer(
        (_) async => const AttendanceAccepted(
          AttendanceReceipt(
            direction: PresenceDirection.clockIn,
            message: 'Absen masuk berhasil.',
          ),
        ),
      );

      final controller = await boot();
      await controller.onDetect(capture(departmentPayload()));

      // A receipt is on screen; a code drifting back into frame must not start
      // a second clock.
      await controller.onDetect(capture(departmentPayload()));

      verify(
        () => repository.redeem(
          any(),
          fallbackDirection: any(named: 'fallbackDirection'),
          position: any(named: 'position'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).called(1);
    });
  });

  group('the biometric NOTICE — not a consent record', () {
    test('an unknown employee is shown it, not silently skipped', () async {
      // Falling back to an unscoped key is the bug this guards: one shared
      // handset where the second employee never sees the notice at all.
      when(() => session.user).thenReturn(null);

      final controller = await boot();

      expect(controller.faceNoticeSeen.value, isFalse);
    });

    test('is remembered per employee, per workspace and per version', () async {
      when(() => session.user).thenReturn(AuthUser.fromJson(const {'id': 7}));
      when(() => repository.workspace).thenReturn('acme');
      when(() => storage.read<bool>('face_notice.v1.acme.7')).thenReturn(true);

      final controller = await boot();

      expect(controller.faceNoticeSeen.value, isTrue);
    });

    test('another employee on the same handset sees it again', () async {
      when(() => session.user).thenReturn(AuthUser.fromJson(const {'id': 8}));
      when(() => repository.workspace).thenReturn('acme');
      when(() => storage.read<bool>('face_notice.v1.acme.7')).thenReturn(true);

      final controller = await boot();

      expect(controller.faceNoticeSeen.value, isFalse);
    });

    test('the same id in another workspace is another person', () async {
      when(() => session.user).thenReturn(AuthUser.fromJson(const {'id': 7}));
      when(() => repository.workspace).thenReturn('globex');
      when(() => storage.read<bool>('face_notice.v1.acme.7')).thenReturn(true);

      final controller = await boot();

      expect(controller.faceNoticeSeen.value, isFalse);
    });

    test('new wording is not suppressed by an old acknowledgement', () async {
      when(() => session.user).thenReturn(AuthUser.fromJson(const {'id': 7}));
      when(() => repository.workspace).thenReturn('acme');
      when(() => storage.read<bool>('face_notice.v0.acme.7')).thenReturn(true);

      final controller = await boot();

      expect(AttendanceController.faceNoticeVersion, 1);
      expect(controller.faceNoticeSeen.value, isFalse);
    });
  });
  group('qr_enabled wires the selector without redesigning it', () {
    test('absent leaves QR attemptable — old backend, new app', () async {
      final controller = await boot();

      expect(controller.context.value?.qrEnabled, isNull);
      expect(controller.qrStatus, MethodStatus.available);
    });

    test('false locks QR with its own cause, not an error', () async {
      when(
        () => repository.context(),
      ).thenAnswer((_) async => contextOf(qrEnabled: false));

      final controller = await boot();

      expect(controller.qrStatus, MethodStatus.methodDisabled);
      expect(controller.unavailableStatus, MethodStatus.methodDisabled);
    });

    test('QR off + face enrolled leaves only the face method', () async {
      when(() => repository.context()).thenAnswer(
        (_) async => contextOf(qrEnabled: false, faceEnrolled: true),
      );

      final controller = await boot();

      expect(controller.qrStatus, MethodStatus.methodDisabled);
      expect(controller.faceStatus, MethodStatus.available);

      await controller.switchTo(AttendanceMethod.face);

      expect(controller.mode.value, AttendanceMethod.face);
    });

    test('QR off does not open the camera', () async {
      when(
        () => repository.context(),
      ).thenAnswer((_) async => contextOf(qrEnabled: false));

      await boot();

      // A locked method must not hold the sensor open behind its own
      // explanation.
      expect(scanner.starts, 0);
    });

    test('both off is a truthful dead end, not a broken screen', () async {
      when(
        () => repository.context(),
      ).thenAnswer((_) async => contextOf(qrEnabled: false));

      final controller = await boot();

      expect(controller.qrStatus, MethodStatus.methodDisabled);
      expect(controller.faceStatus, MethodStatus.notEnrolled);
      // Neither segment is selectable, and neither is described as an error.
      expect(controller.statusOf(AttendanceMethod.qr).usable, isFalse);
      expect(controller.statusOf(AttendanceMethod.face).usable, isFalse);
    });

    test('an account that may not clock outranks qr_enabled: true', () async {
      when(() => repository.context()).thenAnswer(
        (_) async => contextOf(attendanceEnabled: false, qrEnabled: true),
      );

      final controller = await boot();

      expect(controller.qrStatus, MethodStatus.accountDisabled);
    });
  });

  group('Idempotency-Key names an ATTEMPT, not a call', () {
    String? keyUsed = '';

    setUp(() => keyUsed = '');

    void answerWith(AttendanceOutcome outcome) {
      when(
        () => repository.redeem(
          any(),
          fallbackDirection: any(named: 'fallbackDirection'),
          position: any(named: 'position'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer((invocation) async {
        keyUsed =
            invocation.namedArguments[const Symbol('idempotencyKey')]
                as String?;

        return outcome;
      });
    }

    const accepted = AttendanceAccepted(
      AttendanceReceipt(
        direction: PresenceDirection.clockIn,
        message: 'Absen masuk berhasil.',
      ),
    );

    test('a scan carries one', () async {
      answerWith(accepted);

      final controller = await boot();
      await controller.onDetect(capture(departmentPayload()));

      expect(keyUsed, isNotNull);
      // 16 random bytes, hex. Nothing derived from the employee, the code or a
      // timestamp — a key is a name, not a fact about anybody.
      expect(keyUsed, matches(RegExp(r'^[0-9a-f]{32}$')));
    });

    test('two separate scans are two attempts, and two keys', () async {
      answerWith(accepted);

      final controller = await boot();

      await controller.onDetect(capture(departmentPayload()));
      final first = keyUsed;

      await controller.retryCapture();
      await controller.onDetect(capture(departmentPayload()));
      final second = keyUsed;

      expect(first, isNotNull);
      expect(second, isNotNull);
      expect(second, isNot(first));
    });

    test(
      'a definitive refusal ends the attempt, so the next scan renames it',
      () async {
        answerWith(
          const AttendanceRefused(
            AttendanceRefusal(
              kind: RefusalKind.codeRejected,
              message: 'Kode QR sudah kedaluwarsa.',
              code: 'qr_expired',
            ),
          ),
        );

        final controller = await boot();

        await controller.onDetect(capture(departmentPayload()));
        final first = keyUsed;

        await controller.retryCapture();
        await controller.onDetect(capture(departmentPayload()));
        final second = keyUsed;

        expect(second, isNot(first));
      },
    );

    test('an answer that never arrived KEEPS the key', () async {
      // Nothing was stored under it — only successful answers are remembered —
      // so the same attempt can still be named by it. This is what makes a safe
      // retry affordance possible later without renaming the attempt.
      answerWith(
        const AttendanceRefused(
          AttendanceRefusal(
            kind: RefusalKind.unanswered,
            message: 'Jawaban dari server belum diterima.',
            code: 'timeout',
          ),
        ),
      );

      final controller = await boot();
      await controller.onDetect(capture(departmentPayload()));
      final first = keyUsed;

      // The screen offers no retry here today, so reach the state directly.
      await controller.onDetect(capture(departmentPayload()));

      expect(keyUsed, first);
    });
  });

  group('coordinates are recorded, not only enforced', () {
    Position fix({double lat = -6.21, double lng = 106.84}) => Position(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime(2026, 9, 4, 8),
      accuracy: 9,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

    ClockPosition? sentWith(AttendanceController controller) {
      final captured = verify(
        () => repository.redeem(
          any(),
          fallbackDirection: any(named: 'fallbackDirection'),
          position: captureAny(named: 'position'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).captured;

      return captured.isEmpty ? null : captured.single as ClockPosition?;
    }

    setUp(() {
      when(
        () => repository.redeem(
          any(),
          fallbackDirection: any(named: 'fallbackDirection'),
          position: any(named: 'position'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer(
        (_) async => const AttendanceAccepted(
          AttendanceReceipt(
            direction: PresenceDirection.clockIn,
            message: 'Absen masuk berhasil.',
          ),
        ),
      );
    });

    test('a workspace with NO geofence still sends them', () async {
      // Where a clock happened is part of the record — `RecordAttendance` stores
      // it, and `faceMethod` reads it to decide between `face-geolocation` and
      // `face-device`. A company that does not gate on location still wants it.
      when(
        () => location.currentPosition(),
      ).thenAnswer((_) async => LocationSuccess(fix()));

      final controller = await boot();
      await pumpEventQueue();

      expect(controller.locationStatus.value, LocationStatus.notRequired);

      await controller.onDetect(capture(departmentPayload()));

      final sent = sentWith(controller);

      expect(sent, isNotNull);
      expect(sent!.latitude, -6.21);
      expect(sent.longitude, 106.84);
    });

    test('but it does NOT block the clock when the fix fails', () async {
      // Best effort in the strictest sense: no permission, no signal, GPS off —
      // the clock goes up without coordinates, exactly as it did before.
      when(() => location.currentPosition()).thenAnswer(
        (_) async => const LocationRejected(LocationFailure.permissionDenied),
      );

      final controller = await boot();
      await pumpEventQueue();

      expect(controller.locationStatus.value, LocationStatus.notRequired);
      expect(controller.canCapture, isTrue);
      expect(controller.locationBlock.value, isNull);

      await controller.onDetect(capture(departmentPayload()));

      expect(sentWith(controller), isNull);
    });

    test('and the camera does not wait for it', () async {
      // Awaiting an optional fix would hold the camera shut for up to fifteen
      // seconds over something nobody is going to check.
      final slow = Completer<LocationResult>();

      when(() => location.currentPosition()).thenAnswer((_) => slow.future);

      final controller = await boot();

      expect(scanner.starts, 1);
      expect(controller.scannerState.value, ScannerState.ready);

      slow.complete(LocationSuccess(fix()));
      await pumpEventQueue();
    });

    test('a required fence still gates, and still sends them', () async {
      when(
        () => repository.context(),
      ).thenAnswer((_) async => contextOf(locationRequired: true, radius: 50));
      when(
        () => location.currentPosition(),
      ).thenAnswer((_) async => LocationSuccess(fix()));
      when(
        () => location.distanceBetween(
          fromLatitude: any(named: 'fromLatitude'),
          fromLongitude: any(named: 'fromLongitude'),
          toLatitude: any(named: 'toLatitude'),
          toLongitude: any(named: 'toLongitude'),
        ),
      ).thenReturn(11);

      final controller = await boot();

      expect(controller.locationStatus.value, LocationStatus.ready);

      await controller.onDetect(capture(departmentPayload()));

      expect(sentWith(controller)?.latitude, -6.21);
    });
  });

  group('a malformed request does not read as an HR problem', () {
    test('a codeless 422 says the app sent bad data, not "hubungi HR"', () {
      // The shape of the `is_mocked: "false"` defect: Laravel answers 422 with
      // field errors and no `code`, and classifying that by status alone told
      // the employee "Absensi belum dapat diproses. Hubungi HR bila berulang."
      final refusal = AttendanceRepository.refusalFor(
        const ApiException(
          'The is mocked field must be true or false.',
          status: 422,
          errors: {'is_mocked': 'The is mocked field must be true or false.'},
        ),
      );

      expect(refusal.code, 'request_rejected');
      expect(refusal.message, contains('tim IT'));
      expect(refusal.message, isNot(contains('HR')));
      // And never the server's own English validation text.
      expect(refusal.message, isNot(contains('is mocked')));
    });

    test('a 422 that DOES carry a domain code is untouched', () {
      final refusal = AttendanceRepository.refusalFor(
        const ApiException(
          'Anda berada 840 m dari lokasi kantor.',
          status: 422,
          code: 'outside_geofence',
        ),
      );

      expect(refusal.kind, RefusalKind.clockRejected);
      expect(refusal.message, contains('840 m'));
    });
  });

  group('the company switch governs the face method too', () {
    test('face_enabled: false locks it as a COMPANY setting', () async {
      // Not "belum didaftarkan HR". The company switched the method off for
      // everybody, and telling an enrolled employee their enrolment is missing
      // sends them to HR over something HR cannot fix.
      when(() => repository.context()).thenAnswer(
        (_) async => contextOf(faceEnabled: false, faceEnrolled: true),
      );

      final controller = await boot();

      expect(controller.faceStatus, MethodStatus.methodDisabled);
    });

    test('the switch is asked BEFORE the enrolment', () async {
      when(() => repository.context()).thenAnswer(
        (_) async => contextOf(faceEnabled: false, faceEnrolled: false),
      );

      final controller = await boot();

      expect(controller.faceStatus, MethodStatus.methodDisabled);
    });

    test('absent leaves it to the enrolment alone', () async {
      // A deployment that does not send the field is not switching anything off.
      when(
        () => repository.context(),
      ).thenAnswer((_) async => contextOf(faceEnrolled: true));

      final controller = await boot();

      expect(controller.context.value?.faceEnabled, isNull);
      expect(controller.faceStatus, MethodStatus.available);
    });

    test('the two switches are independent', () async {
      when(() => repository.context()).thenAnswer(
        (_) async =>
            contextOf(qrEnabled: false, faceEnabled: true, faceEnrolled: true),
      );

      final controller = await boot();

      expect(controller.qrStatus, MethodStatus.methodDisabled);
      expect(controller.faceStatus, MethodStatus.available);
    });
  });

  group('the masuk / pulang switcher', () {
    test('defaults to what the roster says', () async {
      final controller = await boot();

      expect(controller.expectedDirection, PresenceDirection.clockIn);
      expect(controller.direction, PresenceDirection.clockIn);
      expect(controller.directionIsOverride, isFalse);
    });

    test('an explicit choice wins over next_presence', () async {
      // The roster is right nearly always and wrong in the cases that matter
      // most: clocked in on a colleague's handset, a swapped shift, a night
      // shift over midnight.
      final controller = await boot();

      controller.chooseDirection(PresenceDirection.clockOut);

      expect(controller.direction, PresenceDirection.clockOut);
      expect(controller.expectedDirection, PresenceDirection.clockIn);
      expect(controller.directionIsOverride, isTrue);
    });

    test('choosing what the roster already says is not an override', () async {
      final controller = await boot();

      controller.chooseDirection(PresenceDirection.clockIn);

      expect(controller.directionIsOverride, isFalse);
    });

    test('the chosen direction is what gets submitted', () async {
      PresenceDirection? sent;

      when(
        () => repository.redeem(
          any(),
          fallbackDirection: any(named: 'fallbackDirection'),
          position: any(named: 'position'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer((invocation) async {
        sent =
            invocation.namedArguments[const Symbol('fallbackDirection')]
                as PresenceDirection?;

        return const AttendanceAccepted(
          AttendanceReceipt(
            direction: PresenceDirection.clockOut,
            message: 'Absen pulang berhasil.',
          ),
        );
      });

      final controller = await boot();
      controller.chooseDirection(PresenceDirection.clockOut);

      await controller.onDetect(capture(departmentPayload()));

      expect(sent, PresenceDirection.clockOut);
    });

    test('a day with nothing owed can still be attempted', () async {
      // `next_presence` is null, so before the switcher there was no direction
      // to send and the attempt was refused locally. The server is the authority
      // on whether the day is really complete.
      when(
        () => repository.context(),
      ).thenAnswer((_) async => contextOf(nextPresence: null));

      final controller = await boot();

      expect(controller.direction, isNull);

      controller.chooseDirection(PresenceDirection.clockOut);

      expect(controller.direction, PresenceDirection.clockOut);
      expect(controller.directionIsOverride, isTrue);
    });

    test('it cannot be changed mid-submission', () async {
      final controller = await boot();
      controller.stage.value = CaptureStage.submitting;

      controller.chooseDirection(PresenceDirection.clockOut);

      expect(controller.chosenDirection.value, isNull);
    });

    test('a confirmed clock hands the choice back to the roster', () async {
      when(
        () => repository.redeem(
          any(),
          fallbackDirection: any(named: 'fallbackDirection'),
          position: any(named: 'position'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer(
        (_) async => const AttendanceAccepted(
          AttendanceReceipt(
            direction: PresenceDirection.clockIn,
            message: 'Absen masuk berhasil.',
          ),
        ),
      );

      final controller = await boot();
      controller.chooseDirection(PresenceDirection.clockOut);

      await controller.onDetect(capture(departmentPayload()));

      expect(controller.chosenDirection.value, isNull);
    });

    test('the header line follows the choice', () async {
      final controller = await boot();

      expect(controller.intentLine, 'Absen masuk');

      controller.chooseDirection(PresenceDirection.clockOut);

      expect(controller.intentLine, 'Absen pulang');
    });
  });
}

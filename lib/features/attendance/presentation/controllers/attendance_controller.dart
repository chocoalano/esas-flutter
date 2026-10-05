import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart' show Geolocator, Position;
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/idempotency_key.dart';
import '../../../../core/services/camera_permission_service.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../core/storage/storage_keys.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../auth/data/repositories/session_repository.dart';
import '../../data/liveness/liveness_capture.dart';
import '../../data/models/attendance_context.dart';
import '../../data/models/liveness_challenge.dart';
import '../../data/models/scanned_code.dart';
import '../../data/repositories/attendance_repository.dart';
import '../routes/attendance_routes.dart';

/// The two ways an employee may record attendance from this screen.
///
/// **Alternatives, not stages.** The backend exposes two independent write
/// paths — `POST /qr-presences/redeem` (and `POST /attendance/qr`) for a code,
/// `POST /attendance/face/challenge` → `POST /attendance/face` for a face — and
/// neither requires the other. Which of them an employee may use is the
/// server's answer, read from `attendance/context`, and this enum only names
/// them.
enum AttendanceMethod {
  qr('Scan QR'),
  face('Verifikasi wajah');

  const AttendanceMethod(this.label);

  final String label;
}

/// Whether a method can be used, and if not, what kind of "not".
///
/// Four answers rather than a boolean, because they want four different
/// screens. "Belum terdaftar" is not an error and must not be drawn as one:
/// nothing is broken, and the person cannot fix it by trying again.
enum MethodStatus {
  /// Usable now.
  available,

  /// The company has not put this account on attendance at all. Neither method
  /// works, and the answer is HR rather than a retry.
  accountDisabled,

  /// Face only: HR has not registered this person's reference photographs.
  /// Enrolment happens in the HR panel, not in this app.
  notEnrolled,

  /// QR only: the company has switched QR attendance off. Nothing is wrong with
  /// the account or the handset, and no amount of retrying changes it.
  methodDisabled;

  bool get usable => this == MethodStatus.available;
}

/// What the QR camera is doing, or why it is not.
///
/// Read from `MobileScannerErrorCode` and from the OS permission, never from an
/// Indonesian sentence. The screen this replaces collapsed every one of these
/// into "Kamera tidak bisa dibuka. Periksa izin kamera" — which on a simulator
/// with no camera at all blamed a permission that had been granted, and on a
/// permanent denial offered "Coba lagi" as the primary action.
enum ScannerState {
  /// Not started — this mode is not on screen.
  idle,

  /// Opening.
  starting,

  /// Live.
  ready,

  /// Not granted, and the OS will still prompt. Ask; do not send to Settings.
  permissionAskable,

  /// Only Settings can undo it. Settings is the primary action.
  permissionPermanent,

  /// Withheld by policy — MDM, parental controls. Neither button helps.
  permissionRestricted,

  /// The device has no usable camera. A simulator, or a handset with the
  /// camera disabled. **Not** a permission problem, and must not be described
  /// as one.
  unsupported,

  /// It opened and then failed, or failed for a reason with no better name.
  failed,
}

/// Where a single attempt has got to.
enum CaptureStage {
  /// Nothing in flight. The camera is looking.
  idle,

  /// A code was read, or a face was verified on the handset. Not yet sent.
  detected,

  /// Sent, waiting for the server.
  submitting,

  /// The server confirmed it wrote the clock.
  succeeded,

  /// The server refused, or the handset could not complete the capture.
  refused,
}

/// Why the scanner cannot be used from where the handset is standing.
///
/// Sebelumnya kelima sebab pertama runtuh menjadi satu kalimat di layar —
/// "Anda berada di luar area kantor, atau lokasi palsu terdeteksi" — dengan dua
/// aksi yang salah untuk tiga di antaranya.
enum LocationBlock {
  /// Layanan lokasi perangkat mati.
  gpsOff,

  /// Izin ditolak, dan masih bisa diminta ulang.
  permissionDenied,

  /// Izin ditolak permanen; hanya pengaturan aplikasi yang bisa memulihkannya.
  permissionPermanent,

  /// Penyedia lokasi tiruan terdeteksi.
  mocked,

  /// Perangkat tidak berhasil menentukan posisi.
  unreadable,

  /// Benar-benar di luar radius absensi.
  outOfRange,
}

/// Where a location check has got to.
enum LocationStatus {
  /// The company does not check where a clock came from. Nothing is asked of
  /// the handset, and nothing is shown.
  notRequired,

  checking,
  ready,

  /// The handset thinks it is outside the fence — and says so without
  /// refusing.
  ///
  /// This used to be [blocked]. The client measured a straight-line distance
  /// against `radius_metres` and stopped the capture before anything was sent,
  /// which is a second copy of a rule the server owns: the server widens the
  /// radius by `geofence_accuracy_allowance` before it decides, and the app is
  /// never told that number. So the app was strictly harsher than the thing it
  /// was predicting, and the case it got wrong was somebody standing legitimately
  /// at the edge of the fence being unable to clock in at all.
  ///
  /// A warning is the honest version of what the handset actually knows.
  outsideFence,

  blocked,
}

/// The attendance capture workspace.
///
/// ## What this screen is
///
/// Not a QR scanner. It is the one place an employee records attendance, and it
/// carries **both** methods the backend offers because the backend offers both
/// to the same person on the same day — which of them is usable is a capability
/// the server sends, never a button this app decides to draw.
///
/// ## Where every answer comes from
///
/// | Question | Answer |
/// |---|---|
/// | May I clock at all? | `attendance_enabled` |
/// | May I use my face? | `face_enrolled` |
/// | Masuk or pulang? | `next_presence` |
/// | Does location matter? | `location.required` + centre + radius |
/// | Is the camera usable? | `MobileScannerErrorCode` + OS permission |
/// | Was it recorded? | the server's 201, and nothing else |
///
/// Not one of them is inferred from a message string, and not one is invented
/// here. `attendance/context` is asked once per visit — the same endpoint
/// Beranda already calls — and it replaces reading company coordinates out of a
/// cached login payload that no longer carries them, which is why this screen
/// used to lock itself with "Titik absensi belum diatur" for everybody.
class AttendanceController extends GetxController with WidgetsBindingObserver {
  AttendanceController({
    required AttendanceRepository repository,
    required LocationService location,
    required SessionRepository session,
    required LocalStorage storage,
    CameraPermissionService camera = const CameraPermissionService(),
    MobileScannerController Function()? scannerFactory,
  }) : _repository = repository,
       _location = location,
       _session = session,
       _storage = storage,
       _camera = camera,
       _scannerFactory = scannerFactory ?? _defaultScanner;

  final AttendanceRepository _repository;
  final LocationService _location;
  final SessionRepository _session;
  final LocalStorage _storage;
  final CameraPermissionService _camera;

  /// How the QR scanner is built.
  ///
  /// Injectable for one reason: `MobileScannerController` reaches a platform
  /// channel the moment anything subscribes to it, so a test that could not
  /// substitute it could not exercise a single line of this class.
  final MobileScannerController Function() _scannerFactory;

  static MobileScannerController _defaultScanner() => MobileScannerController(
    // QR codes are read off a screen somebody else is holding or a wall
    // display, so the rear camera. The face path opens its own front camera;
    // there is deliberately no flip control, because neither method has a
    // reason to use the other's lens.
    facing: CameraFacing.back,
    detectionSpeed: DetectionSpeed.normal,
    returnImage: false,
    // Started and stopped by this controller, so the camera is live only while
    // the QR mode is actually on screen and the app is in front.
    autoStart: false,
  );

  late final MobileScannerController scanner;

  // ── Screen state ─────────────────────────────────────────────────────────

  final mode = AttendanceMethod.qr.obs;
  final stage = CaptureStage.idle.obs;

  final context = Rxn<AttendanceContext>();
  final loadingContext = true.obs;

  /// Whether the attendance context could not be read.
  ///
  /// A flag rather than the server's sentence, for the same reason
  /// [AttendanceRepository.refusalFor] exists: a message from a status endpoint
  /// is not written for an employee, and this one has no `code` to judge it by.
  /// The readiness strip says the screen is running blind; the sentence goes to
  /// the log.
  ///
  /// A screen with no context still shows both methods and still scans. The
  /// server is the authority on every refusal anyway, and refusing to draw a
  /// scanner because a status call failed would strand somebody at the gate over
  /// a request that has nothing to do with their code.
  final contextUnavailable = false.obs;

  final scannerState = ScannerState.idle.obs;
  final torchOn = false.obs;
  final torchAvailable = false.obs;

  final locationStatus = LocationStatus.checking.obs;
  final locationBlock = Rxn<LocationBlock>();
  final distanceMeters = RxnDouble();
  final fenceRadius = RxnDouble();

  /// The confirmation, once the server has written the clock. Persists until
  /// the employee closes it.
  final receipt = Rxn<AttendanceReceipt>();

  /// The last refusal, whether the code's, the clock's or the face's.
  final refusal = Rxn<AttendanceRefusal>();

  // ── Face state ───────────────────────────────────────────────────────────

  /// The running attempt, or null. The view watches its notifiers directly.
  final capture = Rxn<LivenessCapture>();

  /// The movements the server drew for this attempt.
  final challenge = Rxn<LivenessChallenge>();

  /// What the face panel is currently saying.
  final faceMessage = RxnString();

  /// Whether the biometric notice has already been shown to this employee, in
  /// this workspace, at the version currently written.
  ///
  /// **Not a consent record.** See [acknowledgeFaceNotice].
  final faceNoticeSeen = false.obs;

  ClockPosition? _position;
  bool _inFlight = false;
  bool _resumed = true;
  bool _closing = false;
  Future<void> _cameraOperation = Future<void>.value();

  /// The key naming the attempt currently in flight, or null between attempts.
  ///
  /// **One key per logical attempt, not per HTTP call.** Minting a fresh one on
  /// every send would be an app that speaks the protocol correctly and gets none
  /// of its protection: the server can only answer a repeat with the first
  /// response if both requests carry the same name.
  ///
  /// What counts as a new attempt is a new *deliberate* action by the person: a
  /// new code in front of the camera, or a new challenge for a new face capture.
  /// A transport retry of the attempt already begun keeps the key it has.
  ///
  /// Cleared on every terminal outcome — a confirmed clock, a refusal, an
  /// abandonment — so that whatever the person does next is named separately.
  /// A definitive refusal ends the logical attempt, and reusing its key would
  /// replay nothing (only successful answers are stored) while conflicting if
  /// the body changed.
  String? _attemptKey;

  // ── Derived ──────────────────────────────────────────────────────────────

  /// The direction the employee has chosen, when they have chosen one.
  ///
  /// Null means "whatever the server expects", which is the ordinary case and
  /// the default every visit starts on.
  final chosenDirection = Rxn<PresenceDirection>();

  /// Which clock this attempt is for.
  ///
  /// The employee's choice wins over `next_presence`, and that is deliberate
  /// rather than permissive. `next_presence` is the roster's answer and it can
  /// be stale in ways only the person standing there knows about — they clocked
  /// in on a colleague's handset, a shift was swapped after the roster was
  /// drawn, the day rolled over on a night shift. What it is NOT is a licence:
  /// the server still refuses `already_clocked_in`, `no_clock_in` and
  /// `already_clocked_out`, so a wrong choice costs a refusal and never a wrong
  /// record.
  ///
  /// A department QR code ignores this entirely — it is minted for one direction
  /// and the server reads that from the code, not from the request — which is
  /// why the receipt reports the direction that was actually written.
  PresenceDirection? get direction =>
      chosenDirection.value ?? context.value?.nextPresence;

  /// What the roster says is owed, whatever has been chosen.
  PresenceDirection? get expectedDirection => context.value?.nextPresence;

  /// Whether the choice differs from what the server is expecting.
  ///
  /// Worth saying out loud before the attempt rather than after: the refusal it
  /// leads to is correct but arrives thirty seconds and one spent QR code later.
  bool get directionIsOverride {
    final chosen = chosenDirection.value;

    return chosen != null && chosen != context.value?.nextPresence;
  }

  /// Choose which clock to record.
  ///
  /// Refused mid-submission: the request already carries a direction and the
  /// answer belongs to the attempt that asked.
  void chooseDirection(PresenceDirection next) {
    if (stage.value == CaptureStage.submitting || faceRunning) return;

    chosenDirection.value = next;
    refusal.value = null;
  }

  /// The subtitle under "Absensi": "Absen masuk · Shift Pagi 08:00–17:00".
  String? get intentLine {
    final loaded = context.value;

    if (loaded == null) return null;

    final chosen = direction;

    final parts = <String>[
      if (chosen != null)
        chosen.label
      else if (loaded.canClock)
        'Absensi hari ini lengkap',
      if (loaded.shift != null) _shiftLine(loaded.shift!),
    ];

    return parts.isEmpty ? null : parts.join(' · ');
  }

  static String _shiftLine(AttendanceShift shift) {
    // `hoursLabel` carries the `(+1 hari)` for a shift that ends on the
    // following date. Formatting it here as well would be a second copy of the
    // rule, and the model is where the server's own answer arrives.
    return [
      shift.name,
      shift.hoursLabel,
    ].whereType<String>().where((part) => part.isNotEmpty).join(' ');
  }

  MethodStatus get qrStatus {
    final loaded = context.value;

    // No context yet, or a backend that does not send `qr_enabled`: QR stays
    // attemptable and the server stays the authority. That is the behaviour
    // that shipped before the field existed, and it is what keeps a new handset
    // working against an old deployment.
    if (loaded == null) return MethodStatus.available;
    if (!loaded.canClock) return MethodStatus.accountDisabled;

    return loaded.qrEnabled == false
        ? MethodStatus.methodDisabled
        : MethodStatus.available;
  }

  MethodStatus get faceStatus {
    final loaded = context.value;

    if (loaded == null) return MethodStatus.available;
    if (!loaded.canClock) return MethodStatus.accountDisabled;

    // The company's switch is asked BEFORE the person's enrolment, because the
    // two want different sentences and the wrong order tells somebody HR has not
    // registered them when in fact the method is switched off for everyone.
    if (loaded.faceEnabled == false) return MethodStatus.methodDisabled;

    return loaded.faceEnrolled
        ? MethodStatus.available
        : MethodStatus.notEnrolled;
  }

  MethodStatus statusOf(AttendanceMethod method) =>
      method == AttendanceMethod.qr ? qrStatus : faceStatus;

  /// The one method that is not usable, if either is.
  ///
  /// What the note under the selector explains. Keyed to the *unavailable*
  /// method rather than to the selected one: with QR active and a face not yet
  /// enrolled, an employee looking at a locked segment and being told nothing
  /// has no way to learn that the next step is HR's.
  MethodStatus get unavailableStatus {
    if (!qrStatus.usable) return qrStatus;
    if (!faceStatus.usable) return faceStatus;

    return MethodStatus.available;
  }

  /// Whether a capture may be attempted at all right now.
  ///
  /// Location is part of it only where the company asks for it: in a workspace
  /// with no geofence the handset is never asked where it is, and a screen that
  /// demanded a fix anyway would strand somebody indoors over a rule that does
  /// not apply to them.
  bool get canCapture =>
      context.value?.canClock != false &&
      locationStatus.value != LocationStatus.blocked &&
      locationStatus.value != LocationStatus.checking;

  /// Whether a face attempt is currently running.
  bool get faceRunning => capture.value != null;

  // ── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void onInit() {
    super.onInit();

    WidgetsBinding.instance.addObserver(this);

    scanner = _scannerFactory();
    scanner.addListener(_onScannerState);

    faceNoticeSeen.value = _noticeAlreadySeen;

    unawaited(loadContext());
  }

  @override
  void onClose() {
    _closing = true;
    WidgetsBinding.instance.removeObserver(this);
    scanner.removeListener(_onScannerState);
    unawaited(_teardownFace());
    unawaited(_disposeScanner());
    super.onClose();
  }

  Future<void> _disposeScanner() async {
    await _stopScanner();
    await scanner.dispose();
  }

  /// The camera runs only while this screen is visible and the app is in front.
  ///
  /// `MobileScanner` carries its own lifecycle observer, but registers it **only
  /// when it created the controller itself** — and this screen passes one in. So
  /// without this the preview kept the sensor open behind a phone call, a
  /// notification shade and a locked screen, and came back to a frozen image
  /// that never scanned again.
  ///
  /// `inactive` is deliberately treated as "gone" for the camera and not for a
  /// face attempt in flight: on iOS it fires for a notification banner and a
  /// Control Centre pull, and killing a half-performed sequence for those would
  /// cost somebody their attempt several times a day.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        _resumed = true;
        unawaited(_syncCamera());
        // A fix taken before the phone went into a pocket is a fix taken
        // somewhere else. Nothing here invents a maximum age — the server has
        // no field for one and the domain has set no threshold — but the one
        // moment the handset KNOWS it may have moved is the moment it comes
        // back, and taking a new reading then costs a second and removes the
        // guesswork.
        if (locationStatus.value != LocationStatus.notRequired) {
          unawaited(revalidateLocation());
        }

      case AppLifecycleState.inactive:
        _resumed = false;
        unawaited(_stopScanner());

      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _resumed = false;
        unawaited(_stopScanner());
        // A face attempt cannot survive the app going away: the camera is taken
        // and the challenge is on a two-minute clock. Ended here, saying so,
        // rather than resumed into a frozen preview that reports "wajah tidak
        // terdeteksi" thirty seconds later.
        if (faceRunning) {
          unawaited(_abandonFace());
        }
    }
  }

  // ── Context ──────────────────────────────────────────────────────────────

  /// Read what this person may do, and where from.
  Future<void> loadContext() async {
    loadingContext.value = true;
    contextUnavailable.value = false;

    try {
      final loaded = await _repository.context();

      context.value = loaded;
      fenceRadius.value = loaded.geofence.radiusMetres;

      // Wajah tidak boleh menjadi mode aktif pada akun yang belum terdaftar:
      // memilihkannya berarti membuka layar yang hanya bisa berkata "belum
      // bisa dipakai".
      if (mode.value == AttendanceMethod.face && !faceStatus.usable) {
        mode.value = AttendanceMethod.qr;
      }
    } on ApiException catch (error) {
      AppLogger.warning('Attendance context unavailable: ${error.message}');
      contextUnavailable.value = true;
    } catch (error, stackTrace) {
      // A payload shaped in a way no model expected must not take the screen
      // down with it: the scanner does not need the context to read a code, and
      // the server refuses whatever it would have refused anyway.
      AppLogger.error(
        'Attendance context could not be read',
        error: error,
        stackTrace: stackTrace,
      );
      contextUnavailable.value = true;
    } finally {
      loadingContext.value = false;
    }

    await revalidateLocation();
    await _syncCamera();
  }

  // ── Location ─────────────────────────────────────────────────────────────

  /// Find out where the handset is, and — only where the company asks — decide
  /// whether that is somewhere it will accept a clock from.
  ///
  /// **Two separate jobs, and conflating them was a bug.** Where a clock
  /// happened is part of the attendance record: `RecordAttendance` stores the
  /// coordinates, and `RecordAttendance::faceMethod` reads them to decide
  /// whether the row is `face-geolocation` or `face-device`. A workspace with no
  /// geofence still wants that; what it does not want is to be *blocked* over
  /// it.
  ///
  /// So the fix is asymmetric on purpose:
  ///
  /// * **geofenced** — the fix is awaited and gates the capture, because a code
  ///   spent from outside the fence is a code spent on a refusal;
  /// * **not geofenced** — the fix is taken in the background and attached to
  ///   whatever is submitted, and a failure is silent. Awaiting it here would
  ///   hold the camera shut for up to fifteen seconds waiting on something
  ///   nobody is going to check.
  Future<void> revalidateLocation() async {
    final fence = context.value?.geofence;

    if (fence == null || !fence.required_) {
      locationStatus.value = LocationStatus.notRequired;
      locationBlock.value = null;
      distanceMeters.value = null;
      _position = null;

      // Not awaited, and nothing on screen waits for it.
      unawaited(_recordPositionQuietly());

      return;
    }

    locationStatus.value = LocationStatus.checking;
    locationBlock.value = null;
    distanceMeters.value = null;
    _position = null;

    final result = await _location.currentPosition();

    switch (result) {
      case LocationRejected(reason: final reason):
        locationBlock.value = _blockFor(reason);
        locationStatus.value = LocationStatus.blocked;

      case LocationSuccess(position: final position):
        _position = _clockPosition(position);

        if (!fence.hasCentre) {
          // The company checks location but has sent no centre. Nothing here can
          // pre-empt that; the coordinates go up and the server decides, which
          // is better than refusing a clock over a configuration the employee
          // cannot see, let alone fix.
          locationStatus.value = LocationStatus.ready;

          return;
        }

        final distance = _location.distanceBetween(
          fromLatitude: position.latitude,
          fromLongitude: position.longitude,
          toLatitude: fence.latitude!,
          toLongitude: fence.longitude!,
        );

        distanceMeters.value = distance;

        final radius = fence.radiusMetres;

        // A hint, never a veto.
        //
        // The server decides eligibility, and it decides it with an accuracy
        // allowance this app is not sent. Refusing here meant the handset could
        // turn somebody away that the server would have accepted — and a person
        // who cannot clock in has no way to appeal to the server that would
        // have said yes.
        //
        // The cost of the other direction is real and smaller: a machine QR is
        // single-use, so a clock attempted from outside the fence spends the
        // code on a refusal. Spending a code is recoverable in seconds; being
        // locked out of attendance is not.
        locationStatus.value = radius == null || distance <= radius
            ? LocationStatus.ready
            : LocationStatus.outsideFence;
    }
  }

  /// Take a fix for the record, where the company does not require one.
  ///
  /// Best effort in the strictest sense: nothing waits for it, nothing is shown
  /// about it, and a refusal — no permission, no signal, GPS off — leaves the
  /// clock to go up without coordinates exactly as it did before. The attendance
  /// is the point; the coordinates are a fact about it that is worth having when
  /// it can be had.
  Future<void> _recordPositionQuietly() async {
    final result = await _location.currentPosition();

    // The screen may have moved on — a submission in flight, a fence that now
    // applies after a reload. Never overwrite a fix that a required check made.
    if (isClosed || locationStatus.value != LocationStatus.notRequired) {
      return;
    }

    if (result case LocationSuccess(position: final position)) {
      _position = _clockPosition(position);
    }
  }

  ClockPosition _clockPosition(Position position) => ClockPosition(
    latitude: position.latitude,
    longitude: position.longitude,
    // The device's own stamp, not `DateTime.now()`. `getCurrentPosition` takes a
    // fresh reading rather than replaying a cached one, so this is the moment
    // the fix was actually produced.
    takenAt: position.timestamp,
    accuracy: position.accuracy,
    // Reported honestly. A client that omits it is telling the server nothing;
    // one that reports it is telling it something no server-side check could
    // work out on its own.
    isMocked: position.isMocked,
  );

  static LocationBlock _blockFor(LocationFailure reason) => switch (reason) {
    LocationFailure.serviceDisabled => LocationBlock.gpsOff,
    LocationFailure.permissionDenied => LocationBlock.permissionDenied,
    LocationFailure.permissionDeniedForever =>
      LocationBlock.permissionPermanent,
    LocationFailure.mocked => LocationBlock.mocked,
    LocationFailure.unavailable => LocationBlock.unreadable,
  };

  /// Membuka pengaturan lokasi perangkat — jawaban untuk GPS yang mati.
  Future<void> openLocationSettings() => Geolocator.openLocationSettings();

  /// Membuka pengaturan aplikasi — satu-satunya jawaban untuk izin yang ditolak
  /// permanen. Sebelumnya halaman ini dibuka sendiri tanpa diminta, tepat saat
  /// sebuah toast sedang menjelaskan mengapa.
  Future<void> openApplicationSettings() => _location.openSettings();

  // ── Mode ─────────────────────────────────────────────────────────────────

  /// Switch method.
  ///
  /// The two cameras belong to different plugins and cannot share a stream, so
  /// exactly one is open at a time: leaving QR stops the scanner, and leaving
  /// the face mode ends any attempt in flight and hands the sensor back. A
  /// switch during a submission is refused rather than queued — the request is
  /// already with the server, and the answer belongs on the screen that asked.
  Future<void> switchTo(AttendanceMethod next) async {
    if (mode.value == next || stage.value == CaptureStage.submitting) return;
    if (!statusOf(next).usable) return;

    mode.value = next;
    refusal.value = null;
    faceMessage.value = null;

    if (next == AttendanceMethod.qr) {
      await _teardownFace();
    } else {
      await _stopScanner();
    }

    await _syncCamera();
  }

  // ── QR ───────────────────────────────────────────────────────────────────

  /// Start or stop the QR camera so it matches the screen.
  Future<void> _syncCamera() async {
    if (_closing) return;

    final wants =
        _resumed &&
        mode.value == AttendanceMethod.qr &&
        // A method the company has switched off must not hold the sensor open
        // behind its own explanation.
        qrStatus.usable &&
        stage.value != CaptureStage.succeeded &&
        canCapture;

    if (!wants) {
      await _stopScanner();

      return;
    }

    await _startScanner();
  }

  Future<void> _startScanner() async {
    return _enqueueCameraOperation(_startScannerQueued);
  }

  Future<void> _startScannerQueued() async {
    // Already going, or already live. Both matter: `start()` returns silently
    // when the camera is running, which fires no state change — so a second
    // call after `ScannerState.starting` had been set would leave the screen on
    // "Menyiapkan kamera" over a preview that was working perfectly.
    if (scannerState.value == ScannerState.starting) return;
    if (scannerState.value == ScannerState.ready && scanner.value.isRunning) {
      return;
    }

    final permission = await _camera.status();

    if (permission != CameraPermission.granted) {
      scannerState.value = _stateFor(permission);

      return;
    }

    scannerState.value = ScannerState.starting;

    try {
      await scanner.start();

      // The listener normally makes this transition. Repeated here for the one
      // path it cannot see: a controller that was already running produces no
      // notification at all.
      if (scanner.value.isRunning) scannerState.value = ScannerState.ready;
    } on MobileScannerException catch (error) {
      reportScannerFailure(error);
    }
  }

  Future<void> _stopScanner() async {
    return _enqueueCameraOperation(_stopScannerQueued);
  }

  Future<void> _pauseScanner() async {
    return _enqueueCameraOperation(_pauseScannerQueued);
  }

  Future<void> _pauseScannerQueued() async {
    if (scannerState.value == ScannerState.idle) return;

    try {
      await scanner.pause();
    } on MobileScannerException catch (error) {
      AppLogger.warning('Could not pause the scanner: ${error.errorCode.name}');
    }

    if (scannerState.value == ScannerState.ready ||
        scannerState.value == ScannerState.starting) {
      scannerState.value = ScannerState.idle;
    }
  }

  Future<void> _stopScannerQueued() async {
    if (scannerState.value == ScannerState.idle) return;

    try {
      await scanner.stop();
    } on MobileScannerException catch (error) {
      AppLogger.warning('Could not stop the scanner: ${error.errorCode.name}');
    }

    if (scannerState.value == ScannerState.ready ||
        scannerState.value == ScannerState.starting) {
      scannerState.value = ScannerState.idle;
    }
  }

  Future<void> _enqueueCameraOperation(Future<void> Function() operation) {
    final next = _cameraOperation.then((_) => operation());
    _cameraOperation = next.catchError((_) {});

    return next;
  }

  /// Ask for the camera, or open Settings — whichever the OS will honour.
  ///
  /// The screen offers exactly one of the two, chosen from the real permission
  /// state. Offering "Buka pengaturan" to somebody who has never been asked
  /// sends them to fix something that is not broken; offering "Izinkan kamera"
  /// after a permanent denial offers a prompt the OS will not show.
  Future<void> requestCameraPermission() async {
    final granted = await _camera.request();

    scannerState.value = granted == CameraPermission.granted
        ? ScannerState.idle
        : _stateFor(granted);

    if (granted == CameraPermission.granted) await _syncCamera();
  }

  Future<void> openCameraSettings() => _camera.openSettings();

  /// Try the camera again after whatever was wrong with it was fixed.
  ///
  /// Re-reads the permission first, so "Coba lagi" after a trip to Settings
  /// lands on the right branch instead of repeating the old failure. Never
  /// opens a second session: [_startScanner] refuses while one is starting, and
  /// the scanner controller is created once for the life of this screen.
  Future<void> retryCamera() async {
    scannerState.value = ScannerState.idle;

    await _syncCamera();
  }

  static ScannerState _stateFor(CameraPermission permission) =>
      switch (permission) {
        CameraPermission.granted => ScannerState.idle,
        CameraPermission.askable => ScannerState.permissionAskable,
        CameraPermission.permanentlyDenied => ScannerState.permissionPermanent,
        CameraPermission.restricted => ScannerState.permissionRestricted,
      };

  /// Called by the scanner's `errorBuilder`, one frame later.
  ///
  /// Typed. `MobileScannerErrorCode.unsupported` is a device with no camera —
  /// a simulator, most often — and telling that person to check a permission
  /// they have already granted is advice that cannot work.
  void reportScannerFailure(MobileScannerException error) {
    AppLogger.warning('QR camera unavailable: $error');

    scannerState.value = switch (error.errorCode) {
      MobileScannerErrorCode.permissionDenied => ScannerState.permissionAskable,
      MobileScannerErrorCode.unsupported => ScannerState.unsupported,
      _ => ScannerState.failed,
    };

    // A permission the plugin reports as denied may in fact be permanently
    // denied, which the plugin has no word for. Asked of the OS, which does.
    if (error.errorCode == MobileScannerErrorCode.permissionDenied) {
      unawaited(_refinePermissionState());
    }
  }

  Future<void> _refinePermissionState() async {
    final permission = await _camera.status();

    if (permission != CameraPermission.granted) {
      scannerState.value = _stateFor(permission);
    }
  }

  void _onScannerState() {
    final value = scanner.value;

    torchAvailable.value = value.torchState != TorchState.unavailable;
    torchOn.value = value.torchState == TorchState.on;

    if (value.isRunning && scannerState.value == ScannerState.starting) {
      scannerState.value = ScannerState.ready;
    }
  }

  /// The torch, only where the device actually has one.
  Future<void> toggleTorch() async {
    if (!torchAvailable.value || !scanner.value.isRunning) return;

    try {
      await scanner.toggleTorch();
    } on MobileScannerException catch (error) {
      AppLogger.warning('Torch unavailable: ${error.errorCode.name}');
    }
  }

  /// A code came into frame.
  ///
  /// The guard is synchronous and set before the first `await`, which is the
  /// whole of the duplicate protection: the camera goes on delivering the same
  /// code ten times a second while a request is in flight, and a check that
  /// awaited anything first would let a second and a third through — each
  /// spending a single-use code, each answering `code_already_used`.
  Future<void> onDetect(BarcodeCapture capture) async {
    if (_inFlight || stage.value != CaptureStage.idle) return;

    final raw = capture.barcodes.firstOrNull?.rawValue;

    if (raw == null || raw.isEmpty) return;

    final scanned = ScannedCode.recognise(raw);

    if (scanned == null) {
      // Not an attendance code. Said quietly, in the viewport, and the scanner
      // carries straight on — a shipping label is not a reason for a full-screen
      // error with a button on it.
      refusal.value = const AttendanceRefusal(
        kind: RefusalKind.unrecognised,
        message: 'Kode ini bukan QR absensi. Arahkan ke QR absensi Anda.',
        code: 'unrecognised',
      );

      return;
    }

    _inFlight = true;
    stage.value = CaptureStage.detected;
    refusal.value = null;

    // This scan is the attempt. `??=` rather than `=` so a future retry of the
    // *same* scan reuses it; a new scan reaches here with the slot already
    // cleared by the last outcome.
    _attemptKey ??= IdempotencyKey.mint();

    // The camera is held up in front of a code, not in front of the screen, so
    // the first confirmation that anything happened has to be something other
    // than a pixel. No package for it: `HapticFeedback` is in the Flutter SDK.
    _tap(HapticFeedback.selectionClick);

    // Paused before the request, not after it. A camera left running behind a
    // submission goes on reading the same code, while stopping it here would
    // destroy the ImageReader and recreate it on every explicit retry.
    await _pauseScanner();
    await _stopScanner();

    stage.value = CaptureStage.submitting;

    final outcome = await _repository.redeem(
      scanned,
      fallbackDirection: direction,
      position: _position,
      idempotencyKey: _attemptKey,
    );

    await _settle(outcome);
  }

  // ── Face ─────────────────────────────────────────────────────────────────

  /// The version of the biometric notice this build shows.
  ///
  /// Bumped whenever the wording changes materially. An acknowledgement is
  /// recorded against a version, so new text is shown again rather than
  /// suppressed by an answer somebody gave to different words.
  static const int faceNoticeVersion = 1;

  /// The key this handset remembers the notice under, or null when there is not
  /// enough to scope it with.
  ///
  /// Null means "show the notice". Falling back to an unscoped key would be the
  /// bug this guards against: one shared handset where the second employee never
  /// sees it.
  String? get _noticeKey {
    final id = _session.user?.id;
    final workspace = _repository.workspace;

    if (id == null || workspace == null || workspace.isEmpty) return null;

    return StorageKeys.local.faceNoticeSeen(
      employeeId: id,
      workspace: workspace,
      version: faceNoticeVersion,
    );
  }

  bool get _noticeAlreadySeen {
    final key = _noticeKey;

    return key == null ? false : (_storage.read<bool>(key) ?? false);
  }

  /// Remember that the biometric notice was displayed on this handset.
  ///
  /// **This is not a consent record and must never be described as one.** The
  /// consent that governs biometric processing is HR's: it lives on the
  /// enrolment as `consent_recorded_at`, and the server refuses to treat an
  /// enrolment as usable without it — which is why `face_enrolled` being true
  /// already implies a consent on file. What this flag prevents is re-showing
  /// the same four paragraphs before every clock-in.
  ///
  /// Consequence, stated rather than hidden: it lives in device storage, so it
  /// is lost on reinstall and survives a logout — which only means the notice is
  /// shown again, never that anything about consent changes.
  Future<void> acknowledgeFaceNotice() async {
    faceNoticeSeen.value = true;

    final key = _noticeKey;

    if (key == null) return;

    await _storage.write(key, true);
  }

  /// Begin a face attempt: ask for a challenge, then watch it performed.
  ///
  /// The challenge is asked for **now**, not when the screen opened. That
  /// ordering is the security control: the movements are issued after the person
  /// has asked to clock, so a recording made beforehand cannot answer them.
  Future<void> startFace() async {
    if (_inFlight || faceRunning) return;

    final owed = direction;

    if (owed == null) {
      refusal.value = const AttendanceRefusal(
        kind: RefusalKind.clockRejected,
        message: 'Absensi untuk hari ini sudah lengkap.',
        code: 'no_clock_owed',
      );

      return;
    }

    final permission = await _camera.status();

    if (permission != CameraPermission.granted) {
      final granted = await _camera.request();

      if (granted != CameraPermission.granted) {
        scannerState.value = _stateFor(granted);
        faceMessage.value = null;

        return;
      }
    }

    _inFlight = true;
    refusal.value = null;
    stage.value = CaptureStage.detected;
    faceMessage.value = 'Menyiapkan verifikasi…';

    LivenessCapture? session;

    try {
      final drawn = LivenessChallenge.fromJson(
        await _repository.faceChallenge(owed),
      );

      challenge.value = drawn;

      // A new challenge is a new attempt, always: the old one is spent or dead,
      // so nothing about the previous key could be replayed against it.
      _attemptKey = IdempotencyKey.mint();

      session = LivenessCapture(challenge: drawn);
      capture.value = session;

      final result = await session.run();

      faceMessage.value = 'Verifikasi wajah berhasil. Memproses absensi…';
      stage.value = CaptureStage.submitting;

      try {
        final outcome = await _repository.submitFace(
          image: result.image,
          challengeToken: drawn.token,
          challengeId: drawn.challengeId,
          direction: owed,
          liveness: result.evidence,
          position: _position,
          idempotencyKey: _attemptKey,
        );

        await _settle(outcome, teardownFace: true);
      } finally {
        // The photograph is of somebody's face and it lives in the OS cache.
        // Deleted whatever the server answered — an attempt that was refused
        // must not leave a picture behind either.
        await LivenessCapture.discard(result.image);
      }
    } on LivenessFailure catch (failure) {
      await _teardownFace();

      // Abandoning is not a refusal to report: the person left, or the app did.
      if (failure.kind == LivenessFailureKind.abandoned) {
        _reset();

        return;
      }

      _inFlight = false;
      stage.value = CaptureStage.refused;
      refusal.value = AttendanceRefusal(
        kind: RefusalKind.faceRejected,
        message: failure.message,
        code: failure.kind.name,
      );
    } on ApiException catch (error) {
      await _teardownFace();

      _inFlight = false;
      stage.value = CaptureStage.refused;
      // Through the same classifier the QR path uses. Asking for a challenge is
      // the one request this screen makes outside the repository's own two, and
      // a second copy of "what may an employee read" here is how the two paths
      // would drift.
      refusal.value = AttendanceRepository.refusalFor(error);
    }
  }

  /// Stop a face attempt the person no longer wants.
  Future<void> cancelFace() async {
    await _teardownFace();

    _reset();
  }

  Future<void> _abandonFace() async {
    await _teardownFace();

    _inFlight = false;
    stage.value = CaptureStage.refused;
    faceMessage.value = null;
    refusal.value = const AttendanceRefusal(
      kind: RefusalKind.faceRejected,
      message:
          'Verifikasi berhenti karena aplikasi berpindah ke belakang. '
          'Mulai lagi bila Anda siap.',
      code: 'abandoned',
    );
  }

  Future<void> _teardownFace() async {
    final session = capture.value;

    capture.value = null;
    challenge.value = null;

    if (session == null) return;

    session.abort();
    await session.dispose();
  }

  // ── Outcome ──────────────────────────────────────────────────────────────

  /// Turn a server answer into a screen state.
  ///
  /// **Success is the server's 201 and nothing else.** Nothing in this method
  /// confirms a clock the server has not written, and nothing navigates away
  /// before the answer arrives — the version this replaces navigated from a
  /// `finally` that ran on every path, so a refused scan looked exactly like an
  /// accepted one (MED-12).
  Future<void> _settle(
    AttendanceOutcome outcome, {
    bool teardownFace = false,
  }) async {
    if (teardownFace) await _teardownFace();

    switch (outcome) {
      case AttendanceAccepted(receipt: final confirmed):
        // The attempt is over, whatever happens next is a new one.
        _attemptKey = null;
        // And so is the choice: the clock that was owed has been recorded, so
        // the next visit starts from what the server says again.
        chosenDirection.value = null;
        // The one moment in this product worth a distinct physical signal, and
        // it fires only for a clock the SERVER wrote.
        _tap(HapticFeedback.mediumImpact);
        receipt.value = confirmed;
        stage.value = CaptureStage.succeeded;
        refusal.value = null;
        faceMessage.value = null;
        _inFlight = false;

      case AttendanceRefused(refusal: final refused):
        // A definitive refusal ends the logical attempt. The next try is a new
        // one, with a new code or a new challenge, and it must be named
        // separately — reusing this key against a changed body is a 409.
        //
        // The one outcome that does NOT end it is an answer that never arrived:
        // nothing was stored under the key, so the same attempt could still be
        // named by it if a retry affordance is ever offered.
        if (refused.kind != RefusalKind.unanswered) _attemptKey = null;

        refusal.value = refused;
        faceMessage.value = null;
        _inFlight = false;

        // Do not restart the camera automatically after a rejected QR. The
        // code is usually still in front of the lens, so resuming here creates
        // a stop/start loop that repeatedly rebuilds CameraX ImageReaders.
        // The employee can remove the old code and press "Pindai lagi".
        stage.value = CaptureStage.refused;
    }
  }

  /// Clear a refusal and go back to looking.
  Future<void> retryCapture() async {
    _reset();

    if (mode.value == AttendanceMethod.qr) await _syncCamera();
  }

  /// Fire a haptic without letting a handset that has none break a clock.
  ///
  /// A device with no vibrator, or a test with no platform behind the channel,
  /// answers with an error rather than silence — and an unhandled one inside an
  /// attendance submission is a crash on the most consequential screen here.
  static void _tap(Future<void> Function() feedback) {
    unawaited(feedback().catchError((Object _) {}));
  }

  void _reset() {
    _inFlight = false;
    _attemptKey = null;
    stage.value = CaptureStage.idle;
    refusal.value = null;
    faceMessage.value = null;
  }

  /// Close the receipt and go on to the history, where the row now is.
  void finishReceipt() {
    receipt.value = null;
    stage.value = CaptureStage.idle;
    Get.offAllNamed(AttendanceRoutes.list);
  }

  void openHistory() => Get.offAllNamed(AttendanceRoutes.list);
}

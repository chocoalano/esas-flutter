import '../models/device_status.dart';
import 'device_proof_repository.dart';

/// Where the attendance entry stands for this phone.
enum DeviceGateStatus {
  /// Open attendance. Either nothing is required (today's behaviour) or the
  /// proof is fresh.
  ready,

  /// A proof must run first. Only [DeviceProofGate.evaluate] answers this;
  /// [DeviceProofGate.ensureReady] runs the proof instead.
  needsProof,

  /// Enrolment is open but not yet required, and this phone is not enrolled.
  /// Offered once, and attendance stays usable.
  offerEnrollment,

  /// Required, and the account has no active key: "Perangkat Absensi Belum
  /// Terdaftar".
  notEnrolled,

  /// A key is enrolled but this install cannot prove it: "Hubungi HR untuk
  /// Mengganti Perangkat".
  recovery,

  /// The keystore cannot be used on this phone.
  keyUnavailable,

  /// No connection while a proof was needed.
  offline,

  /// The token is gone (401) and the app has signed out. Signing in again
  /// continues without a new HR code when this phone's key is enrolled.
  sessionEnded,

  /// Anything else; retrying may help.
  failed,
}

class DeviceGateDecision {
  const DeviceGateDecision(
    this.status, {
    this.device,
    this.failure,
    this.retryAfter,
  });

  final DeviceGateStatus status;
  final DeviceStatus? device;
  final DeviceProofFailure? failure;

  /// How long the server asked to wait before the next try (429, 503). The
  /// screen keeps its retry disabled for that long.
  final Duration? retryAfter;

  bool get isReady => status == DeviceGateStatus.ready;
}

/// The attendance-entry gate (ADR-D §9 option c).
///
/// Login success and attendance permission are different things: nothing here
/// runs anywhere but on the way into attendance, and nothing here runs at all
/// unless the server's `device` object asks for it. A session without that
/// object, or with `proof_required` and `enrollment_available` both false, is
/// [DeviceGateStatus.ready] with no request made.
///
/// When proof is required the token's proof must still have [refreshMargin]
/// left — enough for a face capture and its scoring — or a new one is made
/// before the attendance flow opens. A 403 `DEVICE_PROOF_REQUIRED` from an
/// attendance call is answered with **one** automatic re-proof
/// ([reproveAfterRefusal]); the person then retries.
class DeviceProofGate {
  DeviceProofGate({
    required DeviceProofRepository repository,
    DateTime Function()? now,
    this.refreshMargin = defaultRefreshMargin,
  }) : _repository = repository,
       _now = now ?? DateTime.now;

  /// How much of the proof window must remain to open attendance without a
  /// new proof. The window itself is the server's (10 minutes, D-SEC-03).
  static const Duration defaultRefreshMargin = Duration(minutes: 4);

  final DeviceProofRepository _repository;
  final DateTime Function() _now;
  final Duration refreshMargin;

  Future<DeviceGateDecision>? _proving;
  bool _refusalReproveSpent = false;
  Object? _enrollmentDeferredFor;
  bool _enrollmentDeferred = false;

  DeviceStatus? get device => _repository.current;

  /// Whether [device]'s proof still has [refreshMargin] to run.
  bool proofIsFresh(DeviceStatus device) {
    final until = device.proofValidUntil;

    return until != null && until.difference(_now()) > refreshMargin;
  }

  /// The decision from what the session already knows. No request.
  DeviceGateDecision evaluate() {
    final current = device;

    if (current == null) {
      return const DeviceGateDecision(DeviceGateStatus.ready);
    }

    if (!current.proofRequired) {
      final offer =
          current.enrollmentAvailable &&
          !current.keyEnrolled &&
          !_isEnrollmentDeferred;

      return DeviceGateDecision(
        offer ? DeviceGateStatus.offerEnrollment : DeviceGateStatus.ready,
        device: current,
      );
    }

    if (!current.keyEnrolled ||
        current.attendanceBlock == AttendanceBlock.deviceNotEnrolled) {
      return DeviceGateDecision(DeviceGateStatus.notEnrolled, device: current);
    }

    if (current.attendanceBlock != AttendanceBlock.deviceProofRequired &&
        proofIsFresh(current)) {
      return DeviceGateDecision(DeviceGateStatus.ready, device: current);
    }

    return DeviceGateDecision(DeviceGateStatus.needsProof, device: current);
  }

  /// On the way into attendance: [evaluate], and prove when that is needed.
  ///
  /// Each entry starts a new retry budget for [reproveAfterRefusal].
  Future<DeviceGateDecision> ensureReady() async {
    _refusalReproveSpent = false;

    final decision = evaluate();

    if (decision.status != DeviceGateStatus.needsProof) {
      return confirmKeystore(decision);
    }

    return confirmKeystore(await _prove());
  }

  /// A decision that would send the person to HR for a code, checked against
  /// what this phone can do first.
  ///
  /// Without this, a phone whose keystore cannot make a key was shown "Minta
  /// Kode dari HR", and refused only after the code had been fetched and
  /// typed (measured in the J4 journey: 4 taps, 3 inputs and a trip to HR for
  /// nothing). Now it is told at the door. An optional offer on such a phone
  /// is simply not made: attendance stays as it is today.
  Future<DeviceGateDecision> confirmKeystore(
    DeviceGateDecision decision,
  ) async {
    const leadsToACode = {
      DeviceGateStatus.notEnrolled,
      DeviceGateStatus.recovery,
      DeviceGateStatus.offerEnrollment,
    };

    if (!leadsToACode.contains(decision.status)) return decision;
    if (await _repository.keystoreAvailable()) return decision;

    if (decision.status == DeviceGateStatus.offerEnrollment) {
      return DeviceGateDecision(
        DeviceGateStatus.ready,
        device: decision.device,
      );
    }

    return DeviceGateDecision(
      DeviceGateStatus.keyUnavailable,
      device: decision.device,
      failure: DeviceProofFailure.keyUnsupported,
    );
  }

  /// Ask the server again, then [ensureReady]. For "Periksa Lagi" and retries.
  Future<DeviceGateDecision> refresh() async {
    try {
      await _repository.refreshStatus();
    } on DeviceProofException catch (error) {
      final decision = _decisionFor(error);

      if (decision.status == DeviceGateStatus.offline ||
          decision.status == DeviceGateStatus.sessionEnded ||
          decision.status == DeviceGateStatus.ready) {
        return decision;
      }
      // Otherwise decide from what the session already holds.
    }

    return ensureReady();
  }

  /// An attendance call answered 403 `DEVICE_PROOF_REQUIRED`: prove again,
  /// once. A second refusal before a successful clock is not retried
  /// automatically — it answers [DeviceGateStatus.failed].
  ///
  /// A proof that could not reach the server does not spend the retry.
  Future<DeviceGateDecision> reproveAfterRefusal() async {
    if (_refusalReproveSpent) {
      return DeviceGateDecision(
        DeviceGateStatus.failed,
        device: device,
        failure: DeviceProofFailure.failed,
      );
    }

    _refusalReproveSpent = true;

    final decision = await _prove();

    // Answers that say "not now" rather than "no" leave the retry for later:
    // no connection, a busy shift (429), a rate limiter that is down (503).
    if (decision.status == DeviceGateStatus.offline ||
        decision.failure == DeviceProofFailure.rateLimited ||
        decision.failure == DeviceProofFailure.limiterUnavailable) {
      _refusalReproveSpent = false;
    }

    return decision;
  }

  /// A clock was recorded: the next refusal earns its own re-proof.
  void resetRetryBudget() => _refusalReproveSpent = false;

  /// "Lanjut ke Absensi" on the enrolment offer: not asked again for this
  /// person until the app restarts. Never applies when proof is required.
  void deferEnrollment() {
    _enrollmentDeferred = true;
    _enrollmentDeferredFor = _repository.userKey;
  }

  bool get _isEnrollmentDeferred =>
      _enrollmentDeferred && _enrollmentDeferredFor == _repository.userKey;

  /// One proof at a time: concurrent callers share it.
  Future<DeviceGateDecision> _prove() =>
      _proving ??= _runProof().whenComplete(() => _proving = null);

  Future<DeviceGateDecision> _runProof() async {
    try {
      final proven = await _repository.prove();

      return DeviceGateDecision(
        DeviceGateStatus.ready,
        device: proven ?? device,
      );
    } on DeviceProofException catch (error) {
      return _decisionFor(error);
    }
  }

  DeviceGateDecision _decisionFor(DeviceProofException error) {
    final status = switch (error.failure) {
      // From a proof, "not enrolled" means this phone HAD a key the server no
      // longer holds: HR released it. Never from the cached status, which
      // [evaluate] reads without proving.
      DeviceProofFailure.notEnrolled => DeviceGateStatus.recovery,
      DeviceProofFailure.proofInvalid ||
      DeviceProofFailure.keyMissing => DeviceGateStatus.recovery,
      DeviceProofFailure.keyUnavailable ||
      DeviceProofFailure.keyUnsupported => DeviceGateStatus.keyUnavailable,
      DeviceProofFailure.offline => DeviceGateStatus.offline,
      DeviceProofFailure.sessionEnded => DeviceGateStatus.sessionEnded,
      // The feature is switched off on the server: attendance as today.
      DeviceProofFailure.disabled => DeviceGateStatus.ready,
      DeviceProofFailure.invalidCode ||
      DeviceProofFailure.challengeExpired ||
      DeviceProofFailure.rateLimited ||
      DeviceProofFailure.limiterUnavailable ||
      DeviceProofFailure.failed => DeviceGateStatus.failed,
    };

    return DeviceGateDecision(
      status,
      device: device,
      failure: error.failure,
      retryAfter: error.retryAfter,
    );
  }
}

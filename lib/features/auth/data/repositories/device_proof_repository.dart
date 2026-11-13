import '../../../../core/network/api_exception.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/json_parsers.dart';
import '../models/auth_user.dart';
import '../models/device_status.dart';
import '../models/enrollment_code.dart';
import '../services/device_auth_api_service.dart';
import '../services/device_key_service.dart';
import 'session_repository.dart';

/// What went wrong enrolling or proving, in terms a screen can act on.
enum DeviceProofFailure {
  /// `ENROLLMENT_CODE_INVALID`: wrong, expired, used or exhausted. The server
  /// deliberately does not say which.
  invalidCode,

  /// `DEVICE_NOT_ENROLLED`: the account has no active key.
  notEnrolled,

  /// `DEVICE_PROOF_INVALID`, or a local key that does not match the enrolled
  /// one. Only HR can move attendance to this phone.
  proofInvalid,

  /// A key is enrolled for the account but this install has none: reinstalled,
  /// reset, or a different phone. Only HR can help.
  keyMissing,

  /// The keystore cannot make or use a key on this phone.
  keyUnavailable,

  /// `DEVICE_KEY_UNSUPPORTED`: the server refused the key itself.
  keyUnsupported,

  /// `CHALLENGE_EXPIRED` / `CHALLENGE_REUSED`, still, after one fresh challenge.
  challengeExpired,

  /// No connection to the server.
  offline,

  /// 429.
  rateLimited,

  /// 404 `DEVICE_ENROLLMENT_DISABLED`: the backend's dark flag is off.
  disabled,

  /// 401: the token is gone. Either the session ended, or an enrolment or
  /// proof did reach the server and replaced the token, and its answer was
  /// lost. The app has already signed out; signing in again finishes the job
  /// without a new HR code when the key was enrolled.
  sessionEnded,

  /// Anything else.
  failed,
}

class DeviceProofException implements Exception {
  const DeviceProofException(this.failure, {this.code, this.status});

  final DeviceProofFailure failure;
  final String? code;
  final int? status;

  @override
  String toString() =>
      'DeviceProofException(${failure.name}, $status ${code ?? ''})';
}

/// Enrolment, proof and status for the attendance device key (ADR-D §5, §7).
///
/// ## The token is replaced
///
/// Enrolment and proof answer the login shape with a **new** bearer token and
/// delete the one that asked. The new token goes through
/// [SessionRepository.save] — the same keychain path a sign-in uses — so every
/// request after this one carries it. The `device` object is kept on the
/// session user, where `AuthUser.canRecordAttendance` already reads it.
///
/// ## One key per account (PO 4.2.8)
///
/// The key is named by [DeviceKeyService.aliasFor] the signed-in user in the
/// current workspace. Another account, or another workspace, on the same phone
/// has its own key and never touches this one.
///
/// ## A bad connection never costs a key
///
/// When an enrolment or proof gets no answer, the request may still have
/// landed. `auth/device-status` is asked before anything is redone: a 401 means
/// the token was replaced (sign in again, no new code needed); the server
/// holding this phone's key means the enrolment happened. A retry reuses the
/// key on the phone, and a key is never replaced while the server still holds
/// it — that would orphan an enrolled key and send the person back to HR.
class DeviceProofRepository {
  DeviceProofRepository({
    required DeviceAuthApiService api,
    required DeviceKeyService keys,
    required SessionRepository session,
    String? Function()? workspace,
    DateTime Function()? now,
  }) : _api = api,
       _keys = keys,
       _session = session,
       _workspace = workspace ?? (() => null),
       _now = now ?? DateTime.now;

  final DeviceAuthApiService _api;
  final DeviceKeyService _keys;
  final SessionRepository _session;
  final String? Function() _workspace;
  final DateTime Function() _now;

  /// The device object from the session, or null when the server never sent
  /// one.
  DeviceStatus? get current => DeviceStatus.fromUser(_session.user);

  /// Who is signed in, and where, so per-person decisions do not cross a
  /// sign-out or a workspace switch. User ids are per workspace: id 7 in one
  /// workspace and id 7 in another are two people (Putaran 8, J7).
  Object? get userKey {
    final id = _session.user?.id;

    return id == null ? null : '${_workspace() ?? ''}|$id';
  }

  /// The keystore alias of the signed-in account in this workspace.
  String get keyAlias {
    final userId = _session.user?.id;

    if (userId == null) {
      throw const DeviceProofException(
        DeviceProofFailure.failed,
        code: 'NO_SESSION',
      );
    }

    return DeviceKeyService.aliasFor(
      workspace: _workspace() ?? '',
      userId: userId,
    );
  }

  /// The fingerprint of this account's key on this phone, or null when there
  /// is none.
  Future<String?> localFingerprint() async {
    final alias = keyAlias;

    if (!await _key(() => _keys.exists(alias))) return null;

    return _key(() => _keys.fingerprint(alias));
  }

  /// Whether this phone can make and hold an attendance key at all.
  ///
  /// Asked before anybody is sent to HR for a code: a phone without a usable
  /// keystore could never use one (Putaran 7, J4). A keystore that cannot be
  /// asked counts as unable; a missing session is not this method's verdict.
  Future<bool> keystoreAvailable() async {
    try {
      final capabilities = await _keys.capabilities(alias: keyAlias);

      return capabilities.available && capabilities.platform != 'unknown';
    } on DeviceKeyException {
      return false;
    } on DeviceProofException {
      return true;
    }
  }

  /// `GET auth/device-status`, kept on the session.
  Future<DeviceStatus> refreshStatus() async {
    final body = await _call(_api.status);
    final raw = body['data'] is Map ? body['data'] : body;
    final device = DeviceStatus.tryParse(raw);

    if (device == null) {
      throw const DeviceProofException(
        DeviceProofFailure.failed,
        code: 'malformed_response',
      );
    }

    await _keepDevice(Map<String, dynamic>.from(raw as Map));

    return device;
  }

  /// Enrol this phone for the signed-in account with an HR activation code.
  ///
  /// capabilities → generate key → challenge(enroll, public_key) → sign
  /// `signing_input` → enrolment.
  ///
  /// [freshKey] asks for a new key on the first attempt of a visit (a rebind
  /// replaces this account's key); a retry passes false and reuses the key
  /// already sent. Even with [freshKey], a key the server already holds for
  /// this account is kept and the enrolment is reported as done.
  Future<DeviceStatus?> enroll(String code, {bool freshKey = true}) async {
    final normalized = EnrollmentCode.normalize(code);

    if (!EnrollmentCode.isValid(normalized)) {
      throw const DeviceProofException(
        DeviceProofFailure.invalidCode,
        code: 'ENROLLMENT_CODE_FORMAT',
      );
    }

    final alias = keyAlias;
    final capabilities = await _key(() => _keys.capabilities(alias: alias));

    if (!capabilities.available || capabilities.platform == 'unknown') {
      throw const DeviceProofException(
        DeviceProofFailure.keyUnavailable,
        code: 'KEY_UNAVAILABLE',
      );
    }

    await _forgetLegacyKey();

    // About to replace a key: first make sure the server is not already
    // holding it, from an earlier attempt whose answer never arrived.
    if (freshKey && await _key(() => _keys.exists(alias))) {
      final status = await refreshStatus();

      if (await _holdsThisKey(status, alias)) return status;
    }

    final generated = await _key(
      () => _keys.generate(alias: alias, replace: freshKey),
    );
    final publicKey = await _key(() => _keys.publicKey(alias));

    final Map<String, dynamic> body;

    try {
      body = await _withFreshChallenge(() async {
        final challenge = DeviceChallenge.fromBody(
          await _api.challenge(purpose: 'enroll', publicKey: publicKey),
        );
        final signature = await _key(
          () => _keys.signText(alias, challenge.signingInput),
        );

        return _api.enroll(
          enrollmentCode: normalized,
          publicKey: publicKey,
          challenge: challenge.challenge,
          signature: signature,
          platform: capabilities.platform,
          hardwareBacked: generated.hardwareBackedClaimed,
        );
      });
    } on DeviceProofException catch (error) {
      if (error.failure != DeviceProofFailure.offline) rethrow;

      final status = await _statusAfterNoAnswer(error);

      if (await _holdsThisKey(status, alias)) return status;

      rethrow;
    }

    return _adopt(body);
  }

  /// Prove possession of this account's enrolled key and take the fresh token.
  ///
  /// challenge(proof) → sign `signing_input` → proof. Never enrols: a missing
  /// or different key is [DeviceProofFailure.keyMissing] or
  /// [DeviceProofFailure.proofInvalid], which only HR can resolve.
  Future<DeviceStatus?> prove() async {
    final alias = keyAlias;

    if (!await _key(() => _keys.exists(alias))) {
      throw const DeviceProofException(
        DeviceProofFailure.keyMissing,
        code: 'KEY_MISSING',
      );
    }

    // A key that is not the enrolled one cannot pass, so the round trip is
    // not spent finding that out.
    final enrolled = current?.keyFingerprint;

    if (enrolled != null) {
      final local = await _key(() => _keys.fingerprint(alias));

      if (_unpadded(local) != _unpadded(enrolled)) {
        throw const DeviceProofException(
          DeviceProofFailure.proofInvalid,
          code: 'KEY_MISMATCH',
        );
      }
    }

    final Map<String, dynamic> body;

    try {
      body = await _withFreshChallenge(() async {
        final challenge = DeviceChallenge.fromBody(
          await _api.challenge(purpose: 'proof'),
        );
        final signature = await _key(
          () => _keys.signText(alias, challenge.signingInput),
        );

        return _api.prove(challenge: challenge.challenge, signature: signature);
      });
    } on DeviceProofException catch (error) {
      if (error.failure != DeviceProofFailure.offline) rethrow;

      final status = await _statusAfterNoAnswer(error);

      if (!status.keyEnrolled) {
        throw const DeviceProofException(DeviceProofFailure.notEnrolled);
      }

      if (!await _holdsThisKey(status, alias)) {
        throw const DeviceProofException(
          DeviceProofFailure.proofInvalid,
          code: 'KEY_MISMATCH',
        );
      }

      final until = status.proofValidUntil;

      // This token is still accepted, so the proof did not replace it; it
      // counts only if the token is already proven.
      if (status.attendanceBlock == null &&
          until != null &&
          until.isAfter(_now())) {
        return status;
      }

      rethrow;
    }

    return _adopt(body);
  }

  bool _legacyKeyForgotten = false;

  /// Remove the key Putaran 4 test builds kept under one fixed name for every
  /// account ([DeviceKeyService.legacyAlias]). It is never used for a proof —
  /// current keys are per account — so removing it cannot cost anybody their
  /// enrolment. Once per run, at an enrolment (the only time a phone that
  /// held it can need attendance again), and silent: there is usually nothing
  /// there, and a keystore that refuses changes nothing for this account.
  Future<void> _forgetLegacyKey() async {
    if (_legacyKeyForgotten) return;
    _legacyKeyForgotten = true;

    try {
      await _keys.delete(DeviceKeyService.legacyAlias);
    } on DeviceKeyException catch (error) {
      AppLogger.info('Legacy device key not removed: ${error.code}');
    }
  }

  /// After a request that got no answer: what the server now says, or the
  /// original failure when it cannot be asked either. A 401 is passed on —
  /// the token was replaced, or the session is over.
  Future<DeviceStatus> _statusAfterNoAnswer(
    DeviceProofException original,
  ) async {
    AppLogger.info('No answer from a device request; asking for its status.');

    try {
      return await refreshStatus();
    } on DeviceProofException catch (error) {
      if (error.failure == DeviceProofFailure.sessionEnded) rethrow;

      throw original;
    }
  }

  /// Whether [status] says the server holds this account's key on this phone.
  Future<bool> _holdsThisKey(DeviceStatus status, String alias) async {
    final enrolled = status.keyFingerprint;

    if (!status.keyEnrolled || enrolled == null) return false;
    if (!await _key(() => _keys.exists(alias))) return false;

    final local = await _key(() => _keys.fingerprint(alias));

    return _unpadded(local) == _unpadded(enrolled);
  }

  static String _unpadded(String value) => value.replaceAll('=', '');

  /// Run [attempt]; on an expired or reused challenge, once more with a new
  /// one (ADR-D §7: "ambil ulang sekali").
  Future<Map<String, dynamic>> _withFreshChallenge(
    Future<Map<String, dynamic>> Function() attempt,
  ) async {
    try {
      return await attempt();
    } on ApiException catch (error) {
      if (!_isStaleChallenge(error)) throw _translate(error);

      AppLogger.info('Device challenge went stale; asking for a new one.');
    }

    return _call(attempt);
  }

  static bool _isStaleChallenge(ApiException error) =>
      error.code == DeviceErrorCodes.challengeExpired ||
      error.code == DeviceErrorCodes.challengeReused;

  Future<Map<String, dynamic>> _call(
    Future<Map<String, dynamic>> Function() request,
  ) async {
    try {
      return await request();
    } on ApiException catch (error) {
      throw _translate(error);
    }
  }

  Future<T> _key<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on DeviceKeyException catch (error) {
      AppLogger.warning('Device key unavailable: ${error.code}');
      throw DeviceProofException(
        error.failure == DeviceKeyFailure.missing
            ? DeviceProofFailure.keyMissing
            : DeviceProofFailure.keyUnavailable,
        code: error.code,
      );
    }
  }

  /// The server's verdict, as a failure kind. Never from its prose.
  static DeviceProofException translate(ApiException error) =>
      _translate(error);

  static DeviceProofException _translate(ApiException error) {
    final failure = switch (error.code) {
      DeviceErrorCodes.enrollmentCodeInvalid => DeviceProofFailure.invalidCode,
      DeviceErrorCodes.notEnrolled => DeviceProofFailure.notEnrolled,
      DeviceErrorCodes.proofInvalid => DeviceProofFailure.proofInvalid,
      DeviceErrorCodes.keyUnsupported => DeviceProofFailure.keyUnsupported,
      DeviceErrorCodes.challengeExpired ||
      DeviceErrorCodes.challengeReused => DeviceProofFailure.challengeExpired,
      DeviceErrorCodes.enrollmentDisabled => DeviceProofFailure.disabled,
      _ when error.isUnauthenticated => DeviceProofFailure.sessionEnded,
      _ when error.isConnectionFailure => DeviceProofFailure.offline,
      _ when error.status == 429 => DeviceProofFailure.rateLimited,
      _ => DeviceProofFailure.failed,
    };

    if (failure == DeviceProofFailure.failed) {
      AppLogger.warning(
        'Device request refused (${error.status} ${error.code ?? ''}).',
      );
    }

    return DeviceProofException(
      failure,
      code: error.code,
      status: error.status,
    );
  }

  /// Persist the token and device object of an enrolment or proof reply.
  ///
  /// The token is the only one that works from now on — the server deleted the
  /// one that asked — so it is saved even if the reply leaves out the user.
  Future<DeviceStatus?> _adopt(Map<String, dynamic> reply) async {
    final body = reply['token'] == null && reply['data'] is Map
        ? Map<String, dynamic>.from(reply['data'] as Map)
        : reply;
    final token = asString(body['token']);

    if (token == null) {
      throw const DeviceProofException(
        DeviceProofFailure.failed,
        code: 'malformed_device_response',
      );
    }

    final previous = _session.user;
    final raw = <String, dynamic>{
      if (body['user'] is Map)
        ...Map<String, dynamic>.from(body['user'] as Map)
      else if (previous != null)
        ...previous.raw,
    };

    for (final key in const ['abilities', 'device']) {
      if (body.containsKey(key)) {
        raw[key] = body[key];
      } else if (previous?.raw.containsKey(key) ?? false) {
        raw[key] = previous!.raw[key];
      }
    }

    await _session.save(token: token, user: AuthUser.fromJson(raw));

    return DeviceStatus.tryParse(raw['device']);
  }

  Future<void> _keepDevice(Map<String, dynamic> device) async {
    final user = _session.user;

    if (user == null) return;

    await _session.updateUser(
      AuthUser.fromJson({...user.raw, 'device': device}),
    );
  }
}

import '../../../../core/network/api_exception.dart';
import '../../../../core/utils/json_parsers.dart';
import 'auth_user.dart';

/// The machine-readable codes of the attendance device contract (ADR-D §7).
///
/// Constants, because a screen chooses what to do from these and never from
/// the server's sentence.
class DeviceErrorCodes {
  const DeviceErrorCodes._();

  static const proofRequired = 'DEVICE_PROOF_REQUIRED';
  static const proofInvalid = 'DEVICE_PROOF_INVALID';
  static const notEnrolled = 'DEVICE_NOT_ENROLLED';
  static const notRegistered = 'DEVICE_NOT_REGISTERED';
  static const keyUnsupported = 'DEVICE_KEY_UNSUPPORTED';
  static const enrollmentCodeInvalid = 'ENROLLMENT_CODE_INVALID';
  static const challengeExpired = 'CHALLENGE_EXPIRED';
  static const challengeReused = 'CHALLENGE_REUSED';
  static const enrollmentDisabled = 'DEVICE_ENROLLMENT_DISABLED';
}

/// Why attendance is not available on this phone, as `device.attendance_block`
/// says.
enum AttendanceBlock {
  /// Enforcement is off and this phone is not the registered one. Today's
  /// binding behaviour, unchanged.
  deviceNotRegistered,

  /// Enforcement is on and the account has no active key.
  deviceNotEnrolled,

  /// A key is enrolled; this token has not (or no longer) proven it.
  deviceProofRequired,

  /// A value this build does not know. Treated as "ask the server".
  unknown;

  static AttendanceBlock? parse(Object? raw) => switch (asString(raw)) {
    null => null,
    DeviceErrorCodes.notRegistered => deviceNotRegistered,
    DeviceErrorCodes.notEnrolled => deviceNotEnrolled,
    DeviceErrorCodes.proofRequired => deviceProofRequired,
    _ => unknown,
  };
}

/// The `device` object of the login, enrolment, proof and status replies.
///
/// Every new field defaults to the value that means "nothing changes": a
/// server that predates ADR-D sends none of them, and such a session must look
/// and behave exactly as it did before.
class DeviceStatus {
  const DeviceStatus({
    this.id,
    this.isRegisteredDevice,
    this.canRecordAttendance,
    this.proofRequired = false,
    this.enrollmentAvailable = false,
    this.keyEnrolled = false,
    this.keyFingerprint,
    this.proofValidUntil,
    this.attendanceBlock,
  });

  factory DeviceStatus.fromJson(Map<String, dynamic> json) => DeviceStatus(
    id: asString(json['id']),
    isRegisteredDevice: asBool(json['is_registered_device']),
    canRecordAttendance: asBool(json['can_record_attendance']),
    proofRequired: asBool(json['proof_required']) ?? false,
    enrollmentAvailable: asBool(json['enrollment_available']) ?? false,
    keyEnrolled: asBool(json['key_enrolled']) ?? false,
    keyFingerprint: asString(json['key_fingerprint']),
    proofValidUntil: asDate(json['proof_valid_until']),
    attendanceBlock: AttendanceBlock.parse(json['attendance_block']),
  );

  /// Null unless [raw] is an object.
  static DeviceStatus? tryParse(Object? raw) =>
      raw is Map ? DeviceStatus.fromJson(Map<String, dynamic>.from(raw)) : null;

  /// The device object the session keeps, if the server sent one.
  static DeviceStatus? fromUser(AuthUser? user) =>
      tryParse(user?.raw['device']);

  final String? id;
  final bool? isRegisteredDevice;
  final bool? canRecordAttendance;
  final bool proofRequired;
  final bool enrollmentAvailable;
  final bool keyEnrolled;

  /// `base64url(SHA-256(SPKI DER))` without padding. Never shown whole.
  final String? keyFingerprint;

  final DateTime? proofValidUntil;
  final AttendanceBlock? attendanceBlock;

  /// A short "ID perangkat" an employee can read out to HR: exactly what the
  /// HR panel shows for the active key — `…` and the last six characters of
  /// the fingerprint (`DeviceStatusSummary::key`). Never the whole
  /// fingerprint. Null when there is no key.
  ///
  /// It used to be the first four bytes in hex (`2257-D8C1`), which the panel
  /// never shows, so the two could not be matched on a phone call (Putaran 8).
  String? get shortId {
    final fingerprint = keyFingerprint;

    if (fingerprint == null || fingerprint.isEmpty) return null;

    return fingerprint.length <= 6
        ? '…$fingerprint'
        : '…${fingerprint.substring(fingerprint.length - 6)}';
  }
}

/// A challenge from `POST auth/device-challenge`.
///
/// [signingInput] is signed **byte for byte** as UTF-8 and is never rebuilt on
/// the handset: the server reconstructs it from its own facts when it verifies
/// (ADR-D §7).
class DeviceChallenge {
  const DeviceChallenge({
    required this.challenge,
    required this.purpose,
    required this.signingInput,
    this.expiresAt,
  });

  /// Read `{data: {challenge, purpose, expires_at, signing_input}}`.
  factory DeviceChallenge.fromBody(Map<String, dynamic> body) {
    final data = body['data'] is Map
        ? Map<String, dynamic>.from(body['data'] as Map)
        : body;
    final challenge = data['challenge'];
    final signingInput = data['signing_input'];

    // Not `asString`: that trims, and the bytes signed must be the bytes sent.
    if (challenge is! String ||
        challenge.isEmpty ||
        signingInput is! String ||
        signingInput.isEmpty) {
      throw const ApiException(
        'Kesalahan format data dari server.',
        code: 'malformed_response',
      );
    }

    return DeviceChallenge(
      challenge: challenge,
      purpose: asString(data['purpose']) ?? '',
      signingInput: signingInput,
      expiresAt: asDate(data['expires_at']),
    );
  }

  final String challenge;
  final String purpose;
  final String signingInput;
  final DateTime? expiresAt;
}

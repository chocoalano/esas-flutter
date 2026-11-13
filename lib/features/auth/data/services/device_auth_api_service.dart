import '../../../../core/config/api_routes.dart';
import '../../../../core/network/api_client.dart';

/// The four attendance-device endpoints (ADR-D §7).
///
/// All of them are authenticated with the session token and answer 404
/// `DEVICE_ENROLLMENT_DISABLED` while the backend's dark flag is off.
/// Enrolment and proof **replace** the token: the reply is the login shape and
/// the token that made the request no longer exists afterwards.
class DeviceAuthApiService {
  const DeviceAuthApiService(this._client);

  final ApiClient _client;

  /// [purpose] is `enroll` or `proof`; [publicKey] (SPKI DER, base64) is
  /// required for `enroll`.
  Future<Map<String, dynamic>> challenge({
    required String purpose,
    String? publicKey,
  }) {
    return _client.postObject(ApiRoutes.deviceChallenge, {
      'purpose': purpose,
      'public_key': ?publicKey,
    });
  }

  Future<Map<String, dynamic>> enroll({
    required String enrollmentCode,
    required String publicKey,
    required String challenge,
    required String signature,
    required String platform,
    bool? hardwareBacked,
  }) {
    return _client.postObject(ApiRoutes.deviceEnrollment, {
      'enrollment_code': enrollmentCode,
      'public_key': publicKey,
      'challenge': challenge,
      'signature': signature,
      'platform': platform,
      'hardware_backed': ?hardwareBacked,
    });
  }

  Future<Map<String, dynamic>> prove({
    required String challenge,
    required String signature,
  }) {
    return _client.postObject(ApiRoutes.deviceProof, {
      'challenge': challenge,
      'signature': signature,
    });
  }

  Future<Map<String, dynamic>> status() =>
      _client.getObject(ApiRoutes.deviceStatus);
}

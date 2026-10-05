import 'dart:convert';
import 'dart:io';

import '../../../../core/config/api_routes.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/idempotency_key.dart';
import '../../../../core/network/upload.dart';

/// The attendance endpoints.
///
/// ## `Idempotency-Key` on every write
///
/// All three writes take an optional key and send it as the header
/// [IdempotencyKey.header]. The server answers a repeat of the *same* key with
/// the *first* response instead of running the write again — which is the only
/// safe answer to the retry a handset must make when a reply is lost in transit,
/// because it cannot tell "never arrived" from "arrived, answer lost".
///
/// It is **optional on both sides**, deliberately. A server that predates the
/// change ignores an unknown header, and this server treats a missing one as
/// "run it unguarded" — so the header can be deployed to handsets before or
/// after the backend, in either order, with no coordination.
///
/// A key names an **attempt**, never a call. Minting one per send would be an
/// app that speaks the protocol correctly and gets none of the protection; the
/// controller owns "the person asked for this once" and passes the same value
/// through every retry of it.
class AttendanceApiService {
  const AttendanceApiService(this._client);

  final ApiClient _client;

  /// Everything the clock screen needs before it draws anything.
  ///
  /// Shift, today's attendance, `next_presence`, `attendance_enabled`,
  /// `face_enrolled`, `can_issue_qr`, `location`, `server_time`. Takes no
  /// employee — the token names them.
  ///
  /// The same endpoint Beranda calls. Asking it here is not a second request
  /// bought for a subtitle: it is the only authority on which methods this
  /// person may use and where the geofence is, and the alternative was reading
  /// company coordinates out of a cached login payload that no longer carries
  /// them.
  Future<Map<String, dynamic>> context() =>
      _client.getObject(ApiRoutes.attendanceContext);

  /// The employee's own attendance history, paginated.
  ///
  /// Takes no employee id. It used to send `search[user_id]`, which is a filter
  /// the client chose — and a filter the client chooses is a filter the client
  /// can change. `lat_in`, `long_in` and the capture photograph are all on these
  /// rows, so whose rows come back is the server's decision, made from the
  /// token.
  ///
  /// The query is a map rather than a hand-built string. The controller used to
  /// concatenate `'?page=$p&limit=$n'`, which corrupts the request the moment a
  /// value contains `&` (MED-01).
  Future<Map<String, dynamic>> history({
    required int page,
    required int perPage,
    String? startDate,
    String? endDate,
  }) {
    return _client.getObject(
      ApiRoutes.attendances,
      query: {
        'page': page,
        'per_page': perPage,
        if (startDate != null) 'from': startDate,
        if (endDate != null) 'to': endDate,
      },
    );
  }

  /// The same window, counted: worked days, late arrivals, leave, absence.
  ///
  /// Counted by the same code payroll uses, which is the point of asking the
  /// server for it. Two implementations of "how many days did this person work"
  /// is two answers, and the one on the handset had better be the one the wage
  /// is calculated from.
  Future<Map<String, dynamic>> summary({int? year, int? month}) =>
      _client.getObject(
        ApiRoutes.attendanceSummary,
        query: {
          if (year != null) 'year': year,
          if (month != null) 'month': month,
        },
      );

  /// Redeem a code a DEPARTMENT is displaying.
  ///
  /// `token` is the 48-character secret out of the code's JSON. The department,
  /// the expiry and single use are all the server's checks — a client-side one
  /// is UX, not a control, and the version of it that lived here **failed open**
  /// on `null == null` (CRIT-04).
  ///
  /// The coordinates go with it because the company may require them, and a
  /// clock posted without them from a geofenced workspace is refused with
  /// `location_required`. They used to be collected, validated, and then left
  /// behind in the controller.
  Future<Map<String, dynamic>> redeemDepartmentQr({
    required String token,
    double? latitude,
    double? longitude,
    double? accuracy,
    bool isMocked = false,
    String? idempotencyKey,
  }) {
    return _client.postObject(
      ApiRoutes.qrPresenceRedeem,
      {
        'token': token,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (accuracy != null) 'accuracy': accuracy,
        'is_mocked': isMocked,
      },
      headers: IdempotencyKey.headerFor(idempotencyKey),
    );
  }

  /// Redeem a code read off an attendance MACHINE's screen.
  ///
  /// `code` — not `token`, which is what this method used to send to an endpoint
  /// that has never had a field by that name — is the opaque signed string the
  /// machine displays. `type` is required: a machine code says which machine and
  /// when, and nothing at all about direction, so the direction comes from
  /// `next_presence` in the attendance context rather than from the handset
  /// guessing.
  Future<Map<String, dynamic>> redeemMachineQr({
    required String code,
    required String type,
    double? latitude,
    double? longitude,
    double? accuracy,
    bool isMocked = false,
    String? idempotencyKey,
  }) {
    return _client.postObject(ApiRoutes.kioskQr, {
      'code': code,
      'type': type,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (accuracy != null) 'accuracy': accuracy,
      'is_mocked': isMocked,
    }, headers: IdempotencyKey.headerFor(idempotencyKey));
  }

  /// Ask for the movements this person must perform in front of the camera.
  ///
  /// Asked for **after** they have chosen to clock, never on opening the screen:
  /// the whole security value of the sequence is that it could not have been
  /// prepared for, and a challenge minted early is one a recording made in the
  /// car park can answer.
  Future<Map<String, dynamic>> faceChallenge({required String type}) =>
      _client.postObject(ApiRoutes.faceChallenge, {'type': type});

  /// Send the still, the signed challenge, and what ML Kit measured on this
  /// handset.
  ///
  /// `liveness` travels as a JSON string rather than as nested fields: it goes
  /// through multipart, and a document the server parses once survives form
  /// encoding better than a shape that has to be flattened into
  /// `liveness[actions][0][measured]`.
  Future<Map<String, dynamic>> submitFace({
    required File image,
    required String challengeToken,
    required String challengeId,
    required String type,
    required Map<String, dynamic> liveness,
    double? latitude,
    double? longitude,
    double? accuracy,
    bool isMocked = false,
    String? idempotencyKey,
  }) {
    return _client.postForm(
      ApiRoutes.faceAttendance,
      {
        'challenge_token': challengeToken,
        'challenge_id': challengeId,
        'type': type,
        'liveness': jsonEncode(liveness),
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (accuracy != null) 'accuracy': accuracy,
        'is_mocked': isMocked,
      },
      files: {'image': Upload.file(image)},
      headers: IdempotencyKey.headerFor(idempotencyKey),
      // The backend scores the capture before it answers, and waits on the
      // face service to do it. The ordinary deadline is shorter than that wait.
      awaitsScoring: true,
    );
  }
}

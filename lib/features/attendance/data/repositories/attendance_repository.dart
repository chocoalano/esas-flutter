import 'dart:io';

import 'package:flutter/foundation.dart' show kDebugMode;

import '../../../../core/network/api_exception.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/tenancy/tenant_context.dart';
import '../../../../core/utils/json_parsers.dart';
import '../../../../features/auth/data/repositories/session_repository.dart';
import '../models/attendance.dart';
import '../models/attendance_history_page.dart';
import '../models/attendance_month_totals.dart';
import '../models/attendance_context.dart';
import '../models/scanned_code.dart';
import '../services/attendance_api_service.dart';

/// The shape of a refusal, which is what decides how the screen answers it.
///
/// The server already sends a sentence an employee can read; what it cannot
/// send is what the app should *do* next, and that is the whole of what this
/// enum carries. The five outcomes want five different screens: a code the
/// scanner should carry straight on from, a code that is spent, a clock that was
/// refused for a reason about the person rather than the code, a face that was
/// not matched, and a request whose answer never arrived.
///
/// Chosen from the server's `code`, never from its prose. Matching on Indonesian
/// substrings is how a backend copy edit becomes a client-side bug nobody can
/// reproduce.
enum RefusalKind {
  /// Not an attendance code at all — a shipping label, a Wi-Fi QR, a poster.
  /// The scanner keeps running.
  unrecognised,

  /// One of ours, and no longer usable: expired, already spent, another
  /// workspace's, another department's. The camera stops and waits for an
  /// explicit retry, because the rejected code may still be in front of it.
  codeRejected,

  /// The code was fine; this person may not clock, or may not clock from here.
  /// Geofence, disabled account, a clock already on the record.
  clockRejected,

  /// The movements or the face were not accepted. A new attempt needs a new
  /// challenge, so the sequence restarts rather than resending.
  faceRejected,

  /// Nothing was written, and the reason is ours or the network's.
  transient,

  /// It was sent and never answered. The row **may** exist. Offering a retry
  /// here walks somebody into a duplicate the server will refuse.
  unanswered,
}

/// Why an attempt did not become a record.
class AttendanceRefusal {
  const AttendanceRefusal({
    required this.kind,
    required this.message,
    this.code,
  });

  final RefusalKind kind;

  /// A sentence safe to put on screen as-is. The server's own where there is
  /// one — it knows things the handset does not, such as how far outside the
  /// fence somebody actually is.
  final String message;

  /// The server's machine-readable reason, where it sent one. Kept so the
  /// screen can choose an action without reading the prose.
  final String? code;

  /// Whether a retry can be useful for this refusal.
  ///
  /// The controller still waits for an explicit retry before reopening the
  /// camera, even for these refusal kinds, because the old QR may remain in
  /// front of the lens.
  bool get scannerMayResume =>
      kind == RefusalKind.unrecognised || kind == RefusalKind.codeRejected;
}

/// A clock the server has confirmed it wrote.
class AttendanceReceipt {
  const AttendanceReceipt({
    required this.direction,
    required this.message,
    this.recordedAt,
  });

  final PresenceDirection direction;

  /// The server's confirmation sentence.
  final String message;

  /// The clock the server actually recorded, as text — `08:03:11`.
  ///
  /// Nullable, and drawn only when present. The handset's own clock is not a
  /// substitute: a phone three minutes fast would print a time that disagrees
  /// with the payslip, on the one screen an employee would take a screenshot of.
  final String? recordedAt;
}

sealed class AttendanceOutcome {
  const AttendanceOutcome();
}

class AttendanceAccepted extends AttendanceOutcome {
  const AttendanceAccepted(this.receipt);

  final AttendanceReceipt receipt;
}

class AttendanceRefused extends AttendanceOutcome {
  const AttendanceRefused(this.refusal);

  final AttendanceRefusal refusal;
}

/// Where a clock was taken from, when the company asks.
class ClockPosition {
  const ClockPosition({
    required this.latitude,
    required this.longitude,
    required this.takenAt,
    this.accuracy,
    this.isMocked = false,
  });

  final double latitude;
  final double longitude;

  /// When the device produced this fix.
  ///
  /// Carried rather than sent: the write endpoints take `latitude`, `longitude`,
  /// `accuracy` and `is_mocked`, and there is no field for a timestamp — so
  /// freshness is this side's responsibility. It is kept so the age of a fix is
  /// a fact the screen can act on instead of an assumption.
  final DateTime takenAt;

  /// The device's own error estimate, in metres. The server widens the fence by
  /// it rather than narrowing, and caps it.
  final double? accuracy;

  /// The handset saying its fix came from a mock provider. Reported honestly:
  /// a client that omits it tells the server nothing, and one that reports it
  /// tells it something no server-side check could work out alone.
  final bool isMocked;

  Duration ageAt(DateTime now) => now.difference(takenAt);
}

class AttendanceRepository {
  const AttendanceRepository({
    required AttendanceApiService api,
    required SessionRepository session,
    required TenantContext tenant,
  }) : _api = api,
       _session = session,
       _tenant = tenant;

  final AttendanceApiService _api;
  final SessionRepository _session;
  final TenantContext _tenant;

  /// The workspace this handset is signed in to, for the fail-closed check on a
  /// scanned code.
  String? get workspace => _tenant.tenant;

  /// What this person may do, where from, and which clock they still owe.
  Future<AttendanceContext> context() async =>
      AttendanceContext.fromJson(await _api.context());

  /// The employee's own attendance rows, and what the window adds up to.
  Future<AttendanceHistoryPage> history({
    required int page,
    required int perPage,
    String? startDate,
    String? endDate,
  }) async {
    // No employee id. Whose rows come back is the server's decision, made from
    // the token - `lat_in`, `long_in` and the capture photograph are all on
    // these rows, and a filter the client chooses is a filter the client can
    // change.
    final body = await _api.history(
      page: page,
      perPage: perPage,
      startDate: startDate,
      endDate: endDate,
    );

    return AttendanceHistoryPage(
      rows: asModelList(asPage(body), Attendance.fromJson),
      // Absent on later pages and on older deployments alike, and absent means
      // "keep what you had" rather than "there is nothing".
      monthTotals: AttendanceMonthTotals.tryParseAll(body),
    );
  }

  /// Redeem a scanned code, whichever of the two it turned out to be.
  ///
  /// [fallbackDirection] is `next_presence` from the attendance context. A
  /// department code carries its own direction and ignores it; a machine code
  /// carries none, and without one there is nothing to send — so the attempt is
  /// refused here rather than posting a guess.
  ///
  /// ## Expiry is NOT judged here, and that is deliberate
  ///
  /// Both codes carry an expiry and both models can read it — see
  /// [QrPayload.isExpired] and [MachineCode.isExpired] — but neither is acted
  /// on, because acting on it would mean judging it against **the handset's
  /// clock**. A phone running five minutes fast would refuse every code its
  /// owner scanned, permanently, with a message blaming the code; a phone
  /// running slow would send codes it believed were live. Neither decision is
  /// worth making locally when the server makes it correctly.
  ///
  /// The round trip it costs buys nothing away either: both endpoints test
  /// expiry **before** claiming the code — `QrPresenceController::redeem` calls
  /// `isActive()` before `wasUsedBy()`, and `KioskQrRedemptionController` calls
  /// `hasExpired()` before inserting the `QrRedemption` row — so a photograph of
  /// a stale screen is refused without spending anything and comes back as
  /// `qr_expired` or `code_expired`, with the scanner still running.
  ///
  /// The server is the authority for the workspace as well. The QR metadata is
  /// not necessarily the same identifier as the client tenant slug (some code
  /// issuers use an internal id), so rejecting locally can turn a valid QR into
  /// a false "workspace lain" refusal. The active tenant is already sent as
  /// `X-Tenant` by the API client; the server can validate both sides together.
  Future<AttendanceOutcome> redeem(
    ScannedCode scanned, {
    PresenceDirection? fallbackDirection,
    ClockPosition? position,
    String? idempotencyKey,
  }) async {
    switch (scanned) {
      case DepartmentCode(payload: final payload):
        final direction =
            PresenceDirection.parse(payload.type) ?? fallbackDirection;

        return _guard(
          direction,
          () => _api.redeemDepartmentQr(
            token: payload.token,
            latitude: position?.latitude,
            longitude: position?.longitude,
            accuracy: position?.accuracy,
            isMocked: position?.isMocked ?? false,
            idempotencyKey: idempotencyKey,
          ),
        );

      case MachineCode(:final raw):
        if (fallbackDirection == null) {
          // A machine code names no direction, so without `next_presence` there
          // is nothing to send. Refused here rather than defaulting to 'in',
          // which for somebody halfway through a night shift would ask the
          // server to clock them in twice.
          return const AttendanceRefused(
            AttendanceRefusal(
              kind: RefusalKind.clockRejected,
              message: 'Absensi untuk hari ini sudah lengkap.',
              code: 'no_clock_owed',
            ),
          );
        }

        return _guard(
          fallbackDirection,
          () => _api.redeemMachineQr(
            code: raw,
            type: fallbackDirection.wire,
            latitude: position?.latitude,
            longitude: position?.longitude,
            accuracy: position?.accuracy,
            isMocked: position?.isMocked ?? false,
            idempotencyKey: idempotencyKey,
          ),
        );
    }
  }

  /// Ask for the movements this person must perform.
  Future<Map<String, dynamic>> faceChallenge(PresenceDirection direction) =>
      _api.faceChallenge(type: direction.wire);

  /// Send the capture and the evidence.
  /// What the server said about a face it would not accept, for QA only.
  ///
  /// A refusal body carries a `verification` block — `score_percent`,
  /// `decision`, `awaiting_review` — and the screen deliberately shows none of
  /// it: a similarity score is not something to put in front of an employee, and
  /// §43 of the attendance brief says so.
  ///
  /// It is exactly what a *tester* needs, though, and its absence cost real
  /// time. "Verification failed" has two opposite causes that look identical
  /// from the outside: a score near zero means the picture was unusable — wrong
  /// way up, no face, motion blur — while a score just under the threshold means
  /// the picture was fine and the match was close. Chasing the first when it is
  /// the second, or the reverse, is a wasted release.
  ///
  /// Debug builds only. `kDebugMode` is a compile-time constant, so this call
  /// and the string it builds are removed from release along with everything
  /// they touch.
  static void _noteVerification(Map<String, dynamic> body) {
    if (!kDebugMode) return;

    final verification = asObject(body['verification']);

    if (verification.isEmpty) return;

    AppLogger.debug(
      'Face verification refused: '
      'score=${verification['score_percent']} '
      'decision=${verification['decision']} '
      'review=${verification['awaiting_review']}',
    );
  }

  Future<AttendanceOutcome> submitFace({
    required File image,
    required String challengeToken,
    required String challengeId,
    required PresenceDirection direction,
    required Map<String, dynamic> liveness,
    ClockPosition? position,
    String? idempotencyKey,
  }) {
    return _guard(
      direction,
      () => _api.submitFace(
        image: image,
        challengeToken: challengeToken,
        challengeId: challengeId,
        type: direction.wire,
        liveness: liveness,
        latitude: position?.latitude,
        longitude: position?.longitude,
        accuracy: position?.accuracy,
        isMocked: position?.isMocked ?? false,
        idempotencyKey: idempotencyKey,
      ),
    );
  }

  /// Run one write and turn whatever comes back into an outcome.
  ///
  /// Success is **only** a response the server produced. Nothing here confirms a
  /// clock the server has not written: the method this replaces navigated to the
  /// history screen from a `finally` that ran on every path, so a refused scan
  /// looked exactly like an accepted one (MED-12).
  Future<AttendanceOutcome> _guard(
    PresenceDirection? direction,
    Future<Map<String, dynamic>> Function() send,
  ) async {
    try {
      final body = await send();
      final attendance = asObject(body['attendance']);

      // The direction the server recorded wins over the one that was asked for.
      final recorded =
          PresenceDirection.parse(body['attendance_type']) ??
          direction ??
          PresenceDirection.clockIn;

      return AttendanceAccepted(
        AttendanceReceipt(
          direction: recorded,
          message: asString(body['message']) ?? 'Absensi tercatat.',
          recordedAt: asString(
            recorded == PresenceDirection.clockIn
                ? attendance['time_in']
                : attendance['time_out'],
          ),
        ),
      );
    } on ApiException catch (error) {
      _noteVerification(error.body);

      return AttendanceRefused(_refusalFor(error));
    }
  }

  /// Classify a refusal by the server's own code.
  ///
  /// Every string below is a constant the backend defines — `AttendanceRejected`
  /// for the clock itself, `QrPresenceController` and `KioskQrRedemptionController`
  /// for the two codes, `FaceAttendanceController` for the face. The message
  /// shown is the server's, because the server knows things the handset does
  /// not: how far outside the fence somebody is, or which department a code
  /// belongs to.
  /// Classify a refusal the way [redeem] and [submitFace] do.
  ///
  /// Public because the controller has one path that talks to the server
  /// outside those two — asking for a face challenge — and a second, private
  /// copy of this reasoning is how the QR path and the face path would come to
  /// disagree about what an employee may read.
  static AttendanceRefusal refusalFor(ApiException error) => _refusalFor(error);

  static AttendanceRefusal _refusalFor(ApiException error) {
    if (error.isTransportFailure) {
      return AttendanceRefusal(
        // A request that was sent and never answered is not a refusal: the row
        // may already exist. Told apart from a network that never connected,
        // because the two deserve opposite advice.
        kind: error.code == 'timeout'
            ? RefusalKind.unanswered
            : RefusalKind.transient,
        message: error.code == 'timeout'
            ? 'Jawaban dari server belum diterima. Periksa riwayat absensi '
                  'sebelum mencoba lagi.'
            : error.message,
        code: error.code,
      );
    }

    // A 422 carrying field errors and no `code` is not a decision about this
    // employee — it is the server saying the request was malformed, which means
    // a client bug. Told apart because the generic clock copy sent somebody to
    // HR over `is_mocked` being spelled `"false"`, and because the field names
    // are the one thing that would have made that obvious in a log.
    if (error.isValidationFailure && error.code == null) {
      AppLogger.error(
        // Field NAMES only. The values are coordinates and a challenge token.
        'An attendance write was refused as malformed: '
        '${error.errors.keys.join(', ')}',
      );

      return AttendanceRefusal(
        kind: RefusalKind.clockRejected,
        message:
            'Data absensi tidak diterima server. Perbarui aplikasi, dan '
            'laporkan ke tim IT bila berulang.',
        code: 'request_rejected',
      );
    }

    final kind = _kindFor(error);

    return AttendanceRefusal(
      kind: kind,
      // The server's own sentence, but ONLY where its `code` says the sentence
      // was written for a person. Every code below is raised by
      // `AttendanceRejected`, `QrPresenceController`,
      // `KioskQrRedemptionController` or `FaceAttendanceController`, each of
      // which builds a deliberate Indonesian message — and several of them carry
      // facts the handset does not have, such as how far outside the fence
      // somebody actually is.
      //
      // Anything else gets client copy. A body with no code, or a code this
      // build has never seen, may be Laravel's own English validation text, a
      // framework 500, or a message from a layer that never expected an
      // employee to read it. §47: a refusal is not a licence to print whatever
      // arrived.
      message: _isUserSafe(error) ? error.message : _genericFor(kind),
      code: error.code,
    );
  }

  /// Whether the server's own sentence may be shown as it stands.
  static bool _isUserSafe(ApiException error) {
    final code = error.code;

    if (code == null || !userSafeCodes.contains(code)) return false;

    final message = error.message.trim();

    // A code can be right and the body still wrong — a proxy's error page, a
    // truncated stack trace. Cheap shape checks, not an attempt at parsing.
    if (message.isEmpty || message.length > 300) return false;
    if (message.contains('<') || message.contains('#0 ')) return false;

    return true;
  }

  /// Client copy for a refusal whose message cannot be trusted.
  static String _genericFor(RefusalKind kind) => switch (kind) {
    RefusalKind.unrecognised =>
      'Kode ini bukan QR absensi. Arahkan ke QR absensi Anda.',
    RefusalKind.codeRejected =>
      'Kode ini tidak dapat dipakai. Pindai kode terbaru, lalu coba lagi.',
    RefusalKind.clockRejected =>
      'Absensi belum dapat diproses. Hubungi HR bila berulang.',
    RefusalKind.faceRejected =>
      'Verifikasi wajah belum berhasil. Mulai ulang verifikasi.',
    RefusalKind.transient =>
      'Server sedang tidak dapat memproses absensi. Coba beberapa saat lagi.',
    RefusalKind.unanswered =>
      'Jawaban dari server belum diterima. Periksa riwayat absensi sebelum '
          'mencoba lagi.',
  };

  /// Every refusal code whose message the backend writes for an employee.
  ///
  /// Taken from the controllers in `tenancy-app`, not invented for a test. A
  /// code absent from this set is not refused — it is shown with client copy,
  /// so a backend that grows a new one degrades to a safe sentence rather than
  /// to English or to a stack trace.
  static const Set<String> userSafeCodes = <String>{
    // AttendanceRejected — shared by every write path.
    'already_clocked_in',
    'already_clocked_out',
    'no_clock_in',
    'attendance_disabled',
    'location_mocked',
    'outside_geofence',
    'location_required',
    // QrPresenceController::redeem
    'qr_not_found',
    'qr_expired',
    'qr_wrong_department',
    'qr_already_used',
    // KioskQrRedemptionController
    'qr_disabled',
    'face_disabled',
    'invalid_code',
    'wrong_workspace',
    'code_expired',
    'code_already_used',
    // FaceAttendanceController
    'face_not_available',
    'face_not_enrolled',
    'face_references_missing',
    'face_references_unusable',
    'face_service_unavailable',
    'invalid_challenge',
    'challenge_expired',
    'challenge_mismatch',
    'challenge_already_used',
    'capture_crowded',
    'face_inconclusive',
    'face_no_match',
    'capture_not_stored',
    'attendance_write_failed',
    // Raised by the scoring service and passed through by
    // `FaceAttendanceController::refusalFromService`, which gives each of them a
    // deliberate Indonesian sentence before it leaves.
    //
    // These were missing, and their absence was a real defect rather than an
    // omission: `no_face_detected` answers "Wajah tidak terdeteksi pada foto.
    // Dekatkan wajah ke kamera, pastikan cukup terang" — the one sentence that
    // tells somebody what to do — and this client was replacing it with the
    // generic "Verifikasi wajah belum berhasil". The employee was told to start
    // again, over and over, with the advice removed.
    'no_face_detected',
    'invalid_upload',
    'unsupported_media_type',
    'payload_too_large',
    'video_decode_failed',
    'engine_unavailable',
  };

  static RefusalKind _kindFor(ApiException error) {
    return switch (error.code) {
      'qr_not_found' ||
      'invalid_code' ||
      'qr_expired' ||
      'code_expired' ||
      'qr_wrong_department' ||
      'wrong_workspace' ||
      'qr_already_used' ||
      'code_already_used' => RefusalKind.codeRejected,

      'already_clocked_in' ||
      'already_clocked_out' ||
      'no_clock_in' ||
      'attendance_disabled' ||
      'location_mocked' ||
      'outside_geofence' ||
      'location_required' ||
      'qr_disabled' ||
      'face_disabled' => RefusalKind.clockRejected,

      'face_not_enrolled' ||
      'face_references_missing' ||
      'face_no_match' ||
      'face_inconclusive' ||
      'capture_crowded' ||
      'invalid_challenge' ||
      'challenge_expired' ||
      'challenge_mismatch' ||
      'challenge_already_used' => RefusalKind.faceRejected,

      'face_not_available' ||
      'face_service_unavailable' ||
      'engine_unavailable' ||
      'capture_not_stored' ||
      'attendance_write_failed' => RefusalKind.transient,

      // The capture itself was the problem: no face in it, unreadable, too
      // large. Retrying the sequence is exactly the right answer, and the
      // server's sentence says how to make the next one better.
      'no_face_detected' ||
      'invalid_upload' ||
      'unsupported_media_type' ||
      'payload_too_large' ||
      'video_decode_failed' ||
      'face_references_unusable' => RefusalKind.faceRejected,

      _ => _fallbackKind(error),
    };
  }

  /// What to make of a code this build has never seen.
  ///
  /// Read from the status rather than guessed at: a 5xx is the server's fault
  /// and worth retrying, a 422 about liveness evidence is the face path, and
  /// anything else is a refusal of the clock. The catch-all matters because the
  /// backend grows codes faster than the app is released, and a new one must not
  /// land as a blank screen.
  static RefusalKind _fallbackKind(ApiException error) {
    final code = error.code ?? '';

    if (code.startsWith('liveness_') || code.startsWith('capture_')) {
      return RefusalKind.faceRejected;
    }

    final status = error.status ?? 0;

    return status >= 500 ? RefusalKind.transient : RefusalKind.clockRejected;
  }

  /// The signed-in employee's own name, for the receipt.
  String? get employeeName => _session.user?.name;
}

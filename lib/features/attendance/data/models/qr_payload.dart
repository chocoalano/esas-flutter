import 'dart:convert';

import '../../../../core/utils/json_parsers.dart';

/// What a scanned attendance QR code says.
///
/// Pulled out of `AttendanceController._submitAttendance`, where it was parsed
/// inline and where **the department check failed open** (CRIT-04):
///
/// ```dart
/// final int? currentStorageDeptId = (user?['employee']?['departement_id'] as num?)?.toInt();
/// final int? currentQrDeptId      = int.tryParse(qrCodeData['departement_id']);
///
/// if (currentStorageDeptId == currentQrDeptId) {   // null == null is TRUE
///   // ... posts attendance with "user_id": null
/// }
/// ```
///
/// Two defects sat on those three lines, and both are why this is now a type
/// with a test rather than an expression in a 90-line method.
///
/// **It failed open.** A stale cached user with no `employee.departement_id`,
/// plus a QR whose department did not parse, made both sides `null` — and
/// `null == null` is `true`. The only client-side check that a scanned code
/// belongs to the employee's own department was skipped, and a record was posted
/// with a null user id.
///
/// **It threw on valid input.** `int.tryParse` takes a non-nullable `String`, so
/// a QR encoding `{"departement_id": 12}` as a JSON *number* — which is what any
/// ordinary producer emits — raised a `TypeError`. That was swallowed by a broad
/// `catch`, surfaced as a generic "Pengiriman gagal", and the `finally` then
/// navigated away as though nothing had happened.
class QrPayload {
  const QrPayload({
    required this.token,
    this.type,
    this.tenant,
    this.expiresAt,
  });

  /// Parse a scanned code. Returns null when it is not an attendance QR.
  ///
  /// Never throws: a person pointing the camera at a shipping label should get
  /// "QR tidak valid", not a crash.
  static QrPayload? tryParse(String raw) {
    if (raw.trim().isEmpty) {
      return null;
    }

    final Object? decoded;

    try {
      decoded = json.decode(raw);
    } on FormatException {
      return null;
    }

    final data = asObject(decoded);

    if (data.isEmpty) {
      return null;
    }

    final token = asString(data['token']);

    if (token == null) {
      return null;
    }

    return QrPayload(
      token: token,
      type: asString(data['type']),
      tenant: asString(data['tenant']),
      expiresAt: DateTime.tryParse(asString(data['expires_at']) ?? ''),
    );
  }

  /// `in` or `out`.
  final String? type;

  /// The single-use secret the code carries. This is the whole of what is sent
  /// back: the server looks it up, and one redemption is all a code gets - which
  /// a unique index enforces rather than a check.
  final String token;

  /// Which workspace issued it. Read so a code from another company is refused
  /// here rather than sent to a server that would refuse it anyway.
  final String? tenant;

  /// When it stops working. A code somebody photographed off a screen is worth
  /// nothing a quarter of an hour later.
  final DateTime? expiresAt;

  /// Whether the code is still worth sending.
  bool get isExpired {
    final at = expiresAt;

    return at != null && DateTime.now().isAfter(at);
  }

  /// Whether this code was issued by the workspace this handset is signed in to.
  ///
  /// **Fails closed**, which is the surviving half of CRIT-04. The department
  /// check that used to live here is gone and that is an improvement, not a
  /// removal: the server does it now, in `qr-presences/redeem`, where an
  /// employee cannot skip it by editing a cached user record. What a client can
  /// usefully still check is the thing it knows for certain about itself.
  bool matchesWorkspace(String? signedInTenant) {
    final qrWorkspace = tenant?.trim().toLowerCase();
    final currentWorkspace = signedInTenant?.trim().toLowerCase();

    if (qrWorkspace == null ||
        qrWorkspace.isEmpty ||
        currentWorkspace == null ||
        currentWorkspace.isEmpty) {
      return false;
    }

    return qrWorkspace == currentWorkspace;
  }

  /// Whether there is enough here to submit at all.
  bool get isComplete => type != null && token.isNotEmpty;

  /// Indonesian for the direction, for the success message.
  String get directionLabel => type == 'in' ? 'Masuk' : 'Pulang';
}

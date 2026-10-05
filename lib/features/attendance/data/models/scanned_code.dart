import 'dart:convert';

import '../../../../core/utils/json_parsers.dart';
import 'attendance_context.dart';
import 'qr_payload.dart';

/// What the camera just read, once the app has worked out which of the two
/// attendance codes it is.
///
/// There are two, they are issued by different halves of the backend, and they
/// are redeemed at different endpoints with different field names. The client
/// used to know about only one of them and post it to the other's endpoint:
///
/// | Code | Issued by | Payload | Redeemed at |
/// |---|---|---|---|
/// | Department | `POST /qr-presences` | JSON `{tenant, token, type, expires_at}` | `POST /qr-presences/redeem`, field `token` |
/// | Machine | the attendance machine's own screen | `base64url(json).base64url(hmac)` | `POST /attendance/qr`, fields `code` + `type` |
///
/// Telling them apart is what this type is for, and it is done by shape rather
/// than by trying one endpoint and falling back to the other: a failed redeem is
/// not free — the machine code is single-use and spending it on a guess is
/// spending it.
sealed class ScannedCode {
  const ScannedCode();

  /// Recognise a scanned string, or answer null when it is not one of ours.
  ///
  /// Never throws. Somebody pointing the camera at a shipping label gets "kode
  /// tidak dikenali" and a scanner that carries on, not a crash and not a
  /// full-screen error.
  static ScannedCode? recognise(String raw) {
    final trimmed = raw.trim();

    if (trimmed.isEmpty) return null;

    final department = QrPayload.tryParse(trimmed);

    if (department != null) {
      return DepartmentCode(department);
    }

    return MachineCode.tryParse(trimmed);
  }
}

/// A code a department is displaying. Carries its own direction.
class DepartmentCode extends ScannedCode {
  const DepartmentCode(this.payload);

  final QrPayload payload;

  /// The direction is baked into the code, so the app never has to choose it.
  PresenceDirection? get direction => PresenceDirection.parse(payload.type);
}

/// A code read off an attendance machine's screen.
///
/// Opaque: the signature is the server's to check and the payload is read here
/// only so a code that has plainly expired can be refused without spending a
/// round trip — and, more importantly, without spending the code.
class MachineCode extends ScannedCode {
  const MachineCode({required this.raw, this.id, this.tenant, this.expiresAt});

  /// The whole scanned string, sent back verbatim as `code`.
  final String raw;

  /// `jti` — the id the server claims against a unique index.
  final String? id;

  /// `tid` — the workspace that issued it.
  final String? tenant;

  /// `exp`, as a moment.
  final DateTime? expiresAt;

  /// Read the payload half of a `header.signature` token.
  ///
  /// Two segments, the first decoding to a JSON object that carries `jti` and
  /// `exp`. Anything else is not a machine code, and is not guessed at: a
  /// signed token whose payload cannot be read is one the server would refuse
  /// anyway, and pretending to understand it would send a shipping label to an
  /// endpoint that spends whatever it is given.
  static MachineCode? tryParse(String raw) {
    final parts = raw.split('.');

    if (parts.length != 2 || parts.any((part) => part.isEmpty)) {
      return null;
    }

    final data = asObject(_decodeSegment(parts.first));

    if (data.isEmpty || data['jti'] == null || data['exp'] == null) {
      return null;
    }

    final expiry = asInt(data['exp']);

    return MachineCode(
      raw: raw,
      id: asString(data['jti']),
      tenant: asString(data['tid']),
      expiresAt: expiry == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(expiry * 1000),
    );
  }

  /// Whether the code is already past the moment it named.
  ///
  /// A machine rotates its code every few seconds, so this is the ordinary
  /// outcome of somebody scanning a photograph of the screen — and saying so
  /// locally is both faster and cheaper than a redemption that would spend
  /// nothing and refuse anyway.
  bool get isExpired {
    final at = expiresAt;

    return at != null && DateTime.now().isAfter(at);
  }

  /// Whether this code was issued by the workspace this handset is signed in to.
  ///
  /// **Fails closed**, like [QrPayload.matchesWorkspace]: two unknowns are not a
  /// match. The server checks it too, and its check is the control — this one is
  /// UX, and exists so a code from another company is refused before it is
  /// spent.
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

  /// base64url, padding optional. Returns the decoded JSON, or null.
  static Object? _decodeSegment(String segment) {
    try {
      return json.decode(
        utf8.decode(base64Url.decode(base64Url.normalize(segment))),
      );
    } on FormatException {
      return null;
    } on ArgumentError {
      // `base64Url.normalize` throws this on a length that cannot be padded.
      return null;
    }
  }
}

import 'dart:convert';

import 'package:esas/features/attendance/data/models/qr_payload.dart';
import 'package:flutter_test/flutter_test.dart';

/// What a scanned attendance QR code says, in the shape `tenancy-app` issues.
///
/// The code changed with the backend, and so did what a client can usefully
/// check about it. `QrPresenceController::store` puts this on the screen:
///
/// ```json
/// {"tenant":"acme","token":"…48 random chars…","type":"in","expires_at":"…"}
/// ```
///
/// No `departement_id`, and its absence is the point. The department check used
/// to live on the handset and **failed open** — `null == null` is true, so a
/// stale cached user plus an unparseable department submitted attendance with a
/// null user id (CRIT-04). The server does that check now, in
/// `qr-presences/redeem`, and answers `qr_wrong_department`: an employee cannot
/// skip it by editing a cached record, which is the one place a client-side
/// check can always be skipped from.
///
/// What is left here is what a handset genuinely knows: whether the code parses,
/// whether it has expired, and whether it came from the workspace this phone is
/// signed in to. All three still fail closed.
void main() {
  String qr({
    Object? token = 'tok_abcdef0123456789',
    Object? type = 'in',
    Object? tenant = 'acme',
    Object? expiresAt,
  }) => json.encode({
    if (token != null) 'token': token,
    'type': type,
    'tenant': tenant,
    'expires_at':
        expiresAt ??
        DateTime.now().add(const Duration(minutes: 15)).toIso8601String(),
  });

  group('parsing accepts the code the server issues', () {
    test('reads the token, the direction and the workspace', () {
      final payload = QrPayload.tryParse(qr());

      expect(payload, isNotNull);
      expect(payload!.token, 'tok_abcdef0123456789');
      expect(payload.type, 'in');
      expect(payload.tenant, 'acme');
      expect(payload.expiresAt, isNotNull);
    });

    test('a code with no expiry still parses', () {
      // A producer that omits it is not a producer this app should refuse
      // outright; the server has the authoritative expiry either way.
      final payload = QrPayload.tryParse(
        json.encode({'token': 'tok_1', 'type': 'out', 'tenant': 'acme'}),
      );

      expect(payload!.token, 'tok_1');
      expect(payload.expiresAt, isNull);
      expect(payload.isExpired, isFalse);
    });
  });

  group('parsing refuses what is not an attendance code', () {
    test('returns null instead of throwing', () {
      // Somebody pointing the camera at a shipping label gets "QR tidak valid",
      // not a crash.
      expect(QrPayload.tryParse('not json'), isNull);
      expect(QrPayload.tryParse(''), isNull);
      expect(QrPayload.tryParse('   '), isNull);
      expect(QrPayload.tryParse('{"other":"shape"}'), isNull);
      expect(QrPayload.tryParse('[1,2,3]'), isNull);
    });

    test('a code with no token is not a code', () {
      // The token is the whole of what gets sent back. Without it there is
      // nothing to redeem, and a payload that parsed would be one the app would
      // happily post as an empty string.
      expect(QrPayload.tryParse(qr(token: null)), isNull);
    });
  });

  group('matchesWorkspace — fails CLOSED', () {
    test('two unknowns are NOT a match', () {
      // The shape of CRIT-04, kept pinned on the check that survived it.
      final payload = QrPayload.tryParse(qr(tenant: null))!;

      expect(payload.tenant, isNull);
      expect(payload.matchesWorkspace(null), isFalse);
    });

    test('an unknown signed-in workspace is not a match', () {
      expect(QrPayload.tryParse(qr())!.matchesWorkspace(null), isFalse);
    });

    test('a genuine mismatch is refused', () {
      expect(QrPayload.tryParse(qr())!.matchesWorkspace('globex'), isFalse);
    });

    test('a genuine match is accepted', () {
      expect(QrPayload.tryParse(qr())!.matchesWorkspace('acme'), isTrue);
    });

    test('normalises case and surrounding whitespace', () {
      expect(
        QrPayload.tryParse(qr(tenant: ' ACME '))!.matchesWorkspace('acme'),
        isTrue,
      );
    });
  });

  group('isExpired', () {
    test('a code past its expiry is spent', () {
      // Photographing a code off a screen is pointless a quarter of an hour
      // later, and the app can say so without a round trip.
      final stale = qr(
        expiresAt: DateTime.now()
            .subtract(const Duration(minutes: 1))
            .toIso8601String(),
      );

      expect(QrPayload.tryParse(stale)!.isExpired, isTrue);
    });

    test('a fresh code is not', () {
      expect(QrPayload.tryParse(qr())!.isExpired, isFalse);
    });
  });

  group('isComplete', () {
    test('is false when the direction is missing', () {
      expect(QrPayload.tryParse(qr(type: null))!.isComplete, isFalse);
    });

    test('is true for a whole code', () {
      expect(QrPayload.tryParse(qr())!.isComplete, isTrue);
    });
  });

  test('directionLabel reads as the confirmation message did', () {
    expect(QrPayload.tryParse(qr(type: 'in'))!.directionLabel, 'Masuk');
    expect(QrPayload.tryParse(qr(type: 'out'))!.directionLabel, 'Pulang');
  });
}

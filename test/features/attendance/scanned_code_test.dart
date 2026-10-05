import 'dart:convert';

import 'package:esas/features/attendance/data/models/attendance_context.dart';
import 'package:esas/features/attendance/data/models/scanned_code.dart';
import 'package:flutter_test/flutter_test.dart';

/// Telling the two attendance codes apart.
///
/// There are two, they are issued by different halves of the backend, and until
/// now the client knew about one of them and posted it to the other's endpoint:
///
/// * a **department** code is JSON — `{tenant, token, type, expires_at}` — and
///   is redeemed at `qr-presences/redeem` under the field `token`;
/// * a **machine** code is `base64url(payload).base64url(hmac)` and is redeemed
///   at `attendance/qr` under the field `code`, with a `type` the code itself
///   does not carry.
///
/// Recognising them by shape rather than by trying one endpoint and falling
/// back to the other is not a stylistic choice: both codes are single-use, so a
/// guess that guesses wrong spends somebody's code on a 422.
void main() {
  String machineToken({
    String jti = 'a2f1c0de-0000-4000-8000-000000000001',
    String tenant = 'acme',
    int? exp,
    String signature = 'c2lnbmF0dXJl',
  }) {
    final payload = base64Url
        .encode(
          utf8.encode(
            json.encode({
              'v': 1,
              'jti': jti,
              'tid': tenant,
              'did': 7,
              'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
              'exp':
                  exp ??
                  DateTime.now()
                          .add(const Duration(seconds: 20))
                          .millisecondsSinceEpoch ~/
                      1000,
            }),
          ),
        )
        // The server strips padding; the reader must cope either way.
        .replaceAll('=', '');

    return '$payload.$signature';
  }

  String departmentPayload({
    String token = 'tok_abcdef0123456789',
    String type = 'in',
    String tenant = 'acme',
  }) => json.encode({
    'tenant': tenant,
    'token': token,
    'type': type,
    'expires_at': DateTime.now()
        .add(const Duration(minutes: 15))
        .toIso8601String(),
  });

  group('a department code', () {
    test('is recognised, and carries its own direction', () {
      final scanned = ScannedCode.recognise(departmentPayload(type: 'out'));

      expect(scanned, isA<DepartmentCode>());
      expect(
        (scanned! as DepartmentCode).direction,
        PresenceDirection.clockOut,
      );
      expect((scanned as DepartmentCode).payload.token, 'tok_abcdef0123456789');
    });
  });

  group('a machine code', () {
    test('is recognised from its two base64url segments', () {
      final scanned = ScannedCode.recognise(machineToken());

      expect(scanned, isA<MachineCode>());

      final code = scanned! as MachineCode;

      expect(code.id, 'a2f1c0de-0000-4000-8000-000000000001');
      expect(code.tenant, 'acme');
      expect(code.isExpired, isFalse);
    });

    test('goes back to the server verbatim', () {
      // The signature is the server's to check, so nothing is re-encoded on the
      // way out — a round trip through a decoder is a chance to change a byte.
      final raw = machineToken();

      expect((ScannedCode.recognise(raw)! as MachineCode).raw, raw);
    });

    test('a code past its expiry is spent', () {
      // A machine rotates every few seconds, so this is what a photograph of
      // the screen looks like. Saying so locally spends no code and no round
      // trip.
      final stale = machineToken(
        exp:
            DateTime.now()
                .subtract(const Duration(minutes: 1))
                .millisecondsSinceEpoch ~/
            1000,
      );

      expect((ScannedCode.recognise(stale)! as MachineCode).isExpired, isTrue);
    });

    group('matchesWorkspace — fails CLOSED', () {
      test('two unknowns are not a match', () {
        final code = MachineCode.tryParse(machineToken())!;

        expect(
          MachineCode(raw: code.raw, id: code.id).matchesWorkspace(null),
          isFalse,
        );
      });

      test('a genuine mismatch is refused, a genuine match accepted', () {
        final code = ScannedCode.recognise(machineToken())! as MachineCode;

        expect(code.matchesWorkspace('globex'), isFalse);
        expect(code.matchesWorkspace('acme'), isTrue);
      });

      test('normalises case and surrounding whitespace', () {
        final code =
            ScannedCode.recognise(machineToken(tenant: ' ACME '))!
                as MachineCode;

        expect(code.matchesWorkspace('acme'), isTrue);
      });
    });
  });

  group('anything else is not an attendance code', () {
    test('returns null rather than throwing', () {
      // Somebody pointing the camera at a shipping label, a Wi-Fi QR or a
      // poster gets "kode tidak dikenali" and a scanner that carries on — not a
      // crash, and not a code posted to an endpoint that would spend it.
      for (final raw in <String>[
        '',
        '   ',
        'not json',
        'https://example.com',
        '{"other":"shape"}',
        '[1,2,3]',
        // Two segments, but the first is not base64url JSON.
        'hello.world',
        // Two segments of valid base64url JSON, but with none of the fields a
        // machine code must carry.
        '${base64Url.encode(utf8.encode('{"a":1}'))}.sig',
        // One segment only.
        base64Url.encode(utf8.encode('{"jti":"x","exp":1}')),
      ]) {
        expect(
          ScannedCode.recognise(raw),
          isNull,
          reason: 'should not recognise: $raw',
        );
      }
    });

    test('a JSON code with no token is not a department code', () {
      // The token is the whole of what gets redeemed. Without it there is
      // nothing to send, and a payload that parsed would be one the app posts
      // as an empty string.
      expect(
        ScannedCode.recognise(json.encode({'tenant': 'acme', 'type': 'in'})),
        isNull,
      );
    });
  });
}

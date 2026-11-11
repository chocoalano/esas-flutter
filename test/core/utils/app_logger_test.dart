import 'package:esas/core/utils/app_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Redaction is a backstop for a mistake, not a licence to log secrets. These
/// pin the specific values the app was actually printing (CRIT-05).
void main() {
  group('redact', () {
    test('blanks an Authorization header, scheme and all', () {
      final line = AppLogger.redact(
        'Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.abc-_123',
      );

      expect(line, isNot(contains('eyJhbGciOiJIUzI1NiJ9')));
      expect(line, 'authorization: [redacted]');
    });

    test('blanks a bearer token quoted without its key', () {
      expect(
        AppLogger.redact('retrying with Bearer eyJhbGciOiJIUzI1NiJ9.abc then'),
        'retrying with Bearer [redacted] then',
      );
    });

    test('does not redact an already-redacted value twice', () {
      expect(
        AppLogger.redact('Authorization: Bearer abc.def'),
        isNot(contains('[redacted] [redacted]')),
      );
    });

    test('blanks the login response the old code printed whole', () {
      // login_controller.dart:176 printed the decoded body, which carries
      // data['token'].
      final line = AppLogger.redact(
        '========> response data server : {token: 42|abcdefghijklmnop, user: {name: Budi}}',
      );

      expect(line, isNot(contains('abcdefghijklmnop')));
      expect(line, contains('token: [redacted]'));
      // Non-sensitive context survives, or the log is useless.
      expect(line, contains('Budi'));
    });

    test('blanks an FCM token', () {
      // firebase_messaging_services.dart printed this on every refresh.
      final line = AppLogger.redact('FCM Token: dGhpcy1pcy1hLXRva2Vu:APA91bF');

      expect(line, isNot(contains('APA91bF')));
    });

    test('blanks a password and an employee number', () {
      expect(
        AppLogger.redact('{"nip":"20240113","password":"s3cret!"}'),
        allOf(isNot(contains('s3cret')), isNot(contains('20240113'))),
      );
    });

    test('is case-insensitive about the key', () {
      expect(AppLogger.redact('Token=abc123'), isNot(contains('abc123')));
      expect(AppLogger.redact('PASSWORD: hunter2'), isNot(contains('hunter2')));
    });

    test('leaves an ordinary message alone', () {
      const message = 'Memuat 12 pemberitahuan untuk halaman 2.';

      expect(AppLogger.redact(message), message);
    });
  });

  test('warning and error do not throw without a binding', () {
    // These survive into release builds, so they must never be the thing that
    // brings a release down.
    expect(() => AppLogger.warning('halo'), returnsNormally);
    expect(
      () => AppLogger.error('gagal', error: StateError('x')),
      returnsNormally,
    );
  });

  // CORE-07. `dart:developer.log` only reaches the VM service, which a release
  // build does not have — so the "kept in release" levels wrote nothing, and a
  // failed boot step (CORE-01) left no trace in logcat or Console.
  group('warning and error reach a sink that exists in release', () {
    late List<String> lines;
    late DebugPrintCallback original;

    setUp(() {
      lines = [];
      original = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) lines.add(message);
      };
    });

    tearDown(() => debugPrint = original);

    test('warning is printed, redacted', () {
      AppLogger.warning('boot step failed token=abc123');

      expect(lines, hasLength(1));
      expect(lines.single, contains('boot step failed'));
      expect(lines.single, isNot(contains('abc123')));
    });

    test('error is printed with its cause, redacted', () {
      AppLogger.error(
        'push registration failed',
        error: StateError('password=hunter2'),
      );

      expect(lines.join('\n'), contains('push registration failed'));
      expect(lines.join('\n'), contains('Bad state'));
      expect(lines.join('\n'), isNot(contains('hunter2')));
    });
  });
}

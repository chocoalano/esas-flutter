import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Levelled logging that cannot leak a credential.
///
/// The app had 132 `print`/`debugPrint` calls across 20 files, and some of them
/// printed things that must never reach a device log: the whole login response
/// including `data['token']`, the FCM token on every refresh, and the entire
/// user object with the employee's NIP and company record (CRIT-05).
///
/// `debugPrint` is not the safe option people take it for — it is a rate-limited
/// wrapper around `print` and it stays active in release, readable through
/// `adb logcat` or Console.app.
///
/// So: [debug] and [info] compile out of release builds. [warning] and [error]
/// survive, because a release build that fails silently is worse, but they go
/// through [redact] first.
class AppLogger {
  const AppLogger._();

  static const _name = 'ESAS';

  /// Substrings that mean a value is a credential rather than a fact.
  ///
  /// `authorization` is handled separately, ahead of these, because its value
  /// is two words — `Bearer <token>` — and a rule that takes one word would
  /// blank the scheme and leave the secret.
  static const _sensitiveKeys = <String>[
    'token',
    'password',
    'secret',
    'nip',
    'api_key',
    'apikey',
  ];

  /// `Authorization: Bearer <token>`, scheme and all.
  static final _authorizationHeader = RegExp(
    r'"?authorization"?\s*[:=]\s*"?(?:[A-Za-z]+\s+)?[^,\s}"]+"?',
    caseSensitive: false,
  );

  /// A bearer token with no key in front of it.
  static final _bareBearer = RegExp(
    r'\bBearer\s+[A-Za-z0-9._~+/=|-]+',
    caseSensitive: false,
  );

  /// Developer detail. Removed from release builds.
  static void debug(String message, {Object? data}) {
    if (!kDebugMode) {
      return;
    }

    _emit(500, message, data);
  }

  /// A milestone worth seeing while developing. Removed from release builds.
  static void info(String message, {Object? data}) {
    if (!kDebugMode) {
      return;
    }

    _emit(800, message, data);
  }

  /// Something recoverable went wrong. Kept in release.
  ///
  /// Printed rather than sent to `dart:developer`: `developer.log` reaches only
  /// the VM service, which a release build does not have, so these levels used
  /// to write nothing at all where they were meant to survive (CORE-07).
  static void warning(String message, {Object? data}) {
    _print('WARNING', message, data);
  }

  /// Something failed. Kept in release, printed for the same reason as
  /// [warning].
  static void error(String message, {Object? error, StackTrace? stackTrace}) {
    _print('ERROR', message, error);

    if (stackTrace != null) {
      debugPrint(redact(stackTrace.toString()));
    }
  }

  static void _print(String level, String message, Object? detail) {
    final line = detail == null
        ? redact(message)
        : '${redact(message)} ${redact('$detail')}';

    debugPrint('[$_name] $level: $line');
  }

  static void _emit(int level, String message, Object? data) {
    developer.log(
      data == null ? redact(message) : '${redact(message)} ${redact('$data')}',
      name: _name,
      level: level,
    );
  }

  /// Blank out anything that looks like a credential.
  ///
  /// Deliberately crude, and deliberately biased towards over-redacting. It is a
  /// backstop for a mistake, not a licence to log secrets and rely on it — the
  /// rule is still that credentials are never passed to a logger at all.
  @visibleForTesting
  static String redact(String input) {
    // Ordered, and the order matters. The Authorization header goes first and
    // consumes its whole value including the scheme; the bare-bearer rule then
    // catches a token quoted without its key. The other way round, each rule
    // eats half of the other's match — which yields `[redacted] [redacted]`
    // and, worse, can blank the scheme while leaving the secret beside it.
    var output = input
        .replaceAll(_authorizationHeader, 'authorization: [redacted]')
        .replaceAll(_bareBearer, 'Bearer [redacted]');

    // `key: value`, `key=value`, `"key": "value"` for any sensitive key. The
    // lookahead keeps a value already blanked above from being blanked twice.
    for (final key in _sensitiveKeys) {
      output = output.replaceAll(
        RegExp(
          '"?$key"?\\s*[:=]\\s*"?(?!\\[redacted\\])[^,\\s}"]+"?',
          caseSensitive: false,
        ),
        '$key: [redacted]',
      );
    }

    return output;
  }
}

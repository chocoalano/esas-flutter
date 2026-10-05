import 'dart:io';

import '../config/env.dart';
import '../config/server_config.dart';
import '../utils/app_logger.dart';

/// Trusting a development server's certificate, and nothing else.
///
/// What this replaces accepted **every** certificate, for every host, in every
/// build:
///
/// ```dart
/// // lib/utils/my_http_overrides.dart — installed unconditionally in main()
/// ..badCertificateCallback = (cert, host, port) => true;
/// ```
///
/// `HttpOverrides.global` applies to every `dart:io` client in the process, so
/// that disabled TLS for the ESAS API, for image loading, and for anything a
/// package fetched — in release. Anyone on the network path could present a
/// self-signed certificate and read the bearer token and every payload
/// (CRIT-02).
///
/// Three things keep the replacement honest:
///
///   * it is installed from inside an `assert`, which the release compiler
///     removes outright, so there is no path by which a shipped build runs it;
///   * it additionally checks [Env.isDevelopment], so a debug build pointed at
///     production still validates certificates;
///   * the callback names the hosts it will trust rather than returning `true`,
///     so trusting a development box never means trusting the internet.
///
/// Under subdomain tenancy this matters twice over: that mode needs a wildcard
/// certificate, and a blanket bypass hides a missing one until the day it is
/// removed, at which point every tenant breaks at once (TEN-03).
void installDevHttpOverrides() {
  assert(() {
    if (!Env.isDevelopment) {
      return true;
    }

    HttpOverrides.global = _DevHttpOverrides();
    AppLogger.warning(
      'TLS verification relaxed for development hosts only. '
      'This code is compiled out of release builds.',
    );

    return true;
  }());
}

class _DevHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (cert, host, port) {
        // A private address or a reserved suffix cannot have a publicly issued
        // certificate, so an invalid one there is expected. Anything routable
        // is refused exactly as it would be in release.
        final trusted = ServerConfig.isDevelopmentHost(host);

        if (!trusted) {
          AppLogger.error(
            'Refused an invalid certificate for a non-development host.',
          );
        }

        return trusted;
      };
  }
}

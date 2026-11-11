import 'dart:io';

import 'package:flutter/foundation.dart';

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

    HttpOverrides.global = DevHttpOverrides();
    AppLogger.warning(
      'TLS verification relaxed for development hosts only. '
      'This code is compiled out of release builds.',
    );

    return true;
  }());
}

/// The override itself. Public only so a test can install it in a zone; the
/// one production caller is [installDevHttpOverrides], inside an `assert`.
@visibleForTesting
class DevHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      DevTlsHttpClient(super.createHttpClient(context));
}

/// A client whose certificate rule is the development-host rule, and stays it.
///
/// GetConnect builds its `HttpClient` through this override and then assigns
/// its own `badCertificateCallback` — `allowAutoSignedCert`, false — over the
/// one set here, so `ApiClient` refused the very development server this file
/// exists for (CORE-08). The setter is therefore ignored: the decision is made
/// by host, here, whatever a caller later asks for. That also means a caller
/// asking to accept everything still cannot open a routable host.
@visibleForTesting
class DevTlsHttpClient implements HttpClient {
  DevTlsHttpClient(this._inner) {
    _inner.badCertificateCallback = (cert, host, port) =>
        acceptsInvalidCertificateFor(host);
  }

  final HttpClient _inner;

  /// A private address or a reserved suffix cannot have a publicly issued
  /// certificate, so an invalid one there is expected. Anything routable is
  /// refused exactly as it would be in release.
  bool acceptsInvalidCertificateFor(String host) {
    final trusted = ServerConfig.isDevelopmentHost(host);

    if (!trusted) {
      AppLogger.error(
        'Refused an invalid certificate for a non-development host.',
      );
    }

    return trusted;
  }

  @override
  set badCertificateCallback(
    bool Function(X509Certificate cert, String host, int port)? callback,
  ) {
    // Deliberately ignored — see the class comment.
  }

  // ── Everything else is the inner client's ────────────────────────────────

  @override
  Duration get idleTimeout => _inner.idleTimeout;
  @override
  set idleTimeout(Duration value) => _inner.idleTimeout = value;

  @override
  Duration? get connectionTimeout => _inner.connectionTimeout;
  @override
  set connectionTimeout(Duration? value) => _inner.connectionTimeout = value;

  @override
  int? get maxConnectionsPerHost => _inner.maxConnectionsPerHost;
  @override
  set maxConnectionsPerHost(int? value) => _inner.maxConnectionsPerHost = value;

  @override
  bool get autoUncompress => _inner.autoUncompress;
  @override
  set autoUncompress(bool value) => _inner.autoUncompress = value;

  @override
  String? get userAgent => _inner.userAgent;
  @override
  set userAgent(String? value) => _inner.userAgent = value;

  @override
  set authenticate(
    Future<bool> Function(Uri url, String scheme, String? realm)? f,
  ) => _inner.authenticate = f;

  @override
  set authenticateProxy(
    Future<bool> Function(String host, int port, String scheme, String? realm)?
    f,
  ) => _inner.authenticateProxy = f;

  @override
  set connectionFactory(
    Future<ConnectionTask<Socket>> Function(
      Uri url,
      String? proxyHost,
      int? proxyPort,
    )?
    f,
  ) => _inner.connectionFactory = f;

  @override
  set findProxy(String Function(Uri url)? f) => _inner.findProxy = f;

  @override
  set keyLog(Function(String line)? callback) => _inner.keyLog = callback;

  @override
  void addCredentials(
    Uri url,
    String realm,
    HttpClientCredentials credentials,
  ) => _inner.addCredentials(url, realm, credentials);

  @override
  void addProxyCredentials(
    String host,
    int port,
    String realm,
    HttpClientCredentials credentials,
  ) => _inner.addProxyCredentials(host, port, realm, credentials);

  @override
  void close({bool force = false}) => _inner.close(force: force);

  @override
  Future<HttpClientRequest> open(
    String method,
    String host,
    int port,
    String path,
  ) => _inner.open(method, host, port, path);

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) =>
      _inner.openUrl(method, url);

  @override
  Future<HttpClientRequest> get(String host, int port, String path) =>
      _inner.get(host, port, path);

  @override
  Future<HttpClientRequest> getUrl(Uri url) => _inner.getUrl(url);

  @override
  Future<HttpClientRequest> post(String host, int port, String path) =>
      _inner.post(host, port, path);

  @override
  Future<HttpClientRequest> postUrl(Uri url) => _inner.postUrl(url);

  @override
  Future<HttpClientRequest> put(String host, int port, String path) =>
      _inner.put(host, port, path);

  @override
  Future<HttpClientRequest> putUrl(Uri url) => _inner.putUrl(url);

  @override
  Future<HttpClientRequest> delete(String host, int port, String path) =>
      _inner.delete(host, port, path);

  @override
  Future<HttpClientRequest> deleteUrl(Uri url) => _inner.deleteUrl(url);

  @override
  Future<HttpClientRequest> patch(String host, int port, String path) =>
      _inner.patch(host, port, path);

  @override
  Future<HttpClientRequest> patchUrl(Uri url) => _inner.patchUrl(url);

  @override
  Future<HttpClientRequest> head(String host, int port, String path) =>
      _inner.head(host, port, path);

  @override
  Future<HttpClientRequest> headUrl(Uri url) => _inner.headUrl(url);
}

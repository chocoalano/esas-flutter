import 'dart:io';

import 'package:esas/core/network/dev_http_overrides.dart';
import 'package:flutter_test/flutter_test.dart';

/// CORE-08. The development TLS override set a host-scoped
/// `badCertificateCallback`, and GetConnect — which builds its own
/// `HttpClient` through the override — then assigned its own callback over it
/// (`(_, __, ___) => allowAutoSignedCert`, false). So `ApiClient` refused a
/// development server's certificate the override was meant to accept.
void main() {
  HttpClient clientFromOverride() =>
      HttpOverrides.runWithHttpOverrides(HttpClient.new, DevHttpOverrides());

  test('a later callback does not replace the development-host rule', () {
    final client = clientFromOverride();

    // What GetConnect's HttpRequestImpl does to every client it creates.
    client.badCertificateCallback = (_, _, _) => false;

    expect(client, isA<DevTlsHttpClient>());
    final dev = client as DevTlsHttpClient;
    expect(dev.acceptsInvalidCertificateFor('192.168.1.20'), isTrue);
    expect(dev.acceptsInvalidCertificateFor('hrms.test'), isTrue);
    client.close(force: true);
  });

  test('a routable host is refused, whatever a caller asks for', () {
    final client = clientFromOverride();

    // Not even a blanket "accept everything" opens a public host.
    client.badCertificateCallback = (_, _, _) => true;

    final dev = client as DevTlsHttpClient;
    expect(dev.acceptsInvalidCertificateFor('api.example.com'), isFalse);
    expect(dev.acceptsInvalidCertificateFor('8.8.8.8'), isFalse);
    client.close(force: true);
  });

  // UAT review C2. Installed at the end of bootstrap, the override arrived
  // after `InitialBinding` had already built ApiClient's main HttpClient, so
  // that client never had the development-host rule.
  test('the override is installed before any HTTP client is built', () {
    final source = File('lib/bootstrap.dart').readAsStringSync();
    final installed = source.indexOf('installDevHttpOverrides();');
    final bound = source.indexOf('InitialBinding(');

    expect(installed, isNonNegative);
    expect(bound, isNonNegative);
    expect(installed, lessThan(bound));
  });
}

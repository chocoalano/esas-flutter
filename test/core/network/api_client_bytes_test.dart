import 'dart:io';

import 'package:esas/core/config/server_config.dart';
import 'package:esas/core/network/api_client.dart';
import 'package:esas/core/network/api_exception.dart';
import 'package:esas/core/network/auth_interceptor.dart';
import 'package:esas/core/storage/secure_store.dart';
import 'package:esas/core/storage/token_storage.dart';
import 'package:esas/core/tenancy/tenant_context.dart';
import 'package:flutter_test/flutter_test.dart';

/// PRMT-03. Tenant files are private and are served only through an
/// authenticated endpoint. GetConnect decodes every body as UTF-8 text, which
/// corrupts a PDF or a photo, so binary downloads take their own path — to the
/// same origin, with the same credential and workspace header.
void main() {
  late HttpServer server;
  late List<HttpRequest> seen;
  late int Function(HttpRequest) status;
  late InMemoryTokenStorage tokens;
  late ApiClient client;
  late int unauthorized;

  final pdf = [0x25, 0x50, 0x44, 0x46, 0x2d, 0x31, 0x2e, 0x37, 0xff, 0x00, 0xe2];

  setUp(() async {
    seen = [];
    status = (_) => 200;
    unauthorized = 0;

    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      seen.add(request);
      final code = status(request);
      request.response.statusCode = code;
      if (code == 200) {
        request.response.headers.contentType = ContentType('application', 'pdf');
        request.response.add(pdf);
      } else {
        request.response.headers.contentType = ContentType.json;
        request.response.write('{"message":"Berkas tidak ditemukan.","code":"not_found"}');
      }
      await request.response.close();
    });

    final store = InMemorySecureStore();
    final serverConfig = ServerConfig(store: store);
    final tenantContext = TenantContext(store: store);
    await serverConfig.save(
      domain: 'http://127.0.0.1:${server.port}',
      subdomainMode: false,
    );
    await tenantContext.remember('acme');

    tokens = InMemoryTokenStorage('abc');
    client = ApiClient(
      serverConfig: serverConfig,
      tenantContext: tenantContext,
      authInterceptor: AuthInterceptor(
        tokenStorage: tokens,
        tenantContext: tenantContext,
      ),
      onUnauthorized: () async {
        unauthorized++;
        await tokens.clear();
      },
    );
  });

  tearDown(() => server.close(force: true));

  test('downloads the bytes untouched, as the signed-in workspace', () async {
    final bytes = await client.getBytes('/permits/42/file');

    expect(bytes, pdf);
    final request = seen.single;
    expect(request.uri.path, endsWith('/permits/42/file'));
    expect(request.uri.path, startsWith('/api/'));
    expect(request.headers.value('authorization'), 'Bearer abc');
    expect(request.headers.value('x-tenant'), 'acme');
  });

  test('a refusal is an ApiException with the server\'s sentence', () async {
    status = (_) => 404;

    await expectLater(
      client.getBytes('/permits/42/file'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.status, 'status', 404)
            .having((e) => e.message, 'message', 'Berkas tidak ditemukan.'),
      ),
    );
  });

  test('a 401 ends the session like any other request', () async {
    status = (_) => 401;

    await expectLater(
      client.getBytes('/permits/42/file'),
      throwsA(isA<ApiException>()),
    );
    expect(unauthorized, 1);
    expect(tokens.token, isNull);
  });

  test('no server is a connection failure, and the session stays', () async {
    await server.close(force: true);

    await expectLater(
      client.getBytes('/permits/42/file'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.isConnectionFailure,
          'isConnectionFailure',
          isTrue,
        ),
      ),
    );
    expect(tokens.token, 'abc');
  });
}

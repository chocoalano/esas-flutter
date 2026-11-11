import 'dart:async';
import 'dart:io';

import 'package:esas/core/config/server_config.dart';
import 'package:esas/core/network/api_client.dart';
import 'package:esas/core/network/api_exception.dart';
import 'package:esas/core/network/auth_interceptor.dart';
import 'package:esas/core/storage/secure_store.dart';
import 'package:esas/core/storage/token_storage.dart';
import 'package:esas/core/tenancy/tenant_context.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _Client extends ApiClient {
  _Client(InMemoryTokenStorage tokens)
    : super(
        serverConfig: ServerConfig(store: InMemorySecureStore()),
        tenantContext: TenantContext(store: InMemorySecureStore()),
        authInterceptor: AuthInterceptor(
          tokenStorage: tokens,
          tenantContext: TenantContext(store: InMemorySecureStore()),
        ),
        // Wired to the credential, so a failure mistaken for a 401 shows up
        // as a missing token in the tests below.
        onUnauthorized: tokens.clear,
      );

  late Future<Response<dynamic>> Function() reply;

  @override
  Future<Response<T>> get<T>(
    String url, {
    Map<String, String>? headers,
    String? contentType,
    Map<String, dynamic>? query,
    T Function(dynamic)? decoder,
  }) async => (await reply()) as Response<T>;
}

void main() {
  late InMemoryTokenStorage tokens;
  late _Client client;

  setUp(() {
    tokens = InMemoryTokenStorage('current-token');
    client = _Client(tokens);
  });

  // CORE-04. A radio that has not woken up, a lift, a slow uplink: none of
  // them says anything about whether the credential is still good. Ending the
  // session on them signed people out from background refreshes and from
  // attendance submits the server had already recorded.
  test('a thrown socket failure keeps the session', () async {
    client.reply = () async => throw const SocketException('no route');
    await expectLater(
      client.getObject('/attendance/context'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.isConnectionFailure,
          'isConnectionFailure',
          isTrue,
        ),
      ),
    );
    expect(tokens.token, 'current-token');
  });

  test('a missing HTTP response and a timeout keep the session', () async {
    for (final reply in [
      const Response<dynamic>(),
      const Response<dynamic>(statusText: 'TimeoutException: deadline'),
    ]) {
      client.reply = () async => reply;
      await expectLater(
        client.getObject('/attendance/context'),
        throwsA(isA<ApiException>()),
      );
      expect(tokens.token, 'current-token');
    }
  });

  test(
    'a failed public login request does not disconnect a stored session',
    () async {
      client.reply = () async => throw const SocketException('no route');
      await expectLater(
        client.getObject('/auth/login', authenticated: false),
        throwsA(isA<ApiException>()),
      );
      expect(tokens.token, 'current-token');
    },
  );

  test('HTTP errors and malformed data retain the session', () async {
    for (final reply in [
      const Response<dynamic>(statusCode: 403),
      const Response<dynamic>(statusCode: 423),
      const Response<dynamic>(statusCode: 503),
      const Response<dynamic>(statusCode: 200, body: [1]),
    ]) {
      client.reply = () async => reply;
      await expectLater(
        client.getObject('/attendance/context'),
        throwsA(isA<ApiException>()),
      );
    }
    expect(tokens.token, 'current-token');
  });

  test(
    '401 still ends the authenticated session without a connection alert',
    () async {
      client.reply = () async => const Response<dynamic>(statusCode: 401);
      await expectLater(
        client.getObject('/auth/me'),
        throwsA(isA<ApiException>()),
      );
      expect(tokens.token, isNull);
    },
  );

  test(
    'a delayed 401 from an old account cannot end the new account',
    () async {
      final pending = Completer<Response<dynamic>>();
      client.reply = () => pending.future;
      final request = client.getObject('/attendance/context');
      final checked = expectLater(request, throwsA(isA<ApiException>()));
      await tokens.save('new-account-token');
      pending.complete(const Response<dynamic>(statusCode: 401));
      await checked;
      expect(tokens.token, 'new-account-token');
    },
  );

  // CORE-05. Every failure without a status used to read "Tidak ada koneksi
  // internet" — an expired certificate and a malformed server address too,
  // which sent people to check a Wi-Fi that was working.
  group('a failure that is not the network says so', () {
    test('a certificate the handset will not trust', () async {
      client.reply = () async => const Response<dynamic>(
        statusText:
            'HandshakeException: Handshake error in client (OS Error: '
            'CERTIFICATE_VERIFY_FAILED: certificate has expired)',
      );

      await expectLater(
        client.getObject('/attendance/context'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', 'tls_failure')
              .having((e) => e.isConnectionFailure, 'isConnectionFailure', isFalse)
              .having((e) => e.message, 'message', isNot(contains('internet'))),
        ),
      );
    });

    test('an address that cannot be a request', () async {
      client.reply = () async => const Response<dynamic>(
        statusText: 'FormatException: Invalid radix-10 number',
      );

      await expectLater(
        client.getObject('/attendance/context'),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'client_error')),
      );
    });
  });
}

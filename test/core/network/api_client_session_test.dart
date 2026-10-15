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
  _Client(InMemoryTokenStorage tokens, Future<void> Function() disconnected)
    : super(
        serverConfig: ServerConfig(store: InMemorySecureStore()),
        tenantContext: TenantContext(store: InMemorySecureStore()),
        authInterceptor: AuthInterceptor(
          tokenStorage: tokens,
          tenantContext: TenantContext(store: InMemorySecureStore()),
        ),
        onConnectionLost: disconnected,
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
  late int disconnects;

  setUp(() {
    tokens = InMemoryTokenStorage('current-token');
    disconnects = 0;
    client = _Client(tokens, () async {
      disconnects++;
      await tokens.clear();
    });
  });

  test('a thrown socket failure ends an authenticated session', () async {
    client.reply = () async => throw const SocketException('no route');
    await expectLater(
      client.getObject('/attendance/context'),
      throwsA(isA<ApiException>()),
    );
    expect(tokens.token, isNull);
    expect(disconnects, 1);
  });

  test('a missing HTTP response and timeout both end the session', () async {
    for (final reply in [
      const Response<dynamic>(),
      const Response<dynamic>(statusText: 'TimeoutException: deadline'),
    ]) {
      await tokens.save('current-token');
      client.reply = () async => reply;
      await expectLater(
        client.getObject('/attendance/context'),
        throwsA(isA<ApiException>()),
      );
      expect(tokens.token, isNull);
    }
    expect(disconnects, 2);
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
      expect(disconnects, 0);
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
    expect(disconnects, 0);
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
      expect(disconnects, 0);
    },
  );

  test(
    'a delayed failure from an old account cannot disconnect the new account',
    () async {
      final pending = Completer<Response<dynamic>>();
      client.reply = () => pending.future;
      final request = client.getObject('/attendance/context');
      final checked = expectLater(request, throwsA(isA<ApiException>()));
      await tokens.save('new-account-token');
      pending.complete(const Response<dynamic>());
      await checked;
      expect(tokens.token, 'new-account-token');
      expect(disconnects, 0);
    },
  );
}

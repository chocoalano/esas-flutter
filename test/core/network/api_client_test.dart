import 'dart:async';
import 'dart:io';

import 'package:esas/core/config/api_routes.dart';
import 'package:esas/core/config/env.dart';
import 'package:esas/core/network/api_client.dart';
import 'package:esas/core/network/api_exception.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  group('rebase', () {
    test('moves a path onto the tenant origin', () {
      expect(
        ApiClient.rebase(
          Uri.parse('https://:9443/api/hris-module/permits'),
          'https://acme.hrms.example.com',
        ).toString(),
        'https://acme.hrms.example.com/api/hris-module/permits',
      );
    });

    test('drops the placeholder port instead of carrying it across', () {
      // Uri.replace cannot *remove* a port — asking for port 0 writes a literal
      // `:0` — so the origin is rebuilt rather than patched. Without this the
      // placeholder's :9443 would follow a request onto a server on 443.
      final result = ApiClient.rebase(
        Uri.parse('https://:9443/api/general-module/auth'),
        'https://acme.hrms.example.com',
      );

      expect(result.hasPort, isFalse);
      expect(
        result.toString(),
        'https://acme.hrms.example.com/api/general-module/auth',
      );
    });

    test('keeps an explicit port on the target origin', () {
      expect(
        ApiClient.rebase(
          Uri.parse('https://placeholder/api/x'),
          'http://10.0.2.2:8000',
        ).toString(),
        'http://10.0.2.2:8000/api/x',
      );
    });

    test('carries the query across intact', () {
      expect(
        ApiClient.rebase(
          Uri.parse('https://placeholder/api/notifications?page=2&limit=10'),
          'https://acme.hrms.example.com',
        ).toString(),
        'https://acme.hrms.example.com/api/notifications?page=2&limit=10',
      );
    });
  });

  group('stringifyQuery', () {
    test('drops nulls rather than sending key=null', () {
      expect(
        ApiClient.stringifyQuery({'page': 1, 'search': null, 'limit': 10}),
        {'page': '1', 'limit': '10'},
      );
    });

    test('is null for nothing to send', () {
      expect(ApiClient.stringifyQuery(null), isNull);
      expect(ApiClient.stringifyQuery({}), isNull);
      expect(ApiClient.stringifyQuery({'a': null}), isNull);
    });

    test('encodes a value that would have corrupted a concatenated URL', () {
      // permit_list_controller and notification_controller hand-built
      // '?page=$p&limit=$n'. A search term containing & broke the request
      // (MED-01); going through the query map is what fixes it.
      final query = ApiClient.stringifyQuery({'search': 'A&B'});

      expect(query, {'search': 'A&B'});
      expect(Uri(queryParameters: query).query, 'search=A%26B');
    });
  });

  group('unwrapObject', () {
    test('returns the decoded body on success', () {
      final body = ApiClient.unwrapObject(
        const Response(statusCode: 200, body: {'name': 'Budi'}),
      );

      expect(body, {'name': 'Budi'});
    });

    test('an empty 200 is a success with nothing in it', () {
      // Logout answers this way. It is not a malformed response.
      expect(
        ApiClient.unwrapObject(const Response(statusCode: 200, body: null)),
        isEmpty,
      );
      expect(
        ApiClient.unwrapObject(const Response(statusCode: 200, body: '  ')),
        isEmpty,
      );
    });

    test('throws the server refusal', () {
      expect(
        () => ApiClient.unwrapObject(
          const Response(statusCode: 422, body: {'message': 'Tidak valid.'}),
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.status, 'status', 422)
              .having((e) => e.message, 'message', 'Tidak valid.'),
        ),
      );
    });

    test('a missing status is a transport failure, not a refusal', () {
      expect(
        () => ApiClient.unwrapObject(const Response(body: null)),
        throwsA(
          isA<ApiException>().having(
            (e) => e.isTransportFailure,
            'transport',
            isTrue,
          ),
        ),
      );
    });

    test('refuses a body of the wrong shape', () {
      expect(
        () => ApiClient.unwrapObject(
          const Response(statusCode: 200, body: [1, 2]),
        ),
        throwsA(
          isA<ApiException>().having(
            (e) => e.code,
            'code',
            'malformed_response',
          ),
        ),
      );
    });
  });

  group('unwrapList', () {
    test('returns a bare array', () {
      expect(
        ApiClient.unwrapList(const Response(statusCode: 200, body: [1, 2, 3])),
        [1, 2, 3],
      );
    });

    test('unwraps the paginated {"data": [...]} shape', () {
      // /general-module/notifications answers this way while
      // /general-module/announcements/active answers with a bare array.
      expect(
        ApiClient.unwrapList(
          const Response(
            statusCode: 200,
            body: {
              'data': [1, 2],
            },
          ),
        ),
        [1, 2],
      );
    });

    test('an empty 200 is an empty list', () {
      expect(
        ApiClient.unwrapList(const Response(statusCode: 200, body: null)),
        isEmpty,
      );
    });
  });

  group('guardFailure', () {
    test('turns a dead socket into an ApiException', () async {
      await expectLater(
        ApiClient.guardFailure(
          () async => throw const SocketException('no route'),
        ),
        throwsA(
          isA<ApiException>().having(
            (e) => e.code,
            'code',
            'network_unreachable',
          ),
        ),
      );
    });

    test('catches a TimeoutException the named cases would miss', () async {
      // GetConnect applies its timeout with Future.timeout and no onTimeout.
      await expectLater(
        ApiClient.guardFailure(() async => throw TimeoutException('stalled')),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'timeout')),
      );
    });

    test('lets a success through untouched', () async {
      expect(await ApiClient.guardFailure(() async => 42), 42);
    });
  });

  group('the API prefix reaches the server', () {
    // The regression this pins, in full.
    //
    // Every path in `ApiRoutes` is written relative to `Env.apiPrefix` and never
    // repeats it, so the prefix can only enter a request from `httpClient
    // .baseUrl`. `rebase` then swaps the ORIGIN and keeps whatever path that
    // base produced.
    //
    // Setting the base to a bare origin therefore does not fail loudly: it sends
    // every request one path segment short. Login went to `<origin>/auth/login`
    // and the server answered 404 "The route auth/login could not be found",
    // which reads as a backend fault and is not one.

    test('the placeholder base carries the prefix', () {
      expect(ApiClient.placeholderBaseUrl, endsWith(Env.apiPrefix));
      expect(
        ApiClient.placeholderBaseUrl,
        startsWith(ApiClient.placeholderOrigin),
      );
    });

    test('the placeholder origin can never resolve', () {
      // `.invalid` is reserved by RFC 2606. A request that escaped the modifier
      // must fail locally, not reach a stranger's server.
      expect(Uri.parse(ApiClient.placeholderOrigin).host, endsWith('.invalid'));
    });

    test('GetConnect CONCATENATES the base and the route', () {
      // `GetHttpClient._createUri` is `url = baseUrl! + url!` — string
      // concatenation, not URI resolution. That is the only reason a base of
      // `…/api/v1` and a route of `/auth/login` produce `/api/v1/auth/login`.
      //
      // Pinned because the difference is invisible and total: `Uri.resolve`
      // treats a leading slash as an ABSOLUTE path and throws the prefix away,
      // so a future change to resolution semantics would silently send every
      // request one segment short — which is exactly the shape of the 404 this
      // group exists for.
      final concatenated = Uri.parse(
        '${ApiClient.placeholderBaseUrl}${ApiRoutes.login}',
      );
      final resolved = Uri.parse(
        ApiClient.placeholderBaseUrl,
      ).resolve(ApiRoutes.login);

      expect(concatenated.path, '${Env.apiPrefix}${ApiRoutes.login}');
      // The trap, stated: resolution would drop it.
      expect(resolved.path, ApiRoutes.login);
      expect(resolved.path, isNot(startsWith(Env.apiPrefix)));
    });

    test('a route appended to the base keeps the prefix', () {
      // The composition GetConnect actually performs for a path with no leading
      // slash resolution — base + route — which is what `ApiRoutes` relies on.
      final sent = ApiClient.rebase(
        Uri.parse('${ApiClient.placeholderBaseUrl}${ApiRoutes.login}'),
        'https://acme.hrms.example.com',
      );

      expect(
        sent.toString(),
        'https://acme.hrms.example.com${Env.apiPrefix}${ApiRoutes.login}',
      );
      expect(sent.path, startsWith(Env.apiPrefix));
    });

    test('the placeholder never survives onto a real request', () {
      final sent = ApiClient.rebase(
        Uri.parse(
          '${ApiClient.placeholderBaseUrl}${ApiRoutes.attendanceContext}',
        ),
        'https://acme.hrms.example.com',
      );

      expect(sent.host, 'acme.hrms.example.com');
      expect(sent.toString(), isNot(contains('invalid')));
      expect(sent.hasPort, isFalse);
    });
  });
}

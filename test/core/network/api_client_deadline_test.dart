import 'dart:convert';
import 'dart:io';

import 'package:esas/core/config/api_routes.dart';
import 'package:esas/core/config/env.dart';
import 'package:esas/core/config/server_config.dart';
import 'package:esas/core/network/api_client.dart';
import 'package:esas/core/network/api_exception.dart';
import 'package:esas/core/network/auth_interceptor.dart';
import 'package:esas/core/network/upload.dart';
import 'package:esas/core/storage/secure_store.dart';
import 'package:esas/core/storage/token_storage.dart';
import 'package:esas/core/tenancy/tenant_context.dart';
import 'package:flutter_test/flutter_test.dart';

/// `flutter_test` answers every request with a 400 unless a test opts out.
class _RealHttp extends HttpOverrides {}

/// The one deadline that is deliberately longer than the rest.
///
/// A face submission is answered only after the backend has had the capture
/// scored, and the backend waits on the face service to do it:
/// `FACE_API_CONNECT_TIMEOUT` (10 s) plus `FACE_API_TIMEOUT` (45 s) in
/// `tenancy-app`. A handset that gives up before that has not cancelled
/// anything — the attendance is still written, by a server nobody is listening
/// to, against a challenge that is now spent.
///
/// These run on a real socket because the thing under test is which transport a
/// request leaves on, and a mocked `ApiClient` cannot say.
void main() {
  // What the answer is held back for. Longer than the ordinary deadline below
  // and shorter than the scoring one, so each request can only pass or fail for
  // the reason the test names.
  const serverThinks = Duration(milliseconds: 700);
  const ordinary = Duration(milliseconds: 200);
  const scoring = Duration(seconds: 5);

  late HttpServer server;
  late List<String> served;

  setUp(() async {
    // Held locally as well, so a handler still thinking when its test ends
    // writes into its own list and not into the next test's.
    final seen = served = <String>[];
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);

    server.listen((request) async {
      await request.drain<void>();
      await Future<void>.delayed(serverThinks);

      seen.add('${request.method} ${request.uri.path}');

      request.response
        ..statusCode = HttpStatus.created
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'message': 'Absensi tercatat.'}));

      await request.response.close();
    });
  });

  tearDown(() => server.close(force: true));

  Future<T> onTheWire<T>(Future<T> Function(ApiClient client) body) {
    return HttpOverrides.runWithHttpOverrides(() async {
      final tenant = TenantContext(store: InMemorySecureStore());
      await tenant.remember('acme');

      final client = ApiClient(
        serverConfig: ServerConfig(store: InMemorySecureStore())
          ..domain = 'http://127.0.0.1:${server.port}'
          ..subdomainMode = false,
        tenantContext: tenant,
        authInterceptor: AuthInterceptor(
          tokenStorage: InMemoryTokenStorage('live-token'),
          tenantContext: tenant,
        ),
        timeout: ordinary,
        scoringTimeout: scoring,
      )..onInit();

      try {
        return await body(client);
      } finally {
        client.dispose();
      }
    }, _RealHttp());
  }

  Future<File> capture() async {
    final dir = await Directory.systemTemp.createTemp('esas-capture');
    addTearDown(() => dir.delete(recursive: true));

    return File('${dir.path}/capture.jpg')..writeAsBytesSync(List.filled(64, 0));
  }

  test('an ordinary request gives up at the ordinary deadline', () async {
    await expectLater(
      onTheWire((client) => client.getObject(ApiRoutes.attendanceContext)),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'timeout')),
    );
  });

  test('an ordinary form is held to the ordinary deadline too', () async {
    final image = await capture();

    await expectLater(
      onTheWire(
        (client) => client.postForm(
          ApiRoutes.faceAttendance,
          {'type': 'in'},
          files: {'image': Upload.file(image)},
        ),
      ),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'timeout')),
    );
  });

  test(
    'a form that waits on scoring is still listening when the answer comes',
    () async {
      final image = await capture();

      final body = await onTheWire(
        (client) => client.postForm(
          ApiRoutes.faceAttendance,
          {'type': 'in'},
          files: {'image': Upload.file(image)},
          awaitsScoring: true,
        ),
      );

      expect(body['message'], 'Absensi tercatat.');
      // The same server, the same prefix, the same path: the second transport
      // resolves its origin exactly as the first does.
      expect(served, ['POST ${Env.apiPrefix}${ApiRoutes.faceAttendance}']);
    },
  );

  test('the scoring deadline outlasts the backend\'s wait on the face service', () {
    // FACE_API_CONNECT_TIMEOUT + FACE_API_TIMEOUT in tenancy-app. If either is
    // raised there, this number has to move with it — inner budget first.
    const backendWaitsOnFaceService = Duration(seconds: 10 + 45);

    expect(
      ApiClient.defaultScoringTimeout,
      greaterThan(backendWaitsOnFaceService),
    );
  });
}

import 'package:esas/core/config/api_routes.dart';
import 'package:esas/core/network/api_client.dart';
import 'package:esas/core/storage/local_storage.dart';
import 'package:esas/core/storage/token_storage.dart';
import 'package:esas/features/auth/data/repositories/auth_repository.dart';
import 'package:esas/features/auth/data/repositories/session_repository.dart';
import 'package:esas/features/auth/data/services/auth_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Client extends Mock implements ApiClient {}

class _Api extends Mock implements AuthApiService {}

/// CORE-03. Handsets already bound to the old Android value (`Build.ID`) must
/// not lose attendance the day they update. Sign-in sends that value as
/// `legacy_device_id` so the server can move the binding — and sends nothing
/// when there is nothing to move.
void main() {
  const reply = {
    'token': 'abc',
    'user': {'id': 7, 'name': 'Budi'},
  };

  group('the request', () {
    late _Client client;

    setUp(() {
      client = _Client();
      when(
        () => client.postObject(
          any(),
          any(),
          authenticated: any(named: 'authenticated'),
        ),
      ).thenAnswer((_) async => Map<String, dynamic>.from(reply));
    });

    Map<dynamic, dynamic> sentTo(String path) =>
        verify(
              () => client.postObject(
                path,
                captureAny(),
                authenticated: false,
              ),
            ).captured.single
            as Map<dynamic, dynamic>;

    test('a password sign-in carries the legacy identifier', () async {
      await AuthApiService(client).login(
        identifier: 'x',
        password: 'y',
        deviceId: 'android-id',
        legacyDeviceId: 'TP1A.220624.014',
      );

      final body = sentTo(ApiRoutes.login);
      expect(body['device_id'], 'android-id');
      expect(body['legacy_device_id'], 'TP1A.220624.014');
    });

    test('a Google sign-in carries it too', () async {
      await AuthApiService(client).loginWithFirebase(
        idToken: 't',
        deviceId: 'android-id',
        legacyDeviceId: 'TP1A.220624.014',
      );

      expect(
        sentTo(ApiRoutes.firebaseLogin)['legacy_device_id'],
        'TP1A.220624.014',
      );
    });

    test('nothing is sent when there is nothing to migrate', () async {
      await AuthApiService(
        client,
      ).login(identifier: 'x', password: 'y', deviceId: 'idfv');

      expect(sentTo(ApiRoutes.login).containsKey('legacy_device_id'), isFalse);
    });
  });

  test('the repository passes it through', () async {
    final api = _Api();
    when(
      () => api.login(
        identifier: any(named: 'identifier'),
        password: any(named: 'password'),
        deviceId: any(named: 'deviceId'),
        legacyDeviceId: any(named: 'legacyDeviceId'),
      ),
    ).thenAnswer((_) async => Map<String, dynamic>.from(reply));

    await AuthRepository(
      api: api,
      session: SessionRepository(
        tokenStorage: InMemoryTokenStorage(),
        localStorage: InMemoryLocalStorage(),
      ),
    ).login(
      identifier: 'x',
      password: 'y',
      deviceId: 'android-id',
      legacyDeviceId: 'TP1A.220624.014',
    );

    verify(
      () => api.login(
        identifier: 'x',
        password: 'y',
        deviceId: 'android-id',
        legacyDeviceId: 'TP1A.220624.014',
      ),
    ).called(1);
  });
}

import 'package:esas/core/services/device_info_service.dart';
import 'package:esas/core/storage/secure_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// CORE-03. The handset binding is what stops one employee clocking in for
/// another. It was `AndroidDeviceInfo.id` — `Build.ID`, a firmware label such
/// as `TP1A.220624.014` that every phone on the same build shares and that
/// changes on every OS update — and a constant `'device_info_error'` whenever
/// the platform failed, shared by every handset that failed.
void main() {
  DeviceInfoService service({
    required SecureStore store,
    Future<String?> Function()? platformId,
    Future<String?> Function()? legacyId,
  }) => DeviceInfoService(
    store: store,
    platformId: platformId ?? () async => null,
    legacyId: legacyId ?? () async => null,
  );

  test('uses the platform identifier when there is one', () async {
    final id = await service(
      store: InMemorySecureStore(),
      platformId: () async => 'a1b2c3d4e5f60718',
    ).deviceId();

    expect(id, 'a1b2c3d4e5f60718');
  });

  group('without a platform identifier', () {
    test('falls back to an install identifier, not a shared constant', () async {
      final first = await service(store: InMemorySecureStore()).deviceId();
      final second = await service(store: InMemorySecureStore()).deviceId();

      expect(first, isNotEmpty);
      expect(first, isNot(second));
      expect(first, isNot(contains('error')));
      expect(first, isNot(contains('unknown')));
    });

    test('keeps the same install identifier across launches', () async {
      final store = InMemorySecureStore();

      final first = await service(store: store).deviceId();
      final again = await service(store: store).deviceId();

      expect(again, first);
    });

    test('treats a platform failure the same way', () async {
      final store = InMemorySecureStore();

      final id = await service(
        store: store,
        platformId: () async => throw PlatformException(code: 'boom'),
      ).deviceId();

      expect(id, isNot('device_info_error'));
      expect(await service(store: store).deviceId(), id);
    });
  });

  group('the legacy identifier, for migrating an existing binding', () {
    test('is offered when it differs from the current one', () async {
      final legacy = await service(
        store: InMemorySecureStore(),
        platformId: () async => 'a1b2c3d4e5f60718',
        legacyId: () async => 'TP1A.220624.014',
      ).legacyDeviceId();

      expect(legacy, 'TP1A.220624.014');
    });

    test('is not offered when it is the same identifier', () async {
      final legacy = await service(
        store: InMemorySecureStore(),
        platformId: () async => 'same',
        legacyId: () async => 'same',
      ).legacyDeviceId();

      expect(legacy, isNull);
    });

    test('is not offered when the platform cannot give one', () async {
      final legacy = await service(
        store: InMemorySecureStore(),
        legacyId: () async => throw PlatformException(code: 'boom'),
      ).legacyDeviceId();

      expect(legacy, isNull);
    });
  });

  // UAT review C4. The fallback was cached in memory only, and the platform
  // id was preferred again on every launch. A channel that failed once at
  // sign-in bound the account to `install-…`; the next launch sent ANDROID_ID
  // and the same phone was "another handset", with no migration to recover.
  test('a fallback once used is kept on the next launch', () async {
    final store = InMemorySecureStore();
    var platformWorks = false;
    DeviceInfoService launch() => DeviceInfoService(
      store: store,
      platformId: () async {
        if (!platformWorks) throw PlatformException(code: 'unavailable');
        return 'a1b2c3d4e5f60718';
      },
      legacyId: () async => null,
    );

    final atSignIn = await launch().deviceId();
    expect(atSignIn, startsWith('install-'));

    platformWorks = true;
    expect(await launch().deviceId(), atSignIn);
  });

  test('a platform id that works from the start stays the platform id', () async {
    final store = InMemorySecureStore();
    DeviceInfoService launch() => DeviceInfoService(
      store: store,
      platformId: () async => 'a1b2c3d4e5f60718',
      legacyId: () async => null,
    );

    expect(await launch().deviceId(), 'a1b2c3d4e5f60718');
    expect(await launch().deviceId(), 'a1b2c3d4e5f60718');
  });
}

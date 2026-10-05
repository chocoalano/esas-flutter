import 'package:esas/core/storage/local_storage.dart';
import 'package:esas/core/storage/secure_store.dart';
import 'package:esas/core/storage/storage_keys.dart';
import 'package:esas/core/storage/token_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late InMemorySecureStore secure;
  late InMemoryLocalStorage legacy;

  setUp(() {
    secure = InMemorySecureStore();
    legacy = InMemoryLocalStorage();
  });

  SecureTokenStorage build() =>
      SecureTokenStorage(store: secure, legacy: legacy);

  test('is empty on a fresh install', () async {
    final storage = build();

    await storage.restore();

    expect(storage.token, isNull);
  });

  test('round-trips a token through the keychain', () async {
    final storage = build();

    await storage.save('abc123');

    expect(storage.token, 'abc123');
    expect(await secure.read(StorageKeys.secure.token), 'abc123');
  });

  group('migration from the plaintext store', () {
    test(
      'adopts a token the old login controller left in GetStorage',
      () async {
        await legacy.write(StorageKeys.legacy.token, 'legacy-token');

        final storage = build();
        await storage.restore();

        expect(storage.token, 'legacy-token');
        expect(await secure.read(StorageKeys.secure.token), 'legacy-token');
      },
    );

    test('moves it rather than copying it', () async {
      // A token left in plain storage after being secured is the same exposure
      // with an extra step (MED-06).
      await legacy.write(StorageKeys.legacy.token, 'legacy-token');

      await build().restore();

      expect(legacy.read<String>(StorageKeys.legacy.token), isNull);
    });

    test('runs at most once', () async {
      await legacy.write(StorageKeys.legacy.token, 'legacy-token');
      await build().restore();

      // A later session finds the secure copy and must not look at the legacy
      // key again — nor resurrect a stale one written since.
      await legacy.write(StorageKeys.legacy.token, 'stale');

      final second = build();
      await second.restore();

      expect(second.token, 'legacy-token');
    });

    test('ignores a blank legacy value', () async {
      await legacy.write(StorageKeys.legacy.token, '');

      final storage = build();
      await storage.restore();

      expect(storage.token, isNull);
    });
  });

  test('clear empties both stores', () async {
    await legacy.write(StorageKeys.legacy.token, 'legacy-token');
    final storage = build();
    await storage.restore();

    await storage.clear();

    expect(storage.token, isNull);
    expect(await secure.read(StorageKeys.secure.token), isNull);
    expect(legacy.read<String>(StorageKeys.legacy.token), isNull);
  });

  group('the session wipe list', () {
    test('names every key the three clearStorage copies disagreed about', () {
      // MED-05: SplashController.clearStorage omitted userJson and userAvatar,
      // so employee PII survived a logout the user did not ask for.
      expect(
        StorageKeys.legacy.sessionKeys,
        containsAll([
          'auth_token',
          'auth_token_type',
          'auth_user_name',
          'auth_user_id',
          'auth_user_nip',
          'auth_user_password',
          'auth_user_avatar',
          'auth_user_json',
        ]),
      );
    });

    test('a wipe using it leaves nothing behind', () async {
      final store = InMemoryLocalStorage({
        for (final key in StorageKeys.legacy.sessionKeys) key: 'x',
        'isDarkMode': true,
      });

      await store.removeAll(StorageKeys.legacy.sessionKeys);

      for (final key in StorageKeys.legacy.sessionKeys) {
        expect(store.hasData(key), isFalse, reason: '$key survived the wipe');
      }

      // The theme preference is not an auth key and must survive.
      expect(store.read<bool>('isDarkMode'), isTrue);
    });
  });
}

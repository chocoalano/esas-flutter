import 'package:esas/core/storage/local_storage.dart';
import 'package:esas/core/storage/secure_store.dart';
import 'package:esas/core/storage/storage_keys.dart';
import 'package:esas/core/storage/token_storage.dart';
import 'package:esas/features/auth/data/models/auth_user.dart';
import 'package:esas/features/auth/data/repositories/session_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late InMemoryLocalStorage local;
  late InMemorySecureStore secure;
  late InMemoryTokenStorage tokens;
  late SessionRepository session;

  setUp(() {
    local = InMemoryLocalStorage();
    secure = InMemorySecureStore();
    tokens = InMemoryTokenStorage();
    session = SessionRepository(tokenStorage: tokens, localStorage: local);
  });

  AuthUser user() => AuthUser.fromJson({
    'id': 7,
    'name': 'Budi',
    'nip': '20240113',
    'avatar': 'avatars/budi.png',
    'company': {'id': 1, 'latitude': -6.17566, 'longitude': 106.59925},
    'employee': {'departement_id': 3, 'user_id': 7},
  });

  group('clear', () {
    test('wipes every legacy auth key, from one list', () async {
      // MED-05: three hand-written clearStorage() copies had drifted, and the
      // splash one omitted userJson and userAvatar — so a logout left the
      // previous employee's whole record on the device.
      await session.save(token: 'abc', user: user());

      await session.clear();

      for (final key in StorageKeys.legacy.sessionKeys) {
        expect(local.hasData(key), isFalse, reason: '$key survived clear()');
      }
      expect(tokens.token, isNull);
      expect(session.user, isNull);
      expect(session.isAuthenticated, isFalse);
    });

    test('leaves the theme preference alone', () async {
      await local.write('isDarkMode', true);
      await session.save(token: 'abc', user: user());

      await session.clear();

      // Not an auth key. Signing out must not reset somebody's theme.
      expect(local.read<bool>('isDarkMode'), isTrue);
    });
  });

  group('the plaintext password', () {
    test('is purged from an existing install on restore', () async {
      // CRIT-03. The key is never written again, but without this it would
      // survive on every device that already has it, indefinitely.
      await local.write(StorageKeys.legacy.userPassword, 'hunter2');

      await session.restore();

      expect(local.hasData(StorageKeys.legacy.userPassword), isFalse);
    });

    test('is never written by save', () async {
      await session.save(token: 'abc', user: user());

      expect(local.hasData(StorageKeys.legacy.userPassword), isFalse);
    });
  });

  group('where things are kept', () {
    test('the credential lives in exactly one place', () async {
      // Phase 5 retired the last reader of the plain-storage copy, so the
      // mirror is off: the token is in the keychain and nowhere else.
      await session.save(token: 'abc', user: user());

      expect(tokens.token, 'abc');
      expect(local.read<String>(StorageKeys.legacy.token), isNull);
      expect(local.read<String>(StorageKeys.legacy.userName), isNull);
      expect(local.read<int>(StorageKeys.legacy.userId), isNull);
    });

    test(
      'the user record is cached locally, because losing it is cheap',
      () async {
        await session.save(token: 'abc', user: user());

        expect(local.read<dynamic>(StorageKeys.legacy.userJson), isA<Map>());
      },
    );

    test(
      'updateUser refreshes the cache without touching the credential',
      () async {
        await session.save(token: 'abc', user: user());

        await session.updateUser(user().copyWith(name: 'Budi Santoso'));

        expect(session.user?.name, 'Budi Santoso');
        expect(tokens.token, 'abc');
      },
    );

    test('an upgrading device keeps its session', () async {
      // The token an older build left in plain storage is migrated into the
      // keychain on restore, not ignored — otherwise updating would sign
      // everybody out.
      await local.write(StorageKeys.legacy.token, 'legacy-token');
      await local.write(StorageKeys.legacy.userJson, user().raw);

      final upgraded = SessionRepository(
        tokenStorage: SecureTokenStorage(store: secure, legacy: local),
        localStorage: local,
      );
      await upgraded.restore();

      expect(upgraded.isAuthenticated, isTrue);
      expect(upgraded.token, 'legacy-token');
      expect(upgraded.user?.name, 'Budi');
      expect(local.read<String>(StorageKeys.legacy.token), isNull);
    });
  });

  test('restore rehydrates the cached user', () async {
    await session.save(token: 'abc', user: user());

    final next = SessionRepository(
      tokenStorage: InMemoryTokenStorage('abc'),
      localStorage: local,
    );
    await next.restore();

    expect(next.isAuthenticated, isTrue);
    expect(next.user?.name, 'Budi');
    expect(next.user?.departementId, 3);
  });
}

import 'package:esas/core/storage/install_identity.dart';
import 'package:esas/core/storage/local_storage.dart';
import 'package:esas/core/storage/secure_store.dart';
import 'package:esas/core/storage/storage_keys.dart';
import 'package:esas/core/storage/token_storage.dart';
import 'package:esas/features/auth/data/repositories/session_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// CORE-02. The iOS keychain outlives an uninstall; the app's documents
/// directory (GetStorage) does not. Without telling the two apart, a reinstall
/// on a handed-over iPhone signed straight in as the previous employee.
void main() {
  Map<String, String> previousInstall() => {
    StorageKeys.secure.token: 'token-of-employee-a',
    StorageKeys.secure.tenant: 'acme',
    StorageKeys.secure.serverDomain: 'https://hrms.example.com',
    StorageKeys.secure.serverSubdomainMode: 'true',
  };

  group('a fresh install', () {
    test('forgets the credential and workspace a previous install left', () async {
      final local = InMemoryLocalStorage();
      final secure = InMemorySecureStore(previousInstall());

      final kind = await InstallIdentity(local: local, secure: secure)
          .reconcile();

      expect(kind, InstallKind.fresh);
      for (final key in StorageKeys.secure.installScoped) {
        expect(await secure.read(key), isNull, reason: key);
      }
    });

    test('cannot restore the previous employee\'s session', () async {
      final local = InMemoryLocalStorage();
      final secure = InMemorySecureStore(previousInstall());

      await InstallIdentity(local: local, secure: secure).reconcile();

      final session = SessionRepository(
        tokenStorage: SecureTokenStorage(store: secure, legacy: local),
        localStorage: local,
      );
      await session.restore();

      expect(session.isAuthenticated, isFalse);
    });

    test('is recognised as known on the next launch', () async {
      final local = InMemoryLocalStorage();
      final secure = InMemorySecureStore(previousInstall());
      final identity = InstallIdentity(local: local, secure: secure);

      await identity.reconcile();
      await secure.write(StorageKeys.secure.token, 'token-of-employee-b');

      expect(await identity.reconcile(), InstallKind.known);
      expect(
        await secure.read(StorageKeys.secure.token),
        'token-of-employee-b',
      );
    });
  });

  group('an install upgrading from a build without the marker', () {
    test('keeps its session and workspace', () async {
      // An older build has already written to local storage; only the marker
      // is missing. Signing everybody out on update would be the bug in reverse.
      final local = InMemoryLocalStorage({
        StorageKeys.local.isDarkMode: true,
        StorageKeys.legacy.userJson: {'id': 7, 'name': 'Budi'},
      });
      final secure = InMemorySecureStore(previousInstall());

      final kind = await InstallIdentity(local: local, secure: secure)
          .reconcile();

      expect(kind, InstallKind.upgraded);
      expect(await secure.read(StorageKeys.secure.token), 'token-of-employee-a');
      expect(await secure.read(StorageKeys.secure.tenant), 'acme');
      expect(local.hasData(StorageKeys.local.installMarker), isTrue);
    });
  });

  test('leaves unrelated local preferences alone on a fresh install', () async {
    final local = InMemoryLocalStorage();
    final secure = InMemorySecureStore(previousInstall());

    await InstallIdentity(local: local, secure: secure).reconcile();

    expect(local.hasData(StorageKeys.local.installMarker), isTrue);
  });
}

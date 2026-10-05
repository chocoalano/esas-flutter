import 'local_storage.dart';
import 'secure_store.dart';
import 'storage_keys.dart';

/// The bearer token, and nothing else.
///
/// Deliberately narrow. `AuthInterceptor` needs to answer one question on every
/// request — what token, if any — and giving it the whole storage surface is how
/// a network layer ends up reading a user object.
///
/// [token] is a synchronous getter because a request modifier cannot await. The
/// value is held in memory and refreshed by [restore] at bootstrap and by
/// [save]/[clear]; the keychain is the durable copy, not the hot path.
abstract interface class TokenStorage {
  String? get token;

  Future<void> restore();

  Future<void> save(String token);

  Future<void> clear();
}

/// Keeps the token in the keychain (ADR-0005, TEN-04).
///
/// Migrates a token written by the pre-refactor login controller, which put it
/// in `GetStorage` in the clear. The legacy copy is deleted once the secure copy
/// lands, so the migration runs at most once per install and leaves nothing
/// behind. See MED-06.
class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage({required SecureStore store, LocalStorage? legacy})
    : _store = store,
      _legacy = legacy;

  final SecureStore _store;
  final LocalStorage? _legacy;

  String? _token;

  @override
  String? get token => _token;

  @override
  Future<void> restore() async {
    _token = await _store.read(StorageKeys.secure.token);

    if (_token != null) {
      return;
    }

    final legacyToken = _legacy?.read<String>(StorageKeys.legacy.token);

    if (legacyToken == null || legacyToken.isEmpty) {
      return;
    }

    // Move it, rather than copy it. A token left in plain storage after being
    // secured is the same exposure with an extra step.
    await save(legacyToken);
    await _legacy?.remove(StorageKeys.legacy.token);
  }

  @override
  Future<void> save(String token) async {
    _token = token;

    await _store.write(StorageKeys.secure.token, token);
  }

  @override
  Future<void> clear() async {
    _token = null;

    await _store.delete(StorageKeys.secure.token);
    await _legacy?.remove(StorageKeys.legacy.token);
  }
}

/// An in-memory token store, for tests.
class InMemoryTokenStorage implements TokenStorage {
  InMemoryTokenStorage([this._token]);

  String? _token;

  @override
  String? get token => _token;

  @override
  Future<void> restore() async {}

  @override
  Future<void> save(String token) async => _token = token;

  @override
  Future<void> clear() async => _token = null;
}

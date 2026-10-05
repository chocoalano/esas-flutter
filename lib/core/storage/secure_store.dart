import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The keychain, behind an interface small enough to fake in a test.
///
/// Credentials and the tenancy configuration live here rather than in
/// `GetStorage`, which writes plain JSON to the documents directory. See
/// TEN-04 and MED-06 in the architecture audit, and ADR-0005.
///
/// Every read swallows its failure and answers null. An unreadable keystore — a
/// restored backup, a wiped key, an OEM build where the plugin misbehaves — is a
/// handset that has to be set up again, which the setup screen can do. It is not
/// a crash on the first frame.
abstract interface class SecureStore {
  /// Read a value, or null.
  ///
  /// **Contract: never throws.** Every implementation swallows its failure and
  /// answers null. An unreadable keystore — a restored backup, a wiped key, an
  /// OEM build where the plugin misbehaves — is a handset that has to be set up
  /// again, which the setup screen can do. It is not a crash on the first frame,
  /// and callers are written on that guarantee rather than each guarding
  /// separately.
  Future<String?> read(String key);

  /// Store a value. **Contract: never throws.**
  Future<void> write(String key, String value);

  /// Forget a value. **Contract: never throws.**
  Future<void> delete(String key);
}

/// The real one.
class KeychainSecureStore implements SecureStore {
  KeychainSecureStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock,
            ),
          );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) async {
    try {
      final value = await _storage.read(key: key);

      return (value == null || value.isEmpty) ? null : value;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (_) {
      // A write that cannot land leaves the handset unconfigured rather than
      // half-configured. The caller's next read answers null and the setup or
      // login screen asks again.
    }
  }

  @override
  Future<void> delete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (_) {
      // Nothing to do about a keystore that will not forget. The session is
      // cleared in memory regardless, so the app behaves as signed out.
    }
  }
}

/// An in-memory [SecureStore] for tests and for the widget-test environment,
/// where no platform channel answers.
class InMemorySecureStore implements SecureStore {
  InMemorySecureStore([Map<String, String>? seed]) : _values = {...?seed};

  final Map<String, String> _values;

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);
}

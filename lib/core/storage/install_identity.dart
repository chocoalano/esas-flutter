import '../utils/app_logger.dart';
import 'local_storage.dart';
import 'secure_store.dart';
import 'storage_keys.dart';

/// How this launch relates to what the device already holds.
enum InstallKind {
  /// The marker is there: an install this code has already seen.
  known,

  /// No marker, but local storage has data: an older build of this app,
  /// updated in place. Its session is legitimate and is kept.
  upgraded,

  /// No marker and an empty local store: installed just now. Anything the
  /// keychain still holds belongs to an install that no longer exists.
  fresh,
}

/// Stops a reinstall from inheriting the previous install's session (CORE-02).
///
/// The iOS keychain is not removed with the app; its documents directory is.
/// So the keychain alone cannot tell "this person signed in yesterday" from
/// "somebody else signed in on this phone before it was wiped and handed on" —
/// and a token that survives the second case opens the previous employee's
/// payslips for the next person.
///
/// Local storage can tell, because it does not survive. A marker written there
/// on first launch distinguishes the three cases in [InstallKind]. Only the
/// keys in [StorageKeys.secure.installScoped] are forgotten — never a
/// `deleteAll()` on a store other code may share.
///
/// Must run before anything restores from the keychain.
class InstallIdentity {
  InstallIdentity({required LocalStorage local, required SecureStore secure})
    : _local = local,
      _secure = secure;

  final LocalStorage _local;
  final SecureStore _secure;

  Future<InstallKind> reconcile() async {
    if (_local.hasData(StorageKeys.local.installMarker)) {
      return InstallKind.known;
    }

    // Read before the marker is written: the marker itself would make the
    // store non-empty.
    final fresh = _local.isEmpty;

    if (fresh) {
      for (final key in StorageKeys.secure.installScoped) {
        await _secure.delete(key);
      }

      AppLogger.info('Fresh install: cleared credentials from a previous one.');
    }

    await _local.write(
      StorageKeys.local.installMarker,
      DateTime.now().toUtc().toIso8601String(),
    );

    return fresh ? InstallKind.fresh : InstallKind.upgraded;
  }
}

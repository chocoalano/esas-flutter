import '../../../../core/storage/local_storage.dart';
import '../../../../core/storage/storage_keys.dart';
import '../../../../core/storage/token_storage.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/tenancy/workspace_clock.dart';
import '../models/auth_user.dart';

/// The single authority on whether somebody is signed in, and on what is kept
/// about them.
///
/// It replaces three hand-written `clearStorage()` methods — in
/// `LoginController`, `SplashController` and `ProfileController` — that had
/// drifted apart. `SplashController`'s omitted `auth_user_json` and
/// `auth_user_avatar`, so a logout triggered from splash left the previous
/// employee's whole record, name and photograph on the device for the next
/// person to see (MED-05).
///
/// ## Where things are kept
///
/// The **credential** goes to the keychain, through [TokenStorage]. The **cached
/// user record** goes to local storage: it is display data that is refetched on
/// every launch, and losing it costs a screen refresh rather than a session.
///
/// Until Phase 5 finished, [save] also mirrored the token and four scalar copies
/// of the user into the pre-refactor `GetStorage` keys, because unmigrated
/// screens read them directly — `ApiProvider` took `auth_token` from there to
/// sign its requests. Every one of those readers is now gone, `ApiProvider` with
/// them, so the mirror is off and the token exists in exactly one place.
///
/// [clear] still names every legacy key. That is deliberate: devices upgrading
/// from an older build still carry them, and a logout must not leave a previous
/// employee's record behind (MED-05).
class SessionRepository {
  SessionRepository({
    required TokenStorage tokenStorage,
    required LocalStorage localStorage,
  }) : _tokens = tokenStorage,
       _local = localStorage;

  final TokenStorage _tokens;
  final LocalStorage _local;

  /// Whether to mirror the session into the pre-refactor `GetStorage` keys.
  ///
  /// Off since Phase 5 retired the last reader. Kept as a named constant rather
  /// than deleted so the behaviour it controlled stays findable in history.
  static const bool legacyMirrorEnabled = false;

  AuthUser? _user;

  AuthUser? get user => _user;

  /// Notifikasi belum dibaca yang terakhir DIKETAHUI, atau `null`.
  ///
  /// Hidup di sini karena sesi adalah satu-satunya hal di aplikasi ini yang
  /// berumur lebih panjang daripada rute mana pun, dan angka ini dibutuhkan
  /// oleh dua tempat yang tidak saling mengenal: kepala Beranda dan bilah
  /// navigasi bawah. Menaruhnya di salah satu dari keduanya berarti yang lain
  /// harus memintanya sendiri lewat jaringan.
  ///
  /// **Ia tidak pernah menyebabkan permintaan HTTP.** Isinya datang dari dua
  /// sumber yang sudah dibayar: payload sesi (bila backend mengirimkannya) dan
  /// respons daftar notifikasi, yang memang membawa `unread_count` di setiap
  /// halaman dan selama ini dibuang begitu layarnya ditutup.
  int? _unreadNotifications;

  int? get unreadNotifications => _unreadNotifications;

  /// Catat hitungan yang baru saja diketahui sebuah layar.
  ///
  /// `null` tidak menghapus apa yang sudah diketahui: sebuah respons yang
  /// kebetulan tidak menyebutkan angkanya bukan pernyataan bahwa tidak ada yang
  /// menunggu.
  void noteUnreadNotifications(int? count) {
    if (count == null) return;

    _unreadNotifications = count < 0 ? 0 : count;
  }

  String? get token => _tokens.token;

  bool get isAuthenticated => (token ?? '').isNotEmpty;

  /// Load whatever is on the device.
  ///
  /// Also performs the one-time removal of the plaintext password (CRIT-03).
  /// That key is never written again, and every consumer of it is gone, so
  /// deleting it here is what stops it living on every existing install
  /// forever.
  Future<void> restore() async {
    await _tokens.restore();

    final stored = _local.read<dynamic>(StorageKeys.legacy.userJson);

    if (stored is Map) {
      _user = AuthUser.fromJson(Map<String, dynamic>.from(stored));
      _publishClock();
      noteUnreadNotifications(_user?.unreadNotificationCount);
    }

    await _purgePlaintextPassword();
  }

  /// Persist a freshly established session.
  Future<void> save({required String token, required AuthUser user}) async {
    _user = user;

    _publishClock();
    noteUnreadNotifications(user.unreadNotificationCount);

    await _tokens.save(token);
    await _local.write(StorageKeys.legacy.userJson, user.raw);

    if (legacyMirrorEnabled) {
      await _mirrorToLegacy(token: token, user: user);
    }
  }

  /// Update the cached user without touching the credential.
  Future<void> updateUser(AuthUser user) async {
    _user = user;

    _publishClock();
    noteUnreadNotifications(user.unreadNotificationCount);

    await _local.write(StorageKeys.legacy.userJson, user.raw);
  }

  /// Put the workspace's clock where every screen reads it.
  ///
  /// Done on restore as well as on sign-in: an app reopened from cold draws its
  /// first screen from storage, and a clock published only on login would leave
  /// that screen rendering in the fallback zone until the person signed in
  /// again — which is the one moment nobody does.
  void _publishClock() {
    final clock = _user?.clock;

    if (clock != null) {
      WorkspaceClock.current = clock;
    }
  }

  /// End the session and leave nothing behind.
  ///
  /// Clears the keychain **and** every legacy key, from one list, so the three
  /// implementations that disagreed cannot come back. The theme preference is
  /// not an auth key and deliberately survives.
  Future<void> clear() async {
    _user = null;
    // Hitungan milik orang sebelumnya tidak boleh menyeberang ke sesi
    // berikutnya di handset yang sama.
    _unreadNotifications = null;

    await _tokens.clear();
    await _local.removeAll(StorageKeys.legacy.sessionKeys);

    AppLogger.info('Session cleared.');
  }

  /// Remove the plaintext password left by pre-refactor installs.
  ///
  /// `LoginController` used to write the employee's actual password, in the
  /// clear, into the same unencrypted JSON file as everything else — and two
  /// features then depended on it, which is why it could not simply be deleted
  /// (CRIT-03). Both are gone. This clears it from devices that already have it;
  /// without it, the plaintext would survive on every existing install
  /// indefinitely.
  Future<void> _purgePlaintextPassword() async {
    if (!_local.hasData(StorageKeys.legacy.userPassword)) {
      return;
    }

    await _local.remove(StorageKeys.legacy.userPassword);
    AppLogger.warning(
      'Removed a plaintext password left by an older version of this app.',
    );
  }

  Future<void> _mirrorToLegacy({
    required String token,
    required AuthUser user,
  }) async {
    await _local.write(StorageKeys.legacy.token, token);
    await _local.write(StorageKeys.legacy.tokenType, 'Bearer');
    await _local.write(StorageKeys.legacy.userJson, user.raw);
    await _local.write(StorageKeys.legacy.userName, user.name);
    await _local.write(StorageKeys.legacy.userId, user.id);
    await _local.write(StorageKeys.legacy.userNip, user.nip);
    await _local.write(StorageKeys.legacy.userAvatar, user.avatar);
  }
}

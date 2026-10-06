import '../../../../core/network/api_exception.dart';
import '../../../../core/utils/app_logger.dart';
import '../models/auth_user.dart';
import '../services/auth_api_service.dart';
import '../services/firebase_identity_service.dart';
import 'firestore_user_repository.dart';
import 'session_repository.dart';

/// Signing in, signing out, and deciding what a stored credential is worth.
class AuthRepository {
  AuthRepository({
    required AuthApiService api,
    required SessionRepository session,
    Future<String?> Function()? currentPushToken,
    FirebaseIdentityService? identity,
    FirestoreUserRepository? firestoreUsers,
  }) : _api = api,
       _currentPushToken = currentPushToken,
       _identity = identity,
       _firestoreUsers = firestoreUsers,
       _session = session;

  final AuthApiService _api;
  final SessionRepository _session;

  /// Google sign-in through Firebase. Null when Firebase did not come up at
  /// boot, and then [canSignInWithGoogle] is false and the login screen shows
  /// only the NIP form.
  final FirebaseIdentityService? _identity;

  /// Where a Google sign-in is recorded in Firestore. Null for the same reason.
  final FirestoreUserRepository? _firestoreUsers;

  /// Token push perangkat ini, dibaca saat keluar.
  ///
  /// Sebuah fungsi dan bukan nilai, karena tokennya baru ada setelah Firebase
  /// menyerahkannya — jauh sesudah repository ini dibangun. Disuntikkan oleh
  /// komposisi (`InitialBinding`) supaya lapisan auth tidak perlu mengenal
  /// Firebase sama sekali; `null` berarti build tanpa push, dan keluar tetap
  /// berjalan seperti biasa.
  final Future<String?> Function()? _currentPushToken;

  AuthUser? get user => _session.user;

  bool get isAuthenticated => _session.isAuthenticated;

  bool get canSignInWithGoogle => _identity != null;

  /// Sign in and persist the session.
  ///
  /// `identifier` is an employee number **or** an email address, which is why
  /// it is no longer called `nip`: people know their own NIP, and half a
  /// workforce has no company address at all - so the server accepts either and
  /// the field that carries them should not claim to be one of them.
  ///
  /// Throws [ApiException]; the controller decides what to show. Note what is
  /// **not** here: the password is used to authenticate and then discarded. It
  /// used to be written to unencrypted storage so that auto-login and the
  /// change-password screen could read it back (CRIT-03).
  Future<AuthUser> login({
    required String identifier,
    required String password,
    required String deviceId,
  }) async {
    final body = await _api.login(
      identifier: identifier,
      password: password,
      deviceId: deviceId,
    );

    return _establishSession(body);
  }

  /// Sign in with Google and persist the session.
  ///
  /// Two identities are involved and only one of them is the session. Google,
  /// through Firebase, says who this person is; the ESAS server decides whether
  /// that person has an account here, by matching the verified email, and
  /// issues the same token a password would have. Every screen behind the
  /// login keeps talking to the ESAS server exactly as before.
  ///
  /// Returns null when the person backed out of the Google account picker.
  /// Throws [ApiException] for everything else.
  ///
  /// If the server refuses, the Firebase session is undone too. Otherwise the
  /// handset holds a Google sign-in that opens nothing, and the next tap on the
  /// button would silently reuse an account the server has already said no to.
  Future<AuthUser?> loginWithGoogle({required String deviceId}) async {
    final identity = _identity;

    if (identity == null) {
      throw const ApiException(
        'Masuk dengan Google belum tersedia di perangkat ini.',
        code: 'google_unavailable',
      );
    }

    final google = await identity.signInWithGoogle();
    if (google == null) return null;

    final AuthUser user;

    try {
      final body = await _api.loginWithFirebase(
        idToken: google.idToken,
        deviceId: deviceId,
      );
      user = await _establishSession(body);
    } on Object {
      await identity.signOut();
      rethrow;
    }

    // Best effort. The session is the ESAS token, and it is already saved: a
    // Firestore that is unreachable, or rules not yet deployed, must not turn a
    // successful sign-in into a failed one.
    try {
      await _firestoreUsers?.recordSignIn(google);
    } on Object catch (error) {
      AppLogger.warning('Could not record the sign-in in Firestore: $error');
    }

    return user;
  }

  /// Read a login reply — from either door — and persist what it grants.
  Future<AuthUser> _establishSession(Map<String, dynamic> body) async {
    final token = body['token'];
    final rawUser = body['user'];

    if (token is! String || token.isEmpty || rawUser is! Map) {
      throw const ApiException(
        'Respons login tidak lengkap. Hubungi administrator.',
        code: 'malformed_login_response',
      );
    }

    final user = AuthUser.fromJson(Map<String, dynamic>.from(rawUser));
    await _session.save(token: token, user: user);

    return user;
  }

  /// Decide what the stored credential is worth, without ever destroying it on
  /// a guess.
  ///
  /// The method this replaces had a bare `catch (_) {}` around the probe, so a
  /// `SocketException` came back as "invalid" and the caller wiped the session.
  /// Opening the app on a train signed the employee out (HIGH-02). Here a
  /// transport failure is [SessionState.offline] and the credential is kept.
  Future<SessionState> restoreSession() async {
    await _session.restore();

    if (!_session.isAuthenticated) {
      return SessionState.absent;
    }

    try {
      final body = await _api.currentUser();
      final rawUser = body['user'];

      if (rawUser is! Map) {
        // A 200 that does not describe a user is not a working session.
        await _session.clear();
        return SessionState.expired;
      }

      await _session.updateUser(
        AuthUser.fromJson(Map<String, dynamic>.from(rawUser)),
      );

      return SessionState.authenticated;
    } on ApiException catch (error) {
      // The server's verdict: the credential is genuinely no good.
      if (error.isUnauthenticated) {
        await _session.clear();
        return SessionState.expired;
      }

      // Everything else — no route, a timeout, a 502 — says nothing about the
      // session. Keep it.
      AppLogger.warning(
        'Could not verify the session (${error.code ?? error.status}); '
        'keeping the stored credential.',
      );

      return SessionState.offline;
    }
  }

  /// Sign out.
  ///
  /// The local session is cleared **whatever the server says**. The old
  /// `ProfileController.logout()` only cleared on a 200, so a logout that failed
  /// left the employee signed in on the device with a session the server may
  /// already have dropped — and reported it with the message "Gagal memilih
  /// gambar", pasted from the avatar picker (LOW-05).
  Future<void> logout() async {
    // Token dilepas BERSAMA permintaan keluar, bukan lewat permintaan kedua:
    // `POST /auth/logout` menerima `fcm_token` justru untuk ini, dan satu
    // perjalanan jaringan lebih sedikit di jalur yang paling sering gagal
    // (orang menekan keluar lalu langsung menutup aplikasi).
    //
    // Tanpa ini sebuah handset yang dipakai bergantian tetap terdaftar atas
    // nama karyawan sebelumnya, dan notifikasi miliknya — cuti, gaji, absensi —
    // terus mendarat di layar orang berikutnya.
    String? pushToken;

    try {
      pushToken = await _currentPushToken?.call();
    } on Object catch (error) {
      // Gagal membaca token tidak boleh menghalangi orang keluar.
      AppLogger.warning('Could not read the push token before logout: $error');
    }

    try {
      await _api.logout(fcmToken: pushToken);
    } on ApiException catch (error) {
      AppLogger.warning(
        'Server logout failed (${error.status}); clearing the local session '
        'anyway.',
      );
    } finally {
      await _session.clear();
      // Never throws. Without it the next "Masuk dengan Google" on a shared
      // handset would come back as the previous person.
      await _identity?.signOut();
    }
  }

  /// Called when any request comes back 401.
  Future<void> expireSession() async {
    AppLogger.info('Session expired; clearing.');
    await _session.clear();
  }
}

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
    Future<void> Function()? discardPushToken,
    FirebaseIdentityService? identity,
    FirestoreUserRepository? firestoreUsers,
    Duration pushTokenTimeout = const Duration(seconds: 5),
  }) : _api = api,
       _pushTokenTimeout = pushTokenTimeout,
       _currentPushToken = currentPushToken,
       _discardPushToken = discardPushToken,
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

  /// Invalidate this handset's push token locally (AUTH-02).
  ///
  /// The server only releases a token when `POST /auth/logout` reaches it with
  /// the token in hand. Every other way a session ends — a 401, a token found
  /// expired at start, signing out with no connection — used to leave the
  /// token registered to the previous employee, whose notifications then kept
  /// arriving on a shared phone. Deleting it on the handset makes the token the
  /// server holds a dead one, whichever way the session ended.
  final Future<void> Function()? _discardPushToken;

  /// How long a sign-out waits for FCM to drop the token (UAT review C6).
  /// `deleteToken` is a network call with no deadline of its own, and an
  /// offline sign-out — or the navigation after a 401 — waited on it.
  final Duration _pushTokenTimeout;

  AuthUser? get user => _session.user;

  bool get isAuthenticated => _session.isAuthenticated;

  bool get canSignInWithGoogle => _identity != null;

  bool get canSignInWithApple =>
      _identity != null && isAppleSignInAvailable;

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
    String? legacyDeviceId,
  }) async {
    final body = await _api.login(
      identifier: identifier,
      password: password,
      deviceId: deviceId,
      legacyDeviceId: legacyDeviceId,
    );

    return _establishSession(body);
  }

  /// Request a password reset for [identifier] (NIP or email).
  ///
  /// Returns the server's success message, or a standard confirmation message.
  /// Throws [ApiException] with clear guidance in Indonesian.
  Future<String> requestPasswordReset({required String identifier}) async {
    try {
      final body = await _api.forgotPassword(identifier: identifier);
      return body['message'] as String? ??
          'Instruksi reset kata sandi telah dikirim ke email terdaftar Anda.';
    } on ApiException catch (e) {
      if (e.status == 404 || e.status == 405 || e.status == 501) {
        throw const ApiException(
          'Reset kata sandi lewat aplikasi belum tersedia. '
          'Hubungi HR atau admin IT untuk mengatur ulang kata sandi Anda.',
          status: 404,
        );
      }
      rethrow;
    }
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
  Future<AuthUser?> loginWithGoogle({
    required String deviceId,
    String? legacyDeviceId,
  }) async {
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
        legacyDeviceId: legacyDeviceId,
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

  /// Sign in with Apple and persist the session.
  ///
  /// Returns null when the user cancels the Apple dialog.
  /// Throws [ApiException] for everything else.
  Future<AuthUser?> loginWithApple({
    required String deviceId,
    String? legacyDeviceId,
  }) async {
    final identity = _identity;

    if (identity == null) {
      throw const ApiException(
        'Masuk dengan Apple belum tersedia di perangkat ini.',
        code: 'apple_unavailable',
      );
    }

    final apple = await identity.signInWithApple();
    if (apple == null) return null;

    try {
      final body = await _api.loginWithFirebase(
        idToken: apple.idToken,
        deviceId: deviceId,
        legacyDeviceId: legacyDeviceId,
      );
      return await _establishSession(body);
    } on Object {
      await identity.signOut();
      rethrow;
    }
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

    final user = _userFromSession(body);
    await _session.save(token: token, user: user);

    return user;
  }

  /// Preserve token capabilities separately from the employee's policy flags.
  /// `auth/me` may return only the user, so keep capabilities of the same token.
  AuthUser _userFromSession(Map<String, dynamic> body, {AuthUser? previous}) {
    final raw = Map<String, dynamic>.from(body['user'] as Map);
    for (final key in const ['abilities', 'device']) {
      if (body.containsKey(key)) {
        raw[key] = body[key];
      } else if (previous?.raw.containsKey(key) ?? false) {
        raw[key] = previous!.raw[key];
      }
    }
    return AuthUser.fromJson(raw);
  }

  /// Verify the stored session. A connection failure ends this online session;
  /// an HTTP refusal or server error remains available for diagnosis/retry.
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
        await _endSession();
        return SessionState.expired;
      }

      await _session.updateUser(
        _userFromSession(body, previous: _session.user),
      );

      return SessionState.authenticated;
    } on ApiException catch (error) {
      // The server's verdict: the credential is genuinely no good.
      if (error.isUnauthenticated) {
        await _endSession();
        return SessionState.expired;
      }

      // Not reaching the server is not a verdict on the credential. Ending
      // the session here signed everybody out who opened the app in a lift
      // (CORE-04).
      if (error.isConnectionFailure) {
        AppLogger.warning('Server unreachable at start; keeping the session.');
        return _session.user == null
            ? SessionState.connectionLost
            : SessionState.unverified;
      }

      // An HTTP or decoding error does not establish a connection loss.
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
  ///
  /// Returns whether the server confirmed it (PROF-10): the handset is signed
  /// out either way, but a token the server never heard about lives on there
  /// until it expires, and the screen should not call that a clean sign-out.
  Future<bool> logout() async {
    // A 401 on the way out is this sign-out's to handle, not the 401 handler's
    // (AUTH-06). Without the flag both ended the session and both navigated.
    if (_signingOut) return false;
    _signingOut = true;

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
      return true;
    } on ApiException catch (error) {
      AppLogger.warning(
        'Server logout failed (${error.status}); clearing the local session '
        'anyway.',
      );
      return false;
    } finally {
      try {
        await _endSession();
      } finally {
        _signingOut = false;
      }
    }
  }

  bool _signingOut = false;

  /// Whether a deliberate sign-out is under way.
  bool get isSigningOut => _signingOut;

  /// Called when any request comes back 401.
  ///
  /// Returns whether it ended a session — and so whether the caller should go
  /// to the sign-in screen. It does not when there is no session left, or when
  /// the 401 answered a sign-out already ending it (AUTH-06): the sign-out
  /// does the navigating, once.
  Future<bool> expireSession() async {
    if (_signingOut || !_session.isAuthenticated) return false;

    AppLogger.info('Session expired; clearing.');
    await _endSession();
    return true;
  }

  /// Everything a handset must let go of when a session ends, however it
  /// ended (AUTH-02). One list, so the ways out cannot drift apart again.
  ///
  /// Never throws: a plugin that will not cooperate must not leave somebody
  /// half signed out.
  Future<void> _endSession() async {
    await _session.clear();

    try {
      await _discardPushToken?.call().timeout(_pushTokenTimeout);
    } on Object catch (error) {
      AppLogger.warning('Could not discard the push token: $error');
    }

    // Never throws. Without it the next "Masuk dengan Google" on a shared
    // handset would come back as the previous person.
    await _identity?.signOut();
  }
}

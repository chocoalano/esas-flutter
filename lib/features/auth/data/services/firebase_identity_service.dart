import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/utils/app_logger.dart';

/// Who Google says this person is, as Firebase Authentication has verified it.
///
/// [idToken] is the **Firebase** ID token, not Google's: it is what the server
/// verifies against the `absensascom` project before it issues a session, and
/// what Firestore security rules see as `request.auth`.
class GoogleIdentity {
  const GoogleIdentity({
    required this.uid,
    required this.idToken,
    this.email,
    this.displayName,
    this.photoUrl,
  });

  final String uid;
  final String idToken;
  final String? email;
  final String? displayName;
  final String? photoUrl;
}

/// Google sign-in through Firebase Authentication.
///
/// Registered only when Firebase came up at boot. ESAS still works without it —
/// NIP and password do not need Firebase — so everything that uses this takes
/// it as nullable and hides the Google path when it is absent.
class FirebaseIdentityService {
  FirebaseIdentityService({FirebaseAuth? auth, GoogleSignIn? googleSignIn})
    : _auth = auth ?? FirebaseAuth.instance,
      _google = googleSignIn ?? GoogleSignIn.instance;

  final FirebaseAuth _auth;
  final GoogleSignIn _google;

  Future<void>? _initialized;

  /// `google_sign_in` 7 must be initialised once before any other call.
  ///
  /// Done on first use rather than at boot: most people sign in with their NIP
  /// and never touch it, and a cold start should not pay for a path it does not
  /// take. The client IDs come from `GoogleService-Info.plist` on iOS and from
  /// `default_web_client_id` (generated from `google-services.json`) on Android.
  ///
  /// Skipped on the web, where `initialize()` without a client ID hangs the app
  /// and Firebase's own popup does the whole job instead.
  Future<void> _ensureInitialized() {
    if (kIsWeb) return Future<void>.value();

    return _initialized ??= _google.initialize().catchError((Object error) {
      // A failed initialisation must not be remembered as a successful one.
      _initialized = null;
      throw error;
    });
  }

  /// Ask Google who this is, and sign in to Firebase as them.
  ///
  /// Returns null when the person backs out of the account picker, which is
  /// not an error and must not be reported as one. Everything else throws
  /// [ApiException], so the login screen has one type to catch.
  Future<GoogleIdentity?> signInWithGoogle() async {
    try {
      await _ensureInitialized();

      final UserCredential credential;

      if (kIsWeb) {
        credential = await _auth.signInWithPopup(GoogleAuthProvider());
      } else {
        final account = await _google.authenticate();
        credential = await _auth.signInWithCredential(
          GoogleAuthProvider.credential(
            idToken: account.authentication.idToken,
          ),
        );
      }

      final user = credential.user;
      final idToken = await user?.getIdToken();

      if (user == null || idToken == null || idToken.isEmpty) {
        throw const ApiException(
          'Google tidak mengembalikan identitas. Silakan coba lagi.',
          code: 'google_identity_missing',
        );
      }

      return GoogleIdentity(
        uid: user.uid,
        idToken: idToken,
        email: user.email,
        displayName: user.displayName,
        photoUrl: user.photoURL,
      );
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) return null;

      AppLogger.warning(
        'Google sign-in failed: ${error.code} ${error.description}',
      );
      throw ApiException(
        'Masuk dengan Google gagal. Silakan coba lagi.',
        code: 'google_${error.code.name}',
      );
    } on FirebaseAuthException catch (error) {
      // The web popup reports a closed window this way rather than as a
      // cancellation.
      if (error.code == 'popup-closed-by-user' ||
          error.code == 'cancelled-popup-request') {
        return null;
      }

      AppLogger.warning('Firebase sign-in failed: ${error.code}');
      throw ApiException(
        error.code == 'network-request-failed'
            ? 'Tidak ada koneksi internet. Periksa jaringan Anda.'
            : 'Masuk dengan Google gagal. Silakan coba lagi.',
        code: 'firebase_${error.code}',
      );
    }
  }

  /// Sign out of Firebase **and** Google.
  ///
  /// Signing out of Google too is what makes the next "Masuk dengan Google"
  /// show the account picker again: on a handset that is passed between
  /// employees, silently reusing the previous person's Google account is how
  /// one of them ends up clocking in as the other.
  ///
  /// Never throws. A sign-out that failed halfway must not stop the local
  /// session from being cleared.
  Future<void> signOut() async {
    // Somebody who signed in with their NIP never touched Firebase or Google;
    // there is nothing to undo, and no reason to wake the Google SDK for it.
    if (_auth.currentUser == null) return;

    try {
      if (!kIsWeb) {
        // Initialised here too: after a restart the Google account is still
        // remembered natively even though this process never touched it.
        await _ensureInitialized();
        await _google.signOut();
      }
    } on Object catch (error) {
      AppLogger.warning('Google sign-out failed: $error');
    }

    try {
      await _auth.signOut();
    } on Object catch (error) {
      AppLogger.warning('Firebase sign-out failed: $error');
    }
  }
}

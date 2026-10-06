import '../../../../core/config/api_routes.dart';
import '../../../../core/network/api_client.dart';

/// Every authentication endpoint, in one place.
///
/// Before this, the paths were spread across `LoginController`,
/// `SplashController`, `ProfileController`, `ProfileChangePasswordController`
/// and `FirebaseMessagingService` — five files that each knew a URL (MED-01).
///
/// Paths come from [ApiRoutes], on the `/api/v1` surface. The field names here
/// moved with them: this used to send `nip` and `device_info` to a backend that
/// no longer exists, and sending the old names to the new server is a 422 rather
/// than a 404 — which is the harder failure to read, because the request
/// arrives.
class AuthApiService {
  const AuthApiService(this._client);

  final ApiClient _client;

  /// Sign in. Unauthenticated by definition — a token is what this produces.
  ///
  /// `identifier` accepts an employee number **or** an email address: people
  /// know their own NIP, and half a workforce has no company address at all.
  ///
  /// The reply carries `token`, `user`, `abilities` and a `device` block. That
  /// last one is worth reading rather than discarding: an account registered
  /// against another handset still signs in here, and gets everything except
  /// the ability to clock. `device.can_record_attendance` is how the app knows
  /// to explain that instead of offering a button that answers 403.
  Future<Map<String, dynamic>> login({
    required String identifier,
    required String password,
    required String deviceId,
  }) {
    return _client.postObject(ApiRoutes.login, {
      'identifier': identifier,
      'password': password,
      'device_id': deviceId,
    }, authenticated: false);
  }

  /// Sign in with a Google identity, by exchanging the Firebase ID token for
  /// this server's own token.
  ///
  /// The reply is the same shape as [login]'s, device block included, so an
  /// account bound to another handset is told the same thing either way. A
  /// Google account whose email matches nobody here is refused like a wrong
  /// password: the server does not say whether the address exists.
  Future<Map<String, dynamic>> loginWithFirebase({
    required String idToken,
    required String deviceId,
  }) {
    return _client.postObject(ApiRoutes.firebaseLogin, {
      'id_token': idToken,
      'device_id': deviceId,
    }, authenticated: false);
  }

  /// Who this token belongs to. Also the token-validity probe used at splash.
  ///
  /// Says who you are. It does **not** carry the employee record — that is
  /// `ProfileApiService.profile()`, and keeping the two apart is what stops a
  /// department changed by HR staying stale until somebody signs out.
  Future<Map<String, dynamic>> currentUser() =>
      _client.getObject(ApiRoutes.currentUser);

  /// Sign out. **POST**, and it releases this handset from the notification
  /// registry on the way — a device that logs out otherwise keeps receiving the
  /// next person's notifications.
  Future<Map<String, dynamic>> logout({String? fcmToken}) => _client.postObject(
    ApiRoutes.logout,
    {if (fcmToken != null && fcmToken.isNotEmpty) 'fcm_token': fcmToken},
  );

  /// Change the password.
  ///
  /// The server answers a wrong current password with **422** and a validation
  /// error on `current_password`, not with a 200 carrying `success: false` the
  /// way the retired backend did. Callers branch on the status now.
  ///
  /// Every other token is revoked and this one is kept: the handset in your
  /// hand stays signed in, and the one you are changing it *because of* stops
  /// working.
  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmation,
  }) {
    return _client.postObject(ApiRoutes.changePassword, {
      'current_password': currentPassword,
      'password': newPassword,
      'password_confirmation': confirmation,
    });
  }

  /// Register this device's push token.
  ///
  /// Keyed on the token rather than on the person, which is what makes a shared
  /// handset safe: an FCM token identifies an app *installation*, so a phone
  /// handed to a replacement reports the same token and registering moves it.
  Future<Map<String, dynamic>> setPushToken(String token, {String? platform}) =>
      _client.postObject(ApiRoutes.pushToken, {
        'token': token,
        if (platform != null) 'platform': platform,
      });

  /// Release a push token — on sign-out, or when Firebase rotates one.
  Future<Map<String, dynamic>> forgetPushToken(String token) =>
      _client.postObject(ApiRoutes.forgetPushToken, {'token': token});

  /// The handsets this account is signed in on.
  Future<Map<String, dynamic>> devices() =>
      _client.getObject(ApiRoutes.devices);

  /// Release a handset. Releasing the registered one clears the attendance
  /// binding too, so a lost phone stops standing between somebody and clocking
  /// in on its replacement — which used to need HR.
  Future<Map<String, dynamic>> forgetDevice(String deviceId) =>
      _client.postObject(ApiRoutes.forgetDevice, {'device_id': deviceId});
}

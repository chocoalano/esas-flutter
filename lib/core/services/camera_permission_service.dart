import 'package:permission_handler/permission_handler.dart';

/// What the operating system currently says about the camera.
///
/// Four answers, not two, and the difference between them is which button the
/// screen should offer. Sending somebody whose permission has never been
/// requested to the Settings app asks them to fix something that is not broken;
/// offering "Coba lagi" to somebody who denied it permanently offers a button
/// that can only repeat itself.
enum CameraPermission {
  /// Granted. Nothing to ask.
  granted,

  /// Not granted, and the OS will still show the prompt. **Ask**, do not send
  /// them to Settings.
  askable,

  /// Denied in a way only Settings can undo — "Don't allow" twice on Android,
  /// any denial on iOS after the first. Settings is the primary action.
  permanentlyDenied,

  /// Withheld by policy: parental controls, an MDM profile. Neither asking nor
  /// Settings helps, and saying "izinkan kamera" to somebody who cannot is
  /// worse than saying nothing.
  restricted,
}

/// The camera permission, behind a seam.
///
/// A class rather than a bare call to `permission_handler` so the attendance
/// controller can be tested without a platform channel, and so the mapping from
/// the plugin's seven-value enum to the four answers a screen can act on lives
/// in one place.
class CameraPermissionService {
  const CameraPermissionService();

  /// What the OS says right now, without prompting.
  Future<CameraPermission> status() async =>
      _map(await Permission.camera.status);

  /// Show the system prompt, and report what came back.
  ///
  /// Calling this when the status is already [CameraPermission.permanentlyDenied]
  /// returns immediately without a prompt — which is precisely why the screen
  /// must not offer it there.
  Future<CameraPermission> request() async =>
      _map(await Permission.camera.request());

  /// Open the app's own settings page. The only route out of a permanent denial.
  Future<bool> openSettings() => openAppSettings();

  static CameraPermission _map(PermissionStatus status) => switch (status) {
    PermissionStatus.granted ||
    PermissionStatus.limited ||
    PermissionStatus.provisional => CameraPermission.granted,
    PermissionStatus.permanentlyDenied => CameraPermission.permanentlyDenied,
    PermissionStatus.restricted => CameraPermission.restricted,
    PermissionStatus.denied => CameraPermission.askable,
  };
}

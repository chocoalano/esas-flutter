import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

/// Why a location request did not produce a usable position.
enum LocationFailure {
  /// GPS is switched off on the device.
  serviceDisabled,

  /// The person declined, and can be asked again.
  permissionDenied,

  /// The person declined permanently; only Settings can undo it.
  permissionDeniedForever,

  /// A mock-location provider was detected.
  mocked,

  /// Timed out or the platform refused.
  unavailable,
}

/// The outcome of asking where the device is.
sealed class LocationResult {
  const LocationResult();
}

class LocationSuccess extends LocationResult {
  const LocationSuccess(this.position);

  final Position position;
}

class LocationRejected extends LocationResult {
  const LocationRejected(this.reason, [this.detail]);

  final LocationFailure reason;
  final String? detail;
}

/// Everything about finding out where the handset is.
///
/// `AttendanceController` did all of this inline: service check, permission
/// request, the permanent-denial branch, `openAppSettings()`, the mock check,
/// the distance maths and four snackbars, in one 106-line method. None of it
/// could be tested and none of it could be reused.
///
/// This returns a result. It shows nothing and navigates nowhere — the
/// controller decides what the person is told (MED-03).
class LocationService {
  const LocationService();

  /// Ask for the current position, doing the permission dance first.
  ///
  /// Uses `LocationSettings` rather than the positional `desiredAccuracy` and
  /// `timeLimit` arguments, which `geolocator` 14 deprecated — the four
  /// `deprecated_member_use` findings that have been the entire content of
  /// `flutter analyze` since the baseline (P4-6). Accuracy and timeout are
  /// carried across unchanged.
  Future<LocationResult> currentPosition({
    Duration timeout = const Duration(seconds: 15),
    LocationAccuracy accuracy = LocationAccuracy.high,
    bool rejectMocked = true,
  }) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return const LocationRejected(LocationFailure.serviceDisabled);
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      return const LocationRejected(LocationFailure.permissionDeniedForever);
    }

    if (permission == LocationPermission.denied) {
      return const LocationRejected(LocationFailure.permissionDenied);
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: accuracy,
          timeLimit: timeout,
        ),
      );

      // Android reports whether a mock provider supplied the fix; iOS does not,
      // and always reports false. Kept Android-only, as it was, so the check
      // never becomes a refusal on a platform that cannot answer it.
      if (rejectMocked && isAndroid() && position.isMocked) {
        return const LocationRejected(LocationFailure.mocked);
      }

      return LocationSuccess(position);
    } catch (error) {
      return LocationRejected(LocationFailure.unavailable, error.toString());
    }
  }

  /// Open the OS settings page, for a permanent denial.
  Future<void> openSettings() => openAppSettings();

  /// Metres between two points.
  double distanceBetween({
    required double fromLatitude,
    required double fromLongitude,
    required double toLatitude,
    required double toLongitude,
  }) {
    return Geolocator.distanceBetween(
      fromLatitude,
      fromLongitude,
      toLatitude,
      toLongitude,
    );
  }
}

/// Whether this is Android, behind a seam.
///
/// A function rather than a direct `GetPlatform.isAndroid` so a test can pin the
/// Android-only mock-location branch without a platform channel. Production
/// never reassigns it.
bool Function() isAndroid = () => GetPlatform.isAndroid;

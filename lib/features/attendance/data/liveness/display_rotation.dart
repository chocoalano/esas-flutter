import 'package:camera/camera.dart';
import 'package:flutter/services.dart';

/// How far the display is rotated from the device's own natural orientation.
///
/// ML Kit is told which way up a frame is rather than working it out, and the
/// number it wants is the display rotation from natural — 0, 90, 180 or 270. A
/// frame handed over at the wrong rotation is not rejected: it is scanned, no
/// face is found, and the person is told to move closer to a camera they are
/// already holding at arm's length.
///
/// The kiosk this engine came from reads the number over a method channel,
/// because it runs on a tablet bolted to a lobby wall and tablets are commonly
/// **landscape-natural** — there `CameraValue.deviceOrientation` is UI-relative
/// and disagrees with the display rotation by 90 degrees in every physical
/// position, silently.
///
/// This app runs on employee handsets, and a handset is portrait-natural: for
/// those two devices the enum and the rotation coincide, so the mapping below is
/// exact and needs no platform code. That assumption is written here rather than
/// left implicit, because it is the one thing that would have to change if this
/// app were ever shipped to a tablet.
class DisplayRotation {
  const DisplayRotation._();

  /// The rotation to hand the detector, in degrees, for a portrait-natural
  /// device showing [orientation].
  static int degreesFor(DeviceOrientation orientation) => switch (orientation) {
    DeviceOrientation.portraitUp => 0,
    DeviceOrientation.landscapeLeft => 90,
    DeviceOrientation.portraitDown => 180,
    DeviceOrientation.landscapeRight => 270,
  };

  /// The rotation for whatever a live camera controller currently reports.
  static int of(CameraController controller) =>
      degreesFor(controller.value.deviceOrientation);
}

import 'dart:io';
import 'dart:ui' show Size;

import 'package:flutter/foundation.dart' show visibleForTesting;

import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Turning a camera frame into something ML Kit will look at.
///
/// This is the part of on-device liveness that has nothing to do with liveness
/// and everything to do with why it breaks. The detector accepts NV21 on Android
/// and BGRA on iOS, in one plane, with a rotation it is told rather than one it
/// works out - and a frame handed over in the wrong format or at the wrong
/// rotation is not rejected. It is scanned, no face is found, and the person is
/// told to move closer to a camera they are already standing in front of.
///
/// The format is requested at the source rather than converted here: the
/// `camera` plugin can be asked for NV21 directly, and `camera_android_camerax`
/// honours it — it folds the three YUV_420_888 planes into one NV21 buffer
/// natively and reports the format as NV21. Converting them by hand in Dart is
/// the usual answer and it costs a frame-sized allocation and a plane interleave
/// on every frame, at ten a second, on the cheapest handset in the building.
class CameraInput {
  const CameraInput._();

  /// The format to open the camera with, per platform.
  static ImageFormatGroup get formatGroup =>
      Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888;

  /// Whether the frames this camera streams arrive MIRRORED.
  ///
  /// They do on iOS, for the front camera, and this is not a detail — it
  /// silently swaps two of the six gestures.
  ///
  /// `camera_avfoundation` sets `connection.isVideoMirrored = true` on the video
  /// **data output** connection whenever the device is front-facing
  /// (`DefaultCamera.createConnection`). That connection feeds both the preview
  /// and `startImageStream`, so the buffer ML Kit reads on an iPhone is a mirror
  /// image. `camera_android_camerax` mirrors nothing: on Android the analysis
  /// frames are raw sensor data and only the preview widget flips them at draw
  /// time.
  ///
  /// ML Kit reports `headEulerAngleY` relative to the image it was given, so on
  /// a mirrored frame a person turning to their own left produces a NEGATIVE
  /// yaw where Android produces a positive one — `turn_left` and `turn_right`
  /// trade places. Somebody following the instruction exactly is refused, and
  /// somebody turning the wrong way passes. Pitch, eyes and mouth are unaffected:
  /// the mirror is horizontal, and `FaceSample.eyesOpen` takes the larger of the
  /// two eyes, so the left/right eye swap cancels out.
  ///
  /// The still from `takePicture()` is NOT mirrored on either platform — the
  /// photo output carries no mirroring — so what the face service scores is the
  /// same geometry as the reference photographs either way.
  static bool streamIsMirrored(CameraDescription camera) =>
      mirrorsFor(isIOS: Platform.isIOS, lens: camera.lensDirection);

  /// The rule above, without a platform to ask. Exposed so it can be pinned in
  /// a test on a machine that is neither.
  @visibleForTesting
  static bool mirrorsFor({
    required bool isIOS,
    required CameraLensDirection lens,
  }) => isIOS && lens == CameraLensDirection.front;

  /// Convert a streamed frame, or answer null when it is not one we can use.
  ///
  /// Null rather than an exception: this runs on every frame, and a handset that
  /// hands over one odd frame should drop it, not end somebody's attendance.
  static InputImage? from(
    CameraImage image,
    CameraDescription camera, {
    required int deviceOrientationDegrees,
  }) {
    final rotation = _rotationOf(camera, deviceOrientationDegrees);

    if (rotation == null || image.planes.isEmpty) {
      return null;
    }

    final format = _formatOf(image);

    // One plane is what both accepted formats look like. A three-plane frame is
    // YUV_420_888 that arrived because the platform ignored the request, and
    // feeding its first plane alone would hand the detector luminance with no
    // chroma - which decodes as a grey image nobody's face is in.
    if (format == null || image.planes.length != 1) {
      return null;
    }

    return InputImage.fromBytes(
      bytes: image.planes.first.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  /// The detector's name for the format this frame arrived in.
  ///
  /// `ImageFormat.raw` is the platform's own constant and is typed `dynamic`, so
  /// it is checked rather than cast: a handset reporting something unexpected
  /// drops the frame instead of throwing inside the stream callback, where
  /// nothing is watching to catch it.
  static InputImageFormat? _formatOf(CameraImage image) {
    final raw = image.format.raw;

    if (raw is! int) {
      return null;
    }

    return switch (InputImageFormatValue.fromRawValue(raw)) {
      InputImageFormat.nv21 when Platform.isAndroid => InputImageFormat.nv21,
      InputImageFormat.bgra8888 when Platform.isIOS =>
        InputImageFormat.bgra8888,
      _ => null,
    };
  }

  /// How far the frame has to be turned for the detector to see it upright.
  ///
  /// The two platforms need different arithmetic and the difference is not
  /// cosmetic. On iOS the sensor orientation alone answers it. On Android the
  /// display's rotation comes into it, and a front camera is mirrored, so the
  /// two rotations *add* where a back camera's subtract - get that backwards and
  /// every frame arrives upside down.
  ///
  /// `deviceOrientationDegrees` must be the display's rotation from the device's
  /// NATURAL orientation, which is what `DisplayRotation` answers. On a
  /// landscape-natural device - a tablet - `CameraValue.deviceOrientation` is 90
  /// degrees out from that in every position, silently, with no face ever
  /// detected and no error anywhere; on the portrait-natural handsets this app
  /// runs on the two coincide.
  static InputImageRotation? _rotationOf(
    CameraDescription camera,
    int deviceOrientationDegrees,
  ) {
    if (Platform.isIOS) {
      return InputImageRotationValue.fromRawValue(camera.sensorOrientation);
    }

    final isFront = camera.lensDirection == CameraLensDirection.front;

    final degrees = isFront
        ? (camera.sensorOrientation + deviceOrientationDegrees) % 360
        : (camera.sensorOrientation - deviceOrientationDegrees + 360) % 360;

    return InputImageRotationValue.fromRawValue(degrees);
  }
}

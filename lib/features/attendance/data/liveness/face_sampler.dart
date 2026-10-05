import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'camera_input.dart';
import 'liveness_gestures.dart';

/// The frame-to-[FaceSample] step, and the detector settings behind it.
///
/// Every setting here changes what the detector reads, and the gesture
/// thresholds in [kGestureCatalogue] are sized against those readings. They are
/// gathered in one class rather than spread across the caller so that the two
/// can never drift apart: a preset, a performance mode or a throttle chosen
/// somewhere else would be a detector the thresholds were never measured
/// against.
///
/// Ported from the `esas_attendance` kiosk, which measured these values against
/// `tool/noise_probe`. The numbers are that meter's, not this app's — see
/// [GestureSpec.delta] for what has and has not been measured.
class FaceSampler {
  FaceSampler({FaceDetector? detector})
    : _detector = detector ?? FaceDetector(options: options);

  final FaceDetector _detector;

  /// How much of the frame's shorter side the last detected face spanned, 0..1.
  ///
  /// Kept for physical-device QA only — it answers whether
  /// `ResolutionPreset.medium` with [options]'s `minFaceSize` is practical for a
  /// phone held at arm's length. A size is not an identity, and nothing here
  /// records where the face was, only how much of the frame it filled.
  double? lastFaceRatio;

  /// Wall-clock milliseconds the last detector call took.
  int lastDetectorMs = 0;

  /// What the detector is asked for, in both the kiosk and the meter.
  static FaceDetectorOptions get options => FaceDetectorOptions(
    // Classification is what `blink` and `smile` are read from, and it is
    // off by default. Landmarks and contours stay off: they are the
    // expensive half of the detector and nothing here reads a single point.
    enableClassification: true,
    enableLandmarks: false,
    enableContours: false,
    enableTracking: false,
    // A face smaller than a fifth of the frame is somebody standing too far
    // back to score, and chasing it costs every frame.
    minFaceSize: 0.2,
    // `accurate` roughly triples the per-frame cost and buys nothing here:
    // Google's reference scopes it to detection and position, not to
    // classification, and `smiling` / `eyes open` come from
    // CLASSIFICATION_MODE_ALL either way. The plugin's own Dart doc still
    // claims Euler Y needs `accurate`; that is inherited from Mobile Vision
    // and contradicted by the current face-detection-concepts page. Confirm
    // it on the handset before believing either.
    performanceMode: FaceDetectorMode.fast,
  );

  /// The least time between two frames handed to the detector.
  ///
  /// The camera pushes thirty a second and the detector cannot keep up with
  /// that on a cheap handset; unthrottled, the queue grows until gestures are
  /// scored seconds after they happened.
  static const Duration frameInterval = Duration(milliseconds: 100);

  /// The frame format the camera is opened with.
  ///
  /// NV21 on Android, BGRA on iOS - the two ML Kit reads without a per-frame
  /// plane interleave in Dart. It belongs here for the same reason the preset
  /// does: a frame arriving in another format is a conversion path the
  /// thresholds were never measured against.
  static ImageFormatGroup get formatGroup => CameraInput.formatGroup;

  /// The resolution the camera is opened at.
  ///
  /// Part of the measurement: how many pixels the classifier had is most of
  /// what decides how noisy its answer is.
  static const ResolutionPreset preset = ResolutionPreset.medium;

  /// Turn one camera frame into what the gesture machine scores, or null when
  /// the frame is not one the detector can read.
  ///
  /// [atMs] is stamped by the caller rather than taken here, because it is
  /// measured from the start of the sequence and only the caller knows when that
  /// was.
  ///
  /// [deviceOrientationDegrees] is the display's rotation from the device's
  /// NATURAL orientation, which `DisplayRotation` derives. It is passed in
  /// rather than read from a static so this class stays a pure function of its
  /// arguments, and so a test can pin a rotation without a platform channel.
  Future<FaceSample?> sample(
    CameraImage image,
    CameraDescription camera, {
    required int atMs,
    required int deviceOrientationDegrees,
  }) async {
    final mirrored = CameraInput.streamIsMirrored(camera);

    final input = CameraInput.from(
      image,
      camera,
      deviceOrientationDegrees: deviceOrientationDegrees,
    );

    if (input == null) {
      return null;
    }

    final started = DateTime.now();
    final faces = await _detector.processImage(input);

    lastDetectorMs = DateTime.now().difference(started).inMilliseconds;

    if (faces.isEmpty) {
      lastFaceRatio = null;

      return FaceSample.noFace(atMs);
    }

    // The largest face, which is the person standing at the machine rather than
    // somebody walking past behind them. A frame holding more than one is not
    // scored at all, and does not build a baseline either - see
    // LivenessGestureMachine.
    final face = faces.reduce(
      (a, b) =>
          a.boundingBox.width * a.boundingBox.height >=
              b.boundingBox.width * b.boundingBox.height
          ? a
          : b,
    );

    final shorterSide = input.metadata?.size.shortestSide ?? 0;

    lastFaceRatio = shorterSide <= 0
        ? null
        : face.boundingBox.shortestSide / shorterSide;

    return FaceSample(
      atMs: atMs,
      // Brought back to the unmirrored convention the gesture catalogue is
      // written against, so `turn_left` means the same movement on both
      // platforms. See [CameraInput.streamIsMirrored].
      yaw: mirrored ? _negate(face.headEulerAngleY) : face.headEulerAngleY,
      pitch: face.headEulerAngleX,
      leftEyeOpen: face.leftEyeOpenProbability,
      rightEyeOpen: face.rightEyeOpenProbability,
      smiling: face.smilingProbability,
      faceCount: faces.length,
    );
  }

  /// `-0.0` is not a value anybody wants in evidence; a null stays null.
  static double? _negate(double? value) =>
      value == null ? null : (value == 0 ? 0 : -value);

  Future<void> close() => _detector.close();
}

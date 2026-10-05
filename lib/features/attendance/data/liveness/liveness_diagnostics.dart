import 'package:flutter/foundation.dart';

/// What a physical-device QA session needs to know, and nothing else.
///
/// ## Why this exists
///
/// Liveness cannot be judged on a simulator and cannot be judged from a golden.
/// The questions device QA has to answer — is the detector keeping up, is the
/// face big enough at arm's length, did that gesture register — are all
/// invisible from the outside, and the alternative to measuring them is a tester
/// guessing from how the screen feels.
///
/// ## What it will never carry
///
/// No image, no landmark, no bounding box, no raw yaw or pitch, no eye or mouth
/// probability, no match score, no file path, no challenge token, no employee
/// identifier. Those are the measurements a face is *made of*; a QA aid that
/// logged them would be biometric telemetry wearing a diagnostic's clothes.
///
/// What it does carry is shape and timing: how fast frames are being scored, how
/// long the detector takes, whether a face is present, how many, and roughly how
/// much of the frame it fills. `faceRatio` is the one number close to the line,
/// and it is kept because it answers a question the team has: whether
/// `ResolutionPreset.medium` with `minFaceSize: 0.2` is practical for a phone at
/// arm's length. A size is not an identity.
///
/// ## Debug only, structurally
///
/// Every write is behind `kDebugMode`, which the Dart compiler treats as a
/// constant `false` in release and tree-shakes along with everything it guards.
/// There is no flag, no remote switch and no environment sniff that could turn
/// this on in a shipped build — the code is not in one.
@immutable
class LivenessDiagnostics {
  const LivenessDiagnostics({
    this.framesScored = 0,
    this.framesDropped = 0,
    this.lastDetectorMs = 0,
    this.faceCount = 0,
    this.faceRatio,
    this.elapsedMs = 0,
  });

  /// Frames handed to the detector and measured.
  final int framesScored;

  /// Frames the throttle or the busy gate turned away.
  ///
  /// The pair matters more than either number: a high drop rate with a healthy
  /// score rate is backpressure working, while both falling is a handset that
  /// cannot keep up.
  final int framesDropped;

  /// How long the last detector call took, wall clock.
  final int lastDetectorMs;

  /// How many faces the last scored frame held. Zero, one, or a crowd.
  final int faceCount;

  /// Roughly how much of the frame's shorter side the face spans, 0..1.
  ///
  /// Compared against `FaceSampler.options.minFaceSize` (0.2) during QA. Null
  /// when nothing was detected.
  final double? faceRatio;

  /// Milliseconds since the sequence began.
  final int elapsedMs;

  /// Frames per second reaching the detector, over the sequence so far.
  double get scoredPerSecond =>
      elapsedMs <= 0 ? 0 : framesScored * 1000 / elapsedMs;

  LivenessDiagnostics copyWith({
    int? framesScored,
    int? framesDropped,
    int? lastDetectorMs,
    int? faceCount,
    double? faceRatio,
    bool clearFaceRatio = false,
    int? elapsedMs,
  }) {
    return LivenessDiagnostics(
      framesScored: framesScored ?? this.framesScored,
      framesDropped: framesDropped ?? this.framesDropped,
      lastDetectorMs: lastDetectorMs ?? this.lastDetectorMs,
      faceCount: faceCount ?? this.faceCount,
      faceRatio: clearFaceRatio ? null : (faceRatio ?? this.faceRatio),
      elapsedMs: elapsedMs ?? this.elapsedMs,
    );
  }

  /// One line for a QA worksheet. Deliberately terse and deliberately dull.
  @override
  String toString() =>
      'scored=$framesScored dropped=$framesDropped '
      '${scoredPerSecond.toStringAsFixed(1)}/s '
      'detector=${lastDetectorMs}ms faces=$faceCount '
      'ratio=${faceRatio?.toStringAsFixed(2) ?? '-'} '
      'elapsed=${elapsedMs}ms';
}

/// Collects [LivenessDiagnostics], and only in a debug build.
///
/// In release every method is an empty body behind `kDebugMode` and [value]
/// stays at its zero state, so a caller needs no conditional of its own and the
/// whole class costs nothing.
class LivenessDiagnosticsRecorder {
  final ValueNotifier<LivenessDiagnostics> value = ValueNotifier(
    const LivenessDiagnostics(),
  );

  /// Whether anything is being collected at all.
  static bool get enabled => kDebugMode;

  void countDropped() {
    if (!kDebugMode) return;

    value.value = value.value.copyWith(
      framesDropped: value.value.framesDropped + 1,
    );
  }

  void countScored({
    required int detectorMs,
    required int faceCount,
    required double? faceRatio,
    required int elapsedMs,
  }) {
    if (!kDebugMode) return;

    value.value = value.value.copyWith(
      framesScored: value.value.framesScored + 1,
      lastDetectorMs: detectorMs,
      faceCount: faceCount,
      faceRatio: faceRatio,
      clearFaceRatio: faceRatio == null,
      elapsedMs: elapsedMs,
    );
  }

  void dispose() => value.dispose();
}

import 'dart:math' as math;

/// The facial measurement a gesture moves.
///
/// A challenge never draws two gestures from one axis, and this is what the
/// server enforces it with. The reason is measurement, not variety: every
/// gesture is scored against the person's own resting value for its signal, and
/// asking somebody to look up and then down leaves the pitch axis with no rest
/// in it - both excursions read as half of what they were, and somebody
/// following the instructions exactly is told they did not.
enum GestureAxis { yaw, pitch, eye, mouth }

/// One thing the person can be asked to do, and what ML Kit reports when they do.
///
/// Only signals `google_mlkit_face_detection` actually produces appear here.
/// There is no `open_mouth`: face detection classifies smiling and eyes-open and
/// gives head Euler angles, but has no mouth-open probability. Deriving one from
/// lip contours is possible and unreliable, and a gesture that fails for people
/// who perform it correctly is worse than one that is never asked for.
class GestureSpec {
  const GestureSpec({
    required this.action,
    required this.axis,
    required this.delta,
    required this.direction,
    this.anchor,
  });

  final String action;
  final GestureAxis axis;

  /// How far from the person's own resting value counts as having done it.
  ///
  /// Degrees for the head axes, probability for the eyes and mouth. This is the
  /// half a photograph cannot answer: a still image reads the same on every
  /// frame, so its travel is zero on every axis whatever the picture shows. Its
  /// *size* is meant to be set by detector noise rather than by how definite a
  /// movement ought to look - the question it answers is "could sensor drift
  /// have done this", and the answer has to stay no.
  ///
  /// It is not yet set by a measurement, and this comment is the place that has
  /// to say so. Nobody has recorded what ML Kit's probabilities do frame to
  /// frame on a still image, in the light an employee happens to be standing in,
  /// on the handset in their hand, at arm's length. The present values assume a
  /// per-frame sigma of
  /// about 0.05 and independence between frames - and the second is certainly
  /// false. The readings are autocorrelated, which makes the two-frames-in-a-row
  /// that [LivenessGestureMachine.holdSamples] asks for much cheaper for a still
  /// target than the assumption implies. These values came from the
  /// `esas_attendance` kiosk, where `tool/noise_probe` measures them; until that
  /// meter has been run against a printed photograph and a phone screen on a
  /// handset, they are a guess with a margin rather than a floor.
  final double delta;

  /// Which way the signal has to move: 1 up, -1 down.
  final int direction;

  /// An absolute the reading must also reach, or null where none applies.
  ///
  /// Measuring only from rest let a gesture be cheap for somebody whose rest
  /// already sat near the answer: a resting smile of 0.08 answered "smile
  /// widely" at 0.43, below what Google itself calls likely smiling, and a
  /// resting pitch of -18 degrees - what a handset held at waist height produces
  /// - let `look_up` be answered by raising the phone. It never makes a gesture
  /// easier; the requirement is whichever of the two is further away.
  final double? anchor;

  /// Whether this axis has an end to travel to.
  bool get isBounded => axis == GestureAxis.eye || axis == GestureAxis.mouth;

  /// How far this signal can still travel the way the gesture asks, or null on
  /// an axis with no end.
  ///
  /// Degrees are unbounded: a head at any resting angle can turn twenty more. A
  /// probability is not. `smiling` stops at 1 and `eyesOpen` stops at 0, so
  /// somebody whose resting smile reads 0.7 would have to produce 1.05 to clear
  /// a delta of 0.35 - and no expression, held for any length of time, is a
  /// probability above one. They are not being asked for something strict; they
  /// are being asked for something that is not on the number line, while the bar
  /// on the screen sits at nought and the app tells them to try harder.
  double? headroomFrom(double baseline) => switch (axis) {
    GestureAxis.yaw || GestureAxis.pitch => null,
    GestureAxis.eye ||
    GestureAxis.mouth => direction > 0 ? 1.0 - baseline : baseline,
  };

  /// Determine whether a reading, measured against a baseline, performs this.
  ///
  /// Both halves, and the excursion first: an absolute alone would let a printed
  /// photograph of a smiling face answer `smile` outright, because its reading
  /// is already there and never has to move.
  bool satisfiedBy(double value, double baseline) {
    if ((value - baseline) * direction < delta) {
      return false;
    }

    final anchor = this.anchor;

    return anchor == null || (value - anchor) * direction >= 0;
  }

  /// How far along, 0..1, shown as whichever half is further behind.
  ///
  /// A bar that filled on the excursion alone would sit full while the reading
  /// was still short of the absolute - the bar telling somebody they have
  /// arrived somewhere the check will not let them into, which is the one
  /// thing it must never say.
  double progressOf(double value, double baseline) {
    final travelled = (value - baseline) * direction;
    final byDelta = delta <= 0 ? 1.0 : travelled / delta;

    final anchor = this.anchor;
    final toAnchor = anchor == null ? null : (anchor - baseline) * direction;
    final byAnchor = toAnchor == null || toAnchor <= 0
        ? 1.0
        : travelled / toAnchor;

    return math.min(byDelta, byAnchor).clamp(0.0, 1.0);
  }
}

/// The catalogue, and the thresholds each gesture is judged by.
///
/// The head-angle signs follow ML Kit's own convention: positive `headEulerAngleY`
/// is a face turning toward the right of the *image being processed*, and
/// positive `headEulerAngleX` is a face turning upward. The front camera's frames
/// reach the detector unmirrored - mirroring is something the preview does at
/// draw time - so the image is the view an observer standing at the phone would
/// have. Somebody turning their head to their own left therefore turns toward
/// the right of that image, which is the positive direction.
///
/// Two things are asked of every gesture and they do different jobs. [delta] is
/// the excursion from the person's own rest, sized against detector noise - it
/// is what a photograph cannot produce. [anchor] is an absolute the reading must
/// also reach, and it is what stops a gesture being cheap for somebody whose
/// rest already sits near the answer.
///
/// The head deltas came down - 20 to 15, 13 to 11 - because a photograph is
/// turned by tilting the paper, so their magnitude was never what defended
/// them; the anchors are what now does. `blink` did not move: it is one of only
/// two gestures a rigid image cannot fake, and at a healthy resting value it was
/// never strict - its failures were saturation and unreadable frames, which a
/// smaller number does not fix. `smile` came down by one step and gained the
/// anchor that more than repays it.
const Map<String, GestureSpec> kGestureCatalogue = {
  'turn_left': GestureSpec(
    action: 'turn_left',
    axis: GestureAxis.yaw,
    delta: 15,
    direction: 1,
    anchor: 5,
  ),
  'turn_right': GestureSpec(
    action: 'turn_right',
    axis: GestureAxis.yaw,
    delta: 15,
    direction: -1,
    anchor: -5,
  ),
  'look_up': GestureSpec(
    action: 'look_up',
    axis: GestureAxis.pitch,
    delta: 11,
    direction: 1,
    anchor: 5,
  ),
  'look_down': GestureSpec(
    action: 'look_down',
    axis: GestureAxis.pitch,
    delta: 11,
    direction: -1,
    anchor: -5,
  ),
  'blink': GestureSpec(
    action: 'blink',
    axis: GestureAxis.eye,
    delta: 0.35,
    direction: -1,
    anchor: 0.35,
  ),
  'smile': GestureSpec(
    action: 'smile',
    axis: GestureAxis.mouth,
    delta: 0.30,
    direction: 1,
    anchor: 0.60,
  ),
};

/// One frame's worth of what the detector saw.
///
/// A frame with no face is a sample with every field null, and that is a
/// meaningful thing rather than a gap: it is how "the person walked out of
/// shot" reaches the machine.
class FaceSample {
  const FaceSample({
    required this.atMs,
    this.yaw,
    this.pitch,
    this.leftEyeOpen,
    this.rightEyeOpen,
    this.smiling,
    this.faceCount = 0,
  });

  const FaceSample.noFace(this.atMs)
    : yaw = null,
      pitch = null,
      leftEyeOpen = null,
      rightEyeOpen = null,
      smiling = null,
      faceCount = 0;

  final int atMs;
  final double? yaw;
  final double? pitch;
  final double? leftEyeOpen;
  final double? rightEyeOpen;
  final double? smiling;
  final int faceCount;

  bool get hasFace => faceCount > 0;

  /// Both eyes, taken as the more open of the two.
  ///
  /// A blink closes both. Using the *larger* of the two probabilities means a
  /// wink does not answer the challenge, and neither does one eye that the
  /// detector happens to read badly at an angle.
  double? get eyesOpen {
    final left = leftEyeOpen;
    final right = rightEyeOpen;

    if (left == null && right == null) {
      return null;
    }

    return math.max(left ?? 0, right ?? 0);
  }

  double? reading(GestureAxis axis) => switch (axis) {
    GestureAxis.yaw => yaw,
    GestureAxis.pitch => pitch,
    GestureAxis.eye => eyesOpen,
    GestureAxis.mouth => smiling,
  };
}

/// What the machine concluded about one gesture, and what it saw when it did.
class GestureEvidence {
  const GestureEvidence({
    required this.action,
    required this.performed,
    this.detectedAtMs,
    this.measured,
    this.baseline,
    this.reason,
  });

  final String action;
  final bool performed;
  final int? detectedAtMs;
  final double? measured;
  final double? baseline;

  /// Why it was not performed, when the machine can tell.
  ///
  /// `not_detected` means the person was measured and did not move far enough.
  /// `signal_unavailable` means there was nothing to measure: the detector
  /// returned no value for that axis for the whole window - classification off,
  /// a face too small or too dark for the classifier - or no baseline was ever
  /// established for it. The two look identical on screen and are opposite in
  /// meaning, and telling somebody "you did not move" when the camera never saw
  /// them move sends them to HR to argue about something the row cannot answer.
  final String? reason;

  Map<String, dynamic> toJson() => {
    'action': action,
    'performed': performed,
    if (detectedAtMs != null) 'detected_at_ms': detectedAtMs,
    if (measured != null)
      'measured': double.parse(measured!.toStringAsFixed(4)),
    if (baseline != null)
      'baseline': double.parse(baseline!.toStringAsFixed(4)),
    if (reason != null) 'reason': reason,
  };
}

/// Where the sequence has got to.
enum GesturePhase { baseline, performing, done }

/// Scores a person performing a list of gestures, one frame at a time.
///
/// Pure Dart on purpose: no camera, no plugin, no platform channel. The whole of
/// the liveness decision lives here — the server is sent a photograph and a
/// claim, never a recording — which makes it the part most worth being able to
/// test, and a class that needed a handset to exercise would be the part nobody
/// tested.
///
/// Ported unchanged from the `esas_attendance` kiosk so that one employee cannot
/// be judged by two different implementations of the same check depending on
/// whether they clocked at the gate machine or on their own phone.
///
/// The shape of the check is the one the server used to run, kept deliberately:
/// measure the person's own resting pose first, then look for excursions from
/// *that* rather than from zero, and require the gestures in the order they were
/// asked for. What is gone is the witness - see the controller and the Laravel
/// side for what that costs and what is done about it.
class LivenessGestureMachine {
  LivenessGestureMachine({
    required List<String> actions,
    this.baselineSamples = 8,
    this.holdSamples = 2,
  }) : _specs = actions
           .map((action) => kGestureCatalogue[action])
           .whereType<GestureSpec>()
           .toList(growable: false),
       _unknown = actions
           .where((a) => !kGestureCatalogue.containsKey(a))
           .toList();

  final List<GestureSpec> _specs;

  /// Gestures the server asked for that this build has never heard of.
  ///
  /// Not silently skipped: a build that quietly ignored an unknown gesture would
  /// report a complete answer to a challenge it only half performed, and the
  /// server would accept it. The controller refuses to start instead.
  final List<String> _unknown;

  /// How many face-bearing frames the resting pose is measured over.
  final int baselineSamples;

  /// How many consecutive frames have to agree before a gesture counts.
  ///
  /// One frame is a detector wobble; two in a row at 10-15 fps is a movement
  /// somebody made.
  final int holdSamples;

  final List<FaceSample> _baseline = [];
  final Map<String, double> _resting = {};
  final List<GestureEvidence> _evidence = [];

  int _index = 0;
  int _streak = 0;
  double? _bestReading;
  int? _bestAtMs;
  bool _sawReading = false;
  double _progress = 0;

  GesturePhase phase = GesturePhase.baseline;

  /// Why the resting pose could not be used, when it could not.
  ///
  /// `signal_unavailable`: the detector never produced a reading for an axis a
  /// drawn gesture needs. ML Kit computes "smiling" and "eyes open" only for a
  /// face square to the lens and returns nothing at all off-axis, so entering
  /// [GesturePhase.performing] on such an axis scores three hundred frames
  /// against null and refuses somebody doing exactly as they were told.
  ///
  /// `axis_saturated`: it produced one, and it leaves no room for the excursion
  /// the gesture asks for - a resting smile already near 1, or resting eyes
  /// already reading near 0 through a pair of spectacles.
  ///
  /// Either way the attempt ends here, in about a second and a half, saying
  /// something the person can act on - rather than thirty seconds later, about
  /// a movement they performed correctly.
  String? baselineRefusal;

  /// How many times the resting pose has been discarded and measured again.
  int baselineAttempts = 0;

  /// One retake, and only for the mouth.
  ///
  /// The commonest cause of a saturated mouth is somebody smiling at a camera
  /// that has just told them it will ask them to smile, and "wajah santai"
  /// fixes that. Nothing anybody says fixes a spectacle lens catching an
  /// overhead light, so the eye axis is refused at once - a second draw
  /// there would only hand a still image another chance and keep whichever one
  /// favoured it.
  static const int maxBaselineAttempts = 2;

  /// How much of the axis must remain beyond the excursion for it to be usable.
  static const double saturationMargin = 0.10;

  /// How far a retaken resting value has to have moved to be believed.
  ///
  /// A face that stops posing moves a long way on the axis that was stuck. A
  /// photograph cannot move at all - its second reading is its first plus
  /// noise - so accepting one that barely moved would mean the guard had done
  /// nothing except hand a still image a second draw and keep the better one.
  static const double retakeMinShift = 0.15;

  /// Frames that produced a measurement, sent with the evidence. Nothing at
  /// present records whether the pump ran at ten frames a second or four, and
  /// the difference decides whether a blink could have been caught at all.
  int framesScored = 0;

  /// Whether the axis being looked for has produced any reading at all yet.
  String? get currentReason => phase == GesturePhase.performing && !_sawReading
      ? 'signal_unavailable'
      : null;

  final Map<String, double> _discarded = {};

  List<String> get unknownActions => List.unmodifiable(_unknown);

  /// The gesture being looked for, or null before and after the sequence.
  GestureSpec? get current =>
      phase == GesturePhase.performing && _index < _specs.length
      ? _specs[_index]
      : null;

  int get currentIndex => _index;

  int get total => _specs.length;

  /// How far the baseline has got, 0..1. Drives the "hold still" progress.
  double get baselineProgress => baselineSamples == 0
      ? 1
      : math.min(1, _baseline.length / baselineSamples);

  /// How far the gesture being looked for has travelled toward its threshold,
  /// 0..1, as of the last frame that could be measured.
  ///
  /// The screen shows this while it waits, and it is the difference between a
  /// person who can correct what they are doing and one who cannot. A gesture
  /// is scored against a threshold nobody can see: somebody turning fifteen
  /// degrees when twenty are wanted is doing the right thing and being told
  /// nothing, and the only correction available to them is to try harder at
  /// random. A bar that fills as they turn tells them which way and how much.
  ///
  /// Zero for a frame with no face, or with more than one, because neither is a
  /// small amount of movement - it is no measurement at all.
  double get currentProgress => _progress;

  bool get isComplete => phase == GesturePhase.done;

  /// Every gesture was performed, in order.
  bool get passed =>
      isComplete &&
      _evidence.length == _specs.length &&
      _evidence.every((e) => e.performed);

  List<GestureEvidence> get evidence => List.unmodifiable(_evidence);

  /// Feed one frame. Answers true when this frame completed the current gesture.
  bool offer(FaceSample sample) {
    if (phase == GesturePhase.done) {
      return false;
    }

    if (phase == GesturePhase.baseline) {
      _buildBaseline(sample);
      return false;
    }

    return _score(sample);
  }

  /// Give up on the gesture being looked for and move to the next.
  ///
  /// Called when a window runs out. The evidence records what the closest
  /// reading was, which is what turns "you did not do it" into "you turned, but
  /// not far enough" for whoever reads the row later.
  void timeout() {
    if (phase != GesturePhase.performing || _index >= _specs.length) {
      return;
    }

    final spec = _specs[_index];

    _evidence.add(
      GestureEvidence(
        action: spec.action,
        performed: false,
        measured: _bestReading,
        baseline: _resting[spec.axis.name],
        reason: _sawReading ? 'not_detected' : 'signal_unavailable',
      ),
    );

    _advance();
  }

  void _buildBaseline(FaceSample sample) {
    // As strict as [_score], and for the same reason. A frame with a second
    // face in it is not a slightly noisier measurement of this person's rest:
    // the largest-face reduction upstream may have picked the other one, so the
    // reading can belong to somebody walking past behind them. Eight frames is
    // a short window and two bad ones move a median - and every gesture in the
    // attempt is then scored against a stranger's resting pose.
    if (!sample.hasFace || sample.faceCount != 1) {
      return;
    }

    _baseline.add(sample);

    if (_baseline.length < baselineSamples) {
      return;
    }

    for (final axis in GestureAxis.values) {
      final readings =
          _baseline.map((s) => s.reading(axis)).whereType<double>().toList()
            ..sort();

      if (readings.isNotEmpty) {
        // Median, not mean: one frame caught mid-blink drags a mean far enough
        // to make the blink that follows it unfindable.
        _resting[axis.name] = readings[readings.length ~/ 2];
      }
    }

    final refusal = _refuseBaseline();

    if (refusal != null) {
      baselineAttempts++;

      if (baselineAttempts < maxBaselineAttempts &&
          refusal == 'axis_saturated' &&
          _specs.any((spec) => spec.axis == GestureAxis.mouth)) {
        _discarded
          ..clear()
          ..addAll(_resting);
        _baseline.clear();
        _resting.clear();

        return;
      }

      baselineRefusal = refusal;
      phase = GesturePhase.done;

      return;
    }

    // The retake rests on one belief: that the person was posing at the camera
    // while it measured them, and has now stopped. See [retakeMinShift] for why
    // a value that barely moved is refused rather than accepted.
    if (_discarded.isNotEmpty) {
      for (final spec in _specs) {
        final was = _discarded[spec.axis.name];
        final now = _resting[spec.axis.name];

        if (was == null || now == null || !spec.isBounded) {
          continue;
        }

        if ((was - now) * spec.direction < retakeMinShift) {
          baselineRefusal = 'axis_saturated';
          phase = GesturePhase.done;

          return;
        }
      }
    }

    phase = _specs.isEmpty ? GesturePhase.done : GesturePhase.performing;
  }

  /// Whether the resting pose that was just measured can carry the challenge.
  String? _refuseBaseline() {
    for (final spec in _specs) {
      final baseline = _resting[spec.axis.name];

      if (baseline == null) {
        return 'signal_unavailable';
      }

      final headroom = spec.headroomFrom(baseline);

      if (headroom != null && headroom < spec.delta + saturationMargin) {
        return 'axis_saturated';
      }
    }

    return null;
  }

  bool _score(FaceSample sample) {
    final spec = _specs[_index];
    final reading = sample.reading(spec.axis);
    final baseline = _resting[spec.axis.name];

    if (reading == null || baseline == null || !sample.hasFace) {
      _streak = 0;
      _progress = 0;
      return false;
    }

    // Something was measurable this frame, which is what separates "did not move
    // far enough" from "there was never anything to read".
    _sawReading = true;

    // More than one face in shot is not scored at all. A bystander performing
    // the gesture on somebody else's behalf is the cheapest attack there is.
    if (sample.faceCount > 1) {
      _streak = 0;
      _progress = 0;
      return false;
    }

    final travelled = (reading - baseline) * spec.direction;

    framesScored++;

    // Whichever half is further behind - see [GestureSpec.progressOf]. Clamped
    // at both ends: a negative travel is a movement the other way, and showing
    // it as "some progress" would tell somebody turning the wrong way that they
    // are getting closer.
    _progress = spec.progressOf(reading, baseline);

    if (_bestReading == null ||
        travelled > ((_bestReading! - baseline) * spec.direction)) {
      _bestReading = reading;
      _bestAtMs = sample.atMs;
    }

    if (!spec.satisfiedBy(reading, baseline)) {
      _streak = 0;
      return false;
    }

    _streak++;

    if (_streak < holdSamples) {
      return false;
    }

    _evidence.add(
      GestureEvidence(
        action: spec.action,
        performed: true,
        detectedAtMs: _bestAtMs ?? sample.atMs,
        measured: reading,
        baseline: baseline,
      ),
    );

    _advance();

    return true;
  }

  void _advance() {
    _index++;
    _streak = 0;
    _bestReading = null;
    _bestAtMs = null;
    _sawReading = false;
    _progress = 0;

    if (_index >= _specs.length) {
      phase = GesturePhase.done;
    }
  }

  /// Determine whether this frame shows the person back at their resting pose.
  ///
  /// The still is taken after the last gesture, and the machine accepts a
  /// gesture at the *start* of the excursion - two frames in, roughly 200ms - so
  /// without waiting the shutter fires while the head is still turned 20 degrees
  /// or the eyes are still shut. That photograph is then the one the face
  /// service scores against five forward-facing enrolment photos, and the one
  /// filed on the attendance record for a reviewer to look at.
  ///
  /// Judged against the person's own baseline, like everything else here. An
  /// absolute rule - "eyes open above 0.7" - would hold the settle open forever
  /// for somebody whose resting reading is lower than that, which is a person
  /// standing in front of a camera that will not photograph them.
  bool atRest(FaceSample sample) {
    if (!sample.hasFace || sample.faceCount != 1) {
      return false;
    }

    for (final entry in _resting.entries) {
      final axis = GestureAxis.values.firstWhere(
        (value) => value.name == entry.key,
      );
      final reading = sample.reading(axis);

      if (reading == null) {
        continue;
      }

      // Held below the matching delta by the margin this design has always
      // used. A tolerance at or above its gesture's delta means the shutter can
      // fire on a face still performing the gesture - the photograph then
      // reaching the face service is a profile, or a blink, compared against
      // five forward-facing enrolment photos.
      final tolerance = switch (axis) {
        GestureAxis.yaw => 10.0, // 15 / 10   = 1.50
        GestureAxis.pitch => 7.0, // 11 / 7   = 1.57
        GestureAxis.eye => 0.2, // 0.35 / 0.2 = 1.75
        GestureAxis.mouth => 0.21, // 0.30 / 0.21 = 1.43
      };

      if ((reading - entry.value).abs() > tolerance) {
        return false;
      }
    }

    return true;
  }

  /// The block posted to the server beside the capture.
  ///
  /// The server checks this answers the challenge it drew - the same gestures,
  /// in the same order, all performed - and keeps it verbatim on the
  /// verification row. It cannot verify the measurements, and does not pretend
  /// to: what it gives somebody disputing a refusal months later is a record of
  /// what this handset actually saw.
  Map<String, dynamic> toEvidenceJson({required int elapsedMs}) => {
    'detector': 'google_mlkit_face_detection',
    'elapsed_ms': elapsedMs,
    // How many frames actually reached the scorer. Nothing recorded this
    // before, and it is the difference between "they did not blink" and
    // "the pump delivered four frames a second and could not have seen
    // one". The server reads a fixed field list and ignores extras.
    'frames_scored': framesScored,
    if (baselineRefusal != null) 'baseline_refusal': baselineRefusal,
    'actions': _evidence.map((e) => e.toJson()).toList(),
  };
}

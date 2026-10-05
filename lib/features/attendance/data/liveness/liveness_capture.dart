import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/utils/app_logger.dart';
import '../models/liveness_challenge.dart';
import 'display_rotation.dart';
import 'face_sampler.dart';
import 'liveness_diagnostics.dart';
import 'liveness_gestures.dart';

/// Where a capture has got to. Drives what the screen says, and nothing else.
enum LivenessPhase {
  /// Opening the camera.
  opening,

  /// Reading the person's resting pose. "Tetap diam, wajah santai."
  settling,

  /// Waiting for one of the movements the server asked for.
  performing,

  /// Every movement was accepted; waiting for the face to come back to rest
  /// before the shutter.
  composing,

  /// Taking the photograph.
  capturing,

  /// Nothing is running.
  idle,
}

/// Why a capture ended without a photograph.
///
/// Every one of these is about the handset and the person in front of it —
/// nothing here is the server's verdict, which arrives later and separately. The
/// codes are for the log; [message] is what the employee reads, and it never
/// mentions a detector, a probability or a threshold.
enum LivenessFailureKind {
  /// The camera could not be opened or read.
  camera,

  /// No face was found at all, for long enough that waiting more is pointless.
  noFace,

  /// More than one face in shot. A frame with two is never scored.
  crowded,

  /// The resting pose could not be measured, or leaves no room for a movement.
  unreadable,

  /// A movement was asked for and never seen.
  notPerformed,

  /// The server's challenge outlived the attempt.
  expired,

  /// The server asked for a movement this build does not know.
  unsupported,

  /// The screen was left, or the app went to the background.
  abandoned,
}

class LivenessFailure implements Exception {
  const LivenessFailure(this.kind, this.message);

  final LivenessFailureKind kind;

  /// A sentence for the employee. Plain, and about what they can do.
  final String message;

  @override
  String toString() => 'LivenessFailure(${kind.name}): $message';
}

/// A photograph and the evidence that goes with it.
class LivenessResult {
  const LivenessResult({required this.image, required this.evidence});

  final File image;

  /// What ML Kit measured, in the shape the server reads. Kept verbatim on the
  /// verification row, so a disputed refusal has something to be disputed with.
  final Map<String, dynamic> evidence;
}

/// One person performing one challenge in front of the front camera.
///
/// Owns the camera, the detector and the gesture machine for the length of a
/// single attempt, and hands back a photograph plus a claim about what it saw.
/// It is deliberately not a `GetxController`: it is created per attempt and
/// destroyed with it, and a screen-scoped controller that outlived one attempt
/// would be a native detector session that outlived it too.
///
/// ## What this can and cannot promise
///
/// The gestures are measured **on the handset**, so the server is handed a claim
/// rather than a witness. A rewritten build of this app can post a perfect
/// attestation beside any photograph and nothing here prevents that.
///
/// What it is good for is the honest case, which is nearly all of it: a
/// photograph held up to the lens has one pose and the movements are excursions
/// from a measured baseline; a bystander cannot answer on somebody's behalf,
/// because a frame with two faces is not scored at all; and the movements must
/// arrive in the order the server drew them. What stops the dishonest case is on
/// the server — the challenge is drawn there, signed there, bound to one person
/// and one direction, and spent exactly once against a unique index.
class LivenessCapture {
  LivenessCapture({
    required this.challenge,
    FaceSampler? sampler,
    Future<List<CameraDescription>> Function()? cameras,
  }) : _sampler = sampler ?? FaceSampler(),
       _cameras = cameras ?? availableCameras;

  final LivenessChallenge challenge;
  final FaceSampler _sampler;
  final Future<List<CameraDescription>> Function() _cameras;

  /// How long one movement may be waited for before the attempt ends on it.
  ///
  /// A ceiling, not a window: reaching it does not move the sequence on. Walking
  /// past a movement that was never seen means asking somebody to keep
  /// performing an attempt that is already lost, and telling them at the end.
  static const Duration stepCeiling = Duration(seconds: 30);

  /// How long the resting pose may take to settle.
  static const Duration baselineCeiling = Duration(seconds: 12);

  /// How long to wait for the face to come back to centre before the shutter.
  static const Duration settleCeiling = Duration(milliseconds: 1800);

  /// How often to change the hint while a movement is being waited for.
  static const Duration hintAfter = Duration(seconds: 6);

  /// How long the face may be out of frame mid-sequence before the attempt is
  /// abandoned.
  ///
  /// Continuity by PRESENCE, not by identity. The gesture machine refuses a
  /// frame holding two faces, but it cannot tell one lone face from another: A
  /// performs gesture one, steps aside, B steps in, and gesture two is scored
  /// against A's resting pose. The server catches the substitution — the
  /// photograph is B's and is scored against A's enrolment — but the attestation
  /// this app posts would still claim a sequence one person completed, and that
  /// is evidence it must not produce.
  ///
  /// A gap in presence is the honest signal available here. Nothing local
  /// attempts to match identity between frames, which would be biometric
  /// processing this screen has neither the consent nor the reason to do.
  /// ML Kit's `enableTracking` would give a stronger instance signal at a
  /// per-frame cost; it is deliberately left off, as in the kiosk this engine
  /// came from.
  static const Duration continuityGap = Duration(milliseconds: 1500);

  final ValueNotifier<LivenessPhase> phase = ValueNotifier(LivenessPhase.idle);

  /// Which movement is being asked for, as an index into [challenge.actions].
  final ValueNotifier<int?> step = ValueNotifier(null);

  /// How far the current movement has travelled toward being accepted, 0..1.
  ///
  /// The bar is the difference between a person who can correct what they are
  /// doing and one who cannot: a movement is scored against a threshold nobody
  /// can see, so somebody turning fifteen degrees when twenty are wanted is
  /// doing the right thing and being told nothing.
  final ValueNotifier<double> progress = ValueNotifier(0);

  /// How far the resting pose has got, 0..1.
  final ValueNotifier<double> settling = ValueNotifier(0);

  final ValueNotifier<bool> faceInFrame = ValueNotifier(false);
  final ValueNotifier<bool> crowded = ValueNotifier(false);

  /// A sentence to show somebody who has been trying for a few seconds.
  final ValueNotifier<String?> hint = ValueNotifier(null);

  /// The live preview, once there is one.
  final ValueNotifier<CameraController?> preview = ValueNotifier(null);

  /// Frame-rate and face-size figures for physical-device QA.
  ///
  /// Collected only in a debug build, and carrying nothing a face is made of —
  /// see [LivenessDiagnostics].
  final LivenessDiagnosticsRecorder diagnostics = LivenessDiagnosticsRecorder();

  DateTime? _startedAt;
  DateTime? _lastFrame;
  bool _busy = false;
  bool _streaming = false;
  bool _measuring = false;
  bool _aborted = false;
  bool _disposed = false;
  int _restStreak = 0;
  final PresenceContinuity _continuity = PresenceContinuity();

  /// Run the whole attempt. Throws [LivenessFailure] if it does not end in a
  /// photograph.
  Future<LivenessResult> run() async {
    final machine = LivenessGestureMachine(
      actions: challenge.actions.map((action) => action.action).toList(),
    );

    // A movement this build has never heard of is refused rather than skipped.
    // Skipping it would report a complete answer to a challenge only half
    // performed — and the server, which cannot see the difference, would take
    // the app's word for it.
    if (machine.unknownActions.isNotEmpty) {
      throw const LivenessFailure(
        LivenessFailureKind.unsupported,
        'Aplikasi ini belum mendukung gerakan yang diminta. Perbarui aplikasi, '
        'lalu coba lagi.',
      );
    }

    if (machine.total == 0) {
      throw const LivenessFailure(
        LivenessFailureKind.unsupported,
        'Tidak ada gerakan yang diminta. Mulai ulang verifikasi.',
      );
    }

    final controller = await _openCamera();

    _startedAt = DateTime.now();
    await _startStream(controller, machine);

    await _measureRest(machine);
    await _performEach(controller, machine);

    return _capture(controller, machine);
  }

  /// Stop everything. Safe to call twice, and safe to call mid-attempt.
  Future<void> dispose() async {
    if (_disposed) return;

    _disposed = true;
    _aborted = true;
    _measuring = false;

    await _stopStream();

    final controller = preview.value;
    preview.value = null;

    // Awaited: `dispose` waits on any in-flight initialise, and it is the only
    // thing that hands the sensor back. Without it the next attempt cannot open
    // the camera at all.
    await controller?.dispose();

    // The detector holds a native ML Kit session. Left open it leaks one per
    // attempt.
    await _sampler.close();
  }

  /// The notifiers above are deliberately **not** disposed here.
  ///
  /// Ownership is split: the controller ends an attempt, and the screen is
  /// still listening when it does. Disposing them at that moment throws "a
  /// ValueNotifier was used after being disposed" on the very next frame — and
  /// it buys nothing, because this object is created per attempt and everything
  /// expensive about it (the camera and the ML Kit session) is released above.
  /// A `ValueNotifier` with no listeners is collected like any other object.

  /// Give up without tearing the object down, so the screen can say why.
  void abort() {
    _aborted = true;
    _measuring = false;
  }

  Future<CameraController> _openCamera() async {
    phase.value = LivenessPhase.opening;

    final List<CameraDescription> cameras;

    try {
      cameras = await _cameras();
    } on CameraException catch (error) {
      throw LivenessFailure(LivenessFailureKind.camera, _cameraSentence(error));
    }

    if (cameras.isEmpty) {
      throw const LivenessFailure(
        LivenessFailureKind.camera,
        'Perangkat ini tidak memiliki kamera yang bisa dipakai untuk '
        'verifikasi wajah.',
      );
    }

    // Front, and only front. Verification is of the person holding the phone;
    // a rear camera here would photograph whoever is standing opposite them.
    final front = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    final controller = CameraController(
      front,
      // The detector downscales anyway and the capture is downscaled again on
      // the server. What a modest preset buys is a stream the handset can keep
      // up with, and frames per second is what catches a blink.
      FaceSampler.preset,
      enableAudio: false,
      // NV21 on Android, BGRA on iOS — the two formats ML Kit reads without a
      // per-frame plane interleave in Dart. See CameraInput.
      imageFormatGroup: FaceSampler.formatGroup,
    );

    try {
      await controller.initialize();
    } on CameraException catch (error) {
      await controller.dispose();

      throw LivenessFailure(LivenessFailureKind.camera, _cameraSentence(error));
    }

    if (_aborted || _disposed) {
      await controller.dispose();

      throw const LivenessFailure(
        LivenessFailureKind.abandoned,
        'Verifikasi dihentikan.',
      );
    }

    preview.value = controller;

    return controller;
  }

  /// Measure the resting pose every movement will be judged against.
  Future<void> _measureRest(LivenessGestureMachine machine) async {
    phase.value = LivenessPhase.settling;
    hint.value = null;

    // Armed only now. A baseline built while somebody was still bringing the
    // phone up to their face makes their first movement look smaller than it
    // was — and the badge above the preview has been updating the whole time,
    // so nobody is left wondering.
    _measuring = true;

    final settled = await _waitFor(
      () => machine.phase != GesturePhase.baseline,
      ceiling: baselineCeiling,
    );

    _guardAbandoned();

    if (!settled) {
      throw const LivenessFailure(
        LivenessFailureKind.noFace,
        'Wajah belum terbaca. Pastikan wajah berada di dalam bingkai dan '
        'ruangan cukup terang.',
      );
    }

    final refusal = machine.baselineRefusal;

    if (refusal != null) {
      // Said now, in about a second and a half, rather than after thirty
      // seconds of somebody performing a movement the measurement had already
      // put out of reach.
      throw LivenessFailure(
        LivenessFailureKind.unreadable,
        refusal == 'axis_saturated'
            ? 'Wajah belum terbaca jelas. Pastikan wajah santai dan lurus ke '
                  'kamera, lalu coba lagi.'
            : 'Wajah belum terbaca jelas. Hadap lurus ke kamera dan majukan '
                  'wajah ke dalam bingkai, lalu coba lagi.',
      );
    }
  }

  /// Ask for each movement in turn, and stop on the first that is not seen.
  Future<void> _performEach(
    CameraController controller,
    LivenessGestureMachine machine,
  ) async {
    phase.value = LivenessPhase.performing;

    for (var index = 0; index < machine.total; index++) {
      _guardAbandoned();

      step.value = index;
      progress.value = 0;
      hint.value = null;

      final performed = await _awaitStep(machine, index);

      if (!performed) {
        machine.timeout();

        if (challenge.hasExpired) {
          throw const LivenessFailure(
            LivenessFailureKind.expired,
            'Waktu verifikasi habis. Mulai ulang verifikasi wajah.',
          );
        }

        if (_continuity.broken) {
          throw const LivenessFailure(
            LivenessFailureKind.noFace,
            'Wajah sempat keluar dari bingkai. Mulai ulang verifikasi agar '
            'seluruh gerakan terekam dalam satu rangkaian.',
          );
        }

        throw LivenessFailure(
          _stepFailureKind(machine),
          _stepFailureSentence(machine, index),
        );
      }

      progress.value = 1;
      hint.value = null;
    }

    step.value = null;
    progress.value = 0;

    // The machine accepts a movement two frames into the excursion — about
    // 200ms — so at this instant the head may still be turned or the eyes still
    // shut. Photographing that hands the server a profile to compare against
    // five forward-facing enrolment photographs, and leaves a reviewer looking
    // at somebody mid-blink.
    phase.value = LivenessPhase.composing;
    await _waitFor(() => _restStreak >= 3, ceiling: settleCeiling);
  }

  Future<bool> _awaitStep(LivenessGestureMachine machine, int index) async {
    const tick = Duration(milliseconds: 120);

    final deadline = DateTime.now().add(stepCeiling);
    var nextHint = DateTime.now().add(hintAfter);

    while (DateTime.now().isBefore(deadline)) {
      if (machine.currentIndex > index) return true;

      // True, not false: a false here would file "you did not perform this
      // movement" against somebody who simply left the screen. The caller
      // re-checks and stops.
      if (_aborted || _disposed) return true;

      // A challenge that died mid-attempt cannot be spent, so waiting the
      // ceiling out would be thirty seconds of somebody performing movements
      // against a token the server will refuse whatever they do.
      if (challenge.hasExpired) return false;

      // The face went away for long enough that what comes back may not be the
      // same person. The sequence does not continue across that gap.
      if (_continuity.broken) return false;

      progress.value = machine.currentProgress;

      if (DateTime.now().isAfter(nextHint)) {
        hint.value = _hintFor(machine);
        nextHint = DateTime.now().add(hintAfter);
      }

      await Future<void>.delayed(tick);
    }

    return machine.currentIndex > index;
  }

  Future<LivenessResult> _capture(
    CameraController controller,
    LivenessGestureMachine machine,
  ) async {
    phase.value = LivenessPhase.capturing;

    // Taken *after* the stream has stopped. Capturing mid-stream is unsupported
    // on a good many Android devices, and where it is supported it races the
    // encoder.
    await _stopStream();

    _guardAbandoned();

    // Checked before the shutter, not after the upload. A capture taken against
    // a dead challenge costs the person a photograph and a round trip to be
    // told something this side already knew.
    if (challenge.hasExpired) {
      throw const LivenessFailure(
        LivenessFailureKind.expired,
        'Waktu verifikasi habis. Mulai ulang verifikasi wajah.',
      );
    }

    if (!machine.passed) {
      // Unreachable by the ordinary route — a movement that is not performed
      // ends the attempt where it happened. Kept because reaching the shutter
      // with an unpassed machine would photograph somebody and send it as a
      // pass, and that is not a thing to leave to the reachability of a branch.
      throw const LivenessFailure(
        LivenessFailureKind.notPerformed,
        'Gerakan belum lengkap terbaca. Mulai ulang verifikasi wajah.',
      );
    }

    final XFile shot;

    try {
      shot = await controller.takePicture();
    } on CameraException catch (error) {
      throw LivenessFailure(LivenessFailureKind.camera, _cameraSentence(error));
    }

    final image = File(shot.path);

    if (_aborted || _disposed) {
      await _discard(image);

      throw const LivenessFailure(
        LivenessFailureKind.abandoned,
        'Verifikasi dihentikan.',
      );
    }

    return LivenessResult(
      image: image,
      evidence: machine.toEvidenceJson(
        elapsedMs: DateTime.now()
            .difference(_startedAt ?? DateTime.now())
            .inMilliseconds,
      ),
    );
  }

  /// Delete a capture that is not going to be sent.
  ///
  /// The photograph lives in the OS cache directory the camera plugin chose, and
  /// it is a picture of somebody's face. An attempt that ended in a refusal
  /// leaves nothing behind on the handset.
  static Future<void> discard(File? image) => _discard(image);

  static Future<void> _discard(File? image) async {
    if (image == null) return;

    try {
      if (image.existsSync()) await image.delete();
    } on FileSystemException {
      // Deliberately without the exception: `FileSystemException.toString()`
      // carries the path, and that path names a photograph of somebody's face.
      // A release log is readable over `adb logcat` and Console.app.
      AppLogger.warning('A face capture could not be deleted.');
    }
  }

  Future<void> _startStream(
    CameraController controller,
    LivenessGestureMachine machine,
  ) async {
    if (_streaming) return;

    _streaming = true;
    _lastFrame = null;

    try {
      await controller.startImageStream(
        (image) => _onFrame(image, controller, machine),
      );
    } on CameraException catch (error) {
      _streaming = false;

      throw LivenessFailure(LivenessFailureKind.camera, _cameraSentence(error));
    }
  }

  Future<void> _stopStream() async {
    final controller = preview.value;

    if (!_streaming || controller == null) return;

    _streaming = false;

    try {
      await controller.stopImageStream();
    } on CameraException catch (error) {
      AppLogger.warning('Could not stop the image stream: ${error.code}');
    }
  }

  /// One frame, throttled and never re-entered.
  ///
  /// The camera pushes frames whether or not the last one has been looked at.
  /// Without the `_busy` gate the detector is handed a second frame while it is
  /// still on the first, and on a cheap handset the backlog grows until
  /// movements are scored seconds after they were performed.
  Future<void> _onFrame(
    CameraImage image,
    CameraController controller,
    LivenessGestureMachine machine,
  ) async {
    if (_busy || !_streaming || _aborted || _disposed) {
      diagnostics.countDropped();

      return;
    }

    final now = DateTime.now();

    if (_lastFrame != null &&
        now.difference(_lastFrame!) < FaceSampler.frameInterval) {
      diagnostics.countDropped();

      return;
    }

    _busy = true;
    _lastFrame = now;

    try {
      final sample = await _sampler.sample(
        image,
        controller.description,
        atMs: now.difference(_startedAt ?? now).inMilliseconds,
        deviceOrientationDegrees: DisplayRotation.of(controller),
      );

      if (sample == null) return;

      diagnostics.countScored(
        detectorMs: _sampler.lastDetectorMs,
        faceCount: sample.faceCount,
        faceRatio: _sampler.lastFaceRatio,
        elapsedMs: now.difference(_startedAt ?? now).inMilliseconds,
      );

      faceInFrame.value = sample.hasFace;
      crowded.value = sample.faceCount > 1;

      if (!_measuring) return;

      _continuity.offer(sample, at: now);

      machine.offer(sample);

      // Once the movements are done, the only thing left to watch for is the
      // person coming back to rest, so the photograph is not of a turned head.
      if (machine.isComplete) {
        _restStreak = machine.atRest(sample) ? _restStreak + 1 : 0;
      }

      settling.value = machine.baselineProgress;
    } catch (error) {
      // A frame the detector cannot read is a frame, not an outage. Throwing
      // here would escape into the plugin's stream callback, where nothing is
      // watching to catch it.
      //
      // The TYPE only. Nothing measured from a face — an angle, a probability,
      // a bounding box — reaches a log, and a detector message quoting its
      // input would be the one way that could happen by accident.
      AppLogger.warning(
        'A camera frame could not be scored: '
        '${error.runtimeType}',
      );
    } finally {
      _busy = false;
    }
  }

  Future<bool> _waitFor(
    bool Function() done, {
    required Duration ceiling,
  }) async {
    final deadline = DateTime.now().add(ceiling);

    while (DateTime.now().isBefore(deadline)) {
      if (done()) return true;
      if (_aborted || _disposed) return false;

      await Future<void>.delayed(const Duration(milliseconds: 100));
    }

    return done();
  }

  void _guardAbandoned() {
    if (_aborted || _disposed) {
      throw const LivenessFailure(
        LivenessFailureKind.abandoned,
        'Verifikasi dihentikan.',
      );
    }
  }

  /// What to tell somebody who has been performing a movement for a few seconds
  /// without it being accepted.
  ///
  /// Ordered by what would stop the measurement outright before what would only
  /// make it short: there is no point telling somebody to hold a movement longer
  /// when the reason nothing is being read is that the camera cannot see them.
  String _hintFor(LivenessGestureMachine machine) {
    if (!faceInFrame.value) {
      return 'Wajah belum terlihat. Dekatkan wajah ke dalam bingkai.';
    }

    if (crowded.value) {
      return 'Pastikan hanya wajah Anda yang terlihat.';
    }

    if (machine.currentReason == 'signal_unavailable') {
      return 'Hadap lurus ke kamera dan majukan wajah sedikit.';
    }

    if (machine.currentProgress >= 0.6) {
      return 'Hampir. Tahan gerakan sekitar satu detik.';
    }

    return 'Lakukan gerakannya lebih jelas, lalu tahan sebentar.';
  }

  LivenessFailureKind _stepFailureKind(LivenessGestureMachine machine) {
    if (!faceInFrame.value) return LivenessFailureKind.noFace;
    if (crowded.value) return LivenessFailureKind.crowded;

    return machine.currentReason == 'signal_unavailable'
        ? LivenessFailureKind.unreadable
        : LivenessFailureKind.notPerformed;
  }

  /// Why the attempt stopped on this movement.
  ///
  /// Names the movement, because that is the thing the person can do
  /// differently. The two environmental reasons are worded without the word
  /// "gerakan" on purpose: a lighting problem described as a movement problem
  /// sends somebody away to practise turning their head in a dark room.
  String _stepFailureSentence(LivenessGestureMachine machine, int index) {
    if (!faceInFrame.value) {
      return 'Wajah tidak terdeteksi. Pastikan wajah berada di dalam bingkai '
          'dan ruangan cukup terang.';
    }

    if (crowded.value) {
      return 'Terdeteksi lebih dari satu wajah. Pastikan hanya Anda yang '
          'terlihat, lalu ulangi.';
    }

    if (machine.currentReason == 'signal_unavailable') {
      return 'Kamera belum dapat membaca wajah Anda untuk gerakan ini. Hadap '
          'lurus ke kamera dan pastikan ruangan cukup terang, lalu ulangi.';
    }

    final instruction = index < challenge.actions.length
        ? challenge.actions[index].instruction
        : '';

    return instruction.isEmpty
        ? 'Gerakan belum terdeteksi. Ulangi, lalu tahan gerakan sekitar satu '
              'detik.'
        : 'Gerakan "$instruction" belum terdeteksi. Ulangi, lalu tahan sekitar '
              'satu detik.';
  }

  /// A camera fault, said without a plugin error code in it.
  static String _cameraSentence(CameraException error) {
    AppLogger.warning('Face camera failed: ${error.code} ${error.description}');

    return switch (error.code) {
      'CameraAccessDenied' ||
      'CameraAccessDeniedWithoutPrompt' ||
      'CameraAccessRestricted' =>
        'Izin kamera belum diberikan untuk verifikasi wajah.',
      'cameraPermission' =>
        'Izin kamera belum diberikan untuk verifikasi '
            'wajah.',
      _ => 'Kamera tidak dapat dibuka untuk verifikasi wajah. Coba lagi.',
    };
  }
}

/// Whether the frames of one attempt plausibly belong to one person.
///
/// Presence, not identity. Nothing here matches a face against another face —
/// that would be biometric processing this screen has no reason and no consent
/// to perform locally. What it watches is a gap: the sequence is scored across
/// many seconds, and if the camera loses the single face it was measuring for
/// long enough, the frames that come back may not be the same person's.
///
/// The attack it closes is cheap and otherwise unhandled: A performs the first
/// gesture, steps aside, B steps in and performs the second. The gesture machine
/// refuses a frame holding *two* faces, but two faces one after the other are
/// two frames of one face each. The server catches the substitution in the end —
/// the photograph is B's and is scored against A's enrolment — but by then this
/// app has already posted an attestation claiming a sequence that one person
/// completed, and that is evidence it must not manufacture.
///
/// A frame with more than one face also breaks continuity, because the largest-
/// face reduction upstream may have switched subjects between frames.
class PresenceContinuity {
  PresenceContinuity({this.gap = LivenessCapture.continuityGap});

  /// How long the single face may be missing before the run is abandoned.
  final Duration gap;

  DateTime? _lostAt;
  bool _broken = false;

  /// Whether the run has already lost continuity. Sticky: once the thread is
  /// broken it cannot be mended by the face coming back, because there is
  /// nothing here that could tell whose face came back.
  bool get broken => _broken;

  void offer(FaceSample sample, {required DateTime at}) {
    if (_broken) return;

    if (sample.hasFace && sample.faceCount == 1) {
      _lostAt = null;

      return;
    }

    _lostAt ??= at;

    if (at.difference(_lostAt!) >= gap) {
      _broken = true;
    }
  }
}

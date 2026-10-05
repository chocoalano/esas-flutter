import 'package:camera/camera.dart';
import 'package:esas/features/attendance/data/liveness/camera_input.dart';
import 'package:esas/features/attendance/data/liveness/liveness_capture.dart';
import 'package:esas/features/attendance/data/liveness/liveness_gestures.dart';
import 'package:flutter_test/flutter_test.dart';

/// The two platform facts that decide whether a gesture means what it says.
///
/// Neither is visible on a passing widget test and neither is visible on the
/// desk this was written at. They are the reason a liveness engine ported from
/// one platform to another needs its own file.
void main() {
  group('front-camera mirroring', () {
    test('iOS mirrors the streamed frames of the FRONT camera only', () {
      // `camera_avfoundation` sets `connection.isVideoMirrored = true` on the
      // video *data output* whenever the device is front-facing, and that
      // connection is what `startImageStream` reads.
      expect(
        CameraInput.mirrorsFor(isIOS: true, lens: CameraLensDirection.front),
        isTrue,
      );

      expect(
        CameraInput.mirrorsFor(isIOS: true, lens: CameraLensDirection.back),
        isFalse,
      );
    });

    test('Android mirrors nothing that reaches the detector', () {
      // `camera_android_camerax` hands over raw sensor frames; only the preview
      // widget flips them at draw time.
      for (final lens in CameraLensDirection.values) {
        expect(
          CameraInput.mirrorsFor(isIOS: false, lens: lens),
          isFalse,
          reason: '$lens',
        );
      }
    });
  });

  group('the yaw convention the catalogue is written against', () {
    // Positive `headEulerAngleY` is a face turning toward the right of the
    // IMAGE. The frames reaching the detector are unmirrored, so the image is
    // the view an observer standing at the phone would have — and somebody
    // turning to their own LEFT turns toward the right of that image.
    //
    // If this ever flips, `turn_left` and `turn_right` trade places: the person
    // following the instruction is refused and the person turning the wrong way
    // passes. On iOS that flip is real and is undone in `FaceSampler`; this test
    // pins the convention that undoing is measured against.
    FaceSample facing(double yaw) => FaceSample(
      atMs: 0,
      yaw: yaw,
      pitch: 0,
      leftEyeOpen: 0.9,
      rightEyeOpen: 0.9,
      smiling: 0.05,
      faceCount: 1,
    );

    void settle(LivenessGestureMachine machine) {
      for (var index = 0; index < 8; index++) {
        machine.offer(facing(0));
      }
    }

    test('turn_left is POSITIVE yaw', () {
      final machine = LivenessGestureMachine(actions: const ['turn_left']);
      settle(machine);

      machine.offer(facing(25));
      machine.offer(facing(26));

      expect(machine.passed, isTrue);
    });

    test('turn_right is NEGATIVE yaw', () {
      final machine = LivenessGestureMachine(actions: const ['turn_right']);
      settle(machine);

      machine.offer(facing(-25));
      machine.offer(facing(-26));

      expect(machine.passed, isTrue);
    });

    test('a mirrored reading fed in raw answers the WRONG gesture', () {
      // The defect this platform handling exists to prevent, demonstrated. On a
      // mirrored iOS frame somebody turning to their own left reads as negative
      // yaw — which is `turn_right`. Feeding it raw would refuse them.
      final asked = LivenessGestureMachine(actions: const ['turn_left']);
      settle(asked);

      // What an unmirrored iOS frame would report for "turn to your own left".
      const mirroredReading = -25.0;

      asked.offer(facing(mirroredReading));
      asked.offer(facing(mirroredReading - 1));

      expect(asked.passed, isFalse);

      // Negated — which is what `FaceSampler` does when the stream is mirrored —
      // the same movement is accepted.
      final corrected = LivenessGestureMachine(actions: const ['turn_left']);
      settle(corrected);

      corrected.offer(facing(-mirroredReading));
      corrected.offer(facing(-(mirroredReading - 1)));

      expect(corrected.passed, isTrue);
    });

    test('pitch, eyes and mouth are untouched by a horizontal mirror', () {
      // Stated as a test so a future "just negate everything" cannot pass. The
      // mirror is horizontal: pitch is unchanged, and `eyesOpen` takes the
      // larger of the two eyes, so the left/right eye swap cancels.
      final sample = FaceSample(
        atMs: 0,
        yaw: 20,
        pitch: 12,
        leftEyeOpen: 0.1,
        rightEyeOpen: 0.9,
        smiling: 0.4,
        faceCount: 1,
      );

      final swapped = FaceSample(
        atMs: 0,
        yaw: -20,
        pitch: 12,
        leftEyeOpen: 0.9,
        rightEyeOpen: 0.1,
        smiling: 0.4,
        faceCount: 1,
      );

      expect(swapped.pitch, sample.pitch);
      expect(swapped.eyesOpen, sample.eyesOpen);
      expect(swapped.smiling, sample.smiling);
    });
  });

  group('presence continuity', () {
    FaceSample face({int count = 1}) => FaceSample(
      atMs: 0,
      yaw: 0,
      pitch: 0,
      leftEyeOpen: 0.9,
      rightEyeOpen: 0.9,
      smiling: 0.05,
      faceCount: count,
    );

    final start = DateTime(2026, 9, 4, 8);

    test('one face, continuously, is continuous', () {
      final continuity = PresenceContinuity();

      for (var ms = 0; ms < 10000; ms += 100) {
        continuity.offer(face(), at: start.add(Duration(milliseconds: ms)));
      }

      expect(continuity.broken, isFalse);
    });

    test('a blink-length gap does not break it', () {
      // Somebody turning their head far enough to lose detection for a moment
      // is performing the gesture, not leaving.
      final continuity = PresenceContinuity();

      continuity.offer(face(), at: start);
      for (var ms = 100; ms <= 600; ms += 100) {
        continuity.offer(
          const FaceSample.noFace(0),
          at: start.add(Duration(milliseconds: ms)),
        );
      }
      continuity.offer(face(), at: start.add(const Duration(seconds: 1)));

      expect(continuity.broken, isFalse);
    });

    test('a gap long enough for a swap breaks it', () {
      final continuity = PresenceContinuity();

      continuity.offer(face(), at: start);
      continuity.offer(
        const FaceSample.noFace(0),
        at: start.add(const Duration(milliseconds: 100)),
      );
      continuity.offer(
        const FaceSample.noFace(0),
        at: start.add(const Duration(milliseconds: 1700)),
      );

      expect(continuity.broken, isTrue);
    });

    test('a second face in frame counts as lost presence', () {
      // The largest-face reduction upstream may have switched subjects between
      // frames, so a crowded frame is not a measurement of the same person.
      final continuity = PresenceContinuity();

      continuity.offer(face(), at: start);
      continuity.offer(
        face(count: 2),
        at: start.add(const Duration(seconds: 1)),
      );
      continuity.offer(
        face(count: 2),
        at: start.add(const Duration(seconds: 3)),
      );

      expect(continuity.broken, isTrue);
    });

    test('once broken it stays broken', () {
      // Sticky on purpose: nothing here can tell whose face came back, so a
      // returning face is not evidence the thread was mended.
      final continuity = PresenceContinuity();

      continuity.offer(face(), at: start);
      continuity.offer(
        const FaceSample.noFace(0),
        at: start.add(const Duration(seconds: 1)),
      );
      continuity.offer(
        const FaceSample.noFace(0),
        at: start.add(const Duration(seconds: 5)),
      );
      expect(continuity.broken, isTrue);

      continuity.offer(face(), at: start.add(const Duration(seconds: 6)));

      expect(continuity.broken, isTrue);
    });
  });
}

import 'package:esas/features/attendance/data/liveness/liveness_gestures.dart';
import 'package:flutter_test/flutter_test.dart';

/// The liveness decision itself.
///
/// This is where a face attempt is judged, and it is pure Dart precisely so it
/// can be judged here rather than only on a handset. What it proves is narrow
/// and worth stating exactly: a **photograph held up to the lens cannot pass**,
/// because every movement is an excursion from the person's own measured resting
/// pose and a still image has one pose; a **bystander cannot answer on somebody
/// else's behalf**, because a frame with two faces is not scored at all; and the
/// movements must arrive **in the order the server drew them**.
///
/// What it cannot prove is that a rewritten build did not fabricate the whole
/// block. That is the server's problem, and the server solves it by drawing the
/// challenge, signing it, binding it to one person and spending it once.
void main() {
  /// A frame with a face in it, resting unless told otherwise.
  FaceSample sample({
    int atMs = 0,
    double yaw = 0,
    double pitch = 0,
    double eyes = 0.9,
    double smile = 0.05,
    int faces = 1,
  }) => FaceSample(
    atMs: atMs,
    yaw: yaw,
    pitch: pitch,
    leftEyeOpen: eyes,
    rightEyeOpen: eyes,
    smiling: smile,
    faceCount: faces,
  );

  /// Feed [count] resting frames, which is how a baseline is measured.
  void settle(LivenessGestureMachine machine, {int count = 8}) {
    for (var index = 0; index < count; index++) {
      machine.offer(sample(atMs: index * 100));
    }
  }

  group('the resting pose is measured before anything is scored', () {
    test('eight face-bearing frames move it out of the baseline phase', () {
      final machine = LivenessGestureMachine(actions: const ['turn_left']);

      expect(machine.phase, GesturePhase.baseline);
      settle(machine);
      expect(machine.phase, GesturePhase.performing);
      expect(machine.baselineRefusal, isNull);
    });

    test('frames with no face build nothing', () {
      final machine = LivenessGestureMachine(actions: const ['turn_left']);

      for (var index = 0; index < 20; index++) {
        machine.offer(FaceSample.noFace(index * 100));
      }

      expect(machine.phase, GesturePhase.baseline);
      expect(machine.baselineProgress, 0);
    });

    test('a frame with two faces in it builds nothing either', () {
      // The largest-face reduction upstream may have picked the other one, so
      // the reading can belong to somebody walking past behind them — and every
      // movement in the attempt would then be scored against a stranger's rest.
      final machine = LivenessGestureMachine(actions: const ['turn_left']);

      for (var index = 0; index < 20; index++) {
        machine.offer(sample(atMs: index * 100, faces: 2));
      }

      expect(machine.phase, GesturePhase.baseline);
    });

    test('a saturated axis is refused, and refused early', () {
      // Somebody already smiling broadly has no room left to smile *more*: they
      // would have to produce a probability above one. Said in a second and a
      // half, rather than after thirty seconds of being told to try harder at
      // something that is not on the number line.
      final machine = LivenessGestureMachine(actions: const ['smile']);

      for (var index = 0; index < 40; index++) {
        machine.offer(sample(atMs: index * 100, smile: 0.97));
      }

      expect(machine.baselineRefusal, 'axis_saturated');
      expect(machine.phase, GesturePhase.done);
      expect(machine.passed, isFalse);
    });
  });

  group('a movement is accepted only when it is actually performed', () {
    test('a held turn passes, and is recorded with what was measured', () {
      final machine = LivenessGestureMachine(actions: const ['turn_left']);
      settle(machine);

      // One frame is a detector wobble; two in a row is a movement somebody
      // made.
      machine.offer(sample(atMs: 900, yaw: 22));
      expect(machine.isComplete, isFalse);
      machine.offer(sample(atMs: 1000, yaw: 23));

      expect(machine.passed, isTrue);
      expect(machine.evidence.single.action, 'turn_left');
      expect(machine.evidence.single.performed, isTrue);
      expect(machine.evidence.single.measured, closeTo(23, 0.01));
      expect(machine.evidence.single.baseline, closeTo(0, 0.01));
    });

    test('a still image never travels, so it never passes', () {
      // The whole of what a photograph cannot do. Its reading is the same on
      // every frame, so its excursion from its own baseline is zero on every
      // axis, whatever the picture shows.
      final machine = LivenessGestureMachine(actions: const ['turn_left']);
      settle(machine);

      for (var index = 0; index < 100; index++) {
        machine.offer(sample(atMs: 900 + index * 100, yaw: 0));
      }

      expect(machine.passed, isFalse);
      expect(machine.currentProgress, 0);
    });

    test('a photograph tilted a long way still fails its anchor', () {
      // A printed photograph is "turned" by tilting the paper, so the size of
      // the excursion was never what defended this. Turning the wrong way is
      // refused outright.
      final machine = LivenessGestureMachine(actions: const ['turn_left']);
      settle(machine);

      for (var index = 0; index < 20; index++) {
        // turn_left wants positive yaw; this is the other way.
        machine.offer(sample(atMs: 900 + index * 100, yaw: -40));
      }

      expect(machine.passed, isFalse);
    });

    test('a frame with a bystander in it is not scored', () {
      final machine = LivenessGestureMachine(actions: const ['turn_left']);
      settle(machine);

      for (var index = 0; index < 20; index++) {
        machine.offer(sample(atMs: 900 + index * 100, yaw: 30, faces: 2));
      }

      expect(machine.passed, isFalse);
    });

    test('progress fills as the movement travels, and never overstates it', () {
      // A movement is scored against a threshold nobody can see. The bar is the
      // only thing that tells somebody turning fifteen degrees when twenty are
      // wanted which way to correct.
      final machine = LivenessGestureMachine(actions: const ['turn_left']);
      settle(machine);

      machine.offer(sample(atMs: 900, yaw: 2));
      final little = machine.currentProgress;

      machine.offer(sample(atMs: 1000, yaw: 10));
      final more = machine.currentProgress;

      expect(little, lessThan(more));
      expect(more, lessThan(1));
    });
  });

  group('the order the server drew is the order that is required', () {
    test('answering the second movement first does not pass the first', () {
      final machine = LivenessGestureMachine(
        actions: const ['turn_left', 'blink'],
      );
      settle(machine);

      // Blinking while a turn is being asked for.
      for (var index = 0; index < 10; index++) {
        machine.offer(sample(atMs: 900 + index * 100, eyes: 0.02));
      }

      expect(machine.currentIndex, 0);
      expect(machine.current?.action, 'turn_left');
      expect(machine.passed, isFalse);
    });

    test('both, in order, passes', () {
      final machine = LivenessGestureMachine(
        actions: const ['turn_left', 'blink'],
      );
      settle(machine);

      machine.offer(sample(atMs: 900, yaw: 25));
      machine.offer(sample(atMs: 1000, yaw: 26));
      machine.offer(sample(atMs: 1100, eyes: 0.02));
      machine.offer(sample(atMs: 1200, eyes: 0.03));

      expect(machine.passed, isTrue);
      expect(machine.evidence.map((item) => item.action), [
        'turn_left',
        'blink',
      ]);
    });
  });

  group('a movement this build has never heard of is refused, not skipped', () {
    test('it is named rather than silently dropped', () {
      // Skipping it would report a complete answer to a challenge only half
      // performed — and the server, which cannot see the difference, would take
      // the app's word for it.
      final machine = LivenessGestureMachine(
        actions: const ['turn_left', 'wiggle_ears'],
      );

      expect(machine.unknownActions, ['wiggle_ears']);
    });
  });

  group('the evidence posted with the capture', () {
    test('names the detector, the elapsed time and every movement', () {
      final machine = LivenessGestureMachine(actions: const ['blink']);
      settle(machine);
      machine.offer(sample(atMs: 900, eyes: 0.02));
      machine.offer(sample(atMs: 1000, eyes: 0.02));

      final evidence = machine.toEvidenceJson(elapsedMs: 4200);

      expect(evidence['detector'], 'google_mlkit_face_detection');
      expect(evidence['elapsed_ms'], 4200);
      expect(evidence['frames_scored'], greaterThan(0));

      final actions = evidence['actions']! as List<dynamic>;

      expect(actions, hasLength(1));
      expect((actions.first as Map)['action'], 'blink');
      expect((actions.first as Map)['performed'], isTrue);
    });

    test('a timed-out movement is recorded as not performed, with why', () {
      // "You did not move" and "the camera never saw you move" look identical on
      // screen and are opposite in meaning. Told apart, so a disputed refusal
      // has something to be disputed with.
      final machine = LivenessGestureMachine(actions: const ['turn_left']);
      settle(machine);
      machine.offer(sample(atMs: 900, yaw: 3));
      machine.timeout();

      final entry =
          (machine.toEvidenceJson(elapsedMs: 30000)['actions']! as List).first
              as Map;

      expect(entry['performed'], isFalse);
      expect(entry['reason'], 'not_detected');
    });

    test('an axis that never produced a reading says so, and differently', () {
      final machine = LivenessGestureMachine(actions: const ['turn_left']);
      settle(machine);

      // A face in frame, but the detector returns nothing for yaw.
      for (var index = 0; index < 5; index++) {
        machine.offer(
          FaceSample(
            atMs: 900 + index * 100,
            leftEyeOpen: 0.9,
            rightEyeOpen: 0.9,
            smiling: 0.05,
            faceCount: 1,
          ),
        );
      }

      machine.timeout();

      final entry =
          (machine.toEvidenceJson(elapsedMs: 30000)['actions']! as List).first
              as Map;

      expect(entry['reason'], 'signal_unavailable');
    });
  });

  group('the shutter waits for the face to come back to centre', () {
    test('a still-turned head is not at rest', () {
      // The machine accepts a movement two frames into the excursion, so at that
      // instant the head may still be turned twenty degrees. Photographing that
      // hands the server a profile to compare against five forward-facing
      // enrolment photographs.
      final machine = LivenessGestureMachine(actions: const ['turn_left']);
      settle(machine);
      machine.offer(sample(atMs: 900, yaw: 25));
      machine.offer(sample(atMs: 1000, yaw: 26));

      expect(machine.atRest(sample(yaw: 26)), isFalse);
      expect(machine.atRest(sample(yaw: 1)), isTrue);
    });

    test('a frame with two faces is never at rest', () {
      final machine = LivenessGestureMachine(actions: const ['turn_left']);
      settle(machine);

      expect(machine.atRest(sample(faces: 2)), isFalse);
    });
  });
}

import 'package:esas/core/boot/boot_pipeline.dart';
import 'package:flutter_test/flutter_test.dart';

/// The boot failure policy (rule §36 / P2-2).
///
/// The pipeline this replaces classified nothing: Firebase was wrapped in a
/// `try/catch` that only printed, and every other step ran unguarded.
void main() {
  group('required steps', () {
    test('returns the value on success and records nothing', () async {
      final pipeline = BootPipeline();

      final value = await pipeline.required('storage', () async => 42);

      expect(value, 42);
      expect(pipeline.report.failures, isEmpty);
      expect(pipeline.report.isUsable, isTrue);
    });

    test('records the failure and rethrows', () async {
      // There is no useful app to show without storage, and swallowing the
      // error would produce a blank screen with no cause.
      final pipeline = BootPipeline();

      await expectLater(
        pipeline.required<void>(
          'storage',
          () async => throw StateError('disk'),
        ),
        throwsA(isA<StateError>()),
      );

      expect(pipeline.report.isUsable, isFalse);
      expect(pipeline.report.fatalFailure?.step, 'storage');
      expect(pipeline.report.fatalFailure?.severity, BootSeverity.fatal);
    });
  });

  group('optional steps', () {
    test('reports success', () async {
      final pipeline = BootPipeline();

      expect(await pipeline.optional('firebase', () async {}), isTrue);
      expect(pipeline.report.isDegraded, isFalse);
    });

    test('swallows the failure and keeps the app usable', () async {
      // ESAS is an ERP. Attendance, permits and payslips do not need push, so a
      // Firebase outage must not be fatal.
      final pipeline = BootPipeline();

      final ok = await pipeline.optional(
        'firebase',
        () async => throw Exception('no network'),
      );

      expect(ok, isFalse);
      expect(pipeline.report.isUsable, isTrue);
      expect(pipeline.report.isDegraded, isTrue);
      expect(pipeline.report.failed('firebase'), isTrue);
    });

    test('lets the caller skip work that depended on it', () async {
      // Registering the messaging service on top of a Firebase that never came
      // up would only move the crash to the first message.
      final pipeline = BootPipeline();
      var messagingRegistered = false;

      final hasFirebase = await pipeline.optional(
        'firebase',
        () async => throw Exception('no network'),
      );

      if (hasFirebase) {
        messagingRegistered = true;
      }

      expect(messagingRegistered, isFalse);
    });
  });

  group('the report', () {
    test('separates degraded from unusable', () async {
      final pipeline = BootPipeline();

      await pipeline.optional('firebase', () async => throw Exception('x'));
      await pipeline.optional(
        'notifications',
        () async => throw Exception('y'),
      );

      final report = pipeline.report;

      // Two features are gone; the app is not.
      expect(report.isDegraded, isTrue);
      expect(report.isUsable, isTrue);
      expect(report.failures, hasLength(2));
      expect(report.fatalFailure, isNull);
    });

    test('names the steps that failed, for the log line', () async {
      final pipeline = BootPipeline();

      await pipeline.optional('firebase', () async => throw Exception('x'));

      expect(
        pipeline.report.failures.map((f) => f.step).join(', '),
        'firebase',
      );
      expect(pipeline.report.failed('storage'), isFalse);
    });

    test('is unmodifiable, so a report cannot be edited after boot', () {
      final report = BootPipeline().report;

      expect(
        () => report.failures.add(
          const BootFailure('x', BootSeverity.fatal, 'e'),
        ),
        throwsUnsupportedError,
      );
    });
  });
}

import '../utils/app_logger.dart';

/// How much a boot step failing actually matters.
enum BootSeverity {
  /// The app cannot function. Nothing after this is worth attempting.
  fatal,

  /// A feature degrades; the rest of the app is fine.
  optional,
}

/// A boot step that did not succeed.
class BootFailure {
  const BootFailure(this.step, this.severity, this.error, [this.stackTrace]);

  final String step;
  final BootSeverity severity;
  final Object error;
  final StackTrace? stackTrace;

  @override
  String toString() => '$step (${severity.name}): $error';
}

/// What happened during boot.
class BootReport {
  BootReport(this.failures);

  final List<BootFailure> failures;

  /// The app started, but something optional did not.
  ///
  /// Push notifications are the case this exists for: ESAS is an ERP and its
  /// core — attendance, permits, payslips — works without them.
  bool get isDegraded =>
      failures.any((f) => f.severity == BootSeverity.optional);

  BootFailure? get fatalFailure {
    for (final failure in failures) {
      if (failure.severity == BootSeverity.fatal) {
        return failure;
      }
    }

    return null;
  }

  bool get isUsable => fatalFailure == null;

  bool failed(String step) => failures.any((f) => f.step == step);
}

/// Runs boot steps and decides what a failure means.
///
/// The pipeline it replaces did none of this. `main()` wrapped Firebase in a
/// `try/catch` that only `debugPrint`ed, and left every other step unguarded —
/// so a Firebase outage was silently indistinguishable from a success, while a
/// failure in `GetStorage.init()` would have taken the app down with an
/// unhandled exception on the first frame and no explanation.
///
/// Classifying each step is the point. Rule §36: a bootstrap must know which of
/// its failures are fatal, which are recoverable, and which are optional.
class BootPipeline {
  BootPipeline();

  final List<BootFailure> _failures = [];

  BootReport get report => BootReport(List.unmodifiable(_failures));

  /// Run a step the app cannot start without.
  ///
  /// Records the failure and rethrows: there is no useful app to show, and
  /// swallowing it would produce a blank screen with no cause.
  Future<T> required<T>(String step, Future<T> Function() run) async {
    try {
      return await run();
    } catch (error, stackTrace) {
      _failures.add(BootFailure(step, BootSeverity.fatal, error, stackTrace));
      AppLogger.error('Boot step "$step" failed fatally', error: error);
      rethrow;
    }
  }

  /// Run a step whose failure costs one feature, not the app.
  ///
  /// Returns whether it succeeded, so a caller can skip work that depended on
  /// it — registering a messaging service on top of a Firebase that never
  /// initialised would only move the crash later.
  Future<bool> optional(String step, Future<void> Function() run) async {
    try {
      await run();
      return true;
    } catch (error, stackTrace) {
      _failures.add(
        BootFailure(step, BootSeverity.optional, error, stackTrace),
      );
      AppLogger.warning('Boot step "$step" failed; continuing without it.');
      AppLogger.error(
        'Boot step "$step"',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }
}

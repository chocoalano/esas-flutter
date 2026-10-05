import 'package:flutter/foundation.dart';

import '../../../../core/utils/json_parsers.dart';

/// One movement the person has to perform on camera, and the sentence that asks
/// for it.
class ChallengeAction {
  const ChallengeAction({required this.action, required this.instruction});

  /// Machine-readable code: `turn_left`, `blink`, and so on. Matched against
  /// `kGestureCatalogue`; one this build has never heard of is refused rather
  /// than skipped.
  final String action;

  /// The sentence, already written for the person and already in Indonesian.
  ///
  /// Shown as it arrives. The server decides the wording, so a new movement
  /// never needs an app release to be explainable — which is also why the UI
  /// must not invent instructions of its own.
  final String instruction;

  static ChallengeAction? fromJson(Object? raw) {
    final data = asObject(raw);
    final action = asString(data['action']);

    if (action == null) return null;

    return ChallengeAction(
      action: action,
      instruction: asString(data['instruction']) ?? '',
    );
  }
}

/// A short, random, signed set of movements, valid for a couple of minutes.
///
/// The randomness is the whole of what the check rests on. A fixed sequence —
/// blink, then smile, every time — is answered perfectly by two photographs held
/// up to the lens. Nobody can prepare for a list they are only handed once they
/// have asked to clock.
///
/// The token is opaque here and goes back untouched. It is signed by the server
/// with the server's own key, bound to this person and this direction, and spent
/// exactly once against a unique index.
class LivenessChallenge {
  LivenessChallenge({
    required this.challengeId,
    required this.token,
    required this.actions,
    required this.ttlSeconds,
    this.expiresAt,
    @visibleForTesting Stopwatch? age,
  }) : _age = (age ?? Stopwatch())..start();

  final String challengeId;

  /// Signed by the server and returned with the capture. Opaque to this app.
  final String token;

  final List<ChallengeAction> actions;

  /// The server's own deadline, kept for reference. **Not** what expiry is
  /// judged against — see [hasExpired].
  final DateTime? expiresAt;

  final int ttlSeconds;

  /// Age since this challenge arrived, measured monotonically.
  final Stopwatch _age;

  /// Whether this challenge has outlived the window the server gave it.
  ///
  /// Measured as elapsed time since it arrived rather than against the server's
  /// absolute deadline, and the difference is a handset that cannot clock
  /// anybody in. A phone whose clock runs three minutes fast would declare every
  /// challenge expired the instant it arrived — permanently, for that person,
  /// with the screen blaming the challenge. Elapsed time is immune to an offset;
  /// only the *rate* would have to be wrong.
  ///
  /// A [Stopwatch] rather than two `DateTime.now()` readings, because a network
  /// time correction landing mid-attempt jumps the wall clock and would expire a
  /// challenge somebody was halfway through answering.
  ///
  /// Fails open when the server named no lifetime: a zero here used to mean
  /// every challenge read as already dead.
  bool get hasExpired => ttlSeconds > 0 && _age.elapsed.inSeconds >= ttlSeconds;

  /// How much of the window is left, 0..1, for a progress hint. `null` when the
  /// server named no lifetime.
  double? get remainingFraction {
    if (ttlSeconds <= 0) return null;

    final left = ttlSeconds - _age.elapsed.inSeconds;

    return left <= 0 ? 0 : (left / ttlSeconds).clamp(0.0, 1.0);
  }

  static LivenessChallenge fromJson(
    Map<String, dynamic> json, {
    @visibleForTesting Stopwatch? age,
  }) {
    return LivenessChallenge(
      age: age,
      challengeId: asString(json['challenge_id']) ?? '',
      token: asString(json['token']) ?? '',
      actions: _actionsOf(json['actions']),
      ttlSeconds: asInt(json['ttl_seconds']) ?? 0,
      expiresAt: _timestamp(json['expires_at']),
    );
  }

  /// Read the actions, whatever shape they arrive in.
  ///
  /// Tested rather than cast, and the difference is a screen that never ends. A
  /// cast throws `TypeError`, which is not an `Exception` and so is caught by
  /// nothing: a server sending `actions` as a list of bare codes would leave the
  /// camera sitting on "Meminta tantangan…" with no message and nothing to
  /// press.
  ///
  /// An entry that is not an object is dropped rather than guessed at. A
  /// challenge that arrives short is then refused by the machine — which checks
  /// the catalogue knows every movement it was given — and that is the right
  /// outcome said out loud, instead of a crash.
  static List<ChallengeAction> _actionsOf(Object? value) {
    if (value is! List) return const <ChallengeAction>[];

    return value
        .map(ChallengeAction.fromJson)
        .whereType<ChallengeAction>()
        .toList(growable: false);
  }

  /// `expires_at` has been sent both as epoch seconds and as ISO-8601.
  static DateTime? _timestamp(Object? value) {
    final seconds = asInt(value);

    if (seconds != null) {
      return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
    }

    return asDate(value);
  }
}

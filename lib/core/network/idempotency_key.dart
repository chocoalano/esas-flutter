import 'dart:math';

/// Names one attempt at a write, so a retry is answered rather than repeated.
///
/// The server requires an `Idempotency-Key` on the writes where a duplicate
/// costs something — raising leave, answering an approval — and replies to a
/// repeat with the first response instead of filing a second record.
///
/// The problem it solves is not a double tap; a disabled button fixes that. It
/// is the retry a client *must* make when a reply is lost in transit: a handset
/// on a train cannot tell "never arrived" from "arrived, answer lost", and
/// without a key the safe thing to do and the wrong thing to do are the same
/// request.
///
/// **A key belongs to an attempt, not to a call.** A caller that mints a fresh
/// one on every send has an app that talks to the endpoint correctly and gets
/// none of the protection. Whoever owns "the user asked for this once" — a
/// controller holding a submit action — should mint one and pass the same value
/// through every retry of it.
class IdempotencyKey {
  const IdempotencyKey._();

  static const String header = 'Idempotency-Key';

  static final Random _random = Random.secure();

  /// A fresh key. Random rather than derived from the payload: two genuinely
  /// separate requests that happen to be identical — the same half day booked
  /// twice by mistake, then deliberately — must not collide.
  static String mint() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));

    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// The header map for a key, or an empty map for none.
  static Map<String, String> headerFor(String? key) =>
      key == null ? const {} : {header: key};
}

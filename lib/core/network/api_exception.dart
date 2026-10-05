/// What went wrong talking to the server.
///
/// One type for every failure — a refusal, a timeout, a dead socket — because
/// three duplicated `switch (statusCode)` blocks in three controllers is how the
/// app ended up telling the user three different things about the same 401
/// (MED-07).
///
/// The exception carries facts: the status, the server's own message, the field
/// errors. It does **not** carry a decision about how to show them. Infrastructure
/// that raises this must not present it — the controller decides, and may
/// override [message] where a screen has a better sentence than the default.
class ApiException implements Exception {
  const ApiException(
    this.message, {
    this.status,
    this.code,
    this.errors = const {},
    this.body = const {},
  });

  /// A sentence in Indonesian, safe to show as-is when a screen has nothing
  /// more specific to say.
  final String message;

  /// The HTTP status, or null when the request never reached a server.
  final int? status;

  /// The server's own machine-readable code, where it sends one.
  final String? code;

  /// Field name to the first message for it, from a 422.
  final Map<String, String> errors;

  /// The decoded response body, verbatim.
  ///
  /// Kept because a refusal often carries structure beyond a sentence and a
  /// code, and dropping it means every caller that needs one of those fields has
  /// to re-request something the server already said. Face verification is the
  /// case that proved it: its 422 carries a `verification` block whose
  /// `score_percent` is the only thing that tells "the photograph was unusable"
  /// apart from "the match was close", and without it the two look identical
  /// from the outside.
  ///
  /// Empty when the server answered with something that was not a JSON object.
  final Map<String, dynamic> body;

  /// The session is gone and the app must sign out.
  ///
  /// Only 401. A 403 means this account may not do this *thing* — signing them
  /// out for it would eject a user who is perfectly well authenticated (R-07).
  bool get isUnauthenticated => status == 401;

  /// This account is authenticated but not permitted.
  bool get isForbidden => status == 403;

  /// The request never got an answer. Distinguished from a refusal because the
  /// two deserve opposite responses: a refusal is the server's verdict, a
  /// transport failure is a reason to keep what we have and retry (HIGH-02).
  bool get isTransportFailure => status == null;

  bool get isValidationFailure => status == 422;

  /// The first field error, for a form that shows one message at a time.
  String? get firstFieldError => errors.isEmpty ? null : errors.values.first;

  @override
  String toString() =>
      'ApiException($status${code == null ? '' : ' $code'}): $message';
}

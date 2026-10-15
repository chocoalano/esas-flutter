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

  /// No HTTP status was available. This can also describe a decoding failure.
  bool get isTransportFailure => status == null;

  /// The app could not maintain its required connection to the server.
  bool get isConnectionFailure =>
      status == null &&
      const {
        'network_unreachable',
        'timeout',
        'transport_failure',
      }.contains(code);

  bool get isValidationFailure => status == 422;

  /// The workspace refuses every request for now (423): suspended by the
  /// platform, not active yet, or its subscription cancelled.
  ///
  /// Not a session problem. The token stays valid and works again the moment
  /// the workspace is operational, so this never signs anybody out - and it is
  /// the server's verdict, not a network blip, so nothing retries it on a
  /// timer.
  bool get isWorkspaceUnavailable => status == 423;

  /// Which of those three, read from the server's [code]; null unless this is
  /// a 423.
  WorkspaceUnavailability? get workspaceUnavailability =>
      isWorkspaceUnavailable ? WorkspaceUnavailability.fromCode(code) : null;

  /// The first field error, for a form that shows one message at a time.
  String? get firstFieldError => errors.isEmpty ? null : errors.values.first;

  @override
  String toString() =>
      'ApiException($status${code == null ? '' : ' $code'}): $message';
}

/// Why a workspace answered 423, as the server's machine-readable `code` says.
///
/// The server sends the sentence too (`message`, in Indonesian), and that is
/// what a screen shows; this is for choosing a title or an icon without matching
/// words.
enum WorkspaceUnavailability {
  /// `tenant_activation_pending`: set up, but its HRMS subscription has not
  /// started yet.
  activationPending,

  /// `tenant_subscription_cancelled`: its subscription ended. Data is kept.
  subscriptionCancelled,

  /// `tenant_suspended`: suspended by the platform administrator.
  suspended;

  /// A 423 without a code this app knows is read as a suspension: before the
  /// other two existed it was the only reason a workspace answered 423.
  static WorkspaceUnavailability fromCode(String? code) => switch (code) {
    'tenant_activation_pending' => activationPending,
    'tenant_subscription_cancelled' => subscriptionCancelled,
    _ => suspended,
  };
}

import '../../../../core/config/api_routes.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/idempotency_key.dart';
import '../../../../core/network/upload.dart';

class PermitApiService {
  const PermitApiService(this._client);

  final ApiClient _client;

  /// The kinds of leave this workspace lets a handset raise.
  ///
  /// Answers `{permit_types, curated}`. `curated` is false when nobody has
  /// marked any type for mobile, in which case the list is everything rather
  /// than nothing - the reference schema defaults that flag off, and honouring
  /// it blindly would give an adopted workspace an app that can request nothing.
  Future<Map<String, dynamic>> leaveTypes() =>
      _client.getObject(ApiRoutes.permitTypes);

  /// This person's own requests, or one kind of them.
  ///
  /// `?type=` replaces the old `/permits/list/{typeId}` path segment, and
  /// `inbox` asks the other question: what is waiting on *this* person's
  /// decision rather than what they asked for.
  Future<Map<String, dynamic>> list({
    Object? typeId,
    required int page,
    required int perPage,
    bool inbox = false,
  }) {
    return _client.getObject(
      ApiRoutes.permits,
      query: {
        'page': page,
        'per_page': perPage,
        if (typeId != null) 'type': typeId,
        if (inbox) 'inbox': 1,
      },
    );
  }

  Future<Map<String, dynamic>> detail(Object id) =>
      _client.getObject(ApiRoutes.permit(id));

  /// The form's reference data: this person's roster rows and the shifts a swap
  /// may name.
  ///
  /// Takes no company, department or employee. All three used to be sent and all
  /// three are the token's - a form that asks the phone whose roster to draw is
  /// a form that can be asked for somebody else's.
  ///
  /// The permit number is not here either. It used to be handed to the form and
  /// typed back in, which meant two requests could share one and a typo was
  /// silent; the server mints it now.
  Future<Map<String, dynamic>> form({String? from, String? to}) {
    return _client.getObject(
      ApiRoutes.permitForm,
      query: {if (from != null) 'from': from, if (to != null) 'to': to},
    );
  }

  /// Raise a request.
  ///
  /// Requires an `Idempotency-Key`, and the caller should hold one across
  /// retries rather than let this mint a fresh one each time: a leave request
  /// sent twice because a reply was lost in transit is two requests, two numbers
  /// and two approval chains, and somebody in HR finds both.
  Future<Map<String, dynamic>> create(
    Map<String, dynamic> fields, {
    Upload? attachment,
    String? idempotencyKey,
  }) {
    return _client.postForm(
      ApiRoutes.permits,
      fields,
      files: {if (attachment != null) 'file': attachment},
      headers: IdempotencyKey.headerFor(
        idempotencyKey ?? IdempotencyKey.mint(),
      ),
    );
  }

  /// Answer a request you were asked about.
  ///
  /// **POST**, and there is no `approval_id`. Which tier is being answered is
  /// the server's to decide from the chain: answering out of turn is refused
  /// with `permit_not_your_turn` rather than recorded, because a chain answered
  /// in any order is not a chain - it is three independent opinions.
  ///
  /// A rejection must carry a reason. One without is refused with
  /// `permit_rejection_needs_reason`, because a refusal the person it lands on
  /// cannot act on is not a decision.
  Future<Map<String, dynamic>> approve({
    required Object permitId,
    required bool approve,
    String? notes,
    String? idempotencyKey,
  }) {
    return _client.postObject(
      ApiRoutes.permitApproval(permitId),
      {
        'decision': approve ? 'y' : 'n',
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
      headers: IdempotencyKey.headerFor(
        idempotencyKey ?? IdempotencyKey.mint(),
      ),
    );
  }
}

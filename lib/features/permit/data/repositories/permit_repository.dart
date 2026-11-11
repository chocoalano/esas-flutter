import 'dart:typed_data';

import '../../../../core/network/upload.dart';
import '../../../../core/utils/json_parsers.dart';
import '../../../../features/auth/data/repositories/session_repository.dart';
import '../models/leave_list.dart';
import '../models/leave_type.dart';
import '../models/schedule.dart';
import '../models/timework.dart';
import '../services/permit_api_service.dart';

/// The reference data the create-permit form needs before it can be filled in.
///
/// The permit number is gone. It used to be handed to the form and typed back
/// in, which meant two requests could share one and a typo was silent; the
/// server mints it on submission now, and a field the form cannot influence has
/// no business being fetched for it.
class PermitFormData {
  const PermitFormData({
    this.schedules = const [],
    this.shifts = const [],
    this.from,
    this.to,
  });

  final List<Schedule> schedules;
  final List<Timework> shifts;

  /// Jendela roster yang dijawab server, dan itulah kebijakan tanggal formulir
  /// ini.
  ///
  /// Bukan angka yang dikarang klien. `GET /permits/form` memulangkan roster
  /// dari `from` sampai `to` — bawaannya hari ini sampai 30 hari ke depan,
  /// dibatasi 90 — dan `POST /permits` menolak dengan `permit_no_schedule`
  /// tanggal yang tidak punya baris roster. Pemilih tanggal yang membiarkan
  /// orang memilih tahun 2001 hanya menunda penolakan itu sampai setelah
  /// formulir dikirim.
  final DateTime? from;
  final DateTime? to;
}

class PermitRepository {
  const PermitRepository({
    required PermitApiService api,
    required SessionRepository session,
  }) : _api = api,
       _session = session;

  final PermitApiService _api;
  final SessionRepository _session;

  int? get currentUserId => _session.user?.id;

  /// The kinds of leave this handset may raise.
  ///
  /// Not a paginator: the answer is `{permit_types, curated}`, and the list is
  /// short by construction.
  Future<List<LeaveType>> leaveTypes() async {
    final body = await _api.leaveTypes();

    return asModelList(body['permit_types'], LeaveType.fromJson);
  }

  Future<List<Permit>> list({
    Object? typeId,
    required int page,
    required int perPage,
    bool inbox = false,
  }) async {
    final body = await _api.list(
      typeId: typeId,
      page: page,
      perPage: perPage,
      inbox: inbox,
    );

    return asModelList(asPage(body), Permit.fromJson);
  }

  /// One request, with the chain as it stands.
  ///
  /// The envelope is `permit`. Reading `data` — the retired backend's name —
  /// found nothing, fell through to the whole body, and handed `Permit.fromJson`
  /// a map whose keys were all one level too high: every field came back as its
  /// default and the screen drew a request numbered zero.
  Future<Permit?> detail(Object id) async {
    final body = await _api.detail(id);
    final payload = asObject(body['permit']);

    return payload.isEmpty ? null : Permit.fromJson(payload);
  }

  /// Load the form's reference data.
  ///
  /// No longer returns null for an incomplete cached user. It used to need the
  /// company, department and employee id off the session to ask at all, so
  /// somebody whose cached record was missing one of them met a form that would
  /// not open. The server reads all three off the token now, and the client has
  /// nothing left to be missing.
  Future<PermitFormData> formData({String? from, String? to}) async {
    final body = await _api.form(from: from, to: to);

    return PermitFormData(
      schedules: asModelList(body['schedules'], Schedule.fromJson),
      shifts: asModelList(body['shifts'], Timework.fromJson),
      from: asDate(body['from']),
      to: asDate(body['to']),
    );
  }

  /// Submit a new permit.
  ///
  /// The company, department and employee that used to be posted alongside the
  /// fields are gone: every one of them was the token's, and a request that
  /// names its own author is a request somebody can author for a colleague.
  Future<bool> create({
    required Map<String, dynamic> fields,
    Upload? attachment,
    String? idempotencyKey,
  }) async {
    await _api.create(
      fields,
      attachment: attachment,
      idempotencyKey: idempotencyKey,
    );

    return true;
  }

  /// Answer a request.
  ///
  /// No `approvalId`. Which tier is being answered is the server's to decide
  /// from the chain, and answering out of turn is refused rather than recorded.
  Future<void> approve({
    required Object permitId,
    required bool approve,
    String? notes,
    String? idempotencyKey,
  }) {
    return _api.approve(
      permitId: permitId,
      approve: approve,
      notes: notes,
      idempotencyKey: idempotencyKey,
    );
  }

  /// A permit's attachment, downloaded with the session (PRMT-03).
  ///
  /// The file is private to the tenant; there is no public address for it.
  Future<PermitAttachment> attachment({
    required Object permitId,
    required String file,
  }) async {
    final bytes = await _api.attachment(permitId);
    final name = file.split('/').where((part) => part.isNotEmpty).lastOrNull;

    return PermitAttachment(
      filename: name ?? 'lampiran-$permitId',
      bytes: bytes,
    );
  }
}

/// A downloaded attachment. Held in memory: nothing is written to disk unless
/// the person chooses to save it.
class PermitAttachment {
  const PermitAttachment({required this.filename, required this.bytes});

  final String filename;
  final Uint8List bytes;

  /// Whether the bytes are a photograph, by their signature rather than by
  /// a file name the server may not have kept.
  bool get isImage {
    bool startsWith(List<int> magic) =>
        bytes.length >= magic.length &&
        Iterable.generate(magic.length).every((i) => bytes[i] == magic[i]);

    return startsWith(const [0xff, 0xd8, 0xff]) || // JPEG
        startsWith(const [0x89, 0x50, 0x4e, 0x47]) || // PNG
        startsWith(const [0x47, 0x49, 0x46, 0x38]) || // GIF
        (startsWith(const [0x52, 0x49, 0x46, 0x46]) &&
            bytes.length > 11 &&
            bytes[8] == 0x57 &&
            bytes[9] == 0x45 &&
            bytes[10] == 0x42 &&
            bytes[11] == 0x50); // WEBP
  }
}

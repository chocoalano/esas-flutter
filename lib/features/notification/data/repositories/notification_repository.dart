import '../../../../core/utils/json_parsers.dart';
import '../models/notification.dart';
import '../services/notification_api_service.dart';

/// Satu halaman notifikasi, beserta jumlah yang belum dibaca.
///
/// Sebelumnya `page()` hanya mengembalikan barisnya dan membuang sisa amplop,
/// sehingga satu-satunya cara menghitung yang belum dibaca adalah menghitung
/// baris yang kebetulan sudah termuat — kotak masuk dengan tiga puluh belum
/// dibaca mengumumkan sepuluh sampai orangnya menggulir. Angka itu sudah
/// dikirim server di setiap respons; ia hanya tidak pernah sampai ke layar.
class NotificationPage {
  const NotificationPage({required this.rows, required this.unreadCount});

  final List<NotificationModel> rows;

  /// `null` bila amplopnya tidak menyebutkan angka sama sekali — backend lama
  /// menjawab daftar telanjang. Nol dan "tidak tahu" adalah dua hal berbeda,
  /// jadi keduanya tidak dilebur: yang satu berarti lencana disembunyikan,
  /// yang lain berarti lencana jatuh ke hitungan lokal.
  final int? unreadCount;
}

class NotificationRepository {
  const NotificationRepository(this._api);

  final NotificationApiService _api;

  Future<NotificationPage> page({
    required int page,
    required int perPage,
    bool unreadOnly = false,
  }) async {
    final body = await _api.page(
      page: page,
      perPage: perPage,
      unreadOnly: unreadOnly,
    );

    // The page carries `unread_count` beside `data`. Reading the body as a bare
    // list - which is what the retired backend answered - gets nothing at all
    // rather than an error, so the badge and the list would both quietly empty.
    return NotificationPage(
      rows: asModelList(asPage(body), NotificationModel.fromJson),
      unreadCount: _unreadCount(body),
    );
  }

  Future<void> markAsRead(String id) => _api.markAsRead(id);

  /// Angkanya pernah dikirim di akar amplop dan pernah di dalam `meta`, jadi
  /// keduanya diperiksa sebelum menyerah — sebuah lencana yang hilang karena
  /// satu tingkat kunci bukan kegagalan yang akan dilaporkan siapa pun.
  static int? _unreadCount(Map<String, dynamic> body) {
    final direct = asInt(body['unread_count']);

    if (direct != null) {
      return direct;
    }

    return asInt(asObject(body['meta'])['unread_count']);
  }
}

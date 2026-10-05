import 'dart:async';
import 'dart:io';

import 'api_exception.dart';

/// The one place an HTTP status becomes something the app can act on.
///
/// Replaces the three divergent `switch (statusCode)` blocks in
/// `login_controller`, `home_controller` and `utils/helper.dart` (MED-07). The
/// messages here are the *defaults* — where a screen had a better sentence, the
/// controller keeps saying it and passes its own. Login's "NIP/Email atau kata
/// sandi salah" is a better 401 than a generic one, and consolidating must not
/// flatten that.
class ApiErrorMapper {
  const ApiErrorMapper._();

  /// Build an exception from a response the server actually answered.
  static ApiException fromResponse({
    required int? status,
    Object? body,
    String? overrideMessage,
  }) {
    final map = body is Map
        ? Map<String, dynamic>.from(body)
        : const <String, dynamic>{};
    final errors = _firstErrors(map['errors']);
    final serverMessage = map['message']?.toString();

    return ApiException(
      overrideMessage ?? serverMessage ?? defaultMessageFor(status),
      status: status,
      code: map['code']?.toString(),
      errors: errors,
      body: map,
    );
  }

  /// Turn a transport failure into the same shape as a refusal, so callers have
  /// one thing to catch.
  ///
  /// The catch-all at the end is not padding. GetConnect applies its timeout
  /// with `Future.timeout` and no `onTimeout`, so a stalled request throws
  /// `TimeoutException`, which is neither of the named cases. An uncaught one
  /// leaves a screen on its spinner with nothing to end it.
  static ApiException fromTransportError(Object error) {
    if (error is ApiException) {
      return error;
    }

    if (error is SocketException || error is HttpException) {
      return const ApiException(
        'Tidak ada koneksi internet. Periksa jaringan Anda.',
        code: 'network_unreachable',
      );
    }

    if (error is TimeoutException) {
      return const ApiException(
        'Koneksi terlalu lama. Silakan coba lagi nanti.',
        code: 'timeout',
      );
    }

    if (error is FormatException) {
      return const ApiException(
        'Kesalahan format data dari server.',
        code: 'malformed_response',
      );
    }

    return ApiException(
      'Terjadi kesalahan tidak terduga. Mohon coba lagi.',
      code: 'transport_failure',
      errors: {'detail': error.toString()},
    );
  }

  /// The sentence shown when neither the screen nor the server supplies one.
  ///
  /// Wording follows `utils/helper.dart`'s `showApiError`, which was the most
  /// neutral of the three existing copies — the other two were written for one
  /// screen each and are kept at those screens.
  static String defaultMessageFor(int? status) {
    if (status == null) {
      return 'Tidak dapat terhubung ke server.';
    }

    return switch (status) {
      400 => 'Permintaan tidak valid.',
      401 => 'Sesi Anda berakhir. Mohon login kembali.',
      403 => 'Anda tidak memiliki izin untuk tindakan ini.',
      404 => 'Data tidak ditemukan.',
      409 => 'Konflik data. Data mungkin sudah diproses.',
      422 => 'Data tidak valid. Periksa kembali input Anda.',
      429 => 'Terlalu banyak permintaan. Coba lagi sebentar lagi.',
      >= 500 && < 600 => 'Kesalahan server internal. Coba lagi nanti.',
      _ => 'Terjadi kesalahan tidak dikenal. Kode: $status',
    };
  }

  /// Laravel answers a 422 with `{"errors": {"field": ["first", ...]}}`. Only
  /// the first message per field is kept; the rest restate it.
  static Map<String, String> _firstErrors(Object? errors) {
    if (errors is! Map) {
      return const {};
    }

    return {
      for (final entry in errors.entries)
        entry.key
            .toString(): entry.value is List && (entry.value as List).isNotEmpty
            ? (entry.value as List).first.toString()
            : entry.value.toString(),
    };
  }
}

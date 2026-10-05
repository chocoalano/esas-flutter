import 'dart:async';
import 'dart:io';

import 'package:esas/core/network/api_error_mapper.dart';
import 'package:esas/core/network/api_exception.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('fromResponse', () {
    test('prefers the server message over the default', () {
      final e = ApiErrorMapper.fromResponse(
        status: 422,
        body: {'message': 'Tanggal mulai tidak boleh lampau.'},
      );

      expect(e.message, 'Tanggal mulai tidak boleh lampau.');
      expect(e.status, 422);
      expect(e.isValidationFailure, isTrue);
    });

    test('lets a screen override both', () {
      // Login says "NIP/Email atau kata sandi salah" for a 401, which is a
      // better sentence than the generic one. Consolidating the three switch
      // blocks must not flatten that.
      final e = ApiErrorMapper.fromResponse(
        status: 401,
        body: {'message': 'Unauthenticated.'},
        overrideMessage: 'NIP/Email atau kata sandi salah. Silakan coba lagi.',
      );

      expect(e.message, 'NIP/Email atau kata sandi salah. Silakan coba lagi.');
    });

    test('keeps the first message per field from a Laravel 422', () {
      final e = ApiErrorMapper.fromResponse(
        status: 422,
        body: {
          'errors': {
            'start_date': ['Wajib diisi.', 'Harus berupa tanggal.'],
            'notes': ['Terlalu panjang.'],
          },
        },
      );

      expect(e.errors, {
        'start_date': 'Wajib diisi.',
        'notes': 'Terlalu panjang.',
      });
      expect(e.firstFieldError, 'Wajib diisi.');
    });

    test('survives a body that is not a map', () {
      final e = ApiErrorMapper.fromResponse(
        status: 500,
        body: '<html>502</html>',
      );

      expect(e.status, 500);
      expect(e.message, 'Kesalahan server internal. Coba lagi nanti.');
      expect(e.errors, isEmpty);
    });
  });

  group('session semantics', () {
    test('401 ends the session, 403 does not', () {
      // A global logout on 403 would eject a user who is perfectly well
      // authenticated but not permitted to do one thing (R-07).
      expect(
        ApiErrorMapper.fromResponse(status: 401).isUnauthenticated,
        isTrue,
      );
      expect(
        ApiErrorMapper.fromResponse(status: 403).isUnauthenticated,
        isFalse,
      );
      expect(ApiErrorMapper.fromResponse(status: 403).isForbidden, isTrue);
    });

    test('a transport failure is not a refusal', () {
      // The distinction HIGH-02 turns on: a refusal is the server's verdict, a
      // transport failure is a reason to keep the session and retry.
      final offline = ApiErrorMapper.fromTransportError(
        const SocketException('no route'),
      );

      expect(offline.isTransportFailure, isTrue);
      expect(offline.isUnauthenticated, isFalse);
      expect(offline.status, isNull);
    });
  });

  group('fromTransportError', () {
    test('maps the named transport failures', () {
      expect(
        ApiErrorMapper.fromTransportError(const SocketException('x')).code,
        'network_unreachable',
      );
      expect(
        ApiErrorMapper.fromTransportError(TimeoutException('x')).code,
        'timeout',
      );
      expect(
        ApiErrorMapper.fromTransportError(const FormatException('x')).code,
        'malformed_response',
      );
    });

    test('catches anything else rather than letting it escape', () {
      // GetConnect times out with Future.timeout and no onTimeout, so a stalled
      // request throws something the named cases do not cover. An uncaught one
      // leaves a screen on its spinner with nothing to end it.
      final e = ApiErrorMapper.fromTransportError(StateError('unexpected'));

      expect(e, isA<ApiException>());
      expect(e.code, 'transport_failure');
      expect(e.errors['detail'], contains('unexpected'));
    });

    test('passes an ApiException through unchanged', () {
      const original = ApiException('sudah dipetakan', status: 409);

      expect(ApiErrorMapper.fromTransportError(original), same(original));
    });
  });

  group('defaultMessageFor', () {
    test('covers the range, including any 5xx', () {
      expect(ApiErrorMapper.defaultMessageFor(400), 'Permintaan tidak valid.');
      expect(ApiErrorMapper.defaultMessageFor(404), 'Data tidak ditemukan.');
      expect(
        ApiErrorMapper.defaultMessageFor(503),
        'Kesalahan server internal. Coba lagi nanti.',
      );
      expect(
        ApiErrorMapper.defaultMessageFor(null),
        'Tidak dapat terhubung ke server.',
      );
    });

    test('interpolates an unknown status instead of printing the variable', () {
      // home_controller.dart:219 wrote '\$statusCode' with a backslash, so users
      // were shown the literal text `$statusCode` (LOW-04).
      final message = ApiErrorMapper.defaultMessageFor(418);

      expect(message, contains('418'));
      expect(message, isNot(contains(r'$status')));
    });
  });
}

import 'dart:io';

import 'package:esas/core/network/api_client.dart';
import 'package:esas/core/network/api_error_mapper.dart';
import 'package:esas/core/network/api_exception.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

/// Putaran 9. The device-proof routes answer a busy shift start with 429 and a
/// rate limiter that cannot reach its store with 503 `RATE_LIMITER_UNAVAILABLE`,
/// both with `Retry-After`. The app used to drop every header, so it could not
/// wait as long as the server asked.
void main() {
  group('Retry-After is read', () {
    test('as seconds', () {
      final error = ApiErrorMapper.fromResponse(
        status: 429,
        body: const {
          'message': 'Too Many Attempts.',
          'code': 'TOO_MANY_REQUESTS',
        },
        headers: const {'retry-after': '20'},
      );

      expect(error.retryAfter, const Duration(seconds: 20));
      expect(error.code, 'TOO_MANY_REQUESTS');
    });

    test('whatever the header name\'s case', () {
      final error = ApiErrorMapper.fromResponse(
        status: 503,
        body: const {'code': 'RATE_LIMITER_UNAVAILABLE'},
        headers: const {'Retry-After': '30'},
      );

      expect(error.retryAfter, const Duration(seconds: 30));
    });

    test('as an HTTP date', () {
      final at = DateTime.now().toUtc().add(const Duration(seconds: 45));
      final error = ApiErrorMapper.fromResponse(
        status: 429,
        headers: {'retry-after': HttpDate.format(at)},
      );

      expect(error.retryAfter!.inSeconds, inInclusiveRange(40, 46));
    });

    test('never longer than five minutes, never negative', () {
      Duration? read(String value) => ApiErrorMapper.fromResponse(
        status: 429,
        headers: {'retry-after': value},
      ).retryAfter;

      expect(read('86400'), const Duration(minutes: 5));
      expect(read('0'), Duration.zero);
      expect(read('-5'), isNull);
      expect(read('soon'), isNull);
    });

    test('absent is absent', () {
      expect(ApiErrorMapper.fromResponse(status: 429).retryAfter, isNull);
    });

    test('reaches the caller through ApiClient', () {
      final response = Response<dynamic>(
        statusCode: 429,
        headers: const {'retry-after': '20'},
        body: const {
          'message': 'Too Many Attempts.',
          'code': 'TOO_MANY_REQUESTS',
        },
      );

      expect(
        () => ApiClient.unwrapObject(response),
        throwsA(
          isA<ApiException>()
              .having((e) => e.status, 'status', 429)
              .having(
                (e) => e.retryAfter,
                'retryAfter',
                const Duration(seconds: 20),
              ),
        ),
      );
    });
  });
}

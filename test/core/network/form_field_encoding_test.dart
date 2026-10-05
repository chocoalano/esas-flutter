import 'package:esas/core/network/api_client.dart';
import 'package:flutter_test/flutter_test.dart';

/// How a multipart field crosses the wire.
///
/// This file exists because of one field. Face attendance sends
/// `is_mocked: false` on every submission, `postForm` stringified it to
/// `"false"`, and Laravel's `boolean` rule compares against
/// `[true, false, 0, 1, '0', '1']` with a **strict** `in_array` — so `"false"`
/// is not a false, it is a validation failure.
///
/// Every face clock was therefore refused with a 422 that carried no `code`,
/// which the screen classified by status alone and reported as "Absensi belum
/// dapat diproses". The QR paths post JSON, where a bool stays a bool, so they
/// kept working and the defect looked like a liveness problem rather than an
/// encoding one.
///
/// Multipart has no types. Whatever this function returns *is* the contract.
void main() {
  group('booleans', () {
    test('cross as 1 and 0, never as true and false', () {
      // The two values Laravel's `boolean` rule accepts as strings.
      expect(ApiClient.encodeFormField(true), '1');
      expect(ApiClient.encodeFormField(false), '0');
    });

    test('false is SENT, not dropped', () {
      // `false` is a fact the server asked for — "this fix did not come from a
      // mock provider" — and dropping it would be the client declining to
      // answer a question it was asked.
      expect(ApiClient.encodeFormField(false), isNotNull);
    });
  });

  group('absent values', () {
    test('null is dropped rather than sent as the word "null"', () {
      // What a naive `toString()` over a field map produces, and what the permit
      // form used to send.
      expect(ApiClient.encodeFormField(null), isNull);
    });

    test('blank and whitespace-only are dropped', () {
      expect(ApiClient.encodeFormField(''), isNull);
      expect(ApiClient.encodeFormField('   '), isNull);
    });
  });

  group('everything else', () {
    test('numbers keep their own representation', () {
      expect(ApiClient.encodeFormField(0), '0');
      expect(ApiClient.encodeFormField(-6.21), '-6.21');
      expect(ApiClient.encodeFormField(12.5), '12.5');
    });

    test('zero is not blank', () {
      // A coordinate on the equator, or an accuracy the device reports as 0, is
      // a value and not an absence.
      expect(ApiClient.encodeFormField(0), isNotNull);
      expect(ApiClient.encodeFormField(0.0), isNotNull);
    });

    test('strings are trimmed', () {
      expect(ApiClient.encodeFormField('  in  '), 'in');
    });
  });
}

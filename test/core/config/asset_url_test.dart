import 'package:esas/core/config/asset_url.dart';
import 'package:esas/core/config/env.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('assetUrl', () {
    test('resolves a stored path against the CDN origin', () {
      expect(
        assetUrl('esas-assets/default.png'),
        '${Env.assetBaseUrl}/esas-assets/default.png',
      );
    });

    test('does not double the separator on a leading slash', () {
      expect(
        assetUrl('/esas-assets/default.png'),
        '${Env.assetBaseUrl}/esas-assets/default.png',
      );
    });

    test('leaves an absolute URL alone', () {
      const absolute = 'https://cdn.example.com/a.png';
      expect(assetUrl(absolute), absolute);
    });
  });
}

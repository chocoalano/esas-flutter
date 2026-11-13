import 'dart:convert';

import 'package:esas/features/auth/data/services/device_key_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// ADR-D §5/§7. The key never reaches Dart; what this pins is the contract of
/// the `esas/device_key` channel and the fingerprint the server recomputes.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(DeviceKeyService.channelName);
  final calls = <MethodCall>[];

  // A real P-256 public key (openssl ecparam -name prime256v1), and the
  // fingerprint `openssl dgst -sha256 -binary | base64url` gives for it.
  const spki =
      'MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEgKXkgZkOPO2vrrRgJkS+bhq134yaBaTSZc'
      'eP7ImMq5rzNld8OI5yroFWKNlXuxe1BD1RMLs+RlOYn01E+4LRTQ==';
  const fingerprint = 'IlfYwWq-JnSBK58YUV9Gn79JLLxxXt8uVrs1RWXf0UI';

  void answer(Future<Object?> Function(MethodCall call) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) {
          calls.add(call);
          return handler(call);
        });
  }

  final alias = DeviceKeyService.aliasFor(workspace: 'acme', userId: 7);

  setUp(calls.clear);

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('fingerprint', () {
    test('is base64url, unpadded, of SHA-256 over the SPKI DER', () {
      expect(DeviceKeyService.fingerprintOf(base64Decode(spki)), fingerprint);
      expect(fingerprint, isNot(contains('=')));
    });

    test('is computed from the public key the platform returns', () async {
      answer((call) async => call.method == 'publicKey' ? spki : null);

      expect(await DeviceKeyService().fingerprint(alias), fingerprint);
      expect(calls.single.arguments, {'alias': alias});
    });

    test('the SPKI prefix iOS wraps its X9.63 point in is the DER prefix', () {
      // AppDelegate.swift prefixes the 65-byte point with this header. The
      // openssl key above starts with the same 26 bytes.
      const header = '3059301306072a8648ce3d020106082a8648ce3d030107034200';
      final der = base64Decode(spki);
      final prefix = der
          .take(26)
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();

      expect(prefix, header);
      expect(der.length, 26 + 65);
      expect(der[26], 0x04, reason: 'an uncompressed point follows');
    });
  });

  group('one key per account (PO 4.2.8)', () {
    test('another user on the same phone gets another key', () {
      expect(
        DeviceKeyService.aliasFor(workspace: 'acme', userId: 7),
        isNot(DeviceKeyService.aliasFor(workspace: 'acme', userId: 8)),
      );
    });

    test('the same user in another workspace gets another key', () {
      expect(
        DeviceKeyService.aliasFor(workspace: 'acme', userId: 7),
        isNot(DeviceKeyService.aliasFor(workspace: 'globex', userId: 7)),
      );
    });

    test('is stable for the same account, whatever the casing', () {
      expect(
        DeviceKeyService.aliasFor(workspace: 'Acme ', userId: 7),
        DeviceKeyService.aliasFor(workspace: 'acme', userId: 7),
      );
    });

    test('names neither the workspace nor the user, and is keystore-safe', () {
      final alias = DeviceKeyService.aliasFor(workspace: 'acme', userId: 7);

      expect(alias, startsWith(DeviceKeyService.aliasPrefix));
      expect(alias, isNot(contains('acme')));
      expect(alias, matches(RegExp(r'^[A-Za-z0-9._-]{1,128}$')));
    });

    test('capabilities can ask about this account\'s key', () async {
      answer((call) async => {'available': true, 'platform': 'android'});

      await DeviceKeyService().capabilities(alias: alias);
      await DeviceKeyService().capabilities();

      expect(calls[0].arguments, {'alias': alias});
      expect(calls[1].arguments, isEmpty);
    });
  });

  group('the channel', () {
    test('reads capabilities', () async {
      answer(
        (call) async => {
          'available': true,
          'hardwareBackedClaimed': true,
          'strongBox': false,
          'platform': 'android',
        },
      );

      final capabilities = await DeviceKeyService().capabilities();

      expect(calls.single.method, 'capabilities');
      expect(capabilities.available, isTrue);
      expect(capabilities.hardwareBackedClaimed, isTrue);
      expect(capabilities.strongBox, isFalse);
      expect(capabilities.platform, 'android');
    });

    test('an unknown platform is reported as unknown', () async {
      answer((call) async => {'available': true});

      expect((await DeviceKeyService().capabilities()).platform, 'unknown');
    });

    test('replaces an existing key only when asked', () async {
      answer((call) async => {'available': true, 'platform': 'ios'});

      await DeviceKeyService().generate(alias: alias);
      await DeviceKeyService().generate(alias: alias, replace: true);

      expect(calls[0].arguments, {'alias': alias, 'replace': false});
      expect(calls[1].arguments, {'alias': alias, 'replace': true});
    });

    test('signs the UTF-8 bytes of the signing input exactly', () async {
      answer((call) async => 'MEUCIQ==');
      const input =
          'esas-device-proof/v1|proof|abc.def|tenant-é|7|42|$fingerprint';

      final signature = await DeviceKeyService().signText(alias, input);

      expect(signature, 'MEUCIQ==');
      expect(calls.single.method, 'sign');
      final arguments = calls.single.arguments as Map;
      expect(arguments['alias'], alias);
      expect(arguments['bytes'] as Uint8List, utf8.encode(input));
    });

    test('says whether a key exists', () async {
      answer((call) async => true);

      expect(await DeviceKeyService().exists(alias), isTrue);
      expect(calls.single.arguments, {'alias': alias});
    });

    test('deletes the key', () async {
      answer((call) async => null);

      await DeviceKeyService().delete(alias);

      expect(calls.single.method, 'delete');
      expect(calls.single.arguments, {'alias': alias});
    });
  });

  group('failures', () {
    test('KEY_MISSING is a missing key', () async {
      answer((call) async => throw PlatformException(code: 'KEY_MISSING'));

      await expectLater(
        DeviceKeyService().publicKey(alias),
        throwsA(
          isA<DeviceKeyException>()
              .having((e) => e.failure, 'failure', DeviceKeyFailure.missing)
              .having((e) => e.code, 'code', 'KEY_MISSING'),
        ),
      );
    });

    test('any other platform error is an unavailable keystore', () async {
      answer((call) async => throw PlatformException(code: 'KEY_UNAVAILABLE'));

      await expectLater(
        DeviceKeyService().sign(alias, [1, 2, 3]),
        throwsA(
          isA<DeviceKeyException>().having(
            (e) => e.failure,
            'failure',
            DeviceKeyFailure.unavailable,
          ),
        ),
      );
    });

    test('a platform without the channel has no key', () async {
      // No handler registered: MissingPluginException.
      await expectLater(
        DeviceKeyService().capabilities(),
        throwsA(
          isA<DeviceKeyException>().having(
            (e) => e.failure,
            'failure',
            DeviceKeyFailure.unavailable,
          ),
        ),
      );
    });

    test('an empty public key is a missing key', () async {
      answer((call) async => '');

      await expectLater(
        DeviceKeyService().publicKey(alias),
        throwsA(
          isA<DeviceKeyException>().having(
            (e) => e.failure,
            'failure',
            DeviceKeyFailure.missing,
          ),
        ),
      );
    });
  });
}

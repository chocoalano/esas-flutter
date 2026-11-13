import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';

/// What the handset says it can do with its attendance key.
///
/// [hardwareBackedClaimed] is a **claim**: the server stores it as
/// `hardware_backed_claimed` and decides nothing on it until key attestation is
/// verified (ADR-D §5, stage 5).
class DeviceKeyCapabilities {
  const DeviceKeyCapabilities({
    required this.available,
    required this.hardwareBackedClaimed,
    required this.strongBox,
    required this.platform,
  });

  factory DeviceKeyCapabilities.fromPlatform(Object? raw) {
    final map = raw is Map ? raw : const {};

    return DeviceKeyCapabilities(
      available: map['available'] == true,
      hardwareBackedClaimed: map['hardwareBackedClaimed'] == true,
      strongBox: map['strongBox'] == true,
      platform: switch (map['platform']) {
        'android' => 'android',
        'ios' => 'ios',
        _ => 'unknown',
      },
    );
  }

  final bool available;
  final bool hardwareBackedClaimed;
  final bool strongBox;

  /// `android`, `ios`, or `unknown` when the native side did not say.
  final String platform;
}

/// Why the key could not be used.
enum DeviceKeyFailure {
  /// No key on this install: it was never made, or the app was reinstalled.
  missing,

  /// The keystore refused: no secure lock screen, a broken keystore, or a
  /// platform without the channel at all.
  unavailable,
}

class DeviceKeyException implements Exception {
  const DeviceKeyException(this.failure, {this.code});

  final DeviceKeyFailure failure;

  /// The native code (`KEY_MISSING`, `KEY_UNAVAILABLE`, ...), for logs only.
  final String? code;

  @override
  String toString() => 'DeviceKeyException(${failure.name}, $code)';
}

/// The attendance device key: a non-exportable EC P-256 key per account on
/// this install, in Android Keystore or the iOS Secure Enclave (ADR-D §5).
///
/// A thin wrapper over the `esas/device_key` channel (`MainActivity` /
/// `DeviceKeyChannel.kt`, `AppDelegate.swift`). The private key never reaches
/// Dart: what crosses is the public key (SPKI DER, base64) and signatures (DER,
/// base64). The channel is injectable so a test can answer for the platform.
///
/// Every key is named by an [alias] from [aliasFor] — workspace plus user — so
/// account B on the same phone never uses or replaces account A's key, and a
/// workspace switch never reuses another workspace's key (PO 4.2.8).
class DeviceKeyService {
  DeviceKeyService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  static const String channelName = 'esas/device_key';

  /// Bumped only if the derivation below ever changes; a new prefix is a new
  /// key for everybody, which means a trip to HR for everybody.
  static const String aliasPrefix = 'esas.attendance.dk.v2.';

  /// The one fixed name Putaran 4 test builds used for every account, before
  /// keys were per account. Nothing reads it any more: it does not carry
  /// [aliasPrefix], so it can never be a current account's key.
  static const String legacyAlias = 'esas.attendance.device_key.v1';

  final MethodChannel _channel;

  /// The keystore alias for [userId] in [workspace].
  ///
  /// A short hash, not the values themselves: the alias is visible to anything
  /// that can list the app's keystore, and it has no reason to spell out a
  /// workspace or an employee number. 64 bits of SHA-256 is far more than one
  /// phone will ever hold accounts for. Not `identifierForVendor`, not the
  /// CORE-03 device id: only who is signed in, and where.
  static String aliasFor({required String workspace, required Object userId}) {
    final digest = sha256.convert(
      utf8.encode('${workspace.trim().toLowerCase()}|$userId'),
    );

    return '$aliasPrefix${digest.toString().substring(0, 16)}';
  }

  /// What the handset can do; with [alias], also how that key is held.
  Future<DeviceKeyCapabilities> capabilities({String? alias}) async =>
      DeviceKeyCapabilities.fromPlatform(
        await _invoke<Object?>('capabilities', {'alias': ?alias}),
      );

  /// Create the key under [alias], or describe the one already there. An
  /// existing key is replaced only when [replace] is true.
  Future<DeviceKeyCapabilities> generate({
    required String alias,
    bool replace = false,
  }) async => DeviceKeyCapabilities.fromPlatform(
    await _invoke<Object?>('generate', {'alias': alias, 'replace': replace}),
  );

  /// The public key as X.509 SubjectPublicKeyInfo DER, standard base64.
  Future<String> publicKey(String alias) async {
    final value = await _invoke<String>('publicKey', {'alias': alias});

    if (value == null || value.isEmpty) {
      throw const DeviceKeyException(
        DeviceKeyFailure.missing,
        code: 'KEY_MISSING',
      );
    }

    return value;
  }

  /// ECDSA P-256 / SHA-256 over exactly [message]. DER, standard base64.
  Future<String> sign(String alias, List<int> message) async {
    final value = await _invoke<String>('sign', {
      'alias': alias,
      'bytes': Uint8List.fromList(message),
    });

    if (value == null || value.isEmpty) {
      throw const DeviceKeyException(
        DeviceKeyFailure.unavailable,
        code: 'SIGN_EMPTY',
      );
    }

    return value;
  }

  /// Sign the UTF-8 bytes of [signingInput] exactly as the server sent it
  /// (ADR-D §7, "Yang ditandatangani app"). Nothing is trimmed or rebuilt.
  Future<String> signText(String alias, String signingInput) =>
      sign(alias, utf8.encode(signingInput));

  Future<void> delete(String alias) =>
      _invoke<void>('delete', {'alias': alias});

  Future<bool> exists(String alias) async =>
      (await _invoke<bool>('exists', {'alias': alias})) ?? false;

  /// The fingerprint of the key under [alias], as the server computes it.
  Future<String> fingerprint(String alias) async =>
      fingerprintOf(base64Decode(await publicKey(alias)));

  /// `base64url` without padding of SHA-256 over the SPKI DER (ADR-D §7).
  static String fingerprintOf(List<int> spkiDer) =>
      base64Url.encode(sha256.convert(spkiDer).bytes).replaceAll('=', '');

  Future<T?> _invoke<T>(String method, [Object? arguments]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on PlatformException catch (error) {
      throw DeviceKeyException(
        error.code == 'KEY_MISSING'
            ? DeviceKeyFailure.missing
            : DeviceKeyFailure.unavailable,
        code: error.code,
      );
    } on MissingPluginException {
      // A platform without the channel (desktop, a widget test) has no key.
      throw const DeviceKeyException(
        DeviceKeyFailure.unavailable,
        code: 'KEY_UNAVAILABLE',
      );
    }
  }
}

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../network/idempotency_key.dart';
import '../storage/secure_store.dart';
import '../storage/storage_keys.dart';
import '../utils/app_logger.dart';

/// The identifier this handset is bound to for attendance (CORE-03).
///
/// The backend binds an account to the first `device_id` it signs in with and
/// refuses attendance from any other, which is what stops one employee
/// clocking in for another. So the value has to be **unique per handset** and
/// **stable** across updates.
///
/// It was neither. On Android it was `AndroidDeviceInfo.id`, which is
/// `Build.ID` — a firmware label like `TP1A.220624.014`, identical on every
/// phone running that build and different after every OS update. And every
/// platform failure answered the constant `'device_info_error'`, shared by
/// every handset that failed.
///
/// Now:
///
/// * **Android** — `Settings.Secure.ANDROID_ID`, read through a method channel
///   in `MainActivity`: unique per handset and signing key, and it survives an
///   OS update and a reinstall.
/// * **iOS** — `identifierForVendor`, unchanged, so iOS bindings need no
///   migration.
/// * **Otherwise** — a random identifier minted once and kept in the keychain.
///   Never a constant.
///
/// [legacyDeviceId] carries the old Android value at sign-in, once, so the
/// server can move an existing binding onto the new identifier instead of
/// treating every updated handset as a stranger.
class DeviceInfoService {
  DeviceInfoService({
    required SecureStore store,
    Future<String?> Function()? platformId,
    Future<String?> Function()? legacyId,
  }) : _store = store,
       _platformId = platformId ?? _defaultPlatformId,
       _legacyId = legacyId ?? _defaultLegacyId;

  final SecureStore _store;
  final Future<String?> Function() _platformId;
  final Future<String?> Function() _legacyId;

  static const _channel = MethodChannel('esas/device');

  String? _cached;

  /// The identifier. Never throws, and never answers a value another handset
  /// could also answer.
  Future<String> deviceId() async {
    final cached = _cached;

    if (cached != null) {
      return cached;
    }

    // A fallback, once minted, is this handset's name for good (UAT review
    // C4). The server may already have bound the account to it; preferring
    // the platform id on a later launch made the same phone a stranger.
    final id =
        await _store.read(StorageKeys.secure.deviceInstallId) ??
        await _attempt(_platformId) ??
        await _installId();
    _cached = id;

    return id;
  }

  /// What older builds sent as `device_id`, when it is not [deviceId].
  ///
  /// Null when there is nothing to migrate from: on iOS, where the value is
  /// unchanged, or when the platform will not say.
  Future<String?> legacyDeviceId() async {
    final legacy = await _attempt(_legacyId);

    if (legacy == null || legacy == await deviceId()) {
      return null;
    }

    return legacy;
  }

  Future<String?> _attempt(Future<String?> Function() read) async {
    try {
      final value = (await read())?.trim();

      return value == null || value.isEmpty ? null : value;
    } on PlatformException catch (error) {
      AppLogger.warning('Could not read device info: ${error.code}');
      return null;
    } catch (error, stackTrace) {
      AppLogger.error(
        'Unexpected failure reading device info',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<String> _installId() async {
    final key = StorageKeys.secure.deviceInstallId;
    final stored = await _store.read(key);

    if (stored != null) {
      return stored;
    }

    final minted = 'install-${IdempotencyKey.mint()}';
    await _store.write(key, minted);

    return minted;
  }

  static Future<String?> _defaultPlatformId() async {
    if (GetPlatform.isAndroid) {
      return _channel.invokeMethod<String>('androidId');
    }

    if (GetPlatform.isIOS) {
      return (await DeviceInfoPlugin().iosInfo).identifierForVendor;
    }

    return null;
  }

  static Future<String?> _defaultLegacyId() async {
    if (GetPlatform.isAndroid) {
      return (await DeviceInfoPlugin().androidInfo).id;
    }

    return null;
  }
}

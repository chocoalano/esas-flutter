import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../utils/app_logger.dart';

/// A stable per-installation identifier for this handset.
///
/// Lifted out of `LoginController`, which built it inline and swallowed both
/// failure paths into `print`. The backend records it as `device_info` on the
/// account, so a value that silently degrades to `'device_info_error'` is a
/// device record that means nothing — worth logging properly rather than
/// printing.
class DeviceInfoService {
  DeviceInfoService([DeviceInfoPlugin? plugin])
    : _plugin = plugin ?? DeviceInfoPlugin();

  final DeviceInfoPlugin _plugin;

  String? _cached;

  /// The identifier, or a marked fallback if the platform will not give one.
  ///
  /// Never throws: failing to identify a handset must not be what stops
  /// somebody signing in.
  Future<String> deviceId() async {
    final cached = _cached;

    if (cached != null) {
      return cached;
    }

    final id = await _resolve();
    _cached = id;

    return id;
  }

  Future<String> _resolve() async {
    try {
      if (GetPlatform.isAndroid) {
        return (await _plugin.androidInfo).id;
      }

      if (GetPlatform.isIOS) {
        return (await _plugin.iosInfo).identifierForVendor ??
            'unknown_ios_device';
      }

      return 'unknown_platform_device';
    } on PlatformException catch (error) {
      AppLogger.warning('Could not read device info: ${error.code}');
      return 'device_info_error';
    } catch (error, stackTrace) {
      AppLogger.error(
        'Unexpected failure reading device info',
        error: error,
        stackTrace: stackTrace,
      );
      return 'device_info_general_error';
    }
  }
}

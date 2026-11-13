import 'package:package_info_plus/package_info_plus.dart';

class AppVersionService {
  AppVersionService._();

  static String _version = '';
  static String _buildNumber = '';
  static String _packageName = '';

  static String get version => _version;
  static String get buildNumber => _buildNumber;
  static String get packageName => _packageName;

  static String get displayVersion =>
      _version.isEmpty ? '' : 'v$_version ($_buildNumber)';

  static Future<void> load() async {
    final info = await PackageInfo.fromPlatform();
    _version = info.version;
    _buildNumber = info.buildNumber;
    _packageName = info.packageName;
  }
}

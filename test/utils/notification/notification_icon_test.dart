import 'dart:io';

import 'package:esas/utils/notification/notification_services.dart';
import 'package:flutter_test/flutter_test.dart';

/// CORE-01. `flutter_local_notifications` resolves the small icon with
/// `getIdentifier` and fails `initialize()` with `invalid_icon` when it is not
/// in the APK — which skipped FCM registration on every Android handset after
/// the launcher icons were regenerated under a different name.
void main() {
  test('the Android notification icon names a resource the APK ships', () {
    final match = RegExp(
      r'^@(mipmap|drawable)/([a-z0-9_]+)$',
    ).firstMatch(NotificationService.androidIcon);

    expect(match, isNotNull, reason: 'expected @mipmap/x or @drawable/x');

    final type = match!.group(1)!;
    final name = match.group(2)!;

    final shipped = Directory('android/app/src/main/res')
        .listSync()
        .whereType<Directory>()
        .where((dir) {
          final folder = dir.uri.pathSegments.lastWhere((s) => s.isNotEmpty);
          return folder == type || folder.startsWith('$type-');
        })
        .any(
          (dir) =>
              File('${dir.path}/$name.png').existsSync() ||
              File('${dir.path}/$name.xml').existsSync(),
        );

    expect(
      shipped,
      isTrue,
      reason: '${NotificationService.androidIcon} is not under res/$type*',
    );
  });

  // A push that arrives while the app is in the background is drawn by the
  // FCM SDK, not by the plugin, and the SDK reads its icon and channel from the
  // manifest. Without them it falls back to the opaque launcher icon (a white
  // square) and to a channel this app never created.
  test('background pushes use the same icon and channel as local ones', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    String? metaValue(String name) => RegExp(
      '<meta-data[^>]*android:name="${RegExp.escape(name)}"[^>]*'
      'android:resource="([^"]+)"',
    ).firstMatch(manifest)?.group(1);

    String? metaString(String name) => RegExp(
      '<meta-data[^>]*android:name="${RegExp.escape(name)}"[^>]*'
      'android:value="([^"]+)"',
    ).firstMatch(manifest)?.group(1);

    expect(
      metaValue('com.google.firebase.messaging.default_notification_icon'),
      NotificationService.androidIcon,
    );
    expect(
      metaString('com.google.firebase.messaging.default_notification_channel_id'),
      NotificationService.channelId,
    );
  });
}

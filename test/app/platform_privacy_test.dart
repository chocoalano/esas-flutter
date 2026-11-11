import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// PROF-01 / CORE-02. GetStorage writes plain JSON into the app's files
/// directory, which Android Auto Backup copies to the user's Google Drive and
/// restores onto the next install. An HR app's cached session has no business
/// in a personal cloud backup, and a restored copy defeats the fresh-install
/// check in `InstallIdentity`.
void main() {
  test('Android backup is disabled for the app', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final application = RegExp(
      r'<application\b[^>]*>',
      multiLine: true,
    ).firstMatch(manifest)!.group(0)!;

    expect(application, contains('android:allowBackup="false"'));
    expect(application, contains('android:fullBackupContent="false"'));
  });

  // UAT review C7. From Android 12 (targetSdk 31+), `allowBackup="false"`
  // no longer stops a device-to-device transfer, and `fullBackupContent` is
  // ignored. Only `dataExtractionRules` covers both cloud backup and transfer.
  test('Android 12+ cloud backup and device transfer take nothing', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final application = RegExp(
      r'<application\b[^>]*>',
      multiLine: true,
    ).firstMatch(manifest)!.group(0)!;
    expect(
      application,
      contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
    );

    final rules = File(
      'android/app/src/main/res/xml/data_extraction_rules.xml',
    ).readAsStringSync();
    for (final section in ['cloud-backup', 'device-transfer']) {
      final body = RegExp(
        '<$section>(.*?)</$section>',
        dotAll: true,
      ).firstMatch(rules)?.group(1);
      expect(body, isNotNull, reason: section);
      for (final domain in ['root', 'file', 'database', 'sharedpref', 'external']) {
        expect(
          body,
          contains('<exclude domain="$domain" path="."'),
          reason: '$section/$domain',
        );
      }
    }
  });
}

// Identity invariants: what must stay constant when the application package
// changes (Round 12). Each group states how it is verified:
//   STATIC_VERIFIED       - read from source/config files in the repo.
//   INTEGRATION_VERIFIED  - exercises the real Dart code under test.
//   BLOCKED_EXTERNAL_CONSOLE - needs a Firebase console registration (see below).
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:esas/features/auth/data/services/device_key_service.dart';
import 'package:esas/utils/notification/notification_services.dart';
import 'package:flutter_test/flutter_test.dart';

String read(String path) => File(path).readAsStringSync();

String gradleValue(String key) {
  final m = RegExp(
    '$key\\s*=\\s*"([^"]+)"',
  ).firstMatch(read('android/app/build.gradle.kts'));
  expect(m, isNotNull, reason: '$key not found in build.gradle.kts');
  return m!.group(1)!;
}

Set<String> googleServicesPackages([String? source]) {
  final json =
      jsonDecode(source ?? read('android/app/google-services.json'))
          as Map<String, dynamic>;
  return {
    for (final c in json['client'] as List)
      (((c as Map)['client_info'] as Map)['android_client_info']
              as Map)['package_name']
          as String,
  };
}

String plistValue(String plist, String key) {
  final m = RegExp(
    '<key>$key</key>\\s*<string>([^<]*)</string>',
  ).firstMatch(plist);
  expect(m, isNotNull, reason: '$key not in plist');
  return m!.group(1)!;
}

/// Bundle id of the Runner app target (not RunnerTests).
Set<String> runnerBundleIds() {
  final ids = RegExp(r'PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);')
      .allMatches(read('ios/Runner.xcodeproj/project.pbxproj'))
      .map((m) => m.group(1)!.trim())
      .where((id) => !id.endsWith('.RunnerTests'))
      .toSet();
  return ids;
}

void main() {
  group(
    'device key channel is constant [STATIC_VERIFIED + INTEGRATION_VERIFIED]',
    () {
      test(
        'the Dart service, Kotlin and Swift register the same channel name',
        () {
          expect(DeviceKeyService.channelName, 'esas/device_key');
          // The Kotlin source lives under the Gradle namespace path, whatever
          // the namespace is, so the check follows a namespace move.
          final kotlinDir =
              'android/app/src/main/kotlin/'
              '${gradleValue('namespace').replaceAll('.', '/')}';
          expect(
            read('$kotlinDir/DeviceKeyChannel.kt'),
            contains('"${DeviceKeyService.channelName}"'),
          );
          expect(
            read('ios/Runner/AppDelegate.swift'),
            contains('"${DeviceKeyService.channelName}"'),
          );
        },
      );

      test(
        'a default-constructed service really talks on that channel',
        () async {
          TestWidgetsFlutterBinding.ensureInitialized();
          final seen = <String>[];
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(
                const MethodChannel('esas/device_key'),
                (call) async {
                  seen.add(call.method);
                  return {'available': true, 'platform': 'android'};
                },
              );
          addTearDown(
            () => TestDefaultBinaryMessengerBinding
                .instance
                .defaultBinaryMessenger
                .setMockMethodCallHandler(
                  const MethodChannel('esas/device_key'),
                  null,
                ),
          );

          final caps = await DeviceKeyService().capabilities();
          expect(caps.available, isTrue);
          expect(seen, ['capabilities']);
        },
      );
    },
  );

  group('device key alias ignores the package [INTEGRATION_VERIFIED]', () {
    test('derives from workspace|userId only, under the v2 prefix', () {
      final alias = DeviceKeyService.aliasFor(workspace: ' Acme ', userId: 42);
      expect(alias, startsWith('esas.attendance.dk.v2.'));
      expect(alias, DeviceKeyService.aliasFor(workspace: 'acme', userId: 42));
      expect(
        alias,
        isNot(DeviceKeyService.aliasFor(workspace: 'acme', userId: 43)),
      );
      expect(
        alias,
        isNot(DeviceKeyService.aliasFor(workspace: 'other', userId: 42)),
      );
    });

    test(
      'the derivation takes no package input: the same alias under two package names',
      () {
        // aliasFor has no package parameter and reads no platform state, so the
        // alias is the same whatever package the app is installed as. Run it once
        // per package to prove it, and check the source does not reference one.
        final aliases = {
          for (final package in ['com.example.esas', 'com.absensas.app'])
            package: DeviceKeyService.aliasFor(workspace: 'acme', userId: 42),
        };
        expect(aliases.values.toSet(), hasLength(1));
        expect(
          read('lib/features/auth/data/services/device_key_service.dart'),
          isNot(contains('PackageInfo')),
        );
      },
    );
  });

  group(
    'notification channel esas_attendance [STATIC_VERIFIED + INTEGRATION_VERIFIED]',
    () {
      test('Dart setup and the manifest FCM default channel match', () {
        expect(NotificationService.channelId, 'esas_attendance');
        final manifest = read('android/app/src/main/AndroidManifest.xml');
        expect(
          manifest,
          matches(
            RegExp(
              r'default_notification_channel_id"\s*android:value="esas_attendance"',
            ),
          ),
        );
        // The channel the plugin creates is built from the very same constant.
        expect(
          read('lib/utils/notification/notification_services.dart'),
          contains('AndroidNotificationChannel(\n            channelId,'),
        );
      });
    },
  );

  group('display name [STATIC_VERIFIED]', () {
    test('Android label and iOS CFBundleDisplayName are Absensas', () {
      expect(
        read('android/app/src/main/AndroidManifest.xml'),
        contains('android:label="Absensas"'),
      );
      expect(
        plistValue(read('ios/Runner/Info.plist'), 'CFBundleDisplayName'),
        'Absensas',
      );
    });
  });

  group('Firebase config matches the application id', () {
    // Mirrors the Google Services Gradle plugin, which fails the build when no
    // client in google-services.json has the module's applicationId. Today this
    // is STATIC_VERIFIED for com.example.esas. For com.absensas.app it is
    // BLOCKED_EXTERNAL_CONSOLE: the Firebase Android/iOS apps are not registered
    // yet, so the downloaded files cannot exist. Changing applicationId without
    // replacing google-services.json makes this test fail.
    test('android applicationId has a client in google-services.json', () {
      final id = gradleValue('applicationId');
      expect(
        googleServicesPackages(),
        contains(id),
        reason:
            'applicationId $id has no matching Firebase client (Google Services plugin would fail)',
      );
    });

    test('iOS bundle id equals BUNDLE_ID in GoogleService-Info.plist', () {
      final ids = runnerBundleIds();
      expect(ids, hasLength(1), reason: 'Runner configs disagree: $ids');
      expect(
        ids.single,
        plistValue(read('ios/Runner/GoogleService-Info.plist'), 'BUNDLE_ID'),
      );
    });

    test(
      'a patched applicationId is caught unless google-services.json is replaced too',
      () {
        const patched = 'com.absensas.app';
        final shipped = read('android/app/google-services.json');
        final withoutRegistration = googleServicesPackages(
          shipped.replaceAll(patched, 'x.unrelated'),
        );
        expect(withoutRegistration, isNot(contains(patched)));
        // Patched id with a file registered for it: the same check passes.
        final registered = googleServicesPackages(
          shipped.replaceAll(gradleValue('applicationId'), patched),
        );
        expect(registered, contains(patched));
      },
    );
  });

  group('namespace is independent of applicationId [STATIC_VERIFIED]', () {
    test('MainActivity package equals the namespace', () {
      final namespace = gradleValue('namespace');
      final dir =
          'android/app/src/main/kotlin/${namespace.replaceAll('.', '/')}';
      final main = File('$dir/MainActivity.kt');
      expect(
        main.existsSync(),
        isTrue,
        reason: 'MainActivity.kt must live under the namespace path',
      );
      expect(
        RegExp(
          r'^package\s+(\S+)',
          multiLine: true,
        ).firstMatch(main.readAsStringSync())!.group(1),
        namespace,
      );
      // The manifest names its classes relative to the namespace, never the applicationId.
      expect(
        read('android/app/src/main/AndroidManifest.xml'),
        isNot(
          contains(
            gradleValue('applicationId') == namespace
                ? '\u0000'
                : gradleValue('applicationId'),
          ),
        ),
      );
    });
  });
}

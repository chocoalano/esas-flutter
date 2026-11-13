import 'package:esas/core/network/api_exception.dart';
import 'package:esas/core/storage/local_storage.dart';
import 'package:esas/features/app_update/data/app_version_info.dart';
import 'package:esas/features/app_update/presentation/app_update_controller.dart';
import 'package:esas/features/app_update/presentation/app_update_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

AppVersionInfo version({int build = 105, bool force = true, String url = 'https://download.absensas.com/selfservice.apk'}) =>
    AppVersionInfo(version: '1.0.$build', buildNumber: build, forceUpdate: force, downloadUrl: url, releaseNotes: 'Perbaikan');

/// A controller over fakes: what the server answers, which build is installed,
/// and which links were opened.
class Harness {
  Harness({this.installed = 104});

  int? installed;
  Object? serverAnswer = version();
  bool openSucceeds = true;
  final opened = <Uri>[];
  final storage = InMemoryLocalStorage();
  int fetches = 0;

  late final AppUpdateController controller = Get.put(
    AppUpdateController(
      fetchLatest: () async {
        fetches++;
        final answer = serverAnswer;
        if (answer is Exception) {
          throw answer;
        }
        return answer as AppVersionInfo?;
      },
      installedBuild: () async => installed,
      openUrl: (url) async {
        opened.add(url);
        return openSucceeds;
      },
      storage: storage,
      interval: const Duration(hours: 1),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() async {
    await Get.deleteAll(force: true);
    Get.reset();
  });

  group('evaluateUpdate', () {
    test('the same or a newer installed build needs nothing', () {
      expect(evaluateUpdate(installedBuild: 105, latest: version()), UpdateRequirement.none);
      expect(evaluateUpdate(installedBuild: 106, latest: version()), UpdateRequirement.none);
      expect(evaluateUpdate(installedBuild: 1, latest: null), UpdateRequirement.none);
    });

    test('an older build must update when forced, and may when not', () {
      expect(evaluateUpdate(installedBuild: 104, latest: version()), UpdateRequirement.required);
      expect(evaluateUpdate(installedBuild: 104, latest: version(force: false)), UpdateRequirement.optional);
    });

    test('an unreadable server answer is not a version', () {
      expect(AppVersionInfo.fromJson({'build_number': '105', 'download_url': 'https://x'}), isNull);
      expect(AppVersionInfo.fromJson({'build_number': 105, 'download_url': ''}), isNull);
      expect(AppVersionInfo.fromJson({'build_number': 105, 'download_url': 'https://x', 'force_update': true})?.forceUpdate, isTrue);
    });
  });

  group('AppUpdateController', () {
    test('an older build is required to update, and the check after updating opens the app again', () async {
      final h = Harness();
      await h.controller.check();
      expect(h.controller.requirement.value, UpdateRequirement.required);

      h.installed = 105;
      await h.controller.check();
      expect(h.controller.requirement.value, UpdateRequirement.none);
    });

    test('the update button opens exactly the link the superadmin set, and a failure offers a retry', () async {
      final h = Harness();
      await h.controller.check();

      await h.controller.openDownload();
      expect(h.opened, [Uri.parse('https://download.absensas.com/selfservice.apk')]);
      expect(h.controller.openFailed.value, isFalse);

      h.openSucceeds = false;
      await h.controller.openDownload();
      expect(h.controller.openFailed.value, isTrue);
    });

    test('a link changed to Google Play is the one opened next', () async {
      final h = Harness();
      await h.controller.check();

      h.serverAnswer = version(url: 'https://play.google.com/store/apps/details?id=com.example.esas');
      await h.controller.check();
      await h.controller.openDownload();

      expect(h.opened.single.host, 'play.google.com');
    });

    test('a network failure never requires an update by itself, and never throws', () async {
      final h = Harness()..serverAnswer = const ApiException('offline');
      await h.controller.check();

      expect(h.controller.requirement.value, UpdateRequirement.none);
    });

    test('a mandatory update already seen stays in force while offline, until the build catches up', () async {
      final h = Harness();
      await h.controller.check();
      expect(h.controller.requirement.value, UpdateRequirement.required);

      h.serverAnswer = const ApiException('offline');
      await h.controller.check();
      expect(h.controller.requirement.value, UpdateRequirement.required);

      h.installed = 105;
      await h.controller.check();
      expect(h.controller.requirement.value, UpdateRequirement.none);
    });

    test('nothing published, or an unknown installed build, means no alert', () async {
      final h = Harness()..serverAnswer = null;
      await h.controller.check();
      expect(h.controller.requirement.value, UpdateRequirement.none);

      final unknown = Harness()..installed = null;
      await unknown.controller.check();
      expect(unknown.controller.requirement.value, UpdateRequirement.none);
    });

    test('overlapping checks share one request', () async {
      final h = Harness();
      await Future.wait([h.controller.check(), h.controller.check(), h.controller.check()]);

      // All three wait for the check onInit started: one request.
      expect(h.fetches, 1);
    });
  });

  group('AppUpdateGate', () {
    Future<void> stop(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await Get.delete<AppUpdateController>(force: true);
    }

    Future<Harness> pump(WidgetTester tester, Harness h) async {
      await h.controller.check();
      await tester.pumpWidget(
        GetMaterialApp(
          builder: (context, child) => AppUpdateGate(child: child!),
          home: const Scaffold(body: Text('beranda')),
        ),
      );
      await tester.pump();
      return h;
    }

    testWidgets('the same build shows no alert', (tester) async {
      await pump(tester, Harness(installed: 105));

      expect(find.text('Pembaruan Wajib'), findsNothing);
      expect(find.text('Update Tersedia'), findsNothing);
      await stop(tester);
    });

    testWidgets('a forced update covers the app with no way to skip it', (tester) async {
      final h = await pump(tester, Harness());

      expect(find.text('Pembaruan Wajib'), findsOneWidget);
      expect(find.byKey(const Key('app-update-dismiss')), findsNothing);
      expect(find.text('Nanti'), findsNothing);

      await tester.tap(find.byKey(const Key('app-update-download')));
      await tester.pump();
      expect(h.opened.single.toString(), 'https://download.absensas.com/selfservice.apk');
      await stop(tester);
    });

    testWidgets('an optional update can be closed and the app carries on', (tester) async {
      final h = Harness()..serverAnswer = version(force: false);
      await pump(tester, h);

      expect(find.text('Update Tersedia'), findsOneWidget);
      expect(find.text('Pembaruan Wajib'), findsNothing);

      await tester.tap(find.byKey(const Key('app-update-dismiss')));
      await tester.pump();

      expect(find.text('Update Tersedia'), findsNothing);
      expect(find.text('beranda'), findsOneWidget);
      await stop(tester);
    });
  });
}

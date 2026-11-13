import 'package:esas/core/storage/local_storage.dart';
import 'package:esas/features/app_update/data/app_version_info.dart';
import 'package:esas/features/app_update/presentation/app_update_controller.dart';
import 'package:esas/features/app_update/presentation/app_update_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

/// PO Putaran 10, Slice U: the update journey when the download link is an APK
/// served through Google Drive.
///
/// The app cannot see Drive's pages or Android's installer, so what it can do
/// is say, before the person leaves, what the next 2-3 screens will ask of
/// them, and name who to call when installing fails or the update screen
/// comes back after installing.
const driveLink = 'https://drive.google.com/file/d/abc123/view';
const apkLink = 'https://absensas.com/selfservice.apk';
const playLink = 'https://play.google.com/store/apps/details?id=com.example';

AppVersionInfo version({
  int build = 105,
  bool force = true,
  String url = driveLink,
  String? notes = 'Perbaikan',
}) => AppVersionInfo(
  version: '1.0.$build',
  buildNumber: build,
  forceUpdate: force,
  downloadUrl: url,
  releaseNotes: notes,
);

class Harness {
  Harness({this.installed = 104, AppVersionInfo? answer})
    : answer = answer ?? version();

  int? installed;
  AppVersionInfo? answer;
  bool openSucceeds = true;
  final opened = <Uri>[];

  late final AppUpdateController controller = Get.put(
    AppUpdateController(
      fetchLatest: () async => answer,
      installedBuild: () async => installed,
      openUrl: (url) async {
        opened.add(url);
        return openSucceeds;
      },
      storage: InMemoryLocalStorage(),
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

  group('AppVersionInfo.opensStore', () {
    test('an app store link installs through the store', () {
      for (final url in [
        playLink,
        'market://details?id=com.example',
        'https://apps.apple.com/id/app/x/id1',
        'https://itunes.apple.com/app/id1',
        'https://testflight.apple.com/join/abc',
      ]) {
        expect(version(url: url).opensStore, isTrue, reason: url);
      }
    });

    test('a Drive share page or an APK link is installed by hand', () {
      for (final url in [driveLink, apkLink, 'http://10.0.2.2:8000/x.apk']) {
        expect(version(url: url).opensStore, isFalse, reason: url);
      }
    });
  });

  group('Forced update, installed by hand', () {
    Future<Harness> pump(
      WidgetTester tester,
      Harness h, {
      Size size = const Size(390, 844),
      double textScale = 1.0,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await h.controller.check();
      await tester.pumpWidget(
        GetMaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: AppUpdateGate(child: child!),
          ),
          home: const Scaffold(body: Text('beranda')),
        ),
      );
      await tester.pump();
      return h;
    }

    Future<void> stop(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await Get.delete<AppUpdateController>(force: true);
    }

    testWidgets('a Drive link shows the steps Drive and Android will ask for', (
      tester,
    ) async {
      await pump(tester, Harness());

      expect(find.text('Pembaruan Wajib'), findsOneWidget);
      expect(find.text('Cara memasang'), findsOneWidget);
      expect(find.textContaining('Google Drive'), findsOneWidget);
      expect(find.textContaining('file .apk'), findsOneWidget);
      expect(find.textContaining('izinkan pemasangan'), findsOneWidget);
      expect(find.textContaining('buka kembali aplikasi'), findsOneWidget);
      await stop(tester);
    });

    testWidgets('it names who to call, and shows the builds they will need', (
      tester,
    ) async {
      await pump(tester, Harness());

      expect(find.textContaining('hubungi HR/IT'), findsOneWidget);
      expect(
        find.text('Terpasang: build 104 · Dibutuhkan: build 105'),
        findsOneWidget,
      );
      await stop(tester);
    });

    testWidgets('a store link leaves the installing to the store', (
      tester,
    ) async {
      await pump(tester, Harness(answer: version(url: playLink)));

      expect(find.text('Pembaruan Wajib'), findsOneWidget);
      expect(find.text('Cara memasang'), findsNothing);
      expect(find.textContaining('file .apk'), findsNothing);
      // Still someone to call, and still the builds to quote.
      expect(find.textContaining('hubungi HR/IT'), findsOneWidget);
      expect(
        find.text('Terpasang: build 104 · Dibutuhkan: build 105'),
        findsOneWidget,
      );
      await stop(tester);
    });

    testWidgets('fits a 320dp phone at 1.5x text with long notes, and the '
        'button stays on screen', (tester) async {
      await pump(
        tester,
        Harness(
          answer: version(notes: List.filled(40, 'Perbaikan.').join(' ')),
        ),
        size: const Size(320, 640),
        textScale: 1.5,
      );

      expect(tester.takeException(), isNull);
      final button = tester.getRect(
        find.byKey(const Key('app-update-download')),
      );
      expect(button.bottom, lessThanOrEqualTo(640));
      expect(button.top, greaterThanOrEqualTo(0));

      // The help and the builds are reachable by scrolling.
      await tester.scrollUntilVisible(
        find.text('Terpasang: build 104 · Dibutuhkan: build 105'),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      expect(tester.takeException(), isNull);
      await stop(tester);
    });

    testWidgets('the button opens exactly the link that was set', (
      tester,
    ) async {
      final h = await pump(tester, Harness());

      await tester.tap(find.byKey(const Key('app-update-download')));
      await tester.pump();

      expect(h.opened.single.toString(), driveLink);
      await stop(tester);
    });
  });

  group('Optional update, installed by hand', () {
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

    Future<void> stop(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await Get.delete<AppUpdateController>(force: true);
    }

    testWidgets('says the file has to be opened to install it', (tester) async {
      await pump(tester, Harness(answer: version(force: false)));

      expect(find.text('Update Tersedia'), findsOneWidget);
      expect(find.textContaining('file .apk'), findsOneWidget);
      await stop(tester);
    });

    testWidgets('a link that cannot be opened says so instead of doing '
        'nothing', (tester) async {
      final h = Harness(answer: version(force: false))..openSucceeds = false;
      await pump(tester, h);

      await tester.tap(find.byKey(const Key('app-update-open')));
      await tester.pump();

      expect(h.opened, hasLength(1));
      expect(
        find.textContaining('Tautan pembaruan tidak dapat dibuka'),
        findsOneWidget,
      );
      await stop(tester);
    });

    testWidgets('a store link carries no .apk hint', (tester) async {
      await pump(tester, Harness(answer: version(force: false, url: playLink)));

      expect(find.text('Update Tersedia'), findsOneWidget);
      expect(find.textContaining('file .apk'), findsNothing);
      await stop(tester);
    });
  });
}

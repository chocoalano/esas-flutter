import 'package:esas/core/storage/local_storage.dart';
import 'package:esas/features/app_update/data/app_version_info.dart';
import 'package:esas/features/app_update/presentation/app_update_controller.dart';
import 'package:esas/features/app_update/presentation/app_update_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

const oldPackage = 'com.example.esas';
const newPackage = 'com.absensas.app';
const newUrl = 'https://download.absensas.com/absensas.apk';

Map<String, dynamic> payload({
  Object? replacement,
  bool force = false,
  int build = 105,
}) => {
  'version': '1.0.$build',
  'build_number': build,
  'force_update': force,
  'download_url': 'https://download.absensas.com/selfservice.apk',
  'replacement': replacement,
};

Map<String, dynamic> replacementJson({
  String package = newPackage,
  String url = newUrl,
  Object? message,
}) => {'package': package, 'download_url': url, 'message': ?message};

class Harness {
  Harness({
    this.installedBuild = 104,
    this.package = oldPackage,
    LocalStorage? storage,
  }) : storage = storage ?? InMemoryLocalStorage();

  int installedBuild;
  String? package;
  Map<String, dynamic> answer = payload(replacement: replacementJson());
  final opened = <Uri>[];
  final LocalStorage storage;

  late final AppUpdateController controller = Get.put(
    AppUpdateController(
      fetchLatest: () async => AppVersionInfo.fromJson(answer),
      installedBuild: () async => installedBuild,
      installedPackage: () async => package,
      openUrl: (url) async {
        opened.add(url);
        return true;
      },
      storage: storage,
      interval: const Duration(hours: 1),
    ),
  );
}

Future<void> pumpGate(
  WidgetTester tester, {
  double textScale = 1.0,
  Size size = const Size(400, 800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: AppUpdateGate(child: child!),
      ),
      home: const Scaffold(body: Center(child: Text('Beranda'))),
    ),
  );
  await tester.pump();
  await tester.pump();
}

Future<void> closeGate(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await Get.delete<AppUpdateController>(force: true);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() async {
    await Get.deleteAll(force: true);
    Get.reset();
  });

  group('AppReplacement.fromJson', () {
    test('null and absent give no replacement', () {
      expect(AppVersionInfo.fromJson(payload())!.replacement, isNull);
      expect(
        AppVersionInfo.fromJson(
          {...payload()}..remove('replacement'),
        )!.replacement,
        isNull,
      );
    });

    test('a valid object is read', () {
      final r = AppVersionInfo.fromJson(
        payload(replacement: replacementJson(message: ' Hubungi HR ')),
      )!.replacement!;
      expect(r.package, newPackage);
      expect(r.downloadUrl, newUrl);
      expect(r.message, 'Hubungi HR');
    });

    test('a malformed object is ignored without losing the version', () {
      for (final bad in <Object>[
        'x',
        5,
        <String>[],
        {'package': 3, 'download_url': newUrl},
        {'package': '', 'download_url': newUrl},
        {'package': newPackage},
      ]) {
        final info = AppVersionInfo.fromJson(payload(replacement: bad));
        expect(info, isNotNull);
        expect(info!.replacement, isNull, reason: '$bad');
      }
    });

    test('only https download links are accepted', () {
      for (final url in [
        'http://x.com/a.apk',
        'javascript:alert(1)',
        'market://details?id=a',
        'https://',
        '',
      ]) {
        expect(
          AppVersionInfo.fromJson(
            payload(replacement: replacementJson(url: url)),
          )!.replacement,
          isNull,
          reason: url,
        );
      }
    });
  });

  group('controller', () {
    test(
      'a different package yields a migration and suppresses the forced update',
      () async {
        final h = Harness()
          ..answer = payload(replacement: replacementJson(), force: true);
        await h.controller.check();
        expect(h.controller.migration.value?.package, newPackage);
        expect(h.controller.requirement.value, UpdateRequirement.none);
        expect(h.controller.showMigration, isTrue);
      },
    );

    test(
      'the same package never yields a migration, and the force update runs as before',
      () async {
        final h = Harness()
          ..answer = payload(
            replacement: replacementJson(package: oldPackage),
            force: true,
          );
        await h.controller.check();
        expect(h.controller.migration.value, isNull);
        expect(h.controller.requirement.value, UpdateRequirement.required);
      },
    );

    test('an unknown running package never shows a migration', () async {
      final h = Harness(package: null);
      await h.controller.check();
      expect(h.controller.migration.value, isNull);
    });

    test('no replacement behaves exactly as before', () async {
      final h = Harness()..answer = payload(force: true);
      await h.controller.check();
      expect(h.controller.migration.value, isNull);
      expect(h.controller.requirement.value, UpdateRequirement.required);
    });

    test('a dismissal is remembered for that build and package only', () async {
      final h = Harness();
      await h.controller.check();
      await h.controller.dismissMigration();
      expect(h.controller.showMigration, isFalse);

      // A later check of the same record stays closed, also after a restart.
      await h.controller.check();
      expect(h.controller.showMigration, isFalse);
      await Get.deleteAll(force: true);
      final restarted = Harness(storage: h.storage);
      await restarted.controller.check();
      expect(restarted.controller.showMigration, isFalse);

      // A different replacement package is a new notice.
      restarted.answer = payload(
        replacement: replacementJson(package: 'com.absensas.other'),
      );
      await restarted.controller.check();
      expect(restarted.controller.showMigration, isTrue);

      // So is a newer build of the same replacement.
      await restarted.controller.dismissMigration();
      restarted.answer = payload(
        build: 106,
        replacement: replacementJson(package: 'com.absensas.other'),
      );
      await restarted.controller.check();
      expect(restarted.controller.showMigration, isTrue);
    });
  });

  group('MigrationNoticeCard', () {
    testWidgets(
      'shows the exact copy for a different package and opens the exact URL once',
      (tester) async {
        final h = Harness();
        await h.controller.check();
        await pumpGate(tester);

        expect(
          find.text('Absensas Pindah ke Aplikasi Resmi Baru'),
          findsOneWidget,
        );
        expect(
          find.text(
            'Pasang aplikasi Absensas yang baru dan masuk menggunakan akun Anda. '
            'Data absensi dan pekerjaan tetap tersimpan di server. '
            'Untuk menggunakan absensi pada aplikasi baru, lakukan aktivasi perangkat melalui HR. '
            'Hapus aplikasi lama hanya setelah aplikasi baru berfungsi.',
          ),
          findsOneWidget,
        );
        expect(find.text('Unduh Aplikasi Baru'), findsOneWidget);
        expect(h.opened, isEmpty, reason: 'nothing opens by itself');

        await tester.tap(find.text('Unduh Aplikasi Baru'));
        await tester.pump();
        expect(h.opened.map((u) => u.toString()), [newUrl]);
        expect(find.text('Beranda'), findsOneWidget);
        await closeGate(tester);
      },
    );

    testWidgets('shows the optional message beneath', (tester) async {
      final h = Harness()
        ..answer = payload(
          replacement: replacementJson(
            message: 'Aktivasi dibuka hingga Jumat.',
          ),
        );
      await h.controller.check();
      await pumpGate(tester);
      expect(find.text('Aktivasi dibuka hingga Jumat.'), findsOneWidget);
      await closeGate(tester);
    });

    testWidgets('is hidden for the same package', (tester) async {
      final h = Harness()
        ..answer = payload(replacement: replacementJson(package: oldPackage));
      await h.controller.check();
      await pumpGate(tester);
      expect(find.text('Absensas Pindah ke Aplikasi Resmi Baru'), findsNothing);
      await closeGate(tester);
    });

    testWidgets('"Nanti" dismisses it and the app stays usable', (
      tester,
    ) async {
      final h = Harness();
      await h.controller.check();
      await pumpGate(tester);

      await tester.tap(find.text('Nanti'));
      await tester.pump();
      expect(find.text('Absensas Pindah ke Aplikasi Resmi Baru'), findsNothing);
      expect(find.text('Beranda'), findsOneWidget);
      expect(h.opened, isEmpty);
      await closeGate(tester);
    });

    testWidgets('does not overflow at 320x640 with 1.5x text, message included', (
      tester,
    ) async {
      final h = Harness()
        ..answer = payload(
          replacement: replacementJson(
            message:
                'Pesan tambahan yang cukup panjang agar kartu harus menggulir di layar kecil. ' *
                3,
          ),
        );
      await h.controller.check();
      await pumpGate(tester, textScale: 1.5, size: const Size(320, 640));

      expect(tester.takeException(), isNull);
      expect(find.text('Nanti'), findsOneWidget);
      expect(find.text('Unduh Aplikasi Baru'), findsOneWidget);
      final card = tester.getRect(find.byType(MigrationNoticeCard));
      expect(card.top, greaterThanOrEqualTo(0));
      expect(card.bottom, lessThanOrEqualTo(640));
      await closeGate(tester);
    });
  });
}

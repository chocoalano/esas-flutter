import 'dart:io';

import 'package:esas/core/network/api_exception.dart';
import 'package:esas/core/theme/app_theme.dart';
import 'package:esas/features/profile/data/repositories/profile_repository.dart';
import 'package:esas/features/profile/presentation/controllers/profile_bug_report_controller.dart';
import 'package:esas/features/profile/presentation/views/profile_bug_report_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

class _Repo extends Mock implements ProfileRepository {}

/// PROF-08. A fresh Idempotency-Key was minted for every tap, so "Kirim" again
/// after a timeout filed the same report twice. And the "Bug Aktif" box was
/// never sent — the server sets a report's status itself and takes none.
void main() {
  late _Repo repo;
  late List<String?> keys;

  setUpAll(() => registerFallbackValue(File('')));

  setUp(() {
    Get.testMode = true;
    repo = _Repo();
    keys = [];
  });

  tearDown(Get.reset);

  void answer(List<Object?> outcomes) {
    var call = 0;
    when(
      () => repo.submitBugReport(
        title: any(named: 'title'),
        message: any(named: 'message'),
        platform: any(named: 'platform'),
        screenshot: any(named: 'screenshot'),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    ).thenAnswer((invocation) async {
      keys.add(invocation.namedArguments[#idempotencyKey] as String?);
      final outcome = outcomes[call++];
      if (outcome != null) throw outcome;
    });
  }

  ProfileBugReportController filled({String title = 'Layar putih'}) {
    final controller = ProfileBugReportController(repository: repo);
    controller.titleController.text = title;
    controller.messageController.text = 'Setelah login layar putih.';
    controller.pickedImage.value = File('${Directory.systemTemp.path}/s.png');
    return controller;
  }

  test('a retry after no answer reuses the key', () async {
    answer([const ApiException('timeout', code: 'network_timeout'), null]);
    final controller = filled();

    await controller.submitBugReport();
    await controller.submitBugReport();

    expect(keys, hasLength(2));
    expect(keys.first, isNotNull);
    expect(keys.last, keys.first);
  });

  test('a new report after one was filed gets a new key', () async {
    answer([null, null]);
    final controller = filled();

    await controller.submitBugReport();
    controller.titleController.text = 'Tombol absen tidak muncul';
    controller.messageController.text = 'Di halaman beranda.';
    controller.pickedImage.value = File('${Directory.systemTemp.path}/t.png');
    await controller.submitBugReport();

    expect(keys, hasLength(2));
    expect(keys.last, isNot(keys.first));
  });

  test(
    'a report the server refused is a new attempt when sent again',
    () async {
      answer([const ApiException('Judul terlalu panjang.', status: 422), null]);
      final controller = filled();

      await controller.submitBugReport();
      await controller.submitBugReport();

      expect(keys.last, isNot(keys.first));
    },
  );

  testWidgets('the form offers no status the server will not take', (
    tester,
  ) async {
    Get.put(ProfileBugReportController(repository: repo));
    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.lightTheme,
        home: const ProfileBugReportView(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bug Aktif'), findsNothing);
  });
}

import 'dart:async';
import 'dart:convert';

import 'package:esas/core/network/api_exception.dart';
import 'package:esas/core/storage/local_storage.dart';
import 'package:esas/core/storage/token_storage.dart';
import 'package:esas/features/auth/data/models/auth_user.dart';
import 'package:esas/features/auth/data/repositories/session_repository.dart';
import 'package:esas/features/profile/data/repositories/profile_repository.dart';
import 'package:esas/features/profile/data/models/payslip.dart';
import 'package:esas/features/profile/data/repositories/payroll_repository.dart';
import 'package:esas/features/profile/data/services/profile_api_service.dart';
import 'package:esas/features/profile/presentation/controllers/profile_tab_controllers.dart';
import 'package:esas/features/profile/presentation/views/profile_payroll_view.dart';
import 'package:esas/features/profile/presentation/routes/profile_routes.dart';
import 'package:esas/features/notification/data/services/notification_sync_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

class MockProfileApi extends Mock implements ProfileApiService {}

class MockPayroll extends Mock implements PayrollRepository {}

Map<String, dynamic> slipJson(int id) => {
  'id': id,
  'period': {
    'code': '2026-09',
    'start_date': '2026-09-01',
    'end_date': '2026-09-30',
    'status': 'paid',
  },
  'employee': {'name': 'Budi'},
  'bank': {'number': 'REKENING-HISTORIS'},
  'earned_income': '1000000.00',
  'applied_deduction': 100000,
  'take_home_pay': '900000.00',
  'earnings': [
    {'label': 'Gaji pokok', 'amount': 1000000},
  ],
  'deductions': [
    {'label': 'PPh 21', 'amount': 100000},
  ],
};
PayslipPage page(int id, {int current = 1, int last = 1}) =>
    PayslipPage.fromJson({
      'data': [slipJson(id)],
      'current_page': current,
      'last_page': last,
    });

void main() {
  tearDown(() => Get.reset());

  test('repository reads the paginated list and exact slip envelope', () async {
    final api = MockProfileApi();
    when(() => api.payslips(page: 2)).thenAnswer(
      (_) async => {
        'data': [slipJson(7)],
        'current_page': 2,
        'last_page': 3,
      },
    );
    when(() => api.payslip(7)).thenAnswer((_) async => {'slip': slipJson(7)});
    final repository = PayrollRepository(api);
    expect((await repository.page(page: 2)).hasMore, isTrue);
    final slip = await repository.slip(7);
    expect(slip.takeHomePay, 900000);
    expect(slip.totalDeduction, 100000);
    expect(slip.bank['number'], 'REKENING-HISTORIS');
  });

  test('pdf must decode to an actual PDF, never an error page', () async {
    final api = MockProfileApi();
    when(() => api.payslipPdf(7)).thenAnswer(
      (_) async => {
        'content_base64': base64Encode(utf8.encode('%PDF-1.4 fixture')),
      },
    );
    expect((await PayrollRepository(api).pdf(7)).filename, 'slip-gaji-7.pdf');
    when(() => api.payslipPdf(7)).thenAnswer(
      (_) async => {
        'content_base64': base64Encode(utf8.encode('<html>error</html>')),
      },
    );
    await expectLater(PayrollRepository(api).pdf(7), throwsFormatException);
  });

  test(
    'missing amounts are an error, not a zero-pay slip or empty history',
    () async {
      final api = MockProfileApi();
      when(() => api.payslip(7)).thenAnswer(
        (_) async => {
          'slip': {
            'id': 7,
            'period': {'code': '2026-09'},
          },
        },
      );
      when(() => api.payslips(page: 1)).thenAnswer(
        (_) async => {
          'data': [
            {'id': 7},
          ],
        },
      );
      await expectLater(
        PayrollRepository(api).slip(7),
        throwsA(isA<ApiException>()),
      );
      await expectLater(
        PayrollRepository(api).page(),
        throwsA(isA<ApiException>()),
      );
    },
  );

  test('older responses cannot replace refreshed slips', () async {
    final repository = MockPayroll();
    final delayed = Completer<PayslipPage>();
    when(() => repository.page()).thenAnswer((_) => delayed.future);
    final controller = ProfilePayrollController(repository: repository);
    final old = controller.refreshSlips();
    when(() => repository.page()).thenAnswer((_) async => page(2));
    await controller.refreshSlips();
    delayed.complete(page(1));
    await old;
    expect(controller.slips.single.id, 2);
    expect(controller.isLoading.value, isFalse);
  });

  test('pagination advances only after a successful page', () async {
    final repository = MockPayroll();
    when(() => repository.page()).thenAnswer((_) async => page(1, last: 2));
    when(
      () => repository.page(page: 2),
    ).thenAnswer((_) async => page(2, current: 2, last: 2));
    final controller = ProfilePayrollController(repository: repository);
    await controller.refreshSlips();
    await controller.loadMore();
    expect(controller.slips.map((slip) => slip.id), [1, 2]);
    expect(controller.hasMore.value, isFalse);
  });

  test(
    'failed pagination keeps the current list and can retry the same page',
    () async {
      final repository = MockPayroll();
      when(() => repository.page()).thenAnswer((_) async => page(1, last: 2));
      when(
        () => repository.page(page: 2),
      ).thenThrow(const ApiException('Server tidak tersedia'));
      final controller = ProfilePayrollController(repository: repository);
      await controller.refreshSlips();
      await controller.loadMore();
      expect(controller.slips.single.id, 1);
      expect(controller.errorMessage.value, 'Server tidak tersedia');
      when(
        () => repository.page(page: 2),
      ).thenAnswer((_) async => page(2, current: 2, last: 2));
      await controller.loadMore();
      expect(controller.slips.length, 2);
    },
  );

  test(
    'opening profile preserves the authenticated tenant for push synchronization',
    () async {
      final session = SessionRepository(
        tokenStorage: InMemoryTokenStorage(),
        localStorage: InMemoryLocalStorage(),
      );
      await session.save(
        token: 'token',
        user: AuthUser.fromJson({'id': 7, 'tenant_id': 'workspace-a'}),
      );
      final api = MockProfileApi();
      when(() => api.profile()).thenAnswer(
        (_) async => {
          'user': {'id': 7, 'name': 'Budi'},
        },
      );
      await ProfileRepository(api: api, session: session).currentUser();
      expect(session.user?.raw['tenant_id'], 'workspace-a');
    },
  );

  test('payslip notification opens payroll with its identifier', () {
    final destination = NotificationDestination.fromData({
      'type': 'payslip.available',
      'slip_id': '7',
    });
    expect(destination.route, ProfileRoutes.payroll);
    expect(destination.arguments, {'slip_id': 7});
  });

  testWidgets(
    'payroll renders a list and fetches detail when a slip is opened',
    (tester) async {
      Get.testMode = true;
      final repository = MockPayroll();
      when(() => repository.page()).thenAnswer((_) async => page(7));
      when(
        () => repository.slip(7),
      ).thenAnswer((_) async => Payslip.fromJson(slipJson(7)));
      Get.put(ProfilePayrollController(repository: repository));
      await tester.pumpWidget(const GetMaterialApp(home: ProfilePayrollView()));
      await tester.pumpAndSettle();
      expect(find.text('2026-09'), findsOneWidget);
      await tester.tap(find.text('2026-09'));
      await tester.pumpAndSettle();
      expect(find.text('Gaji bersih'), findsOneWidget);
      expect(find.text('Gaji pokok'), findsOneWidget);
      await tester.drag(find.byType(ListView).last, const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(find.text('Unduh PDF'), findsOneWidget);
      verify(() => repository.slip(7)).called(1);
    },
  );
}

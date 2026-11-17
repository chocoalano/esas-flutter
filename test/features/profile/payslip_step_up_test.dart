import 'dart:convert';

import 'package:esas/core/network/api_exception.dart';
import 'package:esas/features/profile/data/repositories/payroll_repository.dart';
import 'package:esas/features/profile/data/services/payslip_step_up.dart';
import 'package:esas/features/profile/data/services/profile_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

/// WP-01 Final, G5: pay is read only after the server's password step-up.
class MockProfileApi extends Mock implements ProfileApiService {}

const _stepUp = ApiException(
  'Masukkan kembali kata sandi Anda untuk membuka data gaji.',
  status: 403,
  code: 'payslip_step_up_required',
);

Map<String, dynamic> _slips() => {
  'data': <Object>[],
  'current_page': 1,
  'last_page': 1,
};

Map<String, dynamic> _granted(String grant) => {
  'grant': grant,
  'expires_at': DateTime.now()
      .add(const Duration(minutes: 5))
      .toUtc()
      .toIso8601String(),
};

void main() {
  test(
    'a step-up refusal asks for the password once, and the view grant is reused while it lasts',
    () async {
      final api = MockProfileApi();
      var asked = 0;
      when(() => api.payslips(page: 1, grant: null)).thenThrow(_stepUp);
      when(
        () => api.payslips(page: 1, grant: 'view-1'),
      ).thenAnswer((_) async => _slips());
      when(
        () => api.payslipStepUp(
          password: 'rahasia',
          purpose: PayslipStepUp.view,
          slipId: null,
        ),
      ).thenAnswer((_) async => _granted('view-1'));

      final repository = PayrollRepository(
        api,
        askPassword: () async {
          asked++;
          return 'rahasia';
        },
        grants: PayslipGrantCache(),
      );

      await repository.page();
      await repository.page();

      expect(asked, 1);
      verify(
        () => api.payslipStepUp(
          password: 'rahasia',
          purpose: PayslipStepUp.view,
          slipId: null,
        ),
      ).called(1);
      verify(() => api.payslips(page: 1, grant: 'view-1')).called(2);
    },
  );

  test('cancelling the password asks nothing of the server', () async {
    final api = MockProfileApi();
    when(() => api.payslip(7, grant: null)).thenThrow(_stepUp);

    final repository = PayrollRepository(
      api,
      askPassword: () async => null,
      grants: PayslipGrantCache(),
    );

    await expectLater(
      repository.slip(7),
      throwsA(
        isA<ApiException>().having(
          (error) => error.code,
          'code',
          'payslip_step_up_cancelled',
        ),
      ),
    );
    verifyNever(
      () => api.payslipStepUp(
        password: any(named: 'password'),
        purpose: any(named: 'purpose'),
        slipId: any(named: 'slipId'),
      ),
    );
  });

  test('a PDF takes its own grant for that payslip, every time', () async {
    final api = MockProfileApi();
    final pdf = {
      'content_base64': base64Encode(utf8.encode('%PDF-1.4 fixture')),
      'encrypted': true,
      'password': 'Kp7mQx2RtV9wLz4N',
    };
    when(() => api.payslipPdf(7, grant: null)).thenThrow(_stepUp);
    when(
      () => api.payslipStepUp(
        password: 'rahasia',
        purpose: PayslipStepUp.download,
        slipId: 7,
      ),
    ).thenAnswer((_) async => _granted('download-7'));
    when(
      () => api.payslipPdf(7, grant: 'download-7'),
    ).thenAnswer((_) async => pdf);

    final repository = PayrollRepository(
      api,
      askPassword: () async => 'rahasia',
      grants: PayslipGrantCache(),
    );

    expect((await repository.pdf(7)).filename, 'slip-gaji-7.pdf');
    expect((await repository.pdf(7)).filename, 'slip-gaji-7.pdf');
    verify(
      () => api.payslipStepUp(
        password: 'rahasia',
        purpose: PayslipStepUp.download,
        slipId: 7,
      ),
    ).called(2);
  });

  test('a refusal that is not a step-up is passed on untouched', () async {
    final api = MockProfileApi();
    const disabled = ApiException(
      'Unduhan PDF slip gaji dinonaktifkan.',
      status: 403,
      code: 'payslip_pdf_disabled',
    );
    when(() => api.payslipPdf(7, grant: null)).thenThrow(disabled);
    var asked = 0;

    final repository = PayrollRepository(
      api,
      askPassword: () async {
        asked++;
        return 'rahasia';
      },
      grants: PayslipGrantCache(),
    );

    await expectLater(
      repository.pdf(7),
      throwsA(
        isA<ApiException>().having(
          (error) => error.code,
          'code',
          'payslip_pdf_disabled',
        ),
      ),
    );
    expect(asked, 0);
  });

  test('loans are pay too: asked behind the same step-up', () async {
    final api = MockProfileApi();
    when(() => api.loans(grant: null)).thenThrow(_stepUp);
    when(
      () => api.payslipStepUp(
        password: 'rahasia',
        purpose: PayslipStepUp.view,
        slipId: null,
      ),
    ).thenAnswer((_) async => _granted('view-9'));
    when(
      () => api.loans(grant: 'view-9'),
    ).thenAnswer((_) async => {'loans': <Object>[], 'outstanding_total': 0});

    final repository = PayrollRepository(
      api,
      askPassword: () async => 'rahasia',
      grants: PayslipGrantCache(),
    );

    expect((await repository.loans()).loans, isEmpty);
    verify(() => api.loans(grant: 'view-9')).called(1);
  });
}

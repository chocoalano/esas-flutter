import 'package:esas/features/auth/data/models/auth_user.dart';
import 'package:esas/features/auth/data/repositories/session_repository.dart';
import 'package:esas/features/home/data/repositories/home_repository.dart';
import 'package:esas/features/home/data/services/home_api_service.dart';
import 'package:esas/features/home/presentation/widgets/home_leave_balance.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Api extends Mock implements HomeApiService {}

class _Session extends Mock implements SessionRepository {}

/// HOME-08. Balances were read with `asInt`: a DECIMAL column sent as
/// "8.00" parsed as nothing and the row was dropped — "Belum ada saldo cuti" —
/// and a half day, 2.5, was shown as 2.
void main() {
  late _Api api;
  late HomeRepository repository;

  setUp(() {
    api = _Api();
    final session = _Session();
    when(() => session.user).thenReturn(AuthUser.fromJson({'id': 7}));
    repository = HomeRepository(api: api, session: session);
  });

  test('decimal strings and half days are kept as they are', () async {
    when(() => api.leaveBalance()).thenAnswer(
      (_) async => {
        'data': [
          {'code': 'ANNUAL', 'name': 'Cuti tahunan', 'remaining': '8.00', 'quota': '12.00'},
          {'code': 'SPECIAL', 'name': 'Cuti khusus', 'remaining': 2.5},
        ],
      },
    );

    final balances = await repository.leaveBalances();

    expect(balances, hasLength(2));
    expect(balances[0].remaining, 8);
    expect(balances[0].quota, 12);
    expect(balances[1].remaining, 2.5);
  });

  test('a half day is written the Indonesian way', () {
    expect(leaveDaysLabel(8), '8');
    expect(leaveDaysLabel(2.5), '2,5');
  });
}

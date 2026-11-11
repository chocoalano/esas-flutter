import 'package:esas/core/tenancy/tenant_context.dart';
import 'package:esas/core/storage/secure_store.dart';
import 'package:esas/features/auth/data/models/auth_user.dart';
import 'package:esas/features/auth/data/repositories/auth_repository.dart';
import 'package:esas/features/profile/data/models/user.dart';
import 'package:esas/features/profile/data/repositories/profile_repository.dart';
import 'package:esas/features/profile/presentation/controllers/profile_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

class _Repo extends Mock implements ProfileRepository {}

class _Auth extends Mock implements AuthRepository {}

/// PROF-02. The header read `employee.job_position.name` and
/// `employee.sign_date` from the session. Login sends `job_position` flat, as
/// a string, and no sign date at all — so every profile read "jabatan
/// pengguna" and "Bergabung" this month, from `DateTime.now()`.
void main() {
  late _Repo repo;
  late _Auth auth;

  setUp(() {
    Get.testMode = true;
    repo = _Repo();
    auth = _Auth();
    when(() => repo.attendanceSummary()).thenAnswer(
      (_) async => (points: 0.0, late: 0, attendance: 0, onTime: 0),
    );
    when(() => repo.currentUser()).thenAnswer((_) async => User());
  });

  tearDown(Get.reset);

  ProfileController build() => ProfileController(
    repository: repo,
    auth: auth,
    tenantContext: TenantContext(store: InMemorySecureStore()),
  );

  test('the job title comes from the login payload as it is sent', () {
    expect(
      AuthUser.fromJson({'job_position': 'Engineer'}).jobPosition,
      'Engineer',
    );
  });

  test('nothing known is shown as nothing, not as a placeholder or today', () {
    when(() => auth.user).thenReturn(AuthUser.fromJson({'id': 7}));

    final controller = build()..onInit();

    expect(controller.jobTitle.value, '—');
    expect(controller.joined.value, isNull);
  });

  test('once the profile has loaded, the sign date is shown', () async {
    var user = AuthUser.fromJson({'id': 7, 'job_position': 'Engineer'});
    when(() => auth.user).thenAnswer((_) => user);
    when(() => repo.currentUser()).thenAnswer((_) async {
      // What ProfileRepository does: the employment block joins the session.
      user = AuthUser.fromJson({
        'id': 7,
        'job_position': 'Engineer',
        'employee': {'sign_date': '2020-01-06'},
      });
      return User();
    });

    final controller = build()..onInit();
    await pumpEventQueue();

    expect(controller.jobTitle.value, 'Engineer');
    expect(controller.joined.value, DateTime(2020, 1, 6));
  });
}

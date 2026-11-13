import 'package:esas/core/network/api_exception.dart';
import 'package:esas/core/storage/secure_store.dart';
import 'package:esas/core/tenancy/tenant_context.dart';
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

/// UX-C16. A summary that failed to load used to leave the counters at zero,
/// so the profile showed "0%" and "Perlu perhatian" - a load failure read as
/// a poor attendance record. The failure is now its own state.
void main() {
  late _Repo repo;
  late _Auth auth;

  setUp(() {
    Get.testMode = true;
    repo = _Repo();
    auth = _Auth();
    when(() => auth.user).thenReturn(AuthUser.fromJson({'id': 7}));
    when(() => repo.currentUser()).thenAnswer((_) async => User());
  });

  tearDown(Get.reset);

  ProfileController build() => ProfileController(
    repository: repo,
    auth: auth,
    tenantContext: TenantContext(store: InMemorySecureStore()),
  );

  test('a failed summary is a failure, not a score of zero', () async {
    when(
      () => repo.attendanceSummary(),
    ).thenThrow(const ApiException('Server error', status: 500));

    final controller = build();
    await controller.loadSummary();

    expect(controller.summaryFailed.value, isTrue);
    expect(controller.isLoadingInitial.value, isFalse);
  });

  test('a retry that succeeds clears the failure and shows the record', () async {
    var fail = true;
    when(() => repo.attendanceSummary()).thenAnswer((_) async {
      if (fail) {
        throw const ApiException('Timeout', status: 0);
      }
      return (points: 92.0, late: 1, attendance: 12, onTime: 11);
    });

    final controller = build();
    await controller.loadSummary();
    expect(controller.summaryFailed.value, isTrue);

    fail = false;
    await controller.loadSummary();

    expect(controller.summaryFailed.value, isFalse);
    expect(controller.points.value, 92.0);
    expect(controller.unlate.value, 11);
  });
}

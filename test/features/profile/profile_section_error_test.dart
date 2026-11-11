import 'package:esas/core/network/api_exception.dart';
import 'package:esas/features/profile/data/repositories/profile_repository.dart';
import 'package:esas/features/profile/presentation/controllers/profile_section_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

class _Repo extends Mock implements ProfileRepository {}

class _Section extends ProfileSectionController {
  _Section(ProfileRepository repository) : super(repository: repository);
}

/// PROF-06. Every refusal that was not a lost connection read "Data pengguna
/// tidak ditemukan" — a 500, a 403, an expired session alike — and a reply
/// that did not parse escaped the `catch` and left the tab spinning.
void main() {
  late _Repo repo;

  setUp(() {
    Get.testMode = true;
    repo = _Repo();
  });

  tearDown(Get.reset);

  Future<_Section> loadWith(Object error) async {
    when(
      () => repo.currentUser(refresh: any(named: 'refresh')),
    ).thenAnswer((_) async => throw error);
    final section = _Section(repo);
    await section.loadProfile();
    return section;
  }

  test('a 404 is "not found"', () async {
    final section = await loadWith(
      const ApiException('Not found', status: 404),
    );
    expect(section.errorMessage.value, 'Data pengguna tidak ditemukan.');
  });

  test('a server fault says what the server said', () async {
    final section = await loadWith(
      const ApiException('Server sedang pemeliharaan.', status: 503),
    );
    expect(section.errorMessage.value, 'Server sedang pemeliharaan.');
  });

  test('a reply that does not parse is reported, not left spinning', () async {
    final section = await loadWith(TypeError());
    expect(section.isLoading.value, isFalse);
    expect(section.errorMessage.value, contains('tidak dapat dibaca'));
  });
}

import 'dart:async';
import 'dart:io';

import 'package:esas/core/storage/secure_store.dart';
import 'package:esas/core/tenancy/tenant_context.dart';
import 'package:esas/features/auth/data/models/auth_user.dart';
import 'package:esas/features/auth/data/repositories/auth_repository.dart';
import 'package:esas/features/profile/data/models/user.dart';
import 'package:esas/features/profile/data/repositories/profile_repository.dart';
import 'package:esas/features/profile/presentation/controllers/profile_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';

class _Repo extends Mock implements ProfileRepository {}

class _Auth extends Mock implements AuthRepository {}

class _Picker extends Mock implements ImagePicker {}

/// PROF-11. The avatar went up at the camera's full resolution — often more
/// than the server's 5 MB limit, so the upload was refused — and a second
/// photo chosen while the first was uploading was dropped without a word.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Repo repo;
  late _Picker picker;
  late ProfileController controller;

  setUpAll(() {
    registerFallbackValue(File(''));
    registerFallbackValue(ImageSource.gallery);
  });

  setUp(() {
    Get.testMode = true;
    repo = _Repo();
    picker = _Picker();
    final auth = _Auth();
    when(() => auth.user).thenReturn(AuthUser.fromJson({'id': 7}));
    when(
      () => repo.attendanceSummary(),
    ).thenAnswer((_) async => (points: 0.0, late: 0, attendance: 0, onTime: 0));
    when(() => repo.currentUser()).thenAnswer((_) async => User());
    when(
      () => picker.pickImage(
        source: any(named: 'source'),
        maxWidth: any(named: 'maxWidth'),
        maxHeight: any(named: 'maxHeight'),
        imageQuality: any(named: 'imageQuality'),
      ),
    ).thenAnswer((_) async => XFile('${Directory.systemTemp.path}/a.jpg'));
    controller = ProfileController(
      repository: repo,
      auth: auth,
      tenantContext: TenantContext(store: InMemorySecureStore()),
      imagePicker: picker,
    );
  });

  tearDown(Get.reset);

  test('the picture is scaled down before it is sent', () async {
    when(
      () => repo.uploadAvatar(any()),
    ).thenAnswer((_) async => 'avatars/a.jpg');

    await controller.pickImageFromGallery();

    final call = verify(
      () => picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: captureAny(named: 'maxWidth'),
        maxHeight: captureAny(named: 'maxHeight'),
        imageQuality: captureAny(named: 'imageQuality'),
      ),
    )..called(1);
    final [maxWidth, maxHeight, quality] = call.captured;
    expect(maxWidth, isNotNull);
    expect(maxWidth as double, lessThanOrEqualTo(1024));
    expect(maxHeight as double, lessThanOrEqualTo(1024));
    expect(quality as int, lessThan(100));
  });

  test('a second pick while uploading does not open the picker', () async {
    final upload = Completer<String?>();
    when(() => repo.uploadAvatar(any())).thenAnswer((_) => upload.future);

    final first = controller.pickImageFromGallery();
    await pumpEventQueue();
    expect(controller.isUploading.value, isTrue);

    await controller.pickImageFromGallery();

    verify(
      () => picker.pickImage(
        source: any(named: 'source'),
        maxWidth: any(named: 'maxWidth'),
        maxHeight: any(named: 'maxHeight'),
        imageQuality: any(named: 'imageQuality'),
      ),
    ).called(1);

    upload.complete('avatars/a.jpg');
    await first;
    expect(controller.avatar.value, 'avatars/a.jpg');
  });
}

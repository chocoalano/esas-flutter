import 'dart:io';

import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import 'package:esas/features/auth/presentation/routes/auth_routes.dart';
import 'package:esas/features/setup/presentation/routes/setup_routes.dart';
import '../../../../core/tenancy/tenant_context.dart';
import '../../../../core/ui/dialogs/app_snackbar.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../features/auth/data/repositories/auth_repository.dart';
import '../../data/repositories/profile_repository.dart';

class ProfileController extends GetxController {
  ProfileController({
    required ProfileRepository repository,
    required AuthRepository auth,
    required TenantContext tenantContext,
    ImagePicker? imagePicker,
  }) : _repository = repository,
       _auth = auth,
       _tenantContext = tenantContext,
       _imagePicker = imagePicker ?? ImagePicker();

  final ProfileRepository _repository;
  final AuthRepository _auth;
  final TenantContext _tenantContext;
  final ImagePicker _imagePicker;

  /// The workspace this handset is signed in to, for the profile screen to show.
  String get workspace => _tenantContext.tenant ?? '—';

  final RxString avatar = ''.obs;
  final RxString name = 'nama pengguna'.obs;
  final RxString jobTitle = 'jabatan pengguna'.obs;
  final RxString status = 'status pengguna'.obs;
  final Rx<DateTime> joined = DateTime.now().obs;

  final RxInt late = 0.obs;
  final RxInt attendance = 0.obs;
  final RxInt unlate = 0.obs;
  final RxDouble points = 0.0.obs;

  final RxBool isLoadingInitial = false.obs;
  final RxBool isUploading = false.obs;

  final Rxn<File> pickedImageFile = Rxn<File>();

  @override
  void onInit() {
    super.onInit();
    _readFromSession();
    loadSummary();
  }

  void _readFromSession() {
    final user = _auth.user;

    avatar.value = user?.avatar ?? '';
    name.value = user?.name ?? 'nama pengguna';
    jobTitle.value = user?.jobPosition ?? 'jabatan pengguna';
    status.value = user?.status ?? 'status pengguna';
    joined.value = user?.signDate ?? DateTime.now();
  }

  Future<void> loadSummary() async {
    isLoadingInitial.value = true;

    try {
      final summary = await _repository.attendanceSummary();

      points.value = summary.points;
      late.value = summary.late;
      attendance.value = summary.attendance;
      unlate.value = summary.onTime;
    } on ApiException catch (error) {
      AppLogger.warning(
        'Could not load the attendance summary: ${error.status}',
      );
    } finally {
      isLoadingInitial.value = false;
    }
  }

  Future<void> pickImageFromGallery() async {
    try {
      final image = await _imagePicker.pickImage(source: ImageSource.gallery);

      if (image == null) {
        showInfoSnackbar('Tidak ada gambar yang dipilih.');
        return;
      }

      pickedImageFile.value = File(image.path);
      await uploadProfilePicture(pickedImageFile.value!);
    } catch (error, stackTrace) {
      AppLogger.error(
        'Image picker failed',
        error: error,
        stackTrace: stackTrace,
      );
      showErrorSnackbar('Gagal memilih gambar.');
    }
  }

  Future<void> uploadProfilePicture(File imageFile) async {
    if (isUploading.value) {
      return;
    }

    isUploading.value = true;

    try {
      final newAvatar = await _repository.uploadAvatar(imageFile);

      if (newAvatar == null) {
        showErrorSnackbar('Upload gagal. Coba lagi.');
        return;
      }

      avatar.value = newAvatar;
      showSuccessSnackbar('Foto profil berhasil diunggah!');
    } on ApiException catch (error) {
      showErrorSnackbar('Upload gagal: ${error.message}');
    } finally {
      isUploading.value = false;
      pickedImageFile.value = null;
    }
  }

  /// Sign out.
  ///
  /// The local session is cleared whatever the server answers — that decision
  /// lives in `AuthRepository` now. The version this replaces cleared only on a
  /// 200, so a failed logout left the employee signed in against a session the
  /// server may already have dropped, and reported it with the message "Gagal
  /// memilih gambar", pasted from the avatar picker above (LOW-05).
  Future<void> logout() async {
    await _auth.logout();

    showSuccessSnackbar('Anda berhasil logout.', title: 'Berhasil');
    Get.offAllNamed(AuthRoutes.login);
  }

  /// Hand this handset to another company.
  ///
  /// Deliberately separate from [logout], and deliberately harder to reach.
  /// Signing out ends a *credential*; an employee who signs out still works
  /// where they worked, and being asked for the workspace at every login is
  /// friction with no security value (ADR-0005 §3).
  ///
  /// The session is ended first and the workspace second, in that order: the
  /// token was minted in the old workspace's database and is worth nothing
  /// anywhere else, so leaving it behind would strand a credential that can
  /// never be used and never be revoked from here.
  Future<void> switchWorkspace() async {
    await _auth.logout();
    await _tenantContext.clear();

    showInfoSnackbar(
      'Workspace dilepas. Masukkan kode workspace yang baru.',
      title: 'Pindah Workspace',
    );
    Get.offAllNamed(SetupRoutes.setup);
  }
}

import 'dart:io';

import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import 'package:esas/features/auth/presentation/routes/auth_routes.dart';
import 'package:esas/features/setup/presentation/routes/setup_routes.dart';
import '../../../../core/config/server_config.dart';
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

  /// The active environment label (Produksi, Development, Staging).
  String get environmentLabel {
    if (Get.isRegistered<ServerConfig>()) {
      return Get.find<ServerConfig>().environmentLabel;
    }
    return '';
  }

  final RxString avatar = ''.obs;
  final RxString name = '—'.obs;
  final RxString jobTitle = '—'.obs;
  final RxString status = '—'.obs;

  /// Null when not known yet. It used to fall back to `DateTime.now()`, a date
  /// that looked real and was not (PROF-02).
  final Rxn<DateTime> joined = Rxn<DateTime>();

  final RxInt late = 0.obs;
  final RxInt attendance = 0.obs;
  final RxInt unlate = 0.obs;
  final RxDouble points = 0.0.obs;

  final RxBool isLoadingInitial = false.obs;

  /// The attendance summary could not be read (UX-C16). A failed load is not
  /// a score of zero, so the cards show that it failed instead of "0%".
  final RxBool summaryFailed = false.obs;
  final RxBool isUploading = false.obs;

  final Rxn<File> pickedImageFile = Rxn<File>();

  @override
  void onInit() {
    super.onInit();
    _readFromSession();
    loadSummary();
    _loadEmployment();
  }

  /// What is unknown is shown as "—", never as a placeholder that reads like
  /// data (PROF-02).
  void _readFromSession() {
    final user = _auth.user;

    avatar.value = user?.avatar ?? '';
    name.value = user?.name ?? '—';
    jobTitle.value = user?.jobPosition ?? '—';
    status.value = user?.status ?? '—';
    joined.value = user?.signDate;
  }

  /// The sign date is on the employee record, not on the sign-in payload.
  /// Loading it puts the employment block on the session; read it again.
  Future<void> _loadEmployment() async {
    try {
      await _repository.currentUser();
      if (!isClosed) _readFromSession();
    } on ApiException catch (error) {
      AppLogger.warning('Profile header could not load: ${error.message}');
    }
  }

  Future<void> loadSummary() async {
    isLoadingInitial.value = true;

    try {
      final summary = await _repository.attendanceSummary();

      points.value = summary.points;
      late.value = summary.late;
      attendance.value = summary.attendance;
      unlate.value = summary.onTime;
      summaryFailed.value = false;
    } on ApiException catch (error) {
      summaryFailed.value = true;
      AppLogger.warning(
        'Could not load the attendance summary: ${error.status}',
      );
    } finally {
      isLoadingInitial.value = false;
    }
  }

  /// The largest side an avatar is sent at (PROF-11). It is drawn at 64dp;
  /// a phone camera's full resolution often exceeded the server's 5 MB limit,
  /// so the upload was refused.
  static const double avatarMaxSide = 1024;
  static const int avatarQuality = 85;

  Future<void> pickImageFromGallery() async {
    // A second photo chosen mid-upload used to be dropped without a word: the
    // upload refused it, and the first upload's `finally` cleared it.
    if (isUploading.value) {
      showInfoSnackbar('Tunggu foto sebelumnya selesai diunggah.');
      return;
    }

    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: avatarMaxSide,
        maxHeight: avatarMaxSide,
        imageQuality: avatarQuality,
      );

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
  ///
  /// Guarded (PROF-10): a second tap while the first is on its way does
  /// nothing, rather than signing out and navigating a second time.
  Future<void> logout() async {
    if (isLoggingOut.value) return;
    isLoggingOut.value = true;

    try {
      final confirmed = await _auth.logout();

      if (confirmed) {
        showSuccessSnackbar(signedOutMessage(confirmed: true));
      } else {
        showInfoSnackbar(signedOutMessage(confirmed: false), title: 'Keluar');
      }
      Get.offAllNamed(AuthRoutes.login);
    } finally {
      isLoggingOut.value = false;
    }
  }

  /// True while a sign-out, or a change of workspace, is under way.
  final RxBool isLoggingOut = false.obs;

  /// What to say once signed out (PROF-10). The handset is signed out either
  /// way; whether the server heard of it is the difference worth saying.
  static String signedOutMessage({required bool confirmed}) => confirmed
      ? 'Anda berhasil logout.'
      : 'Anda sudah keluar dari perangkat ini. Server tidak dapat dihubungi, '
            'jadi sesi di server akan berakhir dengan sendirinya.';

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
    if (isLoggingOut.value) return;
    isLoggingOut.value = true;

    try {
      await _auth.logout();
      await _tenantContext.clear();

      showInfoSnackbar(
        'Workspace dilepas. Masukkan kode workspace yang baru.',
        title: 'Pindah Workspace',
      );
      Get.offAllNamed(SetupRoutes.setup);
    } finally {
      isLoggingOut.value = false;
    }
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:introduction_screen/introduction_screen.dart';

import 'package:esas/features/auth/presentation/routes/auth_routes.dart';
import 'package:esas/features/home/presentation/routes/home_routes.dart';
import 'package:esas/features/setup/presentation/routes/setup_routes.dart';
import '../../../../core/config/server_config.dart';
import '../../../../core/tenancy/tenant_context.dart';
import '../../../../core/ui/dialogs/app_snackbar.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../core/storage/storage_keys.dart';
import '../../data/models/auth_user.dart';
import '../../../../utils/notification/firebase_messaging_services.dart';
import '../../data/repositories/auth_repository.dart';

class SplashController extends GetxController {
  SplashController({
    required AuthRepository authRepository,
    required LocalStorage localStorage,
    required ServerConfig serverConfig,
    required TenantContext tenantContext,
  }) : _auth = authRepository,
       _local = localStorage,
       _serverConfig = serverConfig,
       _tenantContext = tenantContext;

  final AuthRepository _auth;
  final LocalStorage _local;
  final ServerConfig _serverConfig;
  final TenantContext _tenantContext;

  /// Controls the onboarding screen.
  final introKey = GlobalKey<IntroductionScreenState>();

  final RxBool isLoading = false.obs;

  /// Selesai begitu pemeriksaan sesi memutuskan ke mana aplikasi dibuka.
  ///
  /// Onboarding berjalan di layar yang sama dengan pemeriksaan itu, jadi
  /// keduanya dulu berlomba: tombol "Mulai Sekarang!" mengirim orang ke layar
  /// masuk tanpa peduli bahwa sebuah token yang masih sah sedang diverifikasi
  /// beberapa milidetik jauhnya. Yang menang bukan jawaban yang benar,
  /// melainkan yang lebih cepat — dan yang lebih cepat adalah ibu jari.
  final Completer<void> _decided = Completer<void>();

  /// Satu perpindahan halaman, siapa pun yang memicunya lebih dulu.
  bool _navigated = false;

  // Deliberately `onReady`, not `onInit`.
  //
  // GetX calls `onInit` while the route's widget is being built, and `onReady`
  // from a post-frame callback. Navigating from the first is marking the
  // navigator dirty *during* a build, which Flutter refuses:
  //
  //     setState() or markNeedsBuild() called during build.
  //     The widget which was currently being built [...] was: SplashView
  //
  // This used to work by accident. Every outcome below sat behind
  // `await _auth.restoreSession()`, and an `async` function runs synchronously
  // only up to its first `await` — so navigation always landed in a later turn
  // of the event loop. The workspace check added for ADR-0005 §4 has no `await`
  // in front of it, which turned a latent assumption into a crash on first
  // launch. Moving the call here removes the assumption rather than restoring
  // it: no path can navigate mid-build now, awaited or not.
  @override
  void onReady() {
    super.onReady();
    _resolveStartDestination();
  }

  /// Decide where the app opens, from what the stored credential turns out to
  /// be worth.
  ///
  /// Four outcomes, where there used to be two. The old flow treated anything
  /// that was not a confirmed-valid token as a reason to wipe the session, and
  /// its probe swallowed `SocketException` in a bare `catch (_) {}` — so
  /// launching with no signal, on hotel wi-fi, or during a brief API outage
  /// signed the employee out and made them type their credentials again at the
  /// factory gate (HIGH-02).
  Future<void> _resolveStartDestination() async {
    isLoading.value = true;

    try {
      // Which workspace comes first, because without one there is nothing to
      // authenticate *against*: a token is minted in, and only valid in, one
      // company's database. A build may carry a workspace compiled in
      // (`--dart-define=TENANT`), and one that does opens straight on the
      // session check — every other build asks once, here (ADR-0005 §4).
      if (!_isConfigured) {
        _open(SetupRoutes.setup);

        return;
      }

      final state = await _auth.restoreSession();

      switch (state) {
        case SessionState.authenticated:
          showSuccessSnackbar('Selamat datang kembali!');
          // Tidak ditunggu: izin dan pendaftaran token tidak boleh menunda
          // layar pertama. Ini juga jalur pemulihan ketika seseorang menyalakan
          // notifikasi dari Setelan setelah sebelumnya menolak.
          unawaited(ensurePushRegisteredIfAvailable());
          _open(HomeRoutes.home);

        case SessionState.offline:
          // The credential is untouched. Say what happened and let them in to
          // retry rather than destroying a session we have no evidence against.
          showWarningSnackbar(
            'Tidak dapat menghubungi server. Periksa koneksi Anda.',
            title: 'Mode Luring',
          );
          _open(AuthRoutes.login);

        case SessionState.expired:
        case SessionState.absent:
          _open(AuthRoutes.login);
      }
    } finally {
      isLoading.value = false;

      if (!_decided.isCompleted) {
        _decided.complete();
      }
    }
  }

  /// Buka satu tujuan, sekali saja.
  void _open(String route) {
    if (_navigated) {
      return;
    }

    _navigated = true;
    Get.offAllNamed(route);
  }

  /// Whether this handset knows both halves of where it belongs.
  ///
  /// The address alone is not enough. A build ships with one compiled in, so
  /// `ServerConfig.isConfigured` is true on the very first launch; the workspace
  /// is the half nobody can guess for the employee.
  bool get _isConfigured =>
      _serverConfig.isConfigured && _tenantContext.isResolved;

  /// Called when the person finishes or skips onboarding.
  ///
  /// This used to navigate to the login screen itself, which made the tap a
  /// race against `_resolveStartDestination` — and one the tap could win. An
  /// employee whose stored token was still valid, who pressed "Mulai Sekarang!"
  /// while the probe was still in flight, was sent to log in again; the probe
  /// then finished, found a perfectly good session, and had nowhere to put it.
  ///
  /// It now defers to the probe instead of guessing: the tap waits for the one
  /// decision that has the evidence, and [_open] guarantees the app opens
  /// exactly one destination no matter which side gets there first. The last
  /// line is a floor, not a path anything is expected to take — if the probe
  /// somehow resolved without navigating, the login screen is still a better
  /// place to stand than an onboarding carousel with a dead button.
  ///
  /// The flag it writes is still **never read** (LOW-02): onboarding runs on
  /// every launch by product decision, and whether it should be gated is
  /// blocking question 8 in `docs/refactoring/05-progress.md`. Deleting the
  /// write before that is answered would throw away the only evidence of who
  /// has already seen the screens.
  Future<void> onIntroEnd() async {
    _local.write(StorageKeys.local.onboardingCompleted, true);

    if (_navigated) {
      return;
    }

    await _decided.future;

    _open(AuthRoutes.login);
  }
}

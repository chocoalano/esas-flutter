import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'app/bindings/initial_binding.dart';
import 'core/boot/boot_pipeline.dart';
import 'core/config/server_config.dart';
import 'core/storage/local_storage.dart';
import 'core/storage/secure_store.dart';
import 'core/storage/token_storage.dart';
import 'core/tenancy/tenant_context.dart';
import 'core/theme/system_ui_style.dart';
import 'core/theme/theme_controller.dart';
import 'core/utils/app_logger.dart';
import 'firebase_options.dart';
import 'utils/my_http_overrides.dart';
import 'utils/notification/notification_services.dart';

/// Bring the application up, in a defined order, with a defined answer for each
/// way a step can fail.
///
/// The order is not arbitrary — each step needs the one before it:
///
/// ```
/// Flutter binding      (the caller does this; nothing else can run first)
///        ↓
/// local storage        theme and session are read from it
///        ↓
/// server + tenancy     which backend, which workspace
///        ↓
/// Firebase             optional; push is an enhancement, not the product
///        ↓
/// dependencies         the composition root
///        ↓
/// notifications        needs the dependencies registered
///        ↓
/// system UI            needs the theme, which needs storage
/// ```
///
/// Returns a [BootReport] rather than throwing on a degraded start, so the app
/// can open and say what is missing instead of failing silently the way the old
/// `try { Firebase.initializeApp() } catch { debugPrint }` did.
Future<BootReport> bootstrap() async {
  final pipeline = BootPipeline();

  // ── Local storage ────────────────────────────────────────────────────────
  // Fatal. The theme, the session and the cached user all live here; an app
  // that cannot read it has nothing to show and nobody to show it to.
  await pipeline.required('storage', GetStorage.init);

  // Carried over verbatim from the old `main()`, where it was commented
  // "Small delay to allow native side to be ready (optional)".
  //
  // It reads as cargo cult and it costs 200ms on every cold start. It is kept
  // anyway: it sits immediately before `Firebase.initializeApp()`, which is
  // presumably what it was added for, and removing an unexplained sleep during
  // a structural refactor is how a heisenbug appears on one device model that
  // nobody here can reproduce. Delete it in its own change, with a measurement
  // and a device to test on.
  await Future<void>.delayed(const Duration(milliseconds: 200));

  final localStorage = GetStorageLocalStorage();
  final secureStore = KeychainSecureStore();
  final serverConfig = ServerConfig(store: secureStore);
  final tenantContext = TenantContext(store: secureStore);

  // ── Server address and workspace ─────────────────────────────────────────
  // Optional, and deliberately: both fall back to the compiled-in seed, and a
  // keystore that cannot be opened is a handset to be set up again rather than
  // a crash on the first frame.
  await pipeline.optional('server-config', serverConfig.restore);
  await pipeline.optional('tenancy', tenantContext.restore);

  // The token is **not** restored here, and that is on purpose.
  //
  // `SecureTokenStorage.restore()` migrates a legacy token out of GetStorage
  // and deletes the original. Every unmigrated screen still reads that original
  // through `ApiProvider`, so running the migration now would sign out every
  // existing user the moment they updated. It runs in Phase 3, in the same
  // change that moves authentication onto `AuthRepository`.
  final tokenStorage = SecureTokenStorage(
    store: secureStore,
    legacy: localStorage,
  );

  // ── Firebase ─────────────────────────────────────────────────────────────
  // Optional. ESAS is an ERP: attendance, permits and payslips do not need
  // push. The old code reached the same outcome by accident, via a `catch` that
  // only printed; this is the same behaviour chosen on purpose and recorded.
  //
  // Google sign-in and Firestore ride on it too. When it fails the login
  // screen simply has no Google button — signing in with a NIP never needed
  // Firebase. Options are explicit (project `absensascom`) rather than read
  // from the native files alone, so Dart and the platform cannot disagree.
  final hasFirebase = await pipeline.optional(
    'firebase',
    () =>
        Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
  );

  // ── Dependencies ─────────────────────────────────────────────────────────
  await pipeline.required('dependencies', () async {
    InitialBinding(
      localStorage: localStorage,
      secureStore: secureStore,
      serverConfig: serverConfig,
      tenantContext: tenantContext,
      tokenStorage: tokenStorage,
      hasFirebase: hasFirebase,
    ).dependencies();
  });

  // ── Notifications ────────────────────────────────────────────────────────
  // Local notifications first, and **not** gated on Firebase.
  //
  // `flutter_local_notifications` does not depend on Firebase, and
  // `initialize()` is what asks for the Android 13+ notification permission.
  // Gating it would mean a Firebase outage silently swallowed the permission
  // prompt — a user-visible change, and the old `main()` called it
  // unconditionally.
  final hasNotifications = await pipeline.optional(
    'notifications',
    Get.find<NotificationService>().initialize,
  );

  // Messaging *is* gated: it needs both. Registering it on top of a Firebase
  // that never came up only moves the failure to the first message, and
  // `FirebaseMessagingService.onInit` calls `Get.find<NotificationService>()`.
  if (hasFirebase && hasNotifications) {
    await pipeline.optional(
      'messaging',
      () async => InitialBinding.registerMessaging(),
    );
  } else {
    AppLogger.warning(
      'Push notifications are disabled this session '
      '(firebase: $hasFirebase, local notifications: $hasNotifications).',
    );
  }

  // ── Presentation chrome ──────────────────────────────────────────────────
  await pipeline.optional('system-ui', () async {
    applySystemUiOverlayStyle(
      isDarkMode: Get.find<ThemeController>().isDarkMode,
    );
  });

  // ── TLS ──────────────────────────────────────────────────────────────────
  // NOTE (CRIT-02 / R-02): this still installs the global bypass that accepts
  // every certificate in release builds. `core/network/dev_http_overrides.dart`
  // is the scoped replacement and is ready, but swapping it in while
  // `:9443` may serve an invalid chain would take the app fully
  // offline. It is gated on that server certificate being verified — see
  // `docs/refactoring/04-risk-register.md` R-02. Left here, loudly, rather than
  // moved somewhere it stops being obvious.
  MyHttpOverrides.install();

  final report = pipeline.report;

  if (report.isDegraded) {
    AppLogger.warning(
      'Application started in a degraded state: '
      '${report.failures.map((f) => f.step).join(', ')}',
    );
  }

  return report;
}

import 'package:get/get.dart';

import '../../core/config/server_config.dart';
import '../../core/network/api_client.dart';
import '../../core/network/auth_interceptor.dart';
import '../../core/storage/local_storage.dart';
import '../../core/storage/secure_store.dart';
import '../../core/storage/token_storage.dart';
import '../../core/services/device_info_service.dart';
import '../../core/tenancy/tenant_context.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/ui/controllers/bottom_nav_controller.dart';
import '../../features/attendance/presentation/routes/attendance_routes.dart';
import '../../features/home/presentation/routes/home_routes.dart';
import '../../features/notification/presentation/routes/notification_routes.dart';
import '../../features/notification/data/repositories/notification_repository.dart';
import '../../features/notification/data/services/notification_api_service.dart';
import '../../features/notification/data/services/notification_sync_service.dart';
import '../../features/permit/presentation/routes/permit_routes.dart';
import '../../features/profile/presentation/routes/profile_routes.dart';
import '../../features/auth/data/repositories/auth_repository.dart';
import '../../features/auth/data/repositories/session_repository.dart';
import '../../features/auth/data/services/auth_api_service.dart';
import '../../utils/notification/firebase_messaging_services.dart';
import '../../utils/notification/notification_services.dart';

/// The composition root. The **only** place application-wide dependencies are
/// registered.
///
/// Before this existed, `ApiProvider` was registered four different ways —
/// permanently in `main()`, again in `SplashController`'s field initialiser, and
/// lazily in three feature bindings — so twenty controllers called
/// `Get.find<ApiProvider>()` and none of them could say which instance they
/// received (HIGH-07). Feature bindings register feature controllers. They do
/// not register infrastructure.
///
/// ## Why each permanent dependency is permanent
///
/// Rule §10 of the brief: `permanent: true` needs a reason in writing, or it is
/// just a leak with a keyword in front of it.
///
/// | Dependency | Why it outlives every route |
/// |---|---|
/// | `LocalStorage` / `SecureStore` | Read on nearly every request and on every route change. |
/// | `ServerConfig`, `TenantContext` | Which server and which workspace: fixed for the session, read per request. |
/// | `TokenStorage` | Backs the session; `AuthInterceptor` reads it synchronously. |
/// | `ApiClient` | One connection pool, one interceptor chain. The bug above is what several instances cost. |
/// | `ThemeController` | Drives `GetMaterialApp` above every route. |
/// | `BottomNavController` | Survives `Get.offAllNamed` between the five tabs — that is the whole point of it. |
/// | `NotificationService`, `FirebaseMessagingService` | Own OS-level callback registrations that must outlive any screen. |
///
/// **Every feature controller is route-scoped**, registered with `Get.lazyPut`
/// in its own feature binding. There are no exceptions to that.
class InitialBinding extends Bindings {
  InitialBinding({
    required this.localStorage,
    required this.secureStore,
    required this.serverConfig,
    required this.tenantContext,
    required this.tokenStorage,
  });

  // Constructed by `bootstrap()` rather than here, because each needs an
  // `await`ed restore before the first frame and `dependencies()` is
  // synchronous. Bootstrap owns the ordering; this owns the registration.
  final LocalStorage localStorage;
  final SecureStore secureStore;
  final ServerConfig serverConfig;
  final TenantContext tenantContext;
  final TokenStorage tokenStorage;

  @override
  void dependencies() {
    // ── Storage and tenancy ────────────────────────────────────────────────
    Get.put<LocalStorage>(localStorage, permanent: true);
    Get.put<SecureStore>(secureStore, permanent: true);
    Get.put<ServerConfig>(serverConfig, permanent: true);
    Get.put<TenantContext>(tenantContext, permanent: true);
    Get.put<TokenStorage>(tokenStorage, permanent: true);

    // ── Network ────────────────────────────────────────────────────────────
    final authInterceptor = AuthInterceptor(
      tokenStorage: tokenStorage,
      tenantContext: tenantContext,
    );
    Get.put<AuthInterceptor>(authInterceptor, permanent: true);

    // Lazy, and deliberately so: nothing calls it until Phase 3 moves the first
    // feature onto it. Registering it eagerly would open a connection pool for
    // a client with no callers.
    Get.lazyPut<ApiClient>(
      () => ApiClient(
        serverConfig: serverConfig,
        tenantContext: tenantContext,
        authInterceptor: authInterceptor,
        // Resolved lazily: `AuthRepository` is registered below and needs the
        // client, so naming it here directly would be a cycle.
        onUnauthorized: () async {
          if (Get.isRegistered<AuthRepository>()) {
            await Get.find<AuthRepository>().expireSession();
          }
        },
      ),
      fenix: true,
    );

    // ── Authentication ─────────────────────────────────────────────────────
    // Application-wide: the session is read on every route change and every
    // request, and there must be exactly one authority on it (MED-05, MED-07).
    final session = SessionRepository(
      tokenStorage: tokenStorage,
      localStorage: localStorage,
    );
    Get.put<SessionRepository>(session, permanent: true);

    final authApi = AuthApiService(Get.find<ApiClient>());
    Get.put<AuthApiService>(authApi, permanent: true);
    Get.put(
      NotificationSyncService(
        repository: NotificationRepository(
          NotificationApiService(Get.find<ApiClient>()),
        ),
        session: session,
      ),
      permanent: true,
    );

    Get.put<AuthRepository>(
      AuthRepository(
        api: authApi,
        session: session,
        // Dibaca LAZILY: `FirebaseMessagingService` didaftarkan setelah
        // `NotificationService.initialize()` selesai ditunggu bootstrap, jadi
        // pada saat baris ini dijalankan ia belum ada. Penjaga
        // `isRegistered` juga yang membuat harness uji — dan build tanpa
        // Firebase — tetap bisa memanggil keluar.
        currentPushToken: () async =>
            Get.isRegistered<FirebaseMessagingService>()
            ? Get.find<FirebaseMessagingService>().fcmToken
            : null,
      ),
      permanent: true,
    );

    Get.put<DeviceInfoService>(DeviceInfoService(), permanent: true);

    // ── Presentation ───────────────────────────────────────────────────────
    Get.put(ThemeController(), permanent: true);
    // The tab order is the bar's order, and it lives here rather than in
    // `core/` so the paths are the same constants the route table registers.
    Get.put(
      BottomNavController(
        destinations: const [
          HomeRoutes.home,
          AttendanceRoutes.attendance,
          PermitRoutes.permit,
          NotificationRoutes.notification,
          ProfileRoutes.profile,
        ],
      ),
      permanent: true,
    );

    // ── Platform services ──────────────────────────────────────────────────
    // Registered here; `initialize()` is awaited by bootstrap, which can decide
    // what a failure means. A binding cannot await.
    Get.put(NotificationService(), permanent: true);
  }

  /// Registered after `NotificationService.initialize()` has been awaited,
  /// because `FirebaseMessagingService.onInit` calls `Get.find` for it.
  static void registerMessaging() {
    Get.put(FirebaseMessagingService(), permanent: true);
  }
}

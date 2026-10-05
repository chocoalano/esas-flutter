/// What this build *starts* pointed at.
///
/// These are seeds, not the answer. Under [ADR-0005] the server address and the
/// workspace are settings, held by `ServerConfig` and `TenantContext`, because
/// one company per APK is not a platform. What is compiled in here is only what
/// a handset opens on before anybody has configured it, which keeps a build made
/// for a known deployment usable out of the box:
///
/// ```
/// flutter build apk --dart-define=API_BASE_URL=https://hrms.example.com \
///                   --dart-define=TENANT=acme
/// ```
///
/// [ADR-0005]: ../../../docs/adr/0005-subdomain-multi-tenancy.md
library;

class Env {
  const Env._();

  /// The origin a handset that has never been configured starts on, with no
  /// trailing slash and no API prefix.
  ///
  /// Still the origin the app shipped with, so a build with no `--dart-define`
  /// reaches a known host rather than nothing. What that host has to be running
  /// has changed: `tenancy-app`, which resolves its workspace from `X-Tenant`
  /// before routing. See [apiPrefix] for the path under it.
  /// The origin a handset that has never been configured starts on.
  ///
  /// **Deliberately empty.** No deployment is compiled into this repository:
  /// the server address is a *setting* under ADR-0005, held by `ServerConfig`,
  /// because one company per APK is not a platform. A build with no
  /// `--dart-define` therefore has no address at all, `ServerConfig.isConfigured`
  /// is false, and the app opens on the setup screen and asks — which is the
  /// only honest thing it can do.
  ///
  /// A build for a known deployment supplies it at compile time:
  ///
  /// ```
  /// flutter build apk --dart-define=API_BASE_URL=https://hrms.example.com \
  ///                   --dart-define=TENANT=acme
  /// ```
  ///
  /// Note what an empty default is *not*: it is not a placeholder host. A
  /// plausible-looking address nobody runs would leave the app configured and
  /// failing at every request, with no setup screen to fix it from. Nothing
  /// derives a network destination from this value being blank —
  /// `ApiClient` carries its own unroutable placeholder for GetConnect's
  /// relative-path resolution, and never sends to it.
  static const String apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// The API prefix appended to whichever origin a request resolves to.
  ///
  /// `/api/v1` — the same surface `esas_attendance` already runs on. ADR-0007 is
  /// settled and this is the answer it settled on: one prefix, not two.
  ///
  /// `/api/selfservice` was the candidate this client was written against, and
  /// it never existed on any server. A second namespace would have meant a
  /// second copy of tenant identification, the Sanctum guard and the rate
  /// limiters — three things that are load-bearing and that nobody wants two
  /// versions of — bought for nothing but a name. What §0.4 warned against was
  /// both of them being live at once; only one ever was.
  ///
  /// See `core/config/api_routes.dart` for the paths under it.
  static const String apiPrefix = String.fromEnvironment(
    'API_PREFIX',
    defaultValue: '/api/v1',
  );

  /// The prefix for endpoints answered by the **platform** rather than by this
  /// client's own resource namespace.
  ///
  /// Today that is one endpoint: the workspace probe the setup screen asks
  /// before anybody signs in. It is not a self-service resource — it is the
  /// platform saying whether a name reaches a workspace at all, and
  /// `esas_attendance` asks the very same endpoint.
  ///
  /// It now holds the same value as [apiPrefix], which is the outcome ADR-0007
  /// was written hoping for. The constant stays rather than being folded away:
  /// the probe is answered by the platform and the rest of this app's paths are
  /// not, and two names that happen to agree today are cheaper to tell apart
  /// than one name that has to be split again if they ever stop agreeing.
  static const String platformApiPrefix = String.fromEnvironment(
    'PLATFORM_API_PREFIX',
    defaultValue: '/api/v1',
  );

  /// Where employee avatars and permit attachments are served from.
  ///
  /// A CDN origin, shared by every tenant, so it is not part of the tenancy
  /// resolution and stays a plain compile-time value.
  static const String assetBaseUrl = String.fromEnvironment(
    'ASSET_BASE_URL',
    defaultValue: 'https://sas-assets.sgp1.cdn.digitaloceanspaces.com',
  );

  /// The workspace this build starts on. Empty means the person is asked once.
  static const String defaultTenant = String.fromEnvironment('TENANT');

  /// Which deployment this build is for. Drives the TLS policy and nothing else
  /// that changes behaviour.
  static const String environment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'production',
  );

  static bool get isProduction => environment == 'production';
  static bool get isDevelopment => environment == 'development';

  /// The API root of the compiled-in default.
  ///
  /// **Unused, and kept only to be found.** With [apiBaseUrl] empty by design
  /// this is the bare path `/api/v1`, which is not an origin and cannot be sent
  /// to. Every request resolves through `ServerConfig.apiRootFor`, which knows
  /// the workspace; `ApiClient` holds its own unroutable placeholder for
  /// GetConnect.
  ///
  /// Delete it when nothing greps for it. Leaving a getter that looks like a
  /// destination is how one gets used as one.
  @Deprecated('No build carries a default origin. Use ServerConfig.apiRootFor.')
  static String get apiRoot => '$apiBaseUrl$apiPrefix';
}

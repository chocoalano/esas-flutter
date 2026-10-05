import 'dart:io';

/// **CRIT-02 — accepts every TLS certificate, in every build.**
///
/// This is the pre-refactor behaviour, left in place deliberately and marked
/// rather than quietly carried forward. `core/network/dev_http_overrides.dart`
/// is the replacement: `assert`-guarded so it cannot exist in a release binary,
/// and scoped to development hosts instead of returning `true` for everything.
///
/// It is **not** swapped in yet because `:9443` may be serving an
/// invalid chain — that is very likely why this class was written. Removing the
/// bypass before the server certificate is fixed takes the app fully offline.
/// Gated on R-02 in `docs/refactoring/04-risk-register.md`; verify with
/// `openssl s_client -connect :9443 -servername ` first.
// NOT marked @Deprecated: the one call site in `bootstrap()` has to keep calling
// it until R-02 clears, and an annotation here would only produce a warning to
// be suppressed. The comment above is the record.
class MyHttpOverrides extends HttpOverrides {
  /// Install the global bypass, exactly as `main()` used to.
  static void install() {
    HttpOverrides.global = MyHttpOverrides();
  }

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        return true;
      };
  }
}

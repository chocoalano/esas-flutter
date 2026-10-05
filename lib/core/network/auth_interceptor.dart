import '../storage/token_storage.dart';
import '../tenancy/tenant_context.dart';

/// Decides what identity headers a request carries.
///
/// Split out and made pure so the decision can be tested without a socket. The
/// rule it replaces could not be: `ApiProvider` decided auth by comparing the
/// request host to the base URL's host, and injected an in-band `X-Bypass-Auth`
/// header that the caller set and the modifier stripped (MED-02).
///
/// Two things were wrong with that beyond the indirection.
///
/// A header the caller sets is a channel anything can write to — a header map
/// reused between two calls silently changes whether a bearer token is attached.
///
/// And host equality does not survive tenancy. Under subdomain mode a request
/// goes to `acme.hrms.example.com` while the configured domain is
/// `hrms.example.com`; the hosts differ, so the old rule would quietly stop
/// sending `Authorization` and every call would 401 (TEN-02). Whether a request
/// is authenticated is a property of the *call*, not of the hostname it happens
/// to resolve to, so it is now an explicit parameter.
class AuthInterceptor {
  const AuthInterceptor({
    required TokenStorage tokenStorage,
    required TenantContext tenantContext,
  }) : _tokenStorage = tokenStorage,
       _tenantContext = tenantContext;

  final TokenStorage _tokenStorage;
  final TenantContext _tenantContext;

  /// Headers for a request, given whether the caller asked for authentication.
  Map<String, String> headersFor({
    required bool authenticated,
    Map<String, String>? extra,
  }) {
    return buildHeaders(
      authenticated: authenticated,
      token: _tokenStorage.token,
      tenant: _tenantContext.tenant,
      extra: extra,
    );
  }

  /// The header decision, as a pure function.
  ///
  /// `X-Tenant` is sent whenever a workspace is known, in both deployment modes.
  /// In subdomain mode it agrees with the host, so which one the server reads
  /// cannot change the answer; in single-host mode it is the only thing naming
  /// the workspace at all (ADR-0005).
  ///
  /// A caller's own header wins over a computed one, so a request that must
  /// carry a different `Accept` or a one-off `Authorization` can say so — but
  /// [authenticated] is what decides whether the *stored* token is attached, and
  /// no header can flip that.
  static Map<String, String> buildHeaders({
    required bool authenticated,
    String? token,
    String? tenant,
    Map<String, String>? extra,
  }) {
    final headers = <String, String>{'Accept': 'application/json'};

    if (tenant != null && tenant.isNotEmpty) {
      headers['X-Tenant'] = tenant;
    }

    if (authenticated && token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    if (extra != null) {
      headers.addAll(extra);
    }

    return headers;
  }
}

# 0004 — Centralised API client, explicit auth

## Status

Accepted — 2026-08-31 · **Implemented — 2026-09-01 kecuali pemulihan TLS** (masih terhalang R-02).
**Partly superseded by [0005](0005-subdomain-multi-tenancy.md)** (2026-09-01): the
base URL is no longer a compile-time constant fixed by `--dart-define`. It becomes a
runtime setting resolved **per request** for the active tenant. `--dart-define`
survives only as the seed a handset opens on before anyone configures it. Everything
else in this ADR — one client, explicit `authenticated:`, typed exceptions, central
401, restored TLS — stands unchanged, and the explicit `authenticated:` flag turns
out to be a *prerequisite* for tenancy (see TEN-02).

## Context

Two `GetConnect` subclasses exist: `ApiProvider` (227 lines, internal API) and
`ApiExternalProvider` (257 lines, external API). Together they own base URL, TLS
policy, token reading, auth decisions, header sanitising, decoding, `get`/`post`
overrides, multipart upload, and — in `ApiProvider` — four `external*` methods that
duplicate the other class entirely and are called from nowhere.

Three concrete problems:

**1. Four registrations of one client (HIGH-07).**
```dart
main.dart:54                Get.put(ApiProvider(), permanent: true);
splash_controller.dart:18   Get.put(ApiProvider());                 // replaces the permanent one
activity_binding.dart:10    Get.lazyPut<ApiProvider>(...);          // and three bindings do this
```
Twenty controllers call `Get.find<ApiProvider>()` and cannot say which instance they
receive. Adding a 401 interceptor might attach to only one of them.

**2. Auth decided by an in-band magic header (MED-02).**
```dart
final bypassAuth = request.headers['X-Bypass-Auth'] == 'true';   // set by the caller,
request.headers.remove('X-Bypass-Auth');                          // stripped by the modifier
```
Auth behaviour rides on a header the caller injects. A header map reused between
calls silently changes whether a bearer token is attached. `_isInternalUri` compares
**host only**, so a same-host different-port or different-scheme URL still receives
the token.

**3. TLS disabled globally (CRIT-02).**
`HttpOverrides.global` accepts every certificate in release builds, and both providers
set `allowAutoSignedCert = true`.

Error handling is spread across three duplicated `switch (statusCode)` blocks that map
the same codes to different Indonesian strings, and none of them terminate the session
on 401 (MED-07).

## Decision

One client, with responsibilities separated:

```
core/network/
├── api_client.dart          # HTTP mechanics only: verbs, headers, timeouts, multipart
├── auth_interceptor.dart    # token injection, driven by an EXPLICIT flag
├── api_error_mapper.dart    # one status → typed exception mapping
├── api_exception.dart       # NetworkException, UnauthorizedException, ValidationException,
│                            # ServerException, TimeoutException, UnknownApiException
├── api_response.dart
└── network_constants.dart
```

**Registered exactly once**, in `app/bindings/initial_binding.dart`. Feature bindings
never register infrastructure. `ApiExternalProvider` folds into `ApiClient` as an
unauthenticated mode; the three unused `external*` methods are deleted.

**Auth becomes an explicit per-request parameter**, not a header:

```dart
Future<ApiResponse<T>> get<T>(String path, {bool authenticated = true, ...});
```

The magic `X-Bypass-Auth` header is removed. The interceptor reads
`TokenStorage`, never `GetStorage` directly.

**401 is handled once.** `ApiErrorMapper` produces `UnauthorizedException`;
`SessionRepository` listens, clears the session, routes to `/login`. 403 is a
permission error and must **not** end the session.

**TLS validation is restored.** The override moves to
`core/network/dev_http_overrides.dart`, wrapped in an `assert` (stripped in release)
and scoped to an explicit dev-host allowlist rather than `return true`.

> **Sequencing gate (R-02):** this cannot merge until `:9443` serves a
> valid chain — verify with `openssl s_client`. If it cannot be fixed this cycle,
> ship the dev-only isolation and keep a **scoped, documented** release exception with
> a tracked follow-up. A narrow known exception beats a silent global one.

Base URLs move to `core/config/` behind `--dart-define`, defaulting to production.
**Superseded by ADR-0005:** that default is a *seed*; the address a request is
actually sent to comes from `ServerConfig.originFor(tenant)` at request time.
**These are configuration, not secrets** — committing the default
production URL is correct. Passwords, tokens and keys are secrets and are never
committed.

## Consequences

**Positive**
- One client means one place to add interceptors, logging, retries, or a base-URL switch.
- Explicit `authenticated:` makes each call site's auth behaviour readable and testable.
- Typed exceptions replace three duplicated switch blocks and let controllers decide
  presentation while infrastructure stays silent (MED-03).
- Central 401 fixes a session that today never terminates on expiry (MED-07).
- Restoring TLS closes the most serious runtime security hole in the app (CRIT-02).
- `--dart-define` makes the target backend visible in the build command instead of
  requiring a source edit (MED-10).

**Negative**
- Every call site changes. This is the bulk of the per-feature migration work and
  must be done one feature at a time.
- Auth-injection rules must be ported **exactly**. The internal/external/absolute/
  relative matrix needs tests written **before** the port, not after — this is the
  single most behaviour-sensitive refactor in the programme.
- Global 401 logout is a real behaviour change and needs validation against every
  endpoint's actual 401 semantics (R-07).
- Restoring TLS is blocked on a server-side fix outside this repository's control.

**Revisit if:** a second backend with different auth semantics is introduced, or
certificate pinning is required for the auth endpoints.

---

## Outcome — 2026-09-01

**Terkirim:**

| Keputusan | Status | Catatan |
|---|---|---|
| Satu client, terdaftar sekali | ✅ | `ApiClient` di `InitialBinding`; `ApiProvider` **dihapus** bersama empat cara pendaftarannya (HIGH-07) |
| `authenticated:` eksplisit | ✅ | `AuthInterceptor.buildHeaders` adalah fungsi murni dan **host-independen** — inilah yang menutup TEN-02 |
| `X-Bypass-Auth` dihapus | ✅ | Bersama `_isInternalUri` yang membandingkan host |
| Exception bertipe | ✅ | `ApiErrorMapper`: satu peta status → exception; 401 ≠ 403 |
| 401 terpusat | ✅ | Hanya 401, hanya request terautentikasi. 403 tidak mengakhiri sesi (R-07) |
| Origin per request | ✅ | Ditambahkan ADR-0005; client yang dibuat sebelum workspace berganti tidak berbicara ke host lama |
| Multipart, timeout, verb | ✅ | 30 detik; 75 detik untuk kiriman absensi wajah |

**Belum terkirim, dan ini yang paling penting untuk dibaca:**

> **Validasi TLS masih mati.** `MyHttpOverrides.install()` masih dipanggil di
> `bootstrap.dart`. Penggantinya — `core/network/dev_http_overrides.dart`,
> `assert`-guarded dan dibatasi daftar host dev — **sudah ditulis dan diuji, tetapi
> belum dipasang**, karena mencabut bypass sebelum server menyajikan rantai
> sertifikat valid akan membuat aplikasi offline (R-02, CRIT-02, TEN-03).
>
> `MyHttpOverrides` sengaja **tidak** ditandai `@Deprecated`: itu akan memunculkan
> peringatan analyzer di satu-satunya pemanggil yang memang wajib memanggilnya, dan
> menekan peringatan adalah pola yang dilarang refactor ini.

**Dua deviasi dari daftar berkas di Decision**, keduanya disengaja:

- **`api_response.dart` tidak dibuat.** `ApiClient` mengembalikan objek bertipe
  langsung (`getObject`/`getList`/`postObject`/`postForm`); pembungkus generik akan
  menambah satu lapisan tanpa menambah informasi.
- **`network_constants.dart` tidak dibuat.** Isinya menjadi `core/config/env.dart`
  dan `core/config/api_routes.dart`, yang merupakan tempat yang benar setelah
  ADR-0005 menjadikan alamat sebagai setelan runtime.

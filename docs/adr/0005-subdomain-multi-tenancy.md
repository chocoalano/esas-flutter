# 0005 — Subdomain-based multi-tenancy

## Status

Accepted — 2026-09-01 · **Terimplementasi penuh — 2026-09-01**, termasuk layar setup (§4 Decision). Lihat Outcome.
**Supersedes part of [0004](0004-centralized-api-client.md)** (base URL as a compile-time constant).

## Context

ESAS self-services must become a multi-tenant SaaS client: one application serving
many companies, each identified by its own subdomain — the model already implemented
in the sibling Flutter app **`esas_attendance`** (`/Users/ict/Documents/esas/esas_attendance`).

### What the sibling app already does

`esas_attendance` solved this and the design is sound. Three pieces:

| Piece | File | Responsibility |
|---|---|---|
| `Env` | `lib/constants.dart` | Compile-time **seeds** via `--dart-define` (`API_BASE_URL`, `TENANT`). Explicitly "seeds, not the answer". |
| `ServerConfig` | `lib/app/data/server_config.dart` | Runtime setting: `domain` + `subdomainMode`, in `flutter_secure_storage`. `originFor(tenant)` builds `https://acme.hrms.example.com`. |
| `Session` | `lib/app/data/session.dart` | Holds `tenant` + `token`, in secure storage. |

The client resolves the origin **per request**, not at construction:

```dart
// api_client.dart — addRequestModifier
request.headers['X-Tenant'] = tenant;                    // sent in BOTH modes
final origin = ServerConfig.instance.originFor(tenant);
return request.copyWith(url: rebase(request.url, origin));
```

Two deployment modes, both supported:

- **Subdomain** (default) → `acme.hrms.example.com`. Matches how the web app resolves
  a tenant, so a handset and a browser reach the same workspace by the same name.
  Requires wildcard DNS **and a wildcard TLS certificate**.
- **Single host** → `hrms.example.com` + `X-Tenant: acme`. For deployments with no
  wildcard certificate, and for emulators where `acme.10.0.2.2` resolves to nothing.

`X-Tenant` is sent either way, so which one the server reads cannot change the answer.

The design also handles cases we would otherwise rediscover the hard way: an IP host
can never carry a workspace on its front (`acme.172.16.2.233` resolves to nothing);
`Uri.replace` cannot remove a port, so a placeholder `:8000` would follow a request
onto a server answering on 443; a bare name is assumed HTTPS while a reserved-TLD or
private address is assumed HTTP.

### Where ESAS self-services stands today

Nothing of this exists. `lib/utils/api_constants.dart` is:

```dart
const String baseApiUrl = 'https://:9443/api';
```

A single compile-time constant. No tenant concept anywhere in 117 files.

**The backends differ, and this is the crux.** `esas_attendance` talks to a
`stancl/tenancy` Laravel app (`/Users/ict/Documents/Laravel/esas-tenancy`, using
`InitializeTenancyByDomain`) over `/api/v1` with endpoints like `/workspace`. ESAS
self-services talks to `:9443/api` over `/general-module/*` and
`/hris-module/*` — an API surface that **does not exist** in `esas-tenancy`
(verified: `grep -rn "general-module\|hris-module" routes/` returns nothing).

So this is not only a client refactor. Either the self-services backend gains
tenancy, or self-services migrates onto the tenancy backend and its entire API
surface changes. **That question is unresolved and blocks the work** — see
`05-progress.md` Q9.

## Decision

**Adopt the `esas_attendance` tenancy model in ESAS self-services**, reusing its
proven components rather than inventing a second dialect of the same idea.

### 1. Address becomes a runtime setting, not a build constant

This **supersedes ADR-0004's** "base URLs move to `core/config/app_config.dart`
behind `--dart-define`". `--dart-define` remains, but demoted to a *seed* — what a
handset opens on before anyone configures it. One company per APK is not a platform.

```
core/config/env.dart            # compile-time seeds: API_BASE_URL, TENANT, API_PREFIX
core/config/server_config.dart  # runtime: domain + subdomainMode, secure storage
core/tenancy/tenant_context.dart# the current tenant, read by the interceptor
```

`ServerConfig` is **ported from `esas_attendance` substantially as-is**, including
`normalise`, `isIpLiteral`, `isDevelopmentHost`, `isValidWorkspace`, and `originFor`.
These encode real deployment lessons; rewriting them would reintroduce the bugs their
comments describe.

### 2. Origin resolved per request

`ApiClient`'s request modifier rebuilds the URL for the active tenant on every
request, and always sends `X-Tenant`. A client built before someone switched
workspaces must not keep talking to the old host.

### 3. Tenant lives in the session, in secure storage

`SessionRepository` gains `tenant`. `flutter_secure_storage` replaces `GetStorage`
for credentials — matching `esas_attendance`, and **resolving MED-06** with a
precedent rather than a fresh argument.

**Logout keeps the tenant, clears the credential.** An employee logging out still
works for the same company; asking for the workspace again at every login is friction
with no security value. Changing workspace is a separate, deliberate action.

### 4. A setup screen gates the app

Boot order becomes:

```
splash → (not configured?) → setup → login → home
```

`/setup` asks for the workspace and, where the deployment allows, the server address,
then validates against an unauthenticated probe before accepting it — as
`WorkspaceProvider.check()` does, returning the workspace's **display name** so the
person sees the company they expected rather than a bare "OK".

### 5. Auth injection stops keying on the host

`ApiProvider._isInternalUri` compares `uri.host == base.host` to decide whether to
attach the bearer token. Under subdomain tenancy the host is
`acme.hrms.example.com` while the stored base is `hrms.example.com` — **the
comparison fails and the token stops being attached.** The rule becomes an explicit
`authenticated:` parameter (already ADR-0004's decision), which is host-independent
and therefore tenancy-safe.

## Consequences

**Positive**

- One signed binary serves every tenant. No per-company APK, no reinstall when a
  server moves.
- Handset and browser resolve the same workspace by the same name.
- Single-host mode keeps emulators and non-wildcard deployments working.
- `flutter_secure_storage` closes MED-06 and CRIT-03's storage half.
- Porting `ServerConfig` rather than reinventing it means the two ESAS Flutter apps
  share one mental model — and one place to fix a tenancy bug.

**Negative — and these are significant**

- **The signing key becomes platform-wide.** One binary for all tenants means
  `esas-keystore.jks` (CRIT-01) no longer risks one company; a forged build is a
  forged build for **every tenant on the platform**. This materially raises CRIT-01's
  severity and is now the strongest argument for rotating it.
- **`com.example.esas` becomes a blocker, not a blemish.** `com.example.*` is
  rejected by the Play Store, and a SaaS product must be distributable. LOW-09 is
  therefore **escalated to HIGH**.
- **Subdomain mode requires a wildcard certificate.** `*.hrms.example.com`. The
  global TLS bypass (CRIT-02) would mask a misconfigured wildcard until it is removed
  — so CRIT-02 and tenancy are coupled, and the bypass must go *before* subdomain
  mode is trusted in the field, not after.
- **The hardcoded attendance machine endpoint cannot survive.**
  `http://128.199.111.239:3000/attmachine/qr-presence`
  (`attendance_controller.dart:279`) is one machine, at one company, over cleartext.
  It must become per-tenant configuration. MED-11 is escalated to HIGH.
- **Every endpoint is affected**, because every request now needs a tenant. This is
  not a feature added beside the refactor; it is a change to the layer the refactor
  builds. It therefore lands in **Phase 1**, not at the end.
- **Backend contract is unresolved** — see below. Scope cannot be fixed until it is.

## Open question — RESOLVED 2026-09-01

> **Answered: self-services migrates onto the `tenancy-app` backend.**
> See [ADR-0006](0006-migrate-to-tenancy-app-api.md) and
> [`06-api-migration-map.md`](../refactoring/06-api-migration-map.md).
>
> Note the target is `/Users/ict/Documents/esas/tenancy-app` (stancl/tenancy ^3.10,
> `/api/v1`), **not** `/Users/ict/Documents/Laravel/esas-tenancy` which this ADR
> originally cited. The original text is kept below for the record.

### Original open question

> Does the ESAS self-services backend (`:9443`, endpoints
> `/general-module/*` and `/hris-module/*`) already resolve tenants by subdomain or
> `X-Tenant`? Or is self-services expected to migrate onto the `esas-tenancy`
> backend, whose API surface is entirely different?

- **If the existing backend gains tenancy** → this ADR is a client-side change and
  the plan below holds.
- **If self-services migrates to `esas-tenancy`** → every endpoint, model and
  repository changes with it. That is a **larger programme than this refactor**, and
  the sequencing must be decided before Phase 1 starts: refactor first onto the
  current API and migrate later, or migrate first and refactor onto the new surface.

I have not assumed an answer. The plan below is written for the first case and flags
where the second diverges.

**Revisit if:** the platform moves to path-based tenancy (`/t/acme/api/...`), or a
tenant needs a fully custom domain rather than a subdomain — `originFor` would then
need a per-tenant override rather than a computed host.

---

## Outcome — 2026-09-01

**Terkirim (Fase 1–3):**

| Bagian keputusan | Status | Berkas |
|---|---|---|
| Alamat menjadi setelan runtime | ✅ | `core/config/env.dart` (seed), `core/config/server_config.dart` |
| `ServerConfig` diport dari `esas_attendance` | ✅ | `originFor`, `normalise`, klasifikasi host — plus perbaikan `isPlausibleHost` yang ditemukan test (frasa berspasi dulu lolos sebagai alamat) |
| Origin di-resolve per request + `X-Tenant` | ✅ | `core/network/api_client.dart` |
| Tenant di secure storage, terpisah dari sesi | ✅ | `core/tenancy/tenant_context.dart` — `clear()` adalah "pindahkan handset", **bukan** bagian dari logout |
| Kredensial ke `flutter_secure_storage` | ✅ | `TokenStorage`/`SecureTokenStorage`; token legacy **dipindahkan**, bukan disalin (MED-06, TEN-04) |
| Auth berhenti keying pada host | ✅ | ADR-0004 `authenticated:` (TEN-02) |

**§4 Decision — layar setup: terkirim 2026-09-01 (P10-1…P10-4).**

| Bagian | Berkas |
|---|---|
| Route `/setup` | `features/setup/presentation/routes/` |
| Probe workspace tanpa token | `features/setup/data/services/workspace_api_service.dart` |
| Simpan hanya setelah server mengonfirmasi | `features/setup/data/repositories/workspace_repository.dart` |
| Urutan boot `splash → setup → login → home` | `features/auth/presentation/controllers/splash_controller.dart` |
| "Pindah Workspace", terpisah dari logout | `features/profile/presentation/controllers/profile_controller.dart` |

Dua hal yang **berbeda dari sibling**, keduanya disengaja:

1. **Kandidat tidak pernah ditulis ke konfigurasi hidup untuk diuji.**
   `esas_attendance` menempelkan alamat kandidat ke `ServerConfig.instance`,
   memanggil, lalu mengembalikannya bila gagal — selama request berlangsung
   handset menunjuk alamat yang belum pernah menjawab, dan permanen bila proses
   mati di tengah. Di sini `ServerConfig.originOf` menyusun kandidat sebagai
   fungsi murni, dan `save()` baru dipanggil setelah server mengonfirmasi.
2. **Probe memakai `Env.platformApiPrefix`, bukan `Env.apiPrefix`.**
   `GET /api/v1/workspace` sudah dijawab hari ini; permukaan self-service masih
   menunggu ADR-0007. Pemisahan itu yang membuat layar setup tidak ikut
   tersandera keputusan yang belum diambil.

**R-22 dan CLI-01 ditutup.** 26 test baru; suite 171 → **197**.

**Koreksi terhadap Context:** backend target adalah
`/Users/ict/Documents/esas/tenancy-app`, **bukan**
`/Users/ict/Documents/Laravel/esas-tenancy` yang dikutip ADR ini semula. Lihat
ADR-0006. Perbedaannya bukan kosmetik: `tenancy-app` sudah membawa seluruh domain
HRIS sebagai model dan migrasi, dan itulah yang mengubah penilaian risiko migrasi
dari HIGH menjadi MEDIUM.

**Yang terkonfirmasi benar dari analisis semula:** `esas_attendance` berjalan di
`/api/v1` dengan `X-Tenant` yang di-resolve **sebelum routing**, dan token Sanctum
hidup di database tenant masing-masing — sehingga mengganti header tidak membuka
data tenant lain. Model tenancy yang diadopsi ADR ini terbukti di produksi, bukan
diasumsikan.

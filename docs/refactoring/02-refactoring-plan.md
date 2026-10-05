# 02 — Refactoring Plan

> **Diperbarui 2026-09-01.** Fase 0–6 **selesai**; Fase 7–9 belum dimulai, dan satu
> fase baru ditambahkan di akhir berkas: **Fase 10 — Tenancy completion & API
> cutover**, yang memuat pekerjaan yang dulu tidak ada di rencana ini karena
> backendnya belum diputuskan.
>
> | Fase | Status | Catatan |
> |---|---|---|
> | 0 Audit & safety | ✅ | 5 CRITICAL, 7 HIGH, 13 MEDIUM, 11 LOW + TEN-01…05 |
> | 1 Core foundation | ✅ | Termasuk P1-10…13 tenancy; P1-9 (TLS) ditulis tetapi **belum dipasang** |
> | 2 Application bootstrap | ✅ | `main.dart` 160 → 12 baris |
> | 3 Authentication | ✅ | CRIT-03, HIGH-02, MED-05, MED-07 tertutup |
> | 4 Attendance pilot | ✅ | CRIT-04, HIGH-09 tertutup; analyze menjadi 0 |
> | 5 Remaining features | ✅ | `ApiProvider` dihapus; mirror legacy dimatikan |
> | 6 Routing & shared UI | ✅ | 22 route dipatok test; nol `ignore_for_file` |
> | 7 Platform services | ⬜ **berikutnya** | HIGH-03, HIGH-05, CRIT-05 sisa |
> | 8 Testing | ⬜ | Fixture **harus** diambil dari API baru — lihat Fase 10 |
> | 9 Documentation & cleanup | 🟨 | README sudah menjadi blueprint v1.1; sisanya belum |
> | **10 Tenancy completion & API cutover** | ⬜ **baru** | Digerbang ADR-0007 |

> Derived from `01-architecture-audit.md`. Every task cites the finding it closes.
> Phases are sequential; tasks inside a phase may be parallel unless noted.
>
> **Gate after every task:** `dart format .` → `flutter analyze` → `flutter test`.
> No task is done until all three are at or better than the `00-current-state.md` baseline.

---

## Guiding constraints

1. **Behaviour is frozen.** Endpoint paths, payload shapes, screen appearance,
   navigation, theme and localisation stay identical. Bugs found are documented and
   fixed in *separate, labelled* commits — never folded into a move.
2. **GetX stays.** See `docs/adr/0001-retain-getx.md`.
3. **Architecture proportional to the app.** 14.5k baris, 24 controller, 22 model *(angka pra-refactor; kini 17 controller, 22 view — lihat `00-current-state.md` §16)*.
   That justifies repositories and API services. It does **not** justify a `domain/`
   layer with use-cases and interfaces for every feature. See `docs/adr/0002`.
4. **No suppression as a fix.** A lint that fires is either fixed or the rule is not
   adopted. `ignore_for_file` is never the answer.
5. **One feature per commit.** File moves have a large blast radius; small commits are
   the only practical review unit.

---

## Target structure

```
lib/
├── main.dart                       # ~8 lines
├── bootstrap.dart                  # deterministic boot pipeline
│
├── app/
│   ├── app.dart                    # EsasApp (was MyApp)
│   ├── bindings/
│   │   └── initial_binding.dart    # the ONLY composition root
│   └── routing/
│       ├── app_pages.dart          # aggregator
│       └── app_routes.dart
│
├── core/
│   ├── config/
│   │   ├── app_config.dart         # AppEnvironment + dart-define reads
│   │   └── api_endpoints.dart      # base URLs only
│   ├── network/
│   │   ├── api_client.dart
│   │   ├── api_response.dart
│   │   ├── api_exception.dart
│   │   ├── api_error_mapper.dart
│   │   ├── auth_interceptor.dart
│   │   └── network_constants.dart
│   ├── storage/
│   │   ├── local_storage.dart      # interface + GetStorage impl
│   │   ├── token_storage.dart      # interface (secure impl staged, MED-06)
│   │   └── storage_keys.dart
│   ├── errors/
│   │   └── failures.dart
│   ├── services/
│   │   ├── location_service.dart
│   │   ├── permission_service.dart
│   │   ├── device_info_service.dart
│   │   └── notifications/
│   │       ├── notification_service.dart
│   │       ├── firebase_messaging_service.dart
│   │       ├── notification_permission_service.dart
│   │       └── notification_router.dart
│   ├── theme/
│   │   ├── app_theme.dart
│   │   └── theme_controller.dart
│   ├── utils/
│   │   ├── app_logger.dart         # NEW — replaces 132 raw prints
│   │   ├── date_formatter.dart
│   │   └── json_parsers.dart       # NEW — _asInt/_asString/_asDate
│   └── ui/
│       ├── components/
│       │   ├── app_avatar.dart
│       │   ├── app_input_decoration.dart
│       │   └── custom_bottom_navbar.dart
│       ├── dialogs/
│       │   └── app_snackbar.dart
│       └── controllers/
│           └── bottom_nav_controller.dart
│
├── features/
│   ├── auth/            # login + splash + session
│   ├── attendance/
│   ├── home/            # + activity, announcement
│   ├── notification/
│   ├── permit/
│   └── profile/
│
└── generated/
```

Per-feature shape (**no `domain/` unless justified** — ADR-0002):

```
features/<feature>/
├── data/
│   ├── models/
│   ├── services/          # <feature>_api_service.dart
│   └── repositories/
└── presentation/
    ├── bindings/
    ├── controllers/
    ├── views/
    └── widgets/
```

---

# Phase 0 — Audit & safety  *(this phase)*

No production code changes. No file moves.

| ID | Task | Closes | Status |
|---|---|---|---|
| P0-1 | Harden `.gitignore` for keystores/secrets | CRIT-01 (partial) | **Done** |
| P0-2 | Capture baseline: versions, analyze, test, format | — | **Done** |
| P0-3 | Full architecture audit | all | **Done** |
| P0-4 | Migration map for every file to move | MED-08 | **Done** |
| P0-5 | Risk register | — | **Done** |
| P0-6 | Dead-code candidate list with reference analysis | LOW-06 | **Done** |
| P0-7 | ADRs 0001–0004 | — | **Done** |
| P0-8 | **Escalate CRIT-01 + CRIT-02 to the repository owner** | CRIT-01, CRIT-02 | **Blocked — needs human decision** |

**P0-1 detail.** `.gitignore` now excludes `*.jks`, `*.keystore`, `key.properties`,
`.env*` (with `!.env.example`), `android/local.properties`, and certificate files.

> **This does not untrack `esas-keystore.jks`.** The file remains in the index, in the
> working tree, and in every commit since `65f3b84`. Untracking and history rewrite
> are deliberately **not** automated — see `04-risk-register.md` R-01.

---

# Phase 1 — Core foundation

Build `core/` **alongside** the existing code. Nothing is deleted; the old
`ApiProvider` keeps working until each feature migrates off it. This is what makes
the later phases reversible.

| ID | Task | Closes | Risk |
|---|---|---|---|
| P1-1 | `core/config/app_config.dart` — `AppEnvironment`, `--dart-define` reads; **default must equal today's `baseApiUrl` byte-for-byte** | MED-10, MED-11 | LOW |
| P1-2 | `core/utils/app_logger.dart` — levelled logging, debug/info compiled out in release, redaction helper | CRIT-05 | LOW |
| P1-3 | `core/storage/local_storage.dart` + `token_storage.dart` interfaces; `GetStorage` implementation behind them; move `storage_keys.dart` | MED-06, LOW-01 | LOW |
| P1-4 | `core/network/api_exception.dart` + `api_error_mapper.dart` — one status→exception mapping | MED-07, MED-02 | LOW |
| P1-5 | `core/network/api_client.dart` + `auth_interceptor.dart` — port `ApiProvider`'s auth rules **exactly**; replace the `X-Bypass-Auth` magic header with an explicit per-request flag | MED-02, HIGH-07 | **MEDIUM** |
| P1-6 | `core/utils/json_parsers.dart` — shared null-safe accessors | MED-04 | LOW |
| P1-7 | `core/ui/` — move `snackbar.dart`, `custom_bottom_navbar.dart`, extract `buildAvatar`/`inputDecoration` from `helper.dart` | LOW-01 | LOW |
| P1-8 | `core/theme/` — move `app_theme.dart`, `theme_controller.dart`. ~~remove the snackbar from `toggleTheme`~~ — **struck 2026-09-01**: MED-03 is about *infrastructure* presenting UI; `ThemeController` is a presentation controller and rule §18 permits it. Removing it would be a UX change inside an architecture commit (rule §43). | MED-03 | LOW |
| P1-9 | Isolate the TLS override behind `AppConfig` + `assert`; scope to explicit dev hosts | CRIT-02, TEN-03 | **HIGH — see gate** |
| **P1-10** | **`core/config/env.dart` + `server_config.dart` — port `ServerConfig` from `esas_attendance` substantially as-is** | TEN-01 | MEDIUM |
| **P1-11** | **`core/tenancy/tenant_context.dart`; `X-Tenant` on every request; origin resolved per request** | TEN-01 | MEDIUM |
| **P1-12** | **Replace host-based auth injection with an explicit `authenticated:` flag — prerequisite for P1-11** | TEN-02 | **MEDIUM** |
| **P1-13** | **`flutter_secure_storage` behind `TokenStorage`; migrate legacy keys; async-safe interface** | TEN-04, MED-06 | MEDIUM |

**P1-5 is the highest-value, highest-care task in this phase.** Write the
auth-injection test matrix *first*: relative URL, absolute internal URL, absolute
external URL, explicit bypass, no token present, empty token. Only then port.

**P1-10 to P1-13 are the multi-tenancy foundation (ADR-0005).** They land in Phase 1
rather than a later phase because they change the network and session layers every
feature migrates onto. Retrofitting tenancy after Phase 5 would mean touching all 24
endpoint call sites twice.

**Order within the tenancy set: P1-12 → P1-10 → P1-11 → P1-13.** P1-12 first because
host-based auth injection (TEN-02) silently stops sending the bearer token the moment
subdomain mode is enabled; fixing it afterwards means debugging a 401 storm.

**Ship single-host mode first.** With a fixed domain and one tenant, behaviour is
byte-identical to today — the safe intermediate state. Enable subdomain mode only
after the wildcard certificate is verified (TEN-03).

**Gate on P1-9 (blocking):** do **not** merge until
`openssl s_client -connect :9443 -servername ` shows a valid
chain. Removing the bypass against an invalid certificate takes the app fully
offline. If the certificate cannot be fixed yet, ship P1-9 as *dev-only isolation*
and leave a release-build bypass in place with a tracked follow-up — a documented,
scoped exception beats a silent global one.

---

# Phase 2 — Application bootstrap

| ID | Task | Closes | Risk |
|---|---|---|---|
| P2-1 | `bootstrap.dart` — ordered pipeline: binding → config → storage → Firebase → infrastructure → notifications | — | LOW |
| P2-2 | Classify each boot step **fatal / recoverable / optional** and act accordingly | — | LOW |
| P2-3 | `app/app.dart` — `MyApp` → `EsasApp` | — | LOW |
| P2-4 | `app/bindings/initial_binding.dart` — single composition root; document why each `permanent` is permanent | HIGH-07 | MEDIUM |
| P2-5 | Delete the two unused dialogs from `main.dart` | LOW-06 | LOW |
| P2-6 | `main.dart` reduced to `ensureInitialized` → `bootstrap()` → `runApp` | — | LOW |
| P2-7 | Move FCM token sync out of boot into the auth lifecycle | HIGH-04 | MEDIUM |

**P2-2 policy:**

| Step | Failure class | Behaviour |
|---|---|---|
| `WidgetsFlutterBinding` | fatal | cannot proceed |
| `GetStorage.init()` | **fatal** | no session, no theme — show a fatal error screen, do not run a broken app |
| `AppConfig` | fatal | misconfigured build |
| `Firebase.initializeApp()` | **optional** | ESAS is an ERP; push is an enhancement. Log, disable notification features, continue. Today's silent `debugPrint` swallow becomes an explicit, documented decision. |
| `NotificationService.initialize()` | optional | same |
| Infrastructure/repos | fatal | programmer error |

**P2-4 permanent-singleton justification** (rule §10 — each must be written down):

| Dependency | Lifetime | Why |
|---|---|---|
| `ApiClient` | permanent | Shared connection pool + single interceptor chain; must be one instance (HIGH-07) |
| `LocalStorage` / `TokenStorage` | permanent | Backs the session; read on every request |
| `SessionRepository` | permanent | Single session authority (MED-07) |
| `ThemeController` | permanent | Drives `GetMaterialApp` above every route |
| `BottomNavController` | permanent | Survives `Get.offAllNamed` between the 5 tabs |
| `NotificationService` / `FirebaseMessagingService` | permanent | Own OS-level callback registrations |
| **Every feature controller** | **route-scoped** | `Get.lazyPut` in the feature binding — no exceptions |

**P2-7 note:** the FCM registration removed from boot **must** land somewhere. Add it
to `AuthRepository` post-login and post-restore in the same commit, or iOS/Android
push silently stops working.

---

# Phase 3 — Authentication

Auth first: every other feature depends on the session. This phase closes the largest
cluster of findings.

| ID | Task | Closes | Risk |
|---|---|---|---|
| P3-1 | `features/auth/data/services/auth_api_service.dart` — login, logout, current-user, change-password, set-token | MED-01 | LOW |
| P3-2 | `SessionRepository` — the single authority for save/restore/clear; **wipes every auth key** | MED-05 | LOW |
| P3-3 | `AuthRepository` — login/logout on top of the API service + session | — | MEDIUM |
| P3-4 | `SplashController`: three-way restore (valid / expired / **offline keeps session**); remove `catch (_) {}` | HIGH-02 | MEDIUM |
| P3-5 | **Remove `password` from the auto-login precondition** | CRIT-03 step 1 | LOW |
| P3-6 | **Change-password: delete the client-side check**, let the server decide; keep the payload identical | CRIT-03 step 2 | **MEDIUM** |
| P3-7 | **Stop writing `userPassword`; drop the key** | CRIT-03 steps 3-4 | LOW |
| P3-8 | One-time migration deleting `auth_user_password` from existing installs | CRIT-03 step 5 | MEDIUM |
| P3-9 | Global `401` → `SessionRepository.expire()` → `/login`; distinguish `401` from `403` | MED-07 | **MEDIUM** |
| P3-10 | Merge login + splash into `features/auth/` | MED-08 | LOW |
| P3-11 | Tests: restore matrix, login success/failure, token persistence, session clear completeness | testing gap | — |

**Strict ordering: P3-4 → P3-5 → P3-6 → P3-7 → P3-8.** Deleting the password before
its two consumers are fixed breaks auto-login and change-password. This ordering is
the entire mitigation for CRIT-03.

**P3-6 prerequisite:** confirm what the backend returns for a wrong current password
(`401`? `422` with `errors.password`?). Map it to the existing
`'Kata sandi saat ini salah.'` message so the UX is unchanged. **If the server does
not validate the current password at all, stop and escalate** — that is a backend
finding, not a client one.

**P3-9 caution:** a global 401 logout is a real behaviour change. Verify no endpoint
legitimately returns 401 for a permission problem (403 is the correct code there).
Ship behind a small allowlist if uncertain.

---

# Phase 4 — Pilot feature: attendance

One feature, migrated fully, to prove the structure before committing to it.

| ID | Task | Closes | Risk |
|---|---|---|---|
| P4-1 | **Characterisation tests first**: department-check matrix (both-null, one-null, string ids, numeric ids, mismatch, match) | CRIT-04 | — |
| P4-2 | Move models → `features/attendance/data/models/` | MED-08, MED-09 | LOW |
| P4-3 | `attendance_api_service.dart` — internal list + external QR endpoints | MED-01 | LOW |
| P4-4 | `attendance_repository.dart` | — | MEDIUM |
| P4-5 | `core/services/location_service.dart` + `permission_service.dart`; controller asks for `getCurrentPosition()` | — | MEDIUM |
| P4-6 | Fix the deprecated geolocator API via `LocationSettings` | analyze baseline | LOW |
| P4-7 | **Fix the fail-open department check** (separate commit) | CRIT-04 | MEDIUM |
| P4-8 | **Fix double navigation** (separate commit) | MED-12 | MEDIUM |
| P4-9 | **Fix the `/attendance_scanner` dead branch** (separate commit) | LOW-03 | LOW |
| P4-10 | Move QR base URL to `AppConfig`; remove the shadowing local `const` | MED-11 | LOW |
| P4-11 | Remove `Get.put` from `attendance_view` / `attendance_list_view` | HIGH-06 | MEDIUM |
| P4-12 | Extract view widgets (status card, action button, location status, history item) | — | LOW |
| P4-13 | Remove the 18 debug prints leaking the user object | CRIT-05 | LOW |

**P4-6 is the only sanctioned way to reach a clean analyze.** Migrating to
`LocationSettings` must preserve `LocationAccuracy.high` and the 15s/5s timeouts
exactly. Suppressing the deprecation is explicitly forbidden.

**Exit criteria — the structure is only ratified if all hold:**
- `flutter analyze` → 0 issues (the 4 baseline deprecations are gone via P4-6)
- attendance tests pass
- manual: scan valid QR → success; wrong-department QR → rejected; out-of-range → blocked; mock GPS → blocked
- everything under `features/attendance/`, nothing attendance-shaped left in `app/`

If the structure feels wrong here, **change the target before Phase 5**, not after.

---

# Phase 5 — Remaining features

Order chosen by ascending risk, so the pattern is well-rehearsed before the hard one:

| Order | Feature | Notes |
|---|---|---|
| 1 | `notification` | Simplest: one controller, one list, one model |
| 2 | `home/activity` | Small, self-contained |
| 3 | `home/announcement` | Two controllers; **consolidate the duplicate `AnnouncementDetailBinding`** |
| 4 | `home` | Dashboard; fix the literal `$statusCode` (LOW-04) |
| 5 | `profile` | 9 controllers, 8 sub-routes; **fix the wrong logout message + clear session on failure** (LOW-05) |
| 6 | `permit` | Largest and riskiest: 4 controllers, 769-line view, multipart upload, the HIGH-01 binding bug, the MED-13 suppression |

Per feature, in order: models → api_service → repository → controller → binding →
views → remove `Get.put` → **`dart format . && flutter analyze && flutter test`** →
commit.

Permit specifics: fix HIGH-01 with a real `PermitCreateBinding`; remove
`PermitCreateController` from `PermitListBinding`; drop the
`use_build_context_synchronously` suppression and fix each site with a
`context.mounted` guard; move `showDatePicker`/`showTimePicker` into the view.

---

# Phase 6 — Routing & shared UI

| ID | Task | Closes | Risk |
|---|---|---|---|
| P6-1 | Per-feature `<Feature>Routes.pages`, aggregated by `AppPages` | — | MEDIUM |
| P6-2 | **`PermitCreateBinding`** on `/permit/create` | HIGH-01 | MEDIUM |
| P6-3 | Full route↔binding audit — every route's controller registered by its own binding | HIGH-01, HIGH-06 | MEDIUM |
| P6-4 | Remove the last view-level `Get.put` | HIGH-06 | MEDIUM |
| P6-5 | Resolve `Routes.INTRODUCTION` — register or delete; decide the fate of the never-read `onboardingCompleted` | LOW-02 | LOW |
| P6-6 | Rename `SCREAMING_CASE` route constants; drop the 3 `constant_identifier_names` suppressions | LOW-06 | **MEDIUM** |
| P6-7 | Consolidate shared UI in `core/ui/` | LOW-01 | LOW |

**P6-6 caution:** the route *constants* are renamed; the route **path strings**
(`'/home'`, `'/permit/create'`, …) must not change. Paths appear in
`BottomNavController` as string literals and may appear in FCM payloads. Grep for
literals, not just constant references.

---

# Phase 7 — Platform services & notifications  ⬜ *berikutnya*

| ID | Task | Closes | Risk |
|---|---|---|---|
| P7-1 | Split notification concerns into service / messaging / permission / router | MED-03 | MEDIUM |
| P7-2 | **Fix iOS FCM token registration** | HIGH-03 | MEDIUM |
| P7-3 | **Fix the background handler**: `await initialize()` in-isolate; decide FCM-renders vs local-renders and document it | HIGH-05 | **MEDIUM** |
| P7-4 | Notification payload → `NotificationIntent` → `NotificationRouter`; stop hardcoding `'Default_Payload'` | MED-03 | MEDIUM |
| P7-5 | Centralise permissions in `PermissionService` | — | MEDIUM |
| P7-6 | Wrap `file_picker`, `image_picker`, `device_info_plus`, `url_launcher` behind thin core services | — | LOW |
| P7-7 | Delete dead `DefaultFirebaseOptions`, or regenerate it correctly with the FlutterFire CLI | LOW-06 | LOW |

**P7-2 needs a physical iPhone** — the simulator cannot obtain an APNs token.
**P7-3 needs all three app states tested on both platforms.** Do not change the FCM
message type server-side; that is out of scope.

---

# Phase 8 — Testing  ⬜

Mirror `lib/` under `test/`. Add `mocktail` and `integration_test` to
`dev_dependencies`.

```
test/
├── core/{network,storage,utils}/
├── features/{auth,attendance,permit,profile,home,notification}/
├── helpers/     # test doubles, pump helpers
└── fixtures/    # REAL captured API responses
integration_test/
```

| Priority | Coverage |
|---|---|
| 1 | Attendance department-check matrix (CRIT-04) |
| 2 | Session restore: valid / expired / offline (HIGH-02) |
| 3 | `ApiErrorMapper` status→exception |
| 4 | Auth-injection matrix (guards MED-02) |
| 5 | Model `fromJson` against real fixtures (MED-04) |
| 6 | Login flow + token persistence |
| 7 | Permit creation form assembly |
| 8 | Widget tests: attendance, permit list, home |
| 9 | Integration: launch → login → home → attendance → permit → logout |

**Delete `test/widget_test.dart`** — the failing counter starter test — in the first
commit of this phase. Fixtures must be **real captured responses**, not invented
ones; invented fixtures would encode the same assumptions the unchecked casts
already make, and would prove nothing.

No coverage target. Coverage that does not exercise the findings above is theatre.

---

# Phase 9 — Documentation & cleanup  🟨

| ID | Task | Closes |
|---|---|---|
| P9-1 | ESAS-specific README (all 17 sections from rule §38) | LOW-11 |
| P9-2 | `docs/architecture.md` with Mermaid diagrams | — |
| P9-3 | Execute `dead-code-candidates.md` after re-verifying references | LOW-06 |
| P9-4 | Import-style consistency pass | LOW-07 |
| P9-5 | Remove noise comments | LOW-08 |
| P9-6 | `flutter_launcher_icons` → `dev_dependencies` | LOW-10 |
| P9-7 | Incremental lint hardening (below) | — |
| P9-8 | `docs/refactoring/final-report.md` | — |

**P9-7 — adopt in this order, fixing all findings before moving on.** Each rule is
here because a finding above proves it would have caught something:

| Wave | Rules | Justified by |
|---|---|---|
| 1 | `avoid_print` | CRIT-05 — 132 calls, tokens logged |
| 2 | `use_build_context_synchronously` (remove the file-wide suppression) | MED-13 |
| 3 | `unawaited_futures`, `discarded_futures` | HIGH-05 — un-awaited `showNotification` in a dying isolate |
| 4 | `prefer_final_locals`, `unnecessary_to_list_in_spreads` | LOW-06 suppression removal |
| 5 | `cancel_subscriptions`, `close_sinks` | `onTokenRefresh` and 3 `ScrollController`s are never cancelled |
| 6 | `avoid_dynamic_calls` | MED-04 — `json['a']['b']` chains |

`depend_on_referenced_packages` is worth enabling early — it is nearly free here.
**Do not enable all six waves at once.** Each will surface findings that must be
fixed, not suppressed (rule §28).

**Deliberately deferred beyond Phase 9:**
- Dependency version upgrades (rule §29 — never mixed with structural refactoring)
- `flutter_secure_storage` migration (MED-06 — staged behind `TokenStorage`)
- Application-id rename (LOW-09 — a product decision with store implications)

---

## Phase → finding coverage

| Finding | Phase |
|---|---|
| CRIT-01 keystore | **Escalated now** — human decision, R-01 (amplified: one binary, all tenants) |
| TEN-01 no tenant concept | P1-10, P1-11 |
| TEN-02 host-based auth breaks | P1-12 |
| TEN-03 wildcard certificate hidden | P1-9 (gated) |
| TEN-04 credentials in plain storage | P1-13 |
| TEN-05 backend contract unknown | **Blocked — Q9** |
| HIGH-08 `com.example.esas` | **Blocked — product decision, R-13** |
| HIGH-09 hardcoded attendance IP | P4-10 (escalated) |
| CRIT-02 TLS | P1-9 (gated on the server certificate) |
| CRIT-03 password | P3-4 → P3-8, in that order |
| CRIT-04 fail-open check | P4-1 (tests) → P4-7 (fix) |
| CRIT-05 logging | P1-2, then per-feature |
| HIGH-01 permit binding | P6-2 |
| HIGH-02 session destroyed | P3-4 |
| HIGH-03 iOS FCM | P7-2 |
| HIGH-04 premature setupToken | P2-7 |
| HIGH-05 background handler | P7-3 |
| HIGH-06 `Get.put` in views | P4-11, P5, P6-4 |
| HIGH-07 multiple `ApiProvider` | P1-5, P2-4 |
| MED-01…13 | P1–P6 as tabled |
| LOW-01…11 | P6, P9 |

Every finding has an owner. Nothing is left unassigned.

---

# Phase 10 — Tenancy completion & API cutover  ⬜ *baru, 2026-09-01*

> **Digerbang [ADR-0007](../adr/0007-self-service-api-namespace.md).** Selama
> namespace belum diputuskan, tidak ada tugas di fase ini yang boleh dimulai —
> memindahkan 24 endpoint ke prefix yang salah lebih mahal daripada menunggu.

Fase ini tidak ada di rencana asli karena backendnya belum ditentukan saat rencana
ditulis. Sekarang ditentukan (ADR-0006), dan pekerjaannya jelas.

## 10a — Melengkapi tenancy (client saja, tidak menunggu backend)  ✅ **SELESAI 2026-09-01**

| ID | Tugas | Menutup | Status |
|---|---|---|---|
| P10-1 | Layar `/setup`: pilih workspace + alamat server | **CLI-01**, ADR-0005 §4 | ✅ |
| P10-2 | Probe workspace `GET /workspace` sebelum menerima input — menampilkan **nama perusahaan**, bukan "OK" | CLI-01 | ✅ |
| P10-3 | Urutan boot `splash → (belum dikonfigurasi?) → setup → login → home` | CLI-01 | ✅ |
| P10-4 | Aksi "Pindah Workspace" yang terpisah dari logout | — | ✅ |

Berkas yang lahir: `features/setup/{data/{models,services,repositories},presentation/{bindings,controllers,routes,views}}`,
ditambah `Env.platformApiPrefix`, `ApiRoutes.workspace`, dan
`ServerConfig.originOf` (komposisi kandidat sebagai fungsi murni).

Tiga keputusan yang layak dicatat karena tidak ada di rencana:

1. **Probe tidak lewat `ApiClient`, dan itu bukan pelanggaran ADR-0004.** Pada saat
   probe dikirim, dua hal yang biasa dipakai `ApiClient` untuk menyusun request
   belum ada: alamatnya masih kandidat, dan prefiksnya milik platform
   (`Env.platformApiPrefix`) bukan milik client ini. GetConnect menyusun URL
   dengan menyambung `baseUrl + path`, jadi tidak ada cara jujur meminta prefix
   lain lewatnya. Yang **tidak** diduplikasi: keputusan header
   (`AuthInterceptor.buildHeaders`), pemetaan status (`ApiErrorMapper`), dan tipe
   kegagalan (`ApiException`).
2. **Kandidat tidak pernah ditempelkan ke konfigurasi hidup untuk diuji** —
   berbeda dari sibling; lihat ADR-0005 Outcome.
3. **Workspace di-lowercase dan di-trim** sebelum disimpan: ia label DNS, dan
   `ACME ` adalah perusahaan yang sama dengan `acme`.

Gerbang: `flutter analyze` 0 issue · `flutter test` **197 lulus** (171 + 26) ·
`dart format` bersih.

## 10b — Pemindahan kontrak auth & absensi (6 endpoint yang sudah ada)

| ID | Tugas | Catatan |
|---|---|---|
| P10-5 | `AuthApiService` → kontrak `/api/v1`: `identifier` + `device_id`, logout **POST** + `fcm_token` | Bentuk lama `nip`/`device_info` hilang |
| P10-6 | Jalur galat device binding (G-2) | Butuh keputusan **M-D2** lebih dulu |
| P10-7 | Absensi memakai `attendance/context` | Menghapus tebakan client soal shift, geofence, dan aksi berikutnya |
| P10-8 | Absensi QR memakai `attendance/qr` / `qr-presences/redeem` | Cek departemen di client menjadi pre-check UX |
| P10-9 | Absensi wajah: challenge → rekam → kirim | Tiga permintaan, urutannya adalah kontrol keamanannya |
| P10-10 | Siklus push token penuh (`push-tokens`, `forget`, logout) | Menutup kebocoran notifikasi handset yang berpindah pemilik |

**P10-7 tidak lagi diblokir G-1.** `attendance/context` sudah membawa koordinat
geofence dan radius — lihat ADR-0006 *Amendment* §A-3.

## 10c — 18 endpoint self-service (menunggu backend)

Satu fitur selesai end-to-end sebelum fitur berikutnya dimulai; urutan dan kontrak
ada di **README Lampiran B**. Untuk setiap fitur, tugas client-nya sama bentuknya:

```text
1. tangkap fixture dari API BARU          ← prasyarat Fase 8, bukan sesudahnya
2. arahkan ulang fromJson + test fixture
3. arahkan ApiService ke path baru
4. Idempotency-Key untuk setiap write
5. hapus jalur lama dalam commit yang sama
```

Urutan fitur: **profile → change-password → announcements → notifications →
activities → attendances → summary → permit (6 endpoint) → bug-reports → payroll**.

## 10d — Gerbang keluar Fase 10

- [ ] ADR-0007 berstatus *Accepted*, bukan *Proposed*
- [ ] M-D2 (device binding) dan G-3 (abilities) terjawab
- [ ] Tidak ada permintaan yang keluar ke backend lama
- [ ] `Env.apiPrefix` bernilai satu, dan hanya satu, permukaan
- [ ] Seluruh fixture berasal dari API baru
- [ ] CRIT-02 tertutup — pemindahan ini menambah permukaan, dan menambah permukaan
      di atas TLS yang tidak divalidasi adalah memperbanyak kerusakan, bukan menundanya

---

## Phase → finding coverage — pembaruan 2026-09-01

Tabel di atas tetap berlaku untuk Fase 0–6. Yang berubah:

| Finding | Rencana lama | Sekarang |
|---|---|---|
| TEN-05 kontrak backend | "Blocked — Q9" | ✅ ADR-0006 |
| HIGH-09 endpoint hardcoded | P4-10 | ✅ tertutup |
| CRIT-04 | P4-1 → P4-7 | ✅ tertutup |
| CRIT-03 | P3-4 → P3-8 | ✅ tertutup |
| **CLI-01** layar setup workspace | *tidak ada di rencana* | **P10-1…4** |
| **G-1** payload profil | "blokir Fase 4" | separuh terjawab; sisanya `GET /profile` di Fase 10c |
| **G-2 / G-3** | dicatat sebagai gap | keputusan M-D2 dan pekerjaan backend; gerbang Fase 10 |
| **BE-01…BE-05** | *tidak ada di rencana* | temuan backend; menggerbang Gate A–C (lihat audit Addendum 3) |

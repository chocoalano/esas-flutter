# 05 — Progress

> **Diperbarui 2026-09-01.** Fase 0–6 selesai dan terverifikasi ulang hari ini:
> `flutter test` **171 lulus**, `flutter analyze` **0 issue**, `dart format` bersih.
> Keadaan terkini, keputusan yang masih menahan pekerjaan, dan Fase 10 yang baru
> ada di **Pembaruan 2026-09-01** di akhir berkas.

> Updated at the end of every task. `flutter analyze` / `flutter test` results are
> recorded per phase so regressions are attributable.

**Baseline** (`00-current-state.md`): analyze 4 info · test 1/1 failing · format 13 dirty

---

## Phase 0 — Audit & safety ✅ COMPLETE

| Task | Status | Notes |
|---|---|---|
| P0-1 `.gitignore` hardening | ✅ | Keystores, secrets, certs, `.env*`, `android/local.properties`. **Does not untrack the existing keystore.** |
| P0-2 Baseline capture | ✅ | Flutter 3.35.5 / Dart 3.9.2. analyze 4 info; test 1 failing; format 13 dirty. |
| P0-3 Architecture audit | ✅ | 5 CRITICAL, 7 HIGH, 13 MEDIUM, 11 LOW. |
| P0-4 Migration map | ✅ | All 117 files mapped. |
| P0-5 Risk register | ✅ | 14 risks; 3 open/blocking. |
| P0-6 Dead-code candidates | ✅ | 4 confirmed (0 references), 3 needing a product decision. |
| P0-7 ADRs 0001–0005 | ✅ | GetX retained; feature-first; repositories; centralised client; **subdomain multi-tenancy (0005, added 2026-09-01)**. |
| P0-9 Multi-tenancy audit addendum | ✅ | TEN-01…05. Reference implementation studied: `esas_attendance`. 2 findings escalated. |
| P0-8 Escalate CRIT-01 / CRIT-02 | ⛔ **BLOCKED** | Needs the repository owner. See R-01, R-02. |

**Code changed in Phase 0:** `.gitignore` only. No Dart file touched.

**Amendment 2026-09-01 — multi-tenancy.** Requirement added after the initial audit:
subdomain-based SaaS multi-tenancy, following `esas_attendance`. The sibling app's
implementation was read in full (`ServerConfig`, `Session`, `ApiClient`,
`WorkspaceProvider`, routing) and is adopted rather than reinvented — see ADR-0005.
Consequences: 5 new findings (TEN-01…05), 2 escalations (LOW-09 → HIGH-08,
MED-11 → HIGH-09), CRIT-01 amplified, 4 new Phase 1 tasks (P1-10…13), 3 new risks
(R-15…17). Still no Dart file touched.

**Verification:**
```
dart format --output=none --set-exit-if-changed .   → 13 dirty  (unchanged from baseline)
flutter analyze                                     → 4 info    (unchanged from baseline)
flutter test                                        → 1 failing (unchanged from baseline)
```
Baseline preserved exactly, as intended for an audit-only phase.

---

## Blocking items — need a decision before Phase 1 completes

| # | Question | Blocks | Owner |
|---|---|---|---|
| 1 | ~~Was the keystore ever created/used?~~ **Answered: yes, it is a real keystore.** Remaining: **is Play App Signing enabled?** That alone decides whether rotation is cheap or breaks every tenant's upgrades. | R-01 / CRIT-01 | Repository owner |
| 9 | ~~Which backend?~~ **ANSWERED 2026-09-01: migrate onto `tenancy-app`** (`/Users/ict/Documents/esas/tenancy-app`, stancl/tenancy ^3.10, `/api/v1`) — the same backend `esas_attendance` uses. See ADR-0006 and `06-api-migration-map.md`. | R-15 | ✅ Decided |
| 12 | **Should self-services adopt `tenancy-app`'s device binding?** It locks an account to one handset and needs HR to clear it before a second. Self-services has no such rule today. Policy, not engineering. **Blocks Phase 3.** | R-19 / G-2 | Product |
| 13 | **Will `GET /api/v1/profile` expose the nested employee record** — specifically `company.latitude`/`.longitude` and `employee.departement_id`? Attendance cannot geofence or run its department check without them. **Blocks Phase 4.** | R-18 / G-1 | Backend |
| 14 | **What token abilities should self-services get?** Login currently mints `['attendance']`; permits, payroll and profile writes need more. | G-3 | Backend |
| 10 | Is there a wildcard DNS record and wildcard TLS certificate for the tenant domain? If not, ship single-host + `X-Tenant` first. | R-17 / TEN-03 | Infra |
| 11 | Should the application id be renamed off `com.example.esas`? Play Store rejects it, but renaming a published app needs a new listing. Same underlying question as #1. | R-13 / HIGH-08 | Product |
| 2 | Does `:9443` serve a valid certificate chain? | R-02 / P1-9 | Backend / infra |
| 3 | Which base URL is production — `:9443` or `apiv2.sinergiabadisentosa.com`? | P1-1 | Backend |
| 4 | Does the backend validate the current password on `/auth/change-password`, and with which status code? | P3-6 / CRIT-03 | Backend |
| 5 | What JSON type do production QR codes use for `departement_id` and `id` — number or string? | P4-7 / CRIT-04 | Backend |
| 6 | Is `128.199.111.239:3000` internal-network-only? Can it serve TLS? | MED-11 | Infra |
| 7 | Is the APNs auth key configured in Firebase for `esas-44d5d`? | P7-2 / HIGH-03 | Owner |
| 8 | Is onboarding (`IntroductionScreen`) meant to be reachable? `onboardingCompleted` is written but never read. **Phase 6 deleted the unregistered `/introduction` constant; the never-read write survives until this is answered.** | P6-5 | Product |

Question 9 is **answered**: self-services migrates onto `tenancy-app`. That settles
the scope. Questions 3, 6 and 10 are **retired by it** — the base URL, the attendance
machine address and the wildcard certificate are now `tenancy-app`'s to answer, and
the hardcoded `128.199.111.239` endpoint disappears entirely (HIGH-09 closed by
construction).

What is now blocking, in order of when it bites:

- **Q12 (device binding)** — before Phase 3.
- **Q13 (profile payload)** — before Phase 4. This is the hard blocker: without
  `company.latitude`/`.longitude` and `employee.departement_id`, attendance cannot
  work at all.
- **Q14 (token abilities)** — before Phase 5.
- **18 backend endpoints** — one per feature, in the order Phase 5 consumes them.

**Phase 2 has no backend dependency and can start now.**

---

## Phase 1 — Core foundation 🟨 IN PROGRESS

Built **alongside** the existing code. `ApiProvider`, `GetStorage` and the old
controllers are untouched and still serve every screen; nothing in `lib/app/` calls
`lib/core/` yet. That is deliberate — Phase 1 lays the layers, Phases 3–5 move
features onto them.

| Task | Status | Notes |
|---|---|---|
| P1-1 `core/config/env.dart` | ✅ | `--dart-define` seeds. Default is byte-identical to the old `baseApiUrl` (`https://:9443` + `/api`). |
| P1-2 `core/utils/app_logger.dart` | ✅ | Levelled; debug/info compiled out of release; redaction for token / password / Authorization / NIP / FCM token. |
| P1-3 `core/storage/` | ✅ | `LocalStorage` + `SecureStore` + `StorageKeys`, each with an in-memory fake. |
| P1-4 `core/network/api_exception.dart`, `api_error_mapper.dart` | ✅ | One status→exception map. 401 ≠ 403; transport failure ≠ refusal. |
| P1-5 `core/network/api_client.dart` | ✅ | One client. `getObject`/`getList`/`postObject`/`postForm`. Origin resolved per request. |
| P1-6 `core/utils/json_parsers.dart` | ✅ | `asInt`/`asString`/`asDate`/`asBool`/`asModelList`/`dig`. |
| P1-7 `core/ui/` | ✅ *(Phase 6)* | Deferred to Phase 6 — moving shared widgets touches 33 views and belongs with the routing pass. Completed in P6-7. |
| P1-8 `core/theme/` | ⬜ | Deferred to Phase 2, with the bootstrap that reads it. |
| P1-9 TLS isolation | ✅ *(code)* / ⛔ *(rollout)* | `dev_http_overrides.dart` is `assert`-guarded and host-scoped. **Not yet wired in**; `main.dart` still installs the global bypass. Blocked on R-02. |
| P1-10 `core/config/server_config.dart` | ✅ | Ported from `esas_attendance`. `originFor`, `normalise`, host classification. |
| P1-11 `core/tenancy/tenant_context.dart` + `X-Tenant` | ✅ | Header sent in both modes; origin rebased per request. |
| P1-12 Explicit `authenticated:` flag | ✅ | `AuthInterceptor.buildHeaders` is a pure function, host-independent. Closes TEN-02 at the layer. |
| P1-13 `flutter_secure_storage` behind `TokenStorage` | ✅ | `SecureTokenStorage` **moves** a legacy plaintext token rather than copying it. |

### Two bugs the new tests found

Both were in code written this phase, and both were caught before anything shipped —
which is the argument for writing the tests alongside the layer rather than after.

1. **`ServerConfig.normalise` accepted a phrase as an address.** `Uri.tryParse` does
   not validate a host, it percent-encodes it: `http://not an address` parses cleanly
   with host `not%20an%20address`. A typo on the setup screen would have been stored
   as a server address and then failed as an unresolvable name — which reads to the
   user as "the server is down". Fixed with `isPlausibleHost`.
2. **Two redaction rules ate each other's matches.** `Authorization: Bearer <token>`
   produced `[redacted] [redacted]`, and under a different ordering would have blanked
   the scheme while leaving the secret beside it. Fixed by ordering the rules and
   adding a negative lookahead.

### Deviation from the plan

`test/widget_test.dart` was deleted now rather than in Phase 8. It is the Flutter
starter counter test — it references a UI ESAS never had and has failed since the
first commit. Leaving it would have made the `flutter test` gate permanently red and
therefore useless for the rest of the programme.

### Gates

|  | Baseline | Now |
|---|---|---|
| `flutter analyze` | 4 info | **4 info** (unchanged — the geolocator deprecations, due in P4-6) |
| `flutter test` | 1 test, **1 failing** | **104 tests, 0 failing** |
| `dart format --set-exit-if-changed` | 13 dirty | **0 dirty** |

The 12 binding files and `lib/generated/assets.dart` were reformatted by `dart format`.
Verified whitespace-only: `git diff --ignore-all-space -- '*.dart'` reports no content
change in any of them.

### Dependency changes

- **added** `flutter_secure_storage: ^9.2.4` — credentials and tenancy config (TEN-04,
  MED-06). Same version as `esas_attendance`.
- **moved** `flutter_launcher_icons` to `dev_dependencies` — a build-time tool with no
  `package:` import anywhere in `lib/` (LOW-10).

No other dependency touched. Version upgrades stay out of the refactor (rule §29).

---

## Phase 1 — remaining ⬜
## Phase 2 — Application bootstrap ✅ COMPLETE

First phase to touch the live path. `main.dart` went from **160 lines to 12**.

| Task | Status | Notes |
|---|---|---|
| P2-1 `bootstrap.dart` | ✅ | Ordered pipeline. Step order is **identical** to the old `main()` — verified line by line against `git show HEAD:lib/main.dart`. |
| P2-2 fatal / optional classification | ✅ | `core/boot/boot_pipeline.dart`, with tests. |
| P2-3 `app/app.dart` | ✅ | `MyApp` → `EsasApp`. Body unchanged. |
| P2-4 `app/bindings/initial_binding.dart` | ✅ | Single composition root. Each `permanent` justified in a table in the file. |
| P2-5 delete the two dead dialogs | ✅ | `showInAppNotification`, `showCustomExplainerDialog` — 61 lines, ATT leftovers, zero references. |
| P2-6 minimal `main.dart` | ✅ | `ensureInitialized` → `bootstrap()` → `runApp`. |
| P2-7 FCM sync out of boot | 🟨 Partial | `setupToken` now no-ops without a session and no longer shows a snackbar. The post-login trigger lands in Phase 3 with `AuthRepository` — see below. |
| P1-8 `core/theme/` (deferred here) | ✅ | `app_theme.dart`, `theme_controller.dart`, plus `system_ui_style.dart` extracted from `main`. |
| P1-7 `core/ui/` (partial) | ✅ | `bottom_nav_controller.dart` and `custom_bottom_navbar.dart` moved; the rest stays for Phase 6. |

### Boot failure policy (P2-2)

| Step | Class | On failure |
|---|---|---|
| `storage` | **fatal** | Rethrows. No theme, no session, nothing to show. |
| `server-config`, `tenancy` | optional | Falls back to the compiled-in seed. |
| `firebase` | optional | Push disabled for the session; the ERP works without it. |
| `notifications` | optional | **Not gated on Firebase** — see the correction below. |
| `messaging` | optional | Gated on both Firebase and local notifications. |
| `dependencies` | **fatal** | Programmer error. |
| `system-ui` | optional | Cosmetic. |

The old `main()` classified nothing: Firebase sat in a `try/catch` that only
`debugPrint`ed, and every other step ran unguarded — so a Firebase outage was
indistinguishable from success, while a `GetStorage.init()` failure would have crashed
on the first frame with no explanation.

### Three judgement calls worth recording

**1. `NotificationService.initialize()` is not gated on Firebase.** My first wiring
gated it, which was a regression: `flutter_local_notifications` does not depend on
Firebase, and `initialize()` is what asks for the Android 13+ notification permission.
Gating it would have let a Firebase outage silently swallow the permission prompt. The
old `main()` called it unconditionally, and now so does this.

**2. The 200 ms startup delay was kept.** It reads as cargo cult and costs 200 ms on
every cold start, but it sits immediately before `Firebase.initializeApp()` — presumably
what it was added for. Removing an unexplained sleep during a structural refactor is
how a heisenbug appears on one device model nobody here can reproduce. It should be
deleted in its own change, with a measurement and a device to test on.

**3. The `ThemeController` snackbar was kept, against my own plan.** P1-8 said to remove
it under MED-03. On reflection that was wrong: MED-03 is about *infrastructure*
presenting UI, and `ThemeController` is a presentation controller — showing a snackbar
is exactly what rule §18 says a controller may do. Removing it would have been a UX
change smuggled into an architecture commit, which rule §43 forbids. The plan entry was
mistaken; the snackbar stays.

By contrast, the snackbar in `FirebaseMessagingService` **was** removed. That one is
genuine infrastructure, and it fired before `runApp` — no `GetMaterialApp`, no overlay,
no theme.

### The migration trap that was deliberately not sprung

`bootstrap()` constructs `SecureTokenStorage` but **does not call `restore()`**.

`restore()` migrates a legacy token out of `GetStorage` and **deletes the original**.
Every unmigrated screen still reads that original through `ApiProvider`. Running the
migration now would have signed out every existing user the moment they updated. It
runs in Phase 3, in the same change that moves authentication onto `AuthRepository`.

This is written as a comment in `bootstrap.dart` at the point where the call would
naturally go, so the next person to look does not add it.

### Gates

|  | Baseline | After Phase 1 | After Phase 2 |
|---|---|---|---|
| `flutter analyze` | 4 info | 4 info | **4 info** |
| `flutter test` | 1 test, 1 failing | 104 passing | **112 passing, 0 failing** |
| `dart format` | 13 dirty | 0 | **0** |

Boot step order verified identical to the pre-refactor `main()`:
`GetStorage.init` → 200 ms delay → Firebase → dependency registration →
`NotificationService.initialize()` → messaging → system UI → `HttpOverrides` → `runApp`.
The two new steps (`server-config`, `tenancy`) are additive and read by nothing yet.

### Still deliberately unchanged

`MyHttpOverrides.install()` remains in the boot path. The scoped replacement
(`core/network/dev_http_overrides.dart`) is written and tested but **not wired**, gated
on R-02 — removing the global bypass before `:9443` serves a valid chain
would take the app offline. The class now carries a comment saying exactly that, and is
deliberately **not** marked `@Deprecated`: that would raise an analyzer warning at the
one call site obliged to keep calling it, and suppressing it is the pattern this
refactor forbids.

---

## Phase 2 — superseded entry ⬜
## Phase 3 — Authentication ✅ COMPLETE

| Task | Status | Notes |
|---|---|---|
| P3-1 `AuthApiService` | ✅ | 5 endpoints in one file. Targets the **current** backend deliberately — see below. |
| P3-2 `SessionRepository` | ✅ | One `clear()`, from one key list. Closes MED-05. |
| P3-3 `AuthRepository` | ✅ | login / logout / restore / expire. |
| P3-4 three-way restore | ✅ | `authenticated` / `expired` / `offline` / `absent`. Closes HIGH-02. |
| P3-5 drop the password precondition | ✅ | Auto-login no longer needs a stored password. |
| P3-6 server-side current-password check | ✅ | **Unblocked by evidence** — see below. |
| P3-7 stop writing `userPassword` | ✅ | Nothing writes it; both consumers deleted. |
| P3-8 purge it from existing installs | ✅ | `SessionRepository.restore()` deletes it once, with a test. |
| P3-9 central 401 → expire | ✅ | In `ApiClient`. 401 only, authenticated requests only. |
| P3-10 merge into `features/auth/` | ✅ | splash + login + change-password. Route paths unchanged. |
| P3-11 tests | ✅ | 21 auth tests; 133 total. |

### P3-6 was unblocked by reading the backend, not by guessing

The plan flagged this as needing backend confirmation: deleting the client-side
current-password check is only safe if the server actually validates it. Rather than
ask, I read `esas-erp-api-modulars`:

```php
// app/GeneralModule/Repositories/AuthRepository.php
if (!Hash::check($currentPassword, $user->password)) {
    return ['success' => false, 'message' => 'Password saat ini salah.'];
}
```

It validates, and answers a wrong password with **HTTP 200** and `success: false` —
which is exactly the shape the Flutter code already branched on. The service layer
unpacks the request correctly (I checked, because the controller passes 2 arguments to
a 4-argument repository method — `AuthService::update_password` adapts them).

So the check could be deleted outright. **CRIT-03 is fully closed**: nothing writes the
password, both consumers are gone, and existing installs are purged on next launch.

That also fixed a real bug: the client-side comparison meant a password changed on the
web portal left the local copy stale, so the mobile screen rejected the employee's
genuine, correct password.

### Endpoints deliberately still point at the old backend

`AuthApiService` targets `/general-module/*`, not `tenancy-app`'s `/api/v1`. ADR-0006
migrates the backend, but those endpoints do not exist yet and gap G-1 blocks the ones
that do. Targeting the live backend means CRIT-03, HIGH-02, MED-05 and MED-07 close
**now** instead of waiting on backend delivery — and retargeting is an edit to one
file, which is the entire reason the layer exists.

### The dual write, and how to know when to remove it

`SessionRepository.save()` writes the token to the keychain **and** mirrors the session
into the old `GetStorage` keys. That is a strangler seam, not belt-and-braces: every
unmigrated screen still reads those keys directly — `ApiProvider` reads `auth_token`,
`HomeController` and `AttendanceController` read `auth_user_json`. Writing only to the
keychain would sign out every existing user on update.

`SessionRepository.legacyMirrorEnabled` is the switch. `grep -rn "StorageKeys.legacy"
lib` tells you when it is safe to flip — end of Phase 5.

### Gates

|  | Baseline | Phase 1 | Phase 2 | Phase 3 |
|---|---|---|---|---|
| `flutter analyze` | 4 info | 4 | 4 | **4 info** |
| `flutter test` | 1 test, 1 failing | 104 | 112 | **133 passing, 0 failing** |
| `dart format` | 13 dirty | 0 | 0 | **0** |

---

## Phase 3 — superseded entry ⬜
## Phase 4 — Attendance pilot ✅ COMPLETE

**`flutter analyze` is now completely clean — 0 issues, better than the 4-issue
baseline.** P4-6 removed the four `geolocator` deprecations that had been its entire
content since the audit.

| Task | Status | Notes |
|---|---|---|
| P4-1 department-check matrix tests | ✅ | 13 tests on `QrPayload`. |
| P4-2 models → feature | ✅ | `attendance.dart`, `attendance_user.dart`; `fromJson` retrofitted to the null-safe accessors. |
| P4-3 `AttendanceApiService` | ✅ | On `/api/selfservice`. |
| P4-4 `AttendanceRepository` | ✅ | Owns the scan decision and the geofence lookup. |
| P4-5 `LocationService` | ✅ | Permission dance, mock check, distance. Returns a result; shows nothing. |
| P4-6 geolocator `LocationSettings` | ✅ | **Closes the last 4 analyze findings.** |
| P4-7 fail-open department check | ✅ | **CRIT-04 closed.** |
| P4-8 double navigation | ✅ | MED-12 closed. |
| P4-9 `/attendance_scanner` dead branch | ✅ | LOW-03 closed. |
| P4-10 QR endpoint to config | ✅ | **HIGH-09 closed** — the hardcoded IP is gone. |
| P4-11 remove `Get.put` from views | ✅ | Both attendance views are `GetView` now. |
| P4-13 remove PII debug prints | ✅ | The 18 prints, including the whole user object, are gone. |
| P4-12 extract view widgets | 🟨 → **P9** | The detail sheet moved to `widgets/`. The rest did **not** land in Phase 6: P6-7 is about *shared* UI moving into `core/`, and these are three feature-private files totalling 1 040 lines with no widget tests under them. Splitting them inside a routing commit would be exactly the untestable behaviour change rule §1 forbids. Rescheduled to Phase 9. |

### The API surface moved to `/api/selfservice`

Per the owner's instruction, paths no longer name the old backend's module layout:

```
before   https://:9443/api/general-module/auth/login
after    https://<tenant>/api/selfservice/auth/login
```

Every path now lives in `core/config/api_routes.dart`. Auth and attendance are on it;
the remaining features migrate in Phase 5 and still reach the old backend through
`ApiProvider` until they do.

> **⚠ These endpoints do not exist yet.** Until `/api/selfservice` ships on
> `tenancy-app`, a build from this source cannot reach a live server for login or
> attendance. That is ADR-0006's cutover, made explicit rather than discovered. A
> build can be pointed elsewhere without editing code:
> `flutter run --dart-define=API_PREFIX=/api/v1`.

### CRIT-04, and why it is a type now

The guard was three lines inside a 90-line method:

```dart
final int? currentQrDeptId = int.tryParse(qrCodeData['departement_id']);
if (currentStorageDeptId == currentQrDeptId) { /* submit */ }
```

Two defects sat on them. It **failed open** — `null == null` is `true`, so a stale
cached user plus an unparseable QR skipped the only client-side department check and
posted a record with a null user id. And it **threw on valid input** — `int.tryParse`
takes a non-nullable `String`, so a QR encoding `{"departement_id": 12}` as a number
raised a `TypeError` that was swallowed and reported as a generic "Pengiriman gagal".

It is now `QrPayload.matchesDepartment`, which fails **closed**, and 13 tests pin the
matrix: numeric ids, string ids, mixed, both-null, either-null, mismatch, match.

### A bug I introduced and caught

My first `LocationService` shipped a convoluted platform helper whose `_detect()`
returned `false` unconditionally — which would have disabled **mock-GPS detection
entirely**, silently defeating an anti-fraud control. Replaced with an injectable
`bool Function() isAndroid = () => GetPlatform.isAndroid`.

### Gates

|  | Baseline | P1 | P2 | P3 | **P4** |
|---|---|---|---|---|---|
| `flutter analyze` | 4 info | 4 | 4 | 4 | **0 — clean** |
| `flutter test` | 1 test, 1 failing | 104 | 112 | 133 | **151 passing** |
| `dart format` | 13 dirty | 0 | 0 | 0 | **0** |

---

## Phase 4 — superseded entry ⬜
## Phase 5 — Remaining features ✅ COMPLETE

All six features migrated, in ascending risk order. **`lib/app/` now holds six files.**

| Order | Feature | Closed along the way |
|---|---|---|
| 1 | notification | 40 unchecked casts in the model; leaked `ScrollController` |
| 2–4 | home (+ activity, announcement) | LOW-04 literal `$statusCode`; the duplicate `AnnouncementDetailBinding` that registered the wrong controller |
| 5 | profile | LOW-05 wrong logout message; five duplicate `/auth` fetches collapsed to one cached read |
| 6 | permit | **HIGH-01** wrong binding; **MED-13** file-wide suppression; 8 undisposed `TextEditingController`s |

### HIGH-01 — `/permit/create` had the wrong binding

The route was wired to `PermitShowBinding`, which registers `PermitShowController` and
nothing else. The screen worked only by accident: `PermitListBinding` registered
`PermitCreateController`, and `Get.toNamed` keeps the list route alive, so the instance
was still in the registry when the create screen asked for it. Any other way in — a deep
link, a notification tap, an `offAllNamed` — threw "PermitCreateController not found".

It now has `PermitCreateBinding`, and `PermitListBinding` no longer registers a
controller belonging to a different screen.

### MED-13 — the suppression is gone, and it was hiding something

`permit_create_controller.dart` opened with
`// ignore_for_file: use_build_context_synchronously`. Removing it surfaced one real
async-gap: `pickTime` calls `picked.format(context)` after awaiting `showTimePicker`,
so it needs a `context.mounted` guard. Fixed rather than re-suppressed.

The other suppression, `unnecessary_to_list_in_spreads` on `permit_show.dart`, was also
removed — and the finding underneath it fixed.

### `ApiProvider` is retired

Its last caller was `FirebaseMessagingService`, now on `AuthApiService`. The class is
deleted, and with it the four-registrations problem behind HIGH-07.

**The legacy storage mirror is off.** Phase 3 dual-wrote the token into the old
`GetStorage` keys because unmigrated screens read them directly. Every one of those
readers is gone, so the token now exists in exactly one place — the keychain. The user
record is still cached locally, because losing it costs a refresh rather than a session,
and `clear()` still names every legacy key so an upgrading device leaves nothing behind.

A test pins the upgrade path: a token left in plain storage by an older build is
migrated into the keychain on restore, not ignored.

### Five duplicate network calls, gone

`personal`, `worked`, `family`, `education` and `experience` each fetched
`/general-module/auth` independently on open — walking the tabs made five identical
requests for one user object. They share `ProfileRepository.currentUser()`, which caches
and de-duplicates concurrent callers.

### Gates

|  | Baseline | P1 | P2 | P3 | P4 | **P5** |
|---|---|---|---|---|---|---|
| `flutter analyze` | 4 info | 4 | 4 | 4 | 0 | **0 — clean** |
| `flutter test` | 1 test, 1 failing | 104 | 112 | 133 | 151 | **153 passing** |
| `dart format` | 13 dirty | 0 | 0 | 0 | 0 | **0** |

### What is left in `lib/app/`

```
app.dart, bindings/initial_binding.dart, routes/{app_pages,app_routes}.dart,
widgets/controllers/storage_keys.dart, widgets/views/snackbar.dart
```

The last two are neither controllers nor views (LOW-01) and move to `core/` in Phase 6,
along with the `utils/helper.dart` split and per-feature route registration.

**Layering verified:** `core/` imports nothing from `utils/`, `app/widgets/` or
`features/`.

---

## Phase 5 — superseded entry ⬜
## Phase 6 — Routing & shared UI ✅ COMPLETE

**`lib/app/` is now three files and two folders**, and `lib/utils/` holds nothing
but the notification services Phase 7 owns. The 120-line route switchboard is gone.

| Task | Status | Notes |
|---|---|---|
| P6-1 Per-feature routes, aggregated by `AppPages` | ✅ | Six features × `<f>_routes.dart` (names) + `<f>_pages.dart` (pages). |
| P6-2 `PermitCreateBinding` on `/permit/create` | ✅ | Done in Phase 5; now pinned by a test. |
| P6-3 Full route↔binding audit | ✅ | A test, not a one-off read. 22 routes, all bound, all correctly. |
| P6-4 Last view-level controller construction | ✅ | `GetBuilder<ThemeController>(init: …)` in `home_view`. |
| P6-5 `Routes.INTRODUCTION` | ✅ *(constant)* / ⛔ *(gate)* | Constant deleted. The never-read `onboardingCompleted` write stays — Q8. |
| P6-6 Rename `SCREAMING_CASE`, drop the suppressions | ✅ | All 3 `constant_identifier_names` suppressions gone. **Zero `ignore_for_file` left in `lib/`.** |
| P6-7 Consolidate shared UI in `core/ui/` | ✅ | `helper.dart` split five ways; `app/widgets/` deleted. |

### The route table split, and what was frozen

Route *names* now live with the feature that owns them, as leaf files that import
nothing:

```
features/<f>/presentation/routes/<f>_routes.dart   # path constants — no imports
features/<f>/presentation/routes/<f>_pages.dart    # GetPage list — imports views + bindings
app/routing/app_pages.dart                          # six spreads, nothing else
```

**Deviation from `03-migration-map.md`.** The map put `pages` and the path
constants in one `<f>_routes.dart`. Splitting them is what keeps the names a
leaf: a view that only wants to spell `/home` would otherwise import every home
view transitively, and `Routes` ↔ views would be a genuine import cycle.

**There is deliberately no central `Routes` class any more.** A destination is
named by its owner — `HomeRoutes.home`, `PermitRoutes.create` — which is the
pattern Phase 5 already established for `ProfileRoutes`, and what makes a
feature's routes deletable with the feature.

The path *strings* are untouched, and that is now enforced rather than asserted:
`test/app/routing/app_pages_test.dart` lists all 22 verbatim. They appear in FCM
payloads, and an install that updates mid-navigation resolves the string it
already had.

### P6-3 is a test, because reading it once does not keep it true

HIGH-01 (`/permit/create` bound to `PermitShowBinding`) and the duplicate
`AnnouncementDetailBinding` were the same mistake twice: a route wired to a
binding that registers a controller belonging to a different screen. Both screens
worked anyway, because some other live route happened to have registered the
controller they wanted — so neither showed up until someone arrived by a deep
link or a notification tap.

A Get registry is not available in a unit test, so the assertion is the naming
convention the codebase already follows: **`XView` is bound by `XBinding`**. All
22 routes pass. The test fails loudly the next time a page is given a neighbour's
binding, which is the only thing that would have caught HIGH-01 before shipping.

### `BottomNavController` held a second copy of the route table

P6-6 warned that the tab paths are string literals. They were — five of them,
`'/home'` … `'/profile'`, in a `switch`. `core/` may not import `features/`, so
the fix is not to reach for the constants but to stop the controller owning the
knowledge: the destinations are a constructor argument, supplied by
`InitialBinding`, which lives in `app/` and may name whatever it likes.

Same paths, same order, and an out-of-range index is now ignored instead of
silently selecting a tab it cannot navigate to.

### `helper.dart` was five things in one file

| Was | Now |
|---|---|
| `formatDateIndo`, `formatFullDateIndo` | `core/utils/date_formatter.dart` |
| `limitString` | `core/utils/string_utils.dart` |
| `imageUrl()` | `core/config/asset_url.dart` — reads `Env.assetBaseUrl` |
| `inputDecoration()` | `core/ui/components/app_input_decoration.dart` |
| `buildAvatar()` | `core/ui/components/app_avatar.dart` — a widget now |
| `showApiError()` | **deleted** — zero callers; `ApiErrorMapper` replaced it in Phase 3 |

`utils/api_constants.dart` went with it. It still held `baseApiUrl` pointing at
the pre-ADR-0006 backend and a second hardcoded CDN origin — both superseded by
`Env`, and both a trap for the next person who grepped for a base URL.

Two behaviour notes, neither visible:

1. **`assetUrl` no longer double-prefixes.** Every call site passed
   `imageUrl("${Env.assetBaseUrl}/$path")` — a full URL, so the function returned
   it untouched and its own CDN constant was dead. The call sites now pass the
   stored path and get the identical string back.
2. **`DateFormatter` builds its formatter outside the `try`.** The old
   `catch (e)` swallowed *everything*, so an uninitialised `id` locale — a boot
   ordering bug — would have rendered every date on every screen as a raw ISO
   string with nothing logged. Only the parse is forgiving now.

### `app/widgets/` is gone (LOW-01)

`storage_keys.dart` was a constants class in `widgets/controllers/` and
`snackbar.dart` four global functions in `widgets/views/`. Neither was a widget.
The snackbars are `core/ui/dialogs/app_snackbar.dart`; the legacy keys were
already duplicated verbatim as `StorageKeys.legacy`, so the file was deleted and
its two readers point at the one that remains.

### Gates

|  | Baseline | P1 | P2 | P3 | P4 | P5 | **P6** |
|---|---|---|---|---|---|---|---|
| `flutter analyze` | 4 info | 4 | 4 | 4 | 0 | 0 | **0 — clean** |
| `flutter test` | 1 test, 1 failing | 104 | 112 | 133 | 151 | 153 | **171 passing** |
| `dart format` | 13 dirty | 0 | 0 | 0 | 0 | 0 | **0** |

18 new tests: 6 on the route table and its bindings, 3 on the tab destinations,
3 on `DateFormatter`, 4 on `limitString`, 3 on `assetUrl` — minus one that
replaced an old expectation.

### What is left in `lib/app/` and `lib/utils/`

```
app/     app.dart, bindings/initial_binding.dart, routing/app_pages.dart
utils/   my_http_overrides.dart  (blocked on R-02)
         notification/           (Phase 7)
```

**Layering verified:** `core/` imports nothing from `features/`, `app/` or
`lib/utils/`; `features/` imports nothing from `app/`.

---

## Phase 7 — Platform services ⬜ NOT STARTED  ← next
## Phase 8 — Testing ⬜ NOT STARTED
## Phase 9 — Documentation & cleanup ⬜ NOT STARTED

---

## Findings ledger

| ID | Title | Severity | Phase | Status |
|---|---|---|---|---|
| CRIT-01 | Keystore committed to a public repo | CRITICAL ↑ | escalated | ⛔ Blocked (Play App Signing?) |
| CRIT-02 | TLS validation globally disabled | CRITICAL | P1-9 | ⛔ Blocked (server cert) |
| CRIT-03 | Plaintext password persisted | CRITICAL | P3-4→8 | ✅ **Closed** |
| CRIT-04 | Department check fails open | CRITICAL | P4-1/7 | ✅ **Closed** |
| CRIT-05 | Tokens & PII in release logs | CRITICAL | P1-2 | ⬜ Planned |
| HIGH-01 | `/permit/create` wrong binding | HIGH | P5 | ✅ **Closed** |
| HIGH-02 | Network blip destroys the session | HIGH | P3-4 | ✅ **Closed** |
| HIGH-03 | iOS never registers its FCM token | HIGH | P7-2 | ⬜ Planned |
| HIGH-04 | `setupToken` fires pre-auth, pre-`runApp` | HIGH | P2-7 | ✅ Closed |
| HIGH-05 | Background handler uses uninitialised plugin | HIGH | P7-3 | ⬜ Planned |
| HIGH-06 | Views self-register controllers (8) | HIGH | P4/P5 | ✅ Closed |
| HIGH-07 | `ApiProvider` registered 4 ways | HIGH | P1-5/P5 | ✅ **Closed** — class deleted |
| MED-01 | 24 endpoints inline in controllers | MEDIUM | P1–P5 | ✅ Closed — all in `ApiRoutes` |
| MED-02 | `ApiProvider` god object | MEDIUM | P1-5/P5 | ✅ Closed |
| MED-03 | Infrastructure shows UI | MEDIUM | P1-8/P7-1 | ⬜ Planned |
| MED-04 | 40 unchecked casts in models | MEDIUM | P1–P5 | ✅ Closed |
| MED-05 | 3 divergent `clearStorage()` | MEDIUM | P3-2 | ✅ Closed |
| MED-06 | Token in unencrypted storage | MEDIUM | P1-3/P5 | ✅ **Closed** — keychain only |
| MED-07 | No central 401 handling | MEDIUM | P3-9 | ✅ Closed — every feature is on `ApiClient` |
| MED-08 | Feature split across 3 roots | MEDIUM | P4–P5 | ✅ Closed |
| MED-09 | PascalCase model folders | MEDIUM | P4–P5 | ✅ Closed |
| MED-10 | Env config requires a source edit | MEDIUM | P1-1 | ⬜ Planned |
| MED-11 / HIGH-09 | Cleartext hardcoded attendance endpoint | HIGH | P4-10 | ✅ **Closed** |
| MED-12 | Double navigation on failure | MEDIUM | P4-8 | ✅ Closed |
| MED-13 | `use_build_context_synchronously` suppressed | MEDIUM | P5 | ✅ Closed |
| LOW-01 | `app/widgets/` misclassifies its contents | LOW | P6-7 | ✅ **Closed** — folder deleted |
| LOW-02 | `Routes.INTRODUCTION` never registered | LOW | P6-5 | 🟨 Constant deleted; the onboarding gate is Q8 |
| LOW-06 | Dead code | LOW | P6 | 🟨 `constant_identifier_names` × 3 and the `PRODUCT_DETAIL` sketch gone; `firebase_services.dart` is P7-7 |
| LOW-07 | Mixed import styles | LOW | P6 | ✅ **Closed** in the routing files |
| LOW-08 | Noise comments | LOW | P6/P9 | 🟨 `api_constants.dart` deleted with its commented-out LAN IPs |
| LOW-03…05, 09…11 | see the audit | LOW | P4/P5/P9 | 🟨 LOW-10 closed (pubspec) |
| **TEN-01** | **No tenant concept anywhere** | **HIGH** | P1-10/11 | 🟨 Layer ready; wired in P2/P3 |
| **TEN-02** | **Host-based auth injection breaks under subdomains** | **HIGH** | P1-12 | ✅ Closed at the layer |
| **TEN-03** | **Wildcard certificate hidden by the TLS bypass** | **CRITICAL** | P1-9 | ⛔ Blocked (infra) |
| **TEN-04** | **Credentials belong in secure storage** | MEDIUM | P1-13 | 🟨 Layer ready; wired in P3 |
| **TEN-05** | **Backend tenancy contract unknown** | **HIGH** | — | ✅ Decided → ADR-0006 |
| **HIGH-09** | ~~Hardcoded attendance IP~~ | HIGH | — | ✅ **Closed by ADR-0006** — endpoint disappears |
| **G-1** | **Login payload omits geofence + dept ids** | **HIGH** | P4 | ⛔ Blocked (Q13) |
| **G-2** | **Device binding is a new policy** | MEDIUM | P5/P6 | ⛔ Blocked (Q12) — not needed until the backend swap |
| **G-3** | **Token abilities too narrow** | MEDIUM | P5 | ⛔ Blocked (Q14) |
| **HIGH-08** | **`com.example.esas` blocks Play Store** | HIGH ↑ | — | ⛔ Blocked (product) |


---

# Pembaruan 2026-09-01

## Gerbang, diverifikasi ulang hari ini

```
flutter analyze                                    → 0 issue
flutter test                                       → 171 lulus, 0 gagal (18 berkas)
dart format --output=none --set-exit-if-changed .  → bersih
```

Angka struktur: 144 berkas Dart · 22 view · 17 controller · 7 repository ·
6 API service · 6 binding fitur · 22 route (path identik dengan baseline).

## Fase 7–10

| Fase | Status | Yang menahannya |
|---|---|---|
| 7 Platform services | ⬜ **berikutnya** | Butuh iPhone fisik (P7-2) dan konfirmasi APNs key (Q7). P7-1/4/5/6/7 tidak menunggu apa pun |
| 8 Testing | ⬜ | **Fixture harus diambil dari API baru.** Menulisnya sekarang hanya mengabadikan bentuk payload yang akan diganti — jadi Fase 8 mengikuti Fase 10c per fitur, bukan mendahuluinya |
| 9 Documentation & cleanup | 🟨 | README sudah menjadi blueprint mobile v1.1 (LOW-11 tertutup). Sisanya: `architecture.md`, eksekusi dead-code, lint hardening |
| **10a Tenancy completion** | ✅ **selesai 2026-09-01** | Layar setup workspace; lihat bagian Fase 10a di akhir berkas |
| **10b–10d API cutover** | ⬜ | Digerbang ADR-0007. Rinciannya di `02-refactoring-plan.md` |

**Rekomendasi urutan itu dijalankan:** P10-1…P10-4 selesai 2026-09-01. Berikutnya
Fase 7, yang juga tidak menunggu backend kecuali dua tugasnya yang butuh perangkat
fisik (P7-2) dan konfirmasi APNs (Q7).

## Keputusan yang masih menahan pekerjaan

Menggantikan tabel *Blocking items* di atas. Yang sudah terjawab tidak diulang.

| # | Pertanyaan | Pemilik | Menahan |
|---|---|---|---|
| **M-D1** | `/api/v1` atau `/api/selfservice`? | owner | **Seluruh pekerjaan backend ESS.** ADR-0007, status *Proposed* |
| **M-D2** (Q12) | Device binding berlaku untuk self-service? | produk | P10-6, jalur galat login |
| **G-3** (Q14) | Abilities token untuk self-service | backend | Setiap endpoint ESS setelah pemindahan |
| **Q1** | Play App Signing aktif? | owner | R-01, rilis publik |
| **Q11** | Ganti application id? | produk | R-13, Play Store |
| **Q2** | Sertifikat server valid? | infra | R-02 → CRIT-02, TEN-03 |
| **Q7** | APNs key terkonfigurasi di Firebase? | owner | P7-2, push iOS |
| **M-D5** (Q8) | Onboarding dipertahankan? | produk | Tulisan `onboardingCompleted` tanpa pembaca |

**Q13 diperbarui, bukan dihapus.** Pertanyaannya dulu: "apakah `GET /profile` akan
mengekspos `company.latitude/longitude` dan `employee.departement_id`, karena tanpa
itu absensi tidak bisa jalan?" Jawaban setelah memeriksa backend: **absensi tidak
membutuhkannya dari sana.** `GET /api/v1/attendance/context` sudah mengirim
`location.required`, `latitude`, `longitude`, `radius_metres`, dan pemeriksaan
departemen QR dilakukan server saat redeem. Yang tersisa dari Q13 adalah kebutuhan
**layar profil**, dan itu tetap dijawab `GET /profile`. Konsekuensinya: Fase 10b
(absensi) dapat berjalan tanpa menunggu Q13.

## Temuan baru yang masuk ke ledger

| ID | Isi | Di mana |
|---|---|---|
| **CLI-01** | Layar setup workspace tidak pernah dibuat (ADR-0005 §4) — satu APK belum melayani banyak tenant | audit Addendum 2, R-22, P10-1…4 |
| **BE-01** | Otorisasi backend fail-open pada workspace tanpa role | audit Addendum 3, R-21 |
| **BE-02** | `qr-presences/redeem` meloloskan karyawan tanpa departemen | audit Addendum 3 |
| **BE-03** | Abilities token `['attendance']` saja | G-3 |
| **BE-04** | Device binding satu handset | G-2 / M-D2 |
| **BE-05** | Lisensi model wajah non-komersial | R-23 |

## Catatan untuk pembaca berikutnya

Dokumen ini mencatat **apa yang dikerjakan dan mengapa**, termasuk keputusan yang
kemudian terbukti salah. Tiga yang paling berguna untuk diingat:

1. **Bug yang ditemukan test yang ditulis bersama lapisannya**, bukan sesudahnya —
   `ServerConfig.normalise` menerima frasa berspasi sebagai alamat, dan dua aturan
   redaksi saling memakan hasil.
2. **Perangkap migrasi yang sengaja tidak dipicu** — `SecureTokenStorage.restore()`
   tidak dipanggil di Fase 2 karena akan mengeluarkan setiap pengguna yang
   memperbarui aplikasi.
3. **Satu rencana yang dibatalkan karena salah** — P1-8 hendak menghapus snackbar
   `ThemeController`; setelah ditimbang, itu perubahan UX yang diselundupkan ke
   commit arsitektur, jadi snackbarnya tetap.

---

# Fase 10a — Melengkapi tenancy ✅ SELESAI 2026-09-01

Dikerjakan lebih dulu justru karena ia satu-satunya pekerjaan tersisa yang **tidak
menunggu siapa pun**: bukan owner (M-D1), bukan backend (18 endpoint), bukan
perangkat uji (Fase 7).

| Task | Status | Catatan |
|---|---|---|
| P10-1 layar `/setup` | ✅ | `features/setup/`, bentuk fitur yang sama dengan enam fitur lain |
| P10-2 probe workspace | ✅ | `GET {platform}/workspace`, tanpa token, menampilkan **nama perusahaan** |
| P10-3 gerbang boot | ✅ | `splash → (belum ada workspace?) → setup → login → home` |
| P10-4 pindah workspace | ✅ | Di profil, terpisah dari logout, dengan konfirmasi yang menyebut workspace yang ditinggalkan |

### Gerbang

|  | Sebelum | Sesudah |
|---|---|---|
| `flutter analyze` | 0 issue | **0 issue** |
| `flutter test` | 171 lulus | **199 lulus** (+28) |
| `dart format` | bersih | **bersih** |
| Route | 22 | **23** — `/setup`, satu-satunya penambahan sejak path dibekukan |

Test route table sengaja **gagal** saat `/setup` ditambahkan, dan itu memang
fungsinya: 22 path itu kontrak yang hidup di payload FCM. Penambahannya diperbarui
secara sadar, dengan alasannya ditulis di dalam test.

### Empat keputusan implementasi

**1. Probe tidak lewat `ApiClient`, dan ADR-0004 tidak dilanggar.** Saat probe
dikirim, dua hal yang biasa dipakai `ApiClient` untuk menyusun request belum ada:
alamatnya masih kandidat yang belum disimpan, dan prefiksnya milik platform
(`Env.platformApiPrefix`) bukan milik client ini. GetConnect menyusun URL dengan
`baseUrl + path` tanpa syarat — terverifikasi di `get-4.7.3/.../http.dart:92` —
jadi tidak ada cara jujur meminta prefix lain lewatnya. Yang **tidak**
diduplikasi: keputusan header (`AuthInterceptor.buildHeaders`), pemetaan status
(`ApiErrorMapper`), dan tipe kegagalan (`ApiException`).

**2. Kandidat tidak pernah ditempelkan ke konfigurasi hidup.** Sibling
`esas_attendance` menulis alamat kandidat ke `ServerConfig.instance`, memanggil,
lalu mengembalikannya bila gagal. Itu bekerja, tetapi selama request berlangsung
handset menunjuk alamat yang belum pernah menjawab — dan permanen bila prosesnya
mati di tengah. `ServerConfig.originOf` menyusun kandidat sebagai fungsi murni;
`save()` baru dipanggil setelah server mengonfirmasi. Jendela itu hilang.

**3. `Env.platformApiPrefix` dipisahkan dari `Env.apiPrefix`.** Bukan duplikasi:
ia seam yang membuat layar setup tidak tersandera M-D1. Bila ADR-0007 memilih
`/api/v1`, kedua nilai menyatu; bila memilih `/api/selfservice`, keduanya tetap
terpisah dan tetap benar.

**4. Urutan pada "Pindah Workspace": sesi dulu, workspace kemudian.** Token
dicetak di database workspace lama dan tidak berlaku di mana pun selain di sana —
melepas workspace lebih dulu akan meninggalkan kredensial yang tidak pernah bisa
dipakai dan tidak pernah bisa dicabut dari sini.

### Satu regresi yang saya buat sendiri, dan bagaimana ia terlihat

Gerbang di P10-3 dipasang di `SplashController.onInit()`, dan itu **salah**.

GetX memanggil `onInit` **selagi widget route sedang dibangun**. Sebuah fungsi
`async` berjalan sinkron sampai `await` pertamanya — dan pemeriksaan workspace
yang baru tidak punya `await` di depannya sama sekali, tidak seperti setiap
keputusan lain di method itu yang duduk di belakang
`await _auth.restoreSession()`. Akibatnya `Get.offAllNamed` dieksekusi di tengah
build:

```text
setState() or markNeedsBuild() called during build.
The widget which was currently being built [...] was: SplashView
```

Ini bukan bug yang saya perkenalkan ke kode yang benar; ini **asumsi terpendam
yang saya langgar**. Method itu sudah bergantung pada "selalu ada await sebelum
navigasi" tanpa satu pun yang menuliskannya.

Diperbaiki dengan memindahkan pemanggilan ke `onReady()`, yang GetX jalankan dari
post-frame callback. Yang dipilih **bukan** menambahkan `await` palsu di depan
pemeriksaan: itu memulihkan asumsinya, sedangkan `onReady` menghapusnya — tidak
ada jalur yang bisa bernavigasi di tengah build lagi, ditunggu atau tidak.

Dipatok dua test (`test/features/auth/splash_controller_test.dart`): `onInit`
tidak boleh mulai menyelesaikan tujuan, `onReady` harus. Keduanya memakai
`Completer` yang tidak pernah selesai, sehingga yang diuji adalah **kapan**
keputusan dimulai, bukan apa hasilnya.

### Yang ditemukan sambil jalan

- **`ServerConfig.originFor` sekarang mendelegasi ke `originOf`.** Perilakunya
  identik dan test lama tetap hijau; yang berubah, komposisi origin bisa dipakai
  tanpa menyentuh state tersimpan.
- **Workspace di-lowercase dan di-trim sebelum disimpan.** Ia label DNS: `ACME `
  adalah perusahaan yang sama dengan `acme`, dan menyimpan apa adanya akan
  menghasilkan host yang tidak resolve.
- **Body yang bukan JSON tidak menutupi status.** Alamat yang salah sering
  menjawab dengan HTML milik orang lain; membiarkannya melempar akan melaporkan
  "format tidak sesuai" untuk apa yang sebenarnya 404.

### Yang ditutup

| ID | Isi |
|---|---|
| **CLI-01** | Layar setup workspace tidak ada (ADR-0005 §4) |
| **R-22** | Satu APK belum benar-benar melayani banyak tenant |

### Yang tetap terbuka setelah ini

Tidak ada yang berubah pada M-D1, G-2, G-3, R-01, R-02, atau Fase 7. Fase 10b–10d
tetap menunggu ADR-0007 berstatus *Accepted*.

Satu catatan yang layak dibaca bersama: layar setup menerima alamat `http://` dan
mengatakannya tidak terenkripsi — tetapi selama bypass TLS global masih terpasang
(R-02), peringatan itu adalah satu-satunya perlindungan yang ada.

---

# Perbaikan build — CLI-02, 2026-09-01

Ditemukan saat menjalankan aplikasi ke perangkat: `assembleDebug` gagal dengan
*"Missing 'storeFile' in key.properties for release signing"*.

Penyebabnya bukan konfigurasi yang hilang, melainkan **kapan** ia diperiksa.
`signingConfigs {}` dievaluasi pada fase konfigurasi Gradle — yang berjalan untuk
setiap task — jadi `error(...)` di dalamnya menggagalkan build debug juga.
`key.properties` memang tidak ada di repositori dan tidak boleh ada: ia menyebut
keystore dan membawa kata sandinya.

| Sebelum | Sesudah |
|---|---|
| `create("release")` selalu dibuat, `error()` bila nilainya kosong | Dibuat **hanya** bila kredensialnya lengkap |
| Gagal pada setiap perintah Gradle | Gagal pada `assembleRelease`/`bundleRelease` saja, lewat `doFirst` |
| Pesan tentang rilis kepada orang yang menekan Run | Pesan menyebut berkas dan kunci mana yang kurang, dan bahwa debug tidak memerlukannya |

Sifat yang dijaga tidak berubah: **rilis tanpa tanda tangan tetap mustahil.**
Yang berubah, build debug tidak lagi membayarnya.

Ditambahkan `android/key.properties.example` — berkas contoh yang boleh
di-commit, supaya jalur rilis terdokumentasi tanpa satu pun rahasia ikut masuk.

Ini **tidak** menyentuh CRIT-01/R-01: `esas-keystore.jks` masih terlacak di
repositori dan masih ada di riwayat Git, dan pertanyaan Play App Signing masih
belum dijawab.

## Kegagalan kedua: SDK platform 31 — CLI-03

Setelah signing beres, `assembleDebug` meminta `platforms;android-31` dan gagal
memasangnya. Penyebabnya satu paket transitif:

```text
introduction_screen 3.1.17
└── flutter_keyboard_visibility 6.0.0
    └── android/build.gradle: compileSdkVersion 31
```

Seluruh plugin lain memakai 34, 35, atau mengikuti `flutter.compileSdkVersion`.
Jadi **satu** paket memaksa setiap mesin — termasuk CI — menyimpan platform SDK
yang jauh lebih tua daripada yang dipakai proyek.

**Diperbaiki dengan menaikkan `introduction_screen` ke `^4.0.0`**, yang di hulu
sudah berpindah ke `flutter_keyboard_visibility_temp_fork 0.1.5`
(compileSdk 34 — sudah terpasang). Dua paket hilang dari pohon dependensi,
lantai compileSdk naik dari 31 ke 34, dan android-31 tidak diminta siapa pun lagi.

**Yang sengaja tidak dipilih:** override `compileSdk` untuk seluruh subproject di
`android/build.gradle.kts`. Itu cara yang lazim dan akan bekerja, tetapi ia
memperbaiki gejala sambil menyembunyikan plugin mana pun yang tertinggal —
termasuk yang berikutnya. Setelah paket bermasalahnya hilang, override itu tidak
punya alasan untuk ada.

**Kompatibilitas diperiksa, bukan diasumsikan.** Breaking change 4.0.0 hanya
menyentuh `overrideDone`, `overrideNext`, `overrideSkip`, `overrideBack`;
`SplashView` memakai `globalFooter` dan `pages`, tidak satu pun dari keempatnya.

Ini **melanggar aturan §29** rencana refactor ("upgrade versi tidak dicampur
dengan refactor struktural"), dan disengaja: ini perbaikan build tersendiri,
bukan campuran. Dicatat di sini supaya pelanggarannya terlihat, bukan tersamar.

### Verifikasi

```
flutter analyze                 → 0 issue
flutter test                    → 197 lulus
flutter build apk --debug       → ✓ Built build/app/outputs/flutter-apk/app-debug.apk
```

Log build tidak menyebut android-31 sama sekali.

### Catatan untuk M-D5

`introduction_screen` hanya dipakai layar onboarding yang gerbangnya tidak pernah
dibaca (LOW-02). Bila M-D5 memutuskan onboarding dibuang, dependensi ini dan
seluruh rantai `flutter_keyboard_visibility_*` ikut hilang — perbaikan di atas
tidak menghalangi keputusan itu, hanya membuat proyek dapat dibangun sementara
keputusannya belum diambil.

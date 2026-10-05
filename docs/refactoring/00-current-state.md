# 00 — Current State (Baseline)

> **Dokumen ini dibekukan pada Fase 0 dan tetap dibekukan.** Ia adalah *baseline*,
> bukan potret keadaan sekarang: gunanya justru sebagai pembanding tetap. Keadaan
> per 2026-09-01 ada di **§16** di akhir berkas ini, dan rinciannya di
> `05-progress.md`.

> Captured before any refactoring. Every number here is a measured baseline, not an estimate.
> Any regression introduced by refactoring must be judged against this file.

**Date captured:** 2026-08-31
**Branch:** `main` @ `d1745fd`
**Repository:** https://github.com/chocoalano/esas-flutter (public remote)

---

## 1. Toolchain

```
Flutter 3.35.5 • channel stable • revision ac4e799d23 (2025-09-26)
Engine  • hash 0274ead41f6265309f36e9d74bc8c559becd5345
Tools   • Dart 3.9.2 • DevTools 2.48.0
Dart SDK version: 3.9.2 (stable) on "macos_arm64"
```

`pubspec.yaml` declares `environment: sdk: ^3.8.1`. Toolchain satisfies it.

---

## 2. Baseline command results

### `flutter pub get`
Exit code **0**. Resolves cleanly, no version conflicts.

### `flutter analyze`
Exit code **0** — **4 issues, all `info` severity, all the same deprecation:**

```
info • 'desiredAccuracy' is deprecated • attendance_controller.dart:119:9 • deprecated_member_use
info • 'timeLimit'       is deprecated • attendance_controller.dart:120:9 • deprecated_member_use
info • 'desiredAccuracy' is deprecated • attendance_controller.dart:228:11 • deprecated_member_use
info • 'timeLimit'       is deprecated • attendance_controller.dart:229:11 • deprecated_member_use

4 issues found. (ran in 2.1s)
```

Cause: `geolocator` 14.x deprecated the positional accuracy/timeout arguments on
`Geolocator.getCurrentPosition()` in favour of a `LocationSettings` object.
**This is a pre-existing condition. It must not be "fixed" by suppressing the lint.**

> Note: a clean `flutter analyze` here is *not* evidence of a healthy codebase. The
> analyzer is running the default `flutter_lints` set with zero project rules added.
> See `01-architecture-audit.md` §Lint for what the current configuration cannot see.

### `flutter test`
Exit code **1** — **1 test, 1 failure.**

```
00:03 +0 -1: Counter increments smoke test [E]
  Expected: exactly one matching candidate
    Actual: _TextWidgetFinder:<Found 0 widgets with text "0": []>
  test/widget_test.dart:17
```

`test/widget_test.dart` is the **unmodified Flutter counter-app starter test**. It
references a counter UI that has never existed in ESAS. It has been failing since
the first commit. This is the entire test suite.

**Effective test coverage of ESAS business logic: 0%.**

### `dart format --output=none --set-exit-if-changed .`
Exit code **1** — **13 of 118 files are not formatted:**

```
lib/app/modules/attendance/bindings/attendance_binding.dart
lib/app/modules/attendance/list/bindings/attendance_list_binding.dart
lib/app/modules/home/bindings/home_binding.dart
lib/app/modules/notification/bindings/notification_binding.dart
lib/app/modules/permit/bindings/permit_binding.dart
lib/app/modules/profile/bindings/profile_binding.dart
lib/app/modules/profile/bug_report/bindings/profile_bug_report_binding.dart
lib/app/modules/profile/education/bindings/profile_education_binding.dart
lib/app/modules/profile/family/bindings/profile_family_binding.dart
lib/app/modules/profile/payroll/bindings/profile_payroll_binding.dart
lib/app/modules/profile/personal/bindings/profile_personal_binding.dart
lib/app/modules/profile/worked/bindings/profile_worked_binding.dart
lib/generated/assets.dart
```

All are trivial line-wrapping differences (get_cli-generated files). No semantic impact.

---

## 3. Codebase size

| Metric | Count |
|---|---|
| Dart files in `lib/` | 117 |
| Lines of Dart in `lib/` | 14,504 |
| GetX controllers | 24 |
| GetX bindings | 21 |
| View files | 33 |
| Data model files | 22 |
| Registered `GetPage` routes | 22 (13 in `app_pages.dart` + 9 in `profile_pages.dart`) |
| Tests | 1 (failing, irrelevant) |

### Largest files

| Lines | File |
|---:|---|
| 769 | `lib/app/modules/permit/views/permit_show.dart` |
| 444 | `lib/app/modules/permit/views/permit_create.dart` |
| 442 | `lib/app/modules/profile/views/profile_view.dart` |
| 397 | `lib/app/modules/profile/bug_report/views/profile_bug_report_view.dart` |
| 396 | `lib/app/modules/attendance/views/attendance_view.dart` |
| 376 | `lib/app/modules/attendance/list/views/bottomsheet_detail_view.dart` |
| 340 | `lib/app/data/Permit/leave_list.m.dart` |
| 338 | `lib/app/modules/profile/education/views/profile_education_view.dart` |
| 335 | `lib/app/modules/profile/personal/views/profile_personal_view.dart` |
| 334 | `lib/app/modules/attendance/controllers/attendance_controller.dart` |

---

## 4. Actual directory structure

```
lib/
├── main.dart                      # 160 lines: bootstrap + DI + 2 dialogs + MyApp widget
├── generated/
│   └── assets.dart                # get_cli generated, 7 lines, ZERO references
├── utils/
│   ├── api_constants.dart         # baseApiUrl, baseImageUrl (+3 commented-out URLs)
│   ├── app_theme.dart             # 287 lines, light + dark ThemeData
│   ├── helper.dart                # date fmt + imageUrl + showApiError + InputDecoration + buildAvatar
│   ├── my_http_overrides.dart     # global badCertificateCallback => true
│   └── notification/
│       ├── firebase_messaging_services.dart
│       ├── firebase_services.dart          # DefaultFirebaseOptions — ZERO references
│       └── notification_services.dart
└── app/
    ├── data/                      # models, INCONSISTENTLY CAPITALISED
    │   ├── Notification/          # PascalCase
    │   ├── Permit/                # PascalCase
    │   ├── Profile/               # PascalCase
    │   ├── activity/              # snake_case
    │   ├── announcement/          # snake_case
    │   └── attendance/            # snake_case
    ├── modules/                   # feature UI + controllers + bindings
    │   ├── attendance/  (+ nested list/)
    │   ├── home/        (+ nested activity/, announcement/)
    │   ├── login/
    │   ├── notification/
    │   ├── permit/
    │   ├── profile/     (+ 8 nested sub-modules, owns its own routes)
    │   └── splash/
    ├── routes/
    │   ├── app_pages.dart
    │   └── app_routes.dart        # `part of` app_pages.dart
    ├── services/
    │   ├── api_provider.dart          # GetConnect, internal API
    │   └── api_external_provider.dart # GetConnect, external API
    └── widgets/
        ├── controllers/
        │   ├── bottom_nav_controller.dart
        │   ├── storage_keys.dart      # NOT a controller
        │   └── theme_controller.dart
        └── views/
            ├── custom_bottom_navbar.dart
            └── snackbar.dart          # NOT a view — 4 global functions
```

**Structural observation:** a single business feature is split across three unrelated
roots. Attendance lives in `app/data/attendance/`, `app/modules/attendance/`, and
partly in `utils/`. See `01-architecture-audit.md` §Feature ownership.

---

## 5. Feature inventory

| Feature | Routes | Controllers | Notes |
|---|---|---|---|
| Splash / session restore | `/splash` | `SplashController` | Also owns onboarding (`IntroductionScreen`) |
| Auth | `/login` | `LoginController` | |
| Home | `/home` | `HomeController` | Dashboard: attendance summary, schedule, announcements, activity |
| Home → Announcement | `/home/announcement`, `/home/announcement/detail` | `AnnouncementController`, `AnnouncementDetailController` | |
| Home → Activity | `/home/activity` | `ActivityController` | |
| Attendance | `/attendance` | `AttendanceController` | QR scan + geofence + mock-GPS check |
| Attendance → List | `/attendance/list` | `AttendanceListController` | + bottom-sheet detail |
| Permit | `/permit` | `PermitController` | Permit type picker |
| Permit → List | `/permit/list` | `PermitListController` | |
| Permit → Show | `/permit/show` | `PermitShowController` | Includes approval action |
| Permit → Create | `/permit/create` | `PermitCreateController` | **Bound to the WRONG binding — see audit HIGH-01** |
| Notification | `/notification` | `NotificationController` | Paginated list, mark-as-read |
| Profile | `/profile` | `ProfileController` | + avatar upload + logout |
| Profile sub-pages | `/profile/{personal,worked,family,education,experience,payroll,change-password,bug-report}` | 8 controllers | |

**Declared but never registered:** `Routes.INTRODUCTION` (`/introduction`) has a
constant and a path but no `GetPage`. Navigating to it would 404.

---

## 6. API inventory

Base URLs (`lib/utils/api_constants.dart`):

```dart
const String baseApiUrl   = 'https://:9443/api';
const String baseImageUrl = 'https://sas-assets.sgp1.cdn.digitaloceanspaces.com';
```

Plus three commented-out alternates (production, office wifi, phone hotspot) — the
environment is switched by editing source and recompiling.

| Endpoint | Method | Called from |
|---|---|---|
| `/general-module/auth/login` | POST | `login_controller.dart:170` |
| `/general-module/auth` | GET | `splash_controller.dart:106`, `profile_controller.dart:113`, and 5 profile sub-controllers |
| `/general-module/auth` | POST (multipart) | `profile_controller.dart:113` (avatar upload) |
| `/general-module/auth/logout` | GET | `profile_controller.dart:144` |
| `/general-module/auth/change-password` | POST | `profile_change_password_controller.dart:127` |
| `/general-module/auth/set-token` | POST | `firebase_messaging_services.dart:161` (FCM token sync) |
| `/general-module/auth/summary-absen` | GET | `profile_controller.dart:69` |
| `/general-module/auth/current-attendance/{id}` | GET | `home_controller.dart:95` |
| `/general-module/auth/schedule` | GET | `home_controller.dart:102` |
| `/general-module/auth/activity` | GET | `home_controller.dart:116`, `activity_controller.dart:73` |
| `/general-module/announcements` | GET | `announcement_controller.dart:75` |
| `/general-module/announcements/active` | GET | `home_controller.dart:109` |
| `/general-module/announcements/{id}` | GET | `announcement_detail_controller.dart:32` |
| `/general-module/notifications` | GET | `notification_controller.dart:53` |
| `/general-module/notifications/{id}` | (mark read) | `notification_controller.dart:131` |
| `/general-module/bug-reports` | POST | `profile_bug_report_controller.dart:166` |
| `/hris-module/user-attendances` | GET | `attendance_list_controller.dart:105` |
| `/hris-module/permit-types/list` | GET | `permit_controller.dart:29` |
| `/hris-module/permits/list/{typeId}` | GET | `permit_list_controller.dart:111` |
| `/hris-module/permits/create` | GET | `permit_create_controller.dart:113` (form bootstrap) |
| `/hris-module/permits` | POST (multipart) | `permit_create_controller.dart:203` |
| `/hris-module/permits/{id}` | GET | `permit_show_controller.dart:82` |
| `/hris-module/permits/{id}/approval` | POST | `permit_show_controller.dart:151` |
| `http://128.199.111.239:3000/attmachine/qr-presence` | POST | `attendance_controller.dart:279-281` — **hardcoded, cleartext, raw IP** |

**Every one of these 24 endpoint strings is embedded directly in a controller.**
There is no API-service layer and no repository layer.

---

## 7. Local persistence inventory

Backed entirely by `GetStorage` (unencrypted JSON on the app-private filesystem).

`lib/app/widgets/controllers/storage_keys.dart`:

| Key constant | Stored value | Written by |
|---|---|---|
| `token` → `auth_token` | Bearer token | `LoginController` |
| `tokenType` → `auth_token_type` | `'Bearer'` | `LoginController` |
| `userName` → `auth_user_name` | Display name | `LoginController`, `SplashController` |
| `userId` → `auth_user_id` | User id | `LoginController`, `SplashController` |
| `userNip` → `auth_user_nip` | Employee number | `LoginController` |
| **`userPassword` → `auth_user_password`** | **Plaintext password** | `LoginController`, `ProfileChangePasswordController` |
| `userAvatar` → `auth_user_avatar` | Avatar path | `LoginController`, `ProfileController` |
| `userJson` → `auth_user_json` | **Full user object** (company, employee, dept, salary-adjacent PII) | `LoginController`, `SplashController`, `ProfileController` |
| `onboardingCompleted` | bool | `SplashController` |
| `isDarkMode` (**not in `StorageKeys`** — hardcoded in `ThemeController`) | bool | `ThemeController` |

**`GetStorage()` is instantiated directly in 12 files**, including 10 controllers.
There is no storage abstraction, so none of these controllers are unit-testable
without the native `path_provider` plugin.

---

## 8. Authentication lifecycle (as built)

```
main() → GetStorage.init() → Get.put(ApiProvider, permanent)
   ↓
SplashController.onInit()
   ↓
autoLogin(): requires nip AND password AND token all non-empty in GetStorage
   ↓
_validateTokenOnBackend(): GET /general-module/auth
   ├─ 200 + body.user → rewrite userName/userId/userJson → /home
   └─ anything else, INCLUDING ANY THROWN EXCEPTION (catch (_) {}) → clearStorage() → /login
```

Token injection: `ApiProvider.onInit()` installs a request modifier that reads
`StorageKeys.token` from a **private `GetStorage` instance** and sets
`Authorization: Bearer <token>` — but only when the URL is relative or its host
matches `baseApiUrl`'s host.

**Logout is implemented three times, with three different key sets:**

| Implementation | Clears |
|---|---|
| `LoginController.clearStorage()` | token, tokenType, userName, userId, userNip, userPassword, userJson, userAvatar |
| `ProfileController.clearStorage()` | token, tokenType, userName, userId, userNip, userPassword, userJson, userAvatar |
| `SplashController.clearStorage()` | token, tokenType, userName, userId, userNip, userPassword — **omits `userJson` and `userAvatar`** |

There is **no central 401 handler**. Each controller maps `401` to its own message
string; none of them terminate the session.

---

## 9. Firebase & notification lifecycle

- `Firebase.initializeApp()` is called in `main()` **without options**, inside a
  `try/catch` that only `debugPrint`s the failure. Config comes from the native
  `google-services.json` / `GoogleService-Info.plist`.
- `lib/utils/notification/firebase_services.dart` defines `DefaultFirebaseOptions`
  with five platform configs spanning **three different Firebase projects**
  (`esasa-app`, `esas-44d5d`, `esas-7d76f`) and a bundle id (`com.sas.esasFlutter`)
  that matches neither platform project. **It has zero references — it is dead code.**
- Native config is internally consistent: both `google-services.json` and
  `GoogleService-Info.plist` are project `esas-44d5d`, package/bundle `com.example.esas`.
- `NotificationService` (local notifications) is `Get.put(permanent)` then `await initialize()`.
- `FirebaseMessagingService` is `Get.put(permanent)`; its `onInit` requests permission,
  fetches the FCM token, `POST`s it to `/general-module/auth/set-token`, and registers
  foreground / background / opened-app listeners.
- `_firebaseMessagingBackgroundHandler` is a top-level `@pragma('vm:entry-point')`
  function that calls `Firebase.initializeApp()` then `NotificationService().showNotification(...)`
  on a **freshly constructed, never-initialised** service.
- Notification tap always routes to `Routes.NOTIFICATION`; the FCM `data` payload is
  passed as arguments but the local-notification path hardcodes `payload: 'Default_Payload'`.

---

## 10. Native platform integrations

| Capability | Package | Used in |
|---|---|---|
| QR scanning | `mobile_scanner` | `AttendanceController`, `attendance_view` |
| Geolocation + mock detection | `geolocator` | `AttendanceController` |
| Runtime permissions | `permission_handler` | `AttendanceController`, `NotificationService` |
| Device id | `device_info_plus` | `LoginController` |
| Image picking | `image_picker` | `ProfileController`, `profile_personal_view` |
| File picking | `file_picker` | `PermitCreateController` |
| URL launching | `url_launcher` | `permit_show`, +2 |
| Push | `firebase_core`, `firebase_messaging` | `utils/notification/` |
| Local notifications | `flutter_local_notifications` | `NotificationService` |
| HTML rendering | `flutter_html` | announcement views |
| SVG | `flutter_svg` | `splash_view` |

**Every one of these is called directly from a controller or a view.** There is no
`PermissionService`, `LocationService`, or `FilePickerService` abstraction.

---

## 11. Android / iOS configuration

| Item | Value | Note |
|---|---|---|
| Android `applicationId` | `com.example.esas` | **Placeholder id shipped to production** |
| Android `namespace` | `com.example.esas` | |
| iOS `PRODUCT_BUNDLE_IDENTIFIER` | `com.example.esas` | **Placeholder id shipped to production** |
| Android release signing | reads `android/key.properties` | File is absent from disk and absent from git history — **good** |
| `esas-keystore.jks` | at repo root | **TRACKED IN GIT — see security audit** |
| `android:label` | `esas` | |
| iOS `NSAppTransportSecurity` | not present | |
| Firebase project | `esas-44d5d` (both platforms) | |
| Min SDK / target SDK | Flutter defaults | |
| R8 / shrinkResources | enabled for release | |

---

## 12. Dependency inventory

| Package | Files importing it | Verdict |
|---|---|---|
| `get` | 80 | Core |
| `intl` | 15 | Core |
| `get_storage` | 13 | Core |
| `firebase_core` | 3 | Core |
| `url_launcher` | 3 | Used |
| `flutter_html` | 2 | Used |
| `geolocator` | 2 | Used |
| `image_picker` | 2 | Used |
| `introduction_screen` | 2 | Used |
| `mobile_scanner` | 2 | Used |
| `permission_handler` | 2 | Used |
| `device_info_plus` | 1 | Used |
| `file_picker` | 1 | Used |
| `firebase_messaging` | 1 | Used |
| `flutter_local_notifications` | 1 | Used |
| `flutter_svg` | 1 | Used |
| `cupertino_icons` | 0 | Asset-only font; conventional to keep |
| **`flutter_launcher_icons`** | 0 | **Build-time tool declared as a runtime `dependency`** |

Dev dependencies: `flutter_test`, `flutter_lints ^5.0.0`. No mocking library, no
`build_runner`.

### Assets

Declared in `pubspec.yaml`: `assets/images/`, `assets/svg/`.

| On disk | Referenced in code? |
|---|---|
| `assets/images/logo-removebg.png` | Yes |
| `assets/svg/onboarding_1.svg` | Yes |
| `assets/svg/onboarding_2.svg` | Yes |
| `assets/svg/onboarding_3.svg` | Yes |
| `assets/icon/icon.png` | Not a Flutter asset — consumed by `flutter_launcher_icons.yaml` at build time. Correctly undeclared. |

No orphaned assets. `lib/generated/assets.dart` exposes `Assets.imagesLogoRemovebg`
but **nothing imports it** — the codebase uses raw string paths instead.

---

## 13. Existing tests

```
test/
└── widget_test.dart    # Flutter starter counter test. Fails. Tests nothing in ESAS.
```

No `test/helpers/`, no `test/fixtures/`, no `integration_test/`, no mocks.

---

## 14. Lint configuration

`analysis_options.yaml` is the **unmodified Flutter template**: it includes
`package:flutter_lints/flutter.yaml` and adds an empty `rules:` block containing
only commented-out examples. No `analyzer:` section, no `errors:` overrides, no
`exclude:`, no language strictness settings.

Existing suppressions (5, all narrow and defensible except where noted):

| File | Suppression | Assessment |
|---|---|---|
| `app/routes/app_pages.dart` | `constant_identifier_names` | get_cli generated style; acceptable for now |
| `app/routes/app_routes.dart` | `constant_identifier_names` | same |
| `app/modules/profile/profile_routes.dart` | `constant_identifier_names` | same |
| `app/modules/permit/views/permit_show.dart` | `unnecessary_to_list_in_spreads` | Cosmetic; should be fixed rather than suppressed |
| `app/modules/permit/controllers/permit_create_controller.dart` | `use_build_context_synchronously` | **Hides a real async-gap bug class. Must be investigated, not carried forward.** |

---

## 15. Baseline acceptance criteria for the refactor

The refactor is only allowed to *improve* on these. Concretely:

| Gate | Baseline | Required after each phase |
|---|---|---|
| `flutter analyze` | 4 info (geolocator deprecation) | ≤ 4 info, **0 new** warnings/errors |
| `flutter test` | 1 test, 1 failing | Increasing pass count, **0 failing** |
| `dart format --set-exit-if-changed` | 13 files dirty | **0 files dirty** |
| Runtime behaviour | see feature inventory §5 | Byte-identical API payloads and endpoints |

---

## 16. Status per 2026-09-01 — baseline vs sekarang

> Ditambahkan setelah Fase 0–6 selesai. Bagian §1–§15 di atas **tidak diubah**:
> nilainya justru pada tetap menjadi angka pembanding.

| Ukuran | Baseline (2026-08-31) | Sekarang (2026-09-01) |
|---|---|---|
| `flutter analyze` | 4 info | **0 issue** |
| `flutter test` | 1 test, **1 gagal** | **171 test, 0 gagal** (18 berkas test) |
| `dart format --set-exit-if-changed` | 13 berkas kotor | **0** |
| Berkas Dart di `lib/` | 117 | 144 |
| View | 33 | 22 |
| Controller | 24 | 17 |
| Berkas yang mengimpor `get` | 80 dari 117 | masih substrat; wiring terkurung di binding |
| Route | 22 | 22 (**path identik**, dipatok test) |
| `ignore_for_file` di `lib/` | 3 | **0** |
| Cara `ApiProvider` didaftarkan | 4 | kelasnya **dihapus**; `ApiClient` didaftarkan sekali |
| Penyimpanan token | `GetStorage` (JSON polos) | Keychain / EncryptedSharedPreferences |
| Password plaintext tersimpan | ya | **tidak** — dan dihapus dari instalasi lama saat upgrade |
| Konsep tenant | tidak ada | `ServerConfig` + `TenantContext` + `X-Tenant` |
| Endpoint di controller | 24 | 0 — seluruhnya di `core/config/api_routes.dart` |

**Yang belum berubah sejak baseline, dan disengaja:**

- **Validasi TLS masih mati** (`MyHttpOverrides.install()` di `bootstrap.dart`).
  Penggantinya sudah ditulis dan diuji tetapi belum dipasang — R-02/CRIT-02.
- **Keystore dan `com.example.esas`** masih apa adanya — CRIT-01/HIGH-08, menunggu
  keputusan owner.
- **Backend masih backend lama.** Aplikasi belum berbicara ke `tenancy-app`;
  pemindahannya menunggu ADR-0007 dan 18 endpoint. Lihat `06-api-migration-map.md`.

**Kriteria penerimaan §15 di atas: terpenuhi** untuk analyze, test, format, dan
"tidak ada perubahan perilaku yang tidak disengaja" — perubahan perilaku yang
memang disengaja (perbaikan bug) tercatat satu per satu di `05-progress.md`.

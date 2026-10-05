# 03 — Migration Map

> **Status: dieksekusi penuh (Fase 2–6, selesai 2026-09-01).** Seluruh 117 berkas
> sudah berada di tujuannya; `lib/app/` kini tiga berkas dan `lib/utils/` hanya
> menyisakan `my_http_overrides.dart` (menunggu R-02) serta `notification/`
> (Fase 7). Peta ini disimpan sebagai catatan pemindahan, bukan sebagai rencana
> yang masih berjalan — verifikasi akhirnya di bagian **Hasil eksekusi** di akhir
> berkas.

> Every file in `lib/` (117 files) with its target location. Produced **before** any
> move, per rule §41. No duplicate implementation may outlive the phase that moves it.

**Legend**

| Mark | Meaning |
|---|---|
| → | Move (content preserved; imports rewritten) |
| ⇒ | Move **and** refactor (content changes — cites the finding) |
| ✂ | Split into multiple files |
| ✖ | Delete (see `dead-code-candidates.md`) |
| ✚ | New file, no predecessor |
| = | Stays where it is |

---

## 1. Entry point & app shell — Phase 2

| | OLD | NEW |
|---|---|---|
| ⇒ | `lib/main.dart` (160 lines) | ✂ into the four rows below |
| ✚ | — | `lib/main.dart` (~8 lines: `ensureInitialized` → `bootstrap()` → `runApp`) |
| ✚ | — | `lib/bootstrap.dart` (ordered boot pipeline, P2-2 failure policy) |
| ⇒ | `main.dart` → `class MyApp` | `lib/app/app.dart` → `class EsasApp` |
| ⇒ | `main.dart` → `_setSystemUIOverlayStyle()` | `lib/core/theme/system_ui_style.dart` |
| ✖ | `main.dart:69` `showInAppNotification()` | deleted — 0 references (LOW-06) |
| ✖ | `main.dart:89` `showCustomExplainerDialog()` | deleted — 0 references (LOW-06) |
| ⇒ | `main.dart:52-59` `Get.put(...)` × 6 | `lib/app/bindings/initial_binding.dart` (HIGH-07) |

---

## 2. Routing — Phase 6

| | OLD | NEW |
|---|---|---|
| → | `lib/app/routes/app_pages.dart` | `lib/app/routing/app_pages.dart` (aggregator only) |
| → | `lib/app/routes/app_routes.dart` | `lib/app/routing/app_routes.dart` |
| ⇒ | `lib/app/modules/profile/profile_pages.dart` | `lib/features/profile/presentation/routes/profile_pages.dart` |
| ⇒ | `lib/app/modules/profile/profile_routes.dart` | `lib/features/profile/presentation/routes/profile_routes.dart` |
| ✚ | — | `features/<f>/presentation/routes/<f>_routes.dart` — path constants, **no imports** |
| ✚ | — | `features/<f>/presentation/routes/<f>_pages.dart` — `GetPage` list |
| ✖ | `lib/app/routes/app_routes.dart` | **deleted** — no central `Routes` class; a path is named by its owner |

**Amended in Phase 6.** The plan above put the pages and the path constants in one
`<f>_routes.dart`. They are two files instead, because the names must stay a leaf:
a view that only wants to spell `/home` would otherwise import every home view
transitively, and the central `Routes` ↔ views relationship would be an import
cycle. `ProfileRoutes` already worked this way; every feature now does.

`AppPages.routes` becomes:
```dart
static final routes = [
  ...AuthRoutes.pages, ...HomeRoutes.pages, ...AttendanceRoutes.pages,
  ...PermitRoutes.pages, ...NotificationRoutes.pages, ...ProfileRoutes.pages,
];
```

**Route path strings must not change** (P6-6). Only the Dart constant names change.

---

## 3. Network — Phase 1

| | OLD | NEW |
|---|---|---|
| ⇒ | `lib/app/services/api_provider.dart` (227) | ✂ into the four rows below (MED-02) |
| ✚ | — | `lib/core/network/api_client.dart` — HTTP mechanics only |
| ✚ | — | `lib/core/network/auth_interceptor.dart` — token injection; explicit flag replaces `X-Bypass-Auth` |
| ✚ | — | `lib/core/network/api_exception.dart` — typed exceptions |
| ✚ | — | `lib/core/network/api_error_mapper.dart` — one status→exception map (MED-07) |
| ✚ | — | `lib/core/network/api_response.dart` |
| ✚ | — | `lib/core/network/network_constants.dart` — timeouts, headers |
| ⇒ | `lib/app/services/api_external_provider.dart` (257) | folded into `ApiClient` as an unauthenticated mode |
| ✖ | `ApiProvider.externalGet/externalPost/externalPostFormData` | deleted — 0 references |
| ⇒ | `lib/utils/my_http_overrides.dart` | `lib/core/network/dev_http_overrides.dart` — dev-only, `assert`-guarded, host-scoped (CRIT-02) |
| ⇒ | `lib/utils/api_constants.dart` | `lib/core/config/api_endpoints.dart` + `app_config.dart` (MED-10) |
| ✚ | — | `lib/core/config/app_config.dart` — `AppEnvironment`, `--dart-define` |

---

## 4. Storage — Phase 1

| | OLD | NEW |
|---|---|---|
| → | `lib/app/widgets/controllers/storage_keys.dart` | `lib/core/storage/storage_keys.dart` (LOW-01) |
| ✚ | — | `lib/core/storage/local_storage.dart` — interface + `GetStorage` impl |
| ✚ | — | `lib/core/storage/token_storage.dart` — interface (secure impl staged, MED-06) |
| ✖ | `StorageKeys.userPassword` | removed in P3-7 (CRIT-03) |

The 12 files that construct `GetStorage()` directly all switch to injected
`LocalStorage` / `TokenStorage`. This is what makes controllers unit-testable.

---

## 5. Theme & shared UI — Phase 1 / 6

| | OLD | NEW |
|---|---|---|
| → | `lib/utils/app_theme.dart` | `lib/core/theme/app_theme.dart` |
| ⇒ | `lib/app/widgets/controllers/theme_controller.dart` | `lib/core/theme/theme_controller.dart` — snackbar removed (MED-03) |
| ⇒ | `lib/app/widgets/views/snackbar.dart` | `lib/core/ui/dialogs/app_snackbar.dart` (LOW-01) |
| → | `lib/app/widgets/views/custom_bottom_navbar.dart` | `lib/core/ui/components/custom_bottom_navbar.dart` |
| → | `lib/app/widgets/controllers/bottom_nav_controller.dart` | `lib/core/ui/controllers/bottom_nav_controller.dart` |
| ⇒ | `lib/utils/helper.dart` (159) | ✂ into the four rows below |
| ⇒ | `helper.dart` → `formatDateIndo`, `formatFullDateIndo` | `lib/core/utils/date_formatter.dart` — `DateFormatter.dayMonthYear` / `.fullDate` |
| ⇒ | `helper.dart` → `limitString` | `lib/core/utils/string_utils.dart` |
| ⇒ | `helper.dart` → `imageUrl()` | `lib/core/config/asset_url.dart` — `assetUrl()`, reading `Env.assetBaseUrl` |
| ✖ | `lib/utils/api_constants.dart` | **deleted** — both constants superseded by `Env` |
| ⇒ | `helper.dart` → `inputDecoration()` | `lib/core/ui/components/app_input_decoration.dart` |
| ⇒ | `helper.dart` → `buildAvatar()`, `_initials()` | `lib/core/ui/components/app_avatar.dart` — an `AppAvatar` widget |
| ✖ | `helper.dart` → `showApiError()` | **deleted** in Phase 6 — zero callers once `ApiErrorMapper` landed (MED-07) |
| ✚ | — | `lib/core/utils/app_logger.dart` (CRIT-05) |
| ✚ | — | `lib/core/utils/json_parsers.dart` (MED-04) |

---

## 6. Platform services — Phase 7

| | OLD | NEW |
|---|---|---|
| → | `lib/utils/notification/notification_services.dart` | `lib/core/services/notifications/notification_service.dart` |
| ⇒ | `lib/utils/notification/firebase_messaging_services.dart` | `lib/core/services/notifications/firebase_messaging_service.dart` — iOS token fix (HIGH-03), background fix (HIGH-05), no snackbar (MED-03) |
| ✚ | — | `lib/core/services/notifications/notification_router.dart` — payload → intent (MED-03) |
| ✚ | — | `lib/core/services/notifications/notification_permission_service.dart` |
| ✖ | `lib/utils/notification/firebase_services.dart` | deleted or regenerated — 0 references, 3 mismatched projects (LOW-06) |
| ✚ | — | `lib/core/services/location_service.dart` — extracted from `AttendanceController` |
| ✚ | — | `lib/core/services/permission_service.dart` |
| ✚ | — | `lib/core/services/device_info_service.dart` — extracted from `LoginController._getDeviceId` |
| ✚ | — | `lib/core/services/file_picker_service.dart`, `image_picker_service.dart` |

---

## 7. Feature: auth — Phase 3

Login and splash merge: both serve one concern, the session.

| | OLD | NEW |
|---|---|---|
| ⇒ | `app/modules/login/controllers/login_controller.dart` | `features/auth/presentation/controllers/login_controller.dart` — no `GetStorage`, no endpoints, no password write (CRIT-03) |
| → | `app/modules/login/views/login_view.dart` | `features/auth/presentation/views/login_view.dart` |
| → | `app/modules/login/bindings/login_binding.dart` | `features/auth/presentation/bindings/login_binding.dart` |
| ⇒ | `app/modules/splash/controllers/splash_controller.dart` | `features/auth/presentation/controllers/splash_controller.dart` — 3-way restore (HIGH-02), no `catch (_) {}` |
| → | `app/modules/splash/views/splash_view.dart` | `features/auth/presentation/views/splash_view.dart` |
| → | `app/modules/splash/bindings/splash_binding.dart` | `features/auth/presentation/bindings/splash_binding.dart` |
| ✚ | — | `features/auth/data/services/auth_api_service.dart` |
| ✚ | — | `features/auth/data/repositories/auth_repository.dart` |
| ✚ | — | `features/auth/data/repositories/session_repository.dart` — single clear (MED-05), 401 authority (MED-07) |
| ✚ | — | `features/auth/data/models/{session.dart,auth_user.dart}` |
| ⇒ | `app/modules/profile/change_password/**` | `features/auth/presentation/{controllers,views,bindings}/change_password_*` — client-side check removed (CRIT-03) |

> **Placement note:** change-password is moved to `auth`, not `profile`. It is a
> credential operation and it is the second consumer of the plaintext password.
> Keeping it beside `SessionRepository` is what makes CRIT-03 fully closeable.
> Its **route path stays `/profile/change-password`** — navigation is unchanged.

---

## 8. Feature: attendance — Phase 4 (pilot)

| | OLD | NEW |
|---|---|---|
| ⇒ | `app/data/attendance/attendance.m.dart` | `features/attendance/data/models/attendance.dart` (MED-09) |
| ⇒ | `app/data/attendance/user.m.dart` | `features/attendance/data/models/attendance_user.dart` |
| ⇒ | `app/modules/attendance/controllers/attendance_controller.dart` | `features/attendance/presentation/controllers/attendance_controller.dart` — fail-open fix (CRIT-04), nav fix (MED-12), location extracted (P4-5) |
| ⇒ | `app/modules/attendance/views/attendance_view.dart` | `features/attendance/presentation/views/attendance_view.dart` — no `Get.put` (HIGH-06) |
| → | `app/modules/attendance/bindings/attendance_binding.dart` | `features/attendance/presentation/bindings/attendance_binding.dart` |
| ⇒ | `app/modules/attendance/list/controllers/attendance_list_controller.dart` | `features/attendance/presentation/controllers/attendance_list_controller.dart` |
| ⇒ | `app/modules/attendance/list/views/attendance_list_view.dart` | `features/attendance/presentation/views/attendance_list_view.dart` — no `Get.put` |
| → | `app/modules/attendance/list/views/bottomsheet_detail_view.dart` | `features/attendance/presentation/widgets/attendance_detail_sheet.dart` |
| → | `app/modules/attendance/list/bindings/attendance_list_binding.dart` | `features/attendance/presentation/bindings/attendance_list_binding.dart` |
| ✚ | — | `features/attendance/data/services/attendance_api_service.dart` |
| ✚ | — | `features/attendance/data/repositories/attendance_repository.dart` |
| ✚ | — | `features/attendance/presentation/widgets/{attendance_status_card,attendance_action_button,location_status,attendance_history_item}.dart` |

Note the nested `list/` sub-module is flattened: one feature, one presentation layer.

---

## 9. Feature: permit — Phase 5

| | OLD | NEW |
|---|---|---|
| ⇒ | `app/data/Permit/leave_list.m.dart` | `features/permit/data/models/leave_list.dart` (MED-09 — case rename) |
| ⇒ | `app/data/Permit/leave_type.m.dart` | `features/permit/data/models/leave_type.dart` |
| ⇒ | `app/data/Permit/permit_type.m.dart` | `features/permit/data/models/permit_type.dart` |
| ⇒ | `app/data/Permit/schedule.m.dart` | `features/permit/data/models/schedule.dart` |
| ⇒ | `app/data/Permit/timework.m.dart` | `features/permit/data/models/timework.dart` |
| ⇒ | `app/modules/permit/controllers/permit_controller.dart` | `features/permit/presentation/controllers/permit_controller.dart` |
| ⇒ | `app/modules/permit/controllers/permit_list_controller.dart` | `features/permit/presentation/controllers/permit_list_controller.dart` |
| ⇒ | `app/modules/permit/controllers/permit_show_controller.dart` | `features/permit/presentation/controllers/permit_show_controller.dart` |
| ⇒ | `app/modules/permit/controllers/permit_create_controller.dart` | `features/permit/presentation/controllers/permit_create_controller.dart` — suppression removed (MED-13), no `BuildContext` |
| ⇒ | `app/modules/permit/views/permit_view.dart` | `features/permit/presentation/views/permit_view.dart` — no `Get.put` |
| → | `app/modules/permit/views/permit_list_view.dart` | `features/permit/presentation/views/permit_list_view.dart` |
| ⇒ | `app/modules/permit/views/permit_show.dart` (769) | `features/permit/presentation/views/permit_show_view.dart` — no `Get.put`, split into widgets |
| → | `app/modules/permit/views/permit_create.dart` | `features/permit/presentation/views/permit_create_view.dart` |
| → | `app/modules/permit/views/widgets/permit_list_item.dart` | `features/permit/presentation/widgets/permit_list_item.dart` |
| → | `app/modules/permit/views/widgets/type_card_item.dart` | `features/permit/presentation/widgets/type_card_item.dart` |
| → | `app/modules/permit/bindings/permit_binding.dart` | `features/permit/presentation/bindings/permit_binding.dart` |
| ⇒ | `app/modules/permit/bindings/permit_list_binding.dart` | `features/permit/presentation/bindings/permit_list_binding.dart` — **`PermitCreateController` removed** (HIGH-01) |
| → | `app/modules/permit/bindings/permit_show_binding.dart` | `features/permit/presentation/bindings/permit_show_binding.dart` |
| ✚ | — | `features/permit/presentation/bindings/permit_create_binding.dart` (**HIGH-01**) |
| ✚ | — | `features/permit/data/services/permit_api_service.dart` |
| ✚ | — | `features/permit/data/repositories/permit_repository.dart` |

---

## 10. Feature: profile — Phase 5

| | OLD | NEW |
|---|---|---|
| ⇒ | `app/data/Profile/{address,approval,company,departement,detail,employe,family,foeducation,ineducation,salary,user,workexp}.m.dart` (12 files) | `features/profile/data/models/<same>.dart` (MED-09) |
| ⇒ | `app/modules/profile/controllers/profile_controller.dart` | `features/profile/presentation/controllers/profile_controller.dart` — logout message fixed, session cleared on failure (LOW-05) |
| ⇒ | `app/modules/profile/views/profile_view.dart` | `features/profile/presentation/views/profile_view.dart` — no `Get.put` |
| → | `app/modules/profile/bindings/profile_binding.dart` | `features/profile/presentation/bindings/profile_binding.dart` |
| → | `app/modules/profile/{personal,worked,family,education,experience,payroll,bug_report}/controllers/*.dart` (7) | `features/profile/presentation/controllers/<same>.dart` |
| → | …matching `views/*.dart` (7) | `features/profile/presentation/views/<same>.dart` |
| → | …matching `bindings/*.dart` (7) | `features/profile/presentation/bindings/<same>.dart` |
| ⇒ | `app/modules/profile/change_password/**` (3) | **→ `features/auth/`** — see §7 |
| ✚ | — | `features/profile/data/services/profile_api_service.dart` |
| ✚ | — | `features/profile/data/repositories/profile_repository.dart` |

The 5 sub-controllers that each independently `GET /general-module/auth`
(`personal`, `worked`, `family`, `education`, `experience`) collapse onto one shared
`ProfileRepository.getCurrentUser()` — removing 5 duplicate network calls.

---

## 11. Feature: home (+ activity, announcement) — Phase 5

| | OLD | NEW |
|---|---|---|
| ⇒ | `app/data/activity/log.m.dart` | `features/home/data/models/activity_log.dart` |
| ⇒ | `app/data/announcement/list.m.dart` | `features/home/data/models/announcement.dart` |
| ⇒ | `app/modules/home/controllers/attribute.m.dart` | `features/home/data/models/summary_card.dart` |
| ⇒ | `app/modules/home/controllers/home_controller.dart` | `features/home/presentation/controllers/home_controller.dart` — `$statusCode` fixed (LOW-04) |
| → | `app/modules/home/views/home_view.dart` | `features/home/presentation/views/home_view.dart` |
| → | `app/modules/home/views/widgets/{activity_tile,announcement_carousel,app_bar_content,recent_activity,summary_card,summary_grid}.dart` (6) | `features/home/presentation/widgets/<same>.dart` |
| → | `app/modules/home/bindings/home_binding.dart` | `features/home/presentation/bindings/home_binding.dart` |
| → | `app/modules/home/activity/{controllers,views,bindings}/*` | `features/home/presentation/{controllers,views,bindings}/activity_*` |
| ⇒ | `app/modules/home/announcement/{controllers,views,bindings}/*` | `features/home/presentation/{controllers,views,bindings}/announcement_*` |
| ✖ | `app/modules/home/announcement/bindings/announcement_detail_binding.dart` | merged — it is byte-identical to `announcement_binding.dart` |
| ✚ | — | `features/home/data/services/home_api_service.dart` |
| ✚ | — | `features/home/data/repositories/home_repository.dart` |

> `attribute.m.dart` currently sits in `controllers/` but is a pure model
> (`SummaryCard`). Renaming it to `summary_card.dart` under `data/models/` fixes both
> the location and the meaningless name.

---

## 12. Feature: notification — Phase 5

| | OLD | NEW |
|---|---|---|
| ⇒ | `app/data/Notification/notification.m.dart` | `features/notification/data/models/notification.dart` (MED-09) |
| ⇒ | `app/modules/notification/controllers/notification_controller.dart` | `features/notification/presentation/controllers/notification_controller.dart` — `ScrollController` disposed |
| ⇒ | `app/modules/notification/views/notification_view.dart` | `features/notification/presentation/views/notification_view.dart` — no `Get.put` |
| → | `app/modules/notification/bindings/notification_binding.dart` | `features/notification/presentation/bindings/notification_binding.dart` |
| ✚ | — | `features/notification/data/services/notification_api_service.dart` |
| ✚ | — | `features/notification/data/repositories/notification_repository.dart` |

---

## 13. Generated

| | OLD | NEW |
|---|---|---|
| ✖ | `lib/generated/assets.dart` | deleted — 0 references (LOW-06). Regenerate only if the project adopts `Assets.*` constants; document the command if so. |

---

## 14. Tests

| | OLD | NEW |
|---|---|---|
| ✖ | `test/widget_test.dart` | deleted — starter counter test, failing since the first commit |
| ✚ | — | `test/{core,features,helpers,fixtures}/…` mirroring `lib/` |
| ✚ | — | `integration_test/app_test.dart` |

---

## Folder case renames (MED-09)

These are **case-only** renames on a case-insensitive filesystem (macOS). Git will
not record them with a single `git mv`. Use the two-step form and verify:

```bash
git mv lib/app/data/Notification lib/app/data/notification_tmp
git mv lib/app/data/notification_tmp lib/features/notification/data/models
git ls-files lib/features/notification    # confirm the case in the index
```

| OLD | NEW |
|---|---|
| `app/data/Notification/` | `features/notification/data/models/` |
| `app/data/Permit/` | `features/permit/data/models/` |
| `app/data/Profile/` | `features/profile/data/models/` |
| `app/data/activity/` | `features/home/data/models/` |
| `app/data/announcement/` | `features/home/data/models/` |
| `app/data/attendance/` | `features/attendance/data/models/` |

The `.m.dart` suffix is dropped throughout: `leave_type.m.dart` → `leave_type.dart`.

---

## Directories emptied by this migration

Deleted once their last file moves — **verify empty, never delete pre-emptively**:

```
lib/app/data/          → features/<f>/data/models/
lib/app/modules/       → features/<f>/presentation/
lib/app/services/      → core/network/                                    ✅ P5
lib/app/widgets/       → core/ui/, core/theme/, core/storage/            ✅ P6
lib/app/routes/        → lib/app/routing/ + features/<f>/…/routes/       ✅ P6
lib/utils/             → core/{config,theme,utils,network,services}/     🟨 notification/ is P7
```

`lib/app/` survives, holding only `app.dart`, `bindings/`, and `routing/` — true as
of Phase 6. `lib/utils/` still holds `my_http_overrides.dart` (blocked on R-02) and
`notification/` (Phase 7).

---

## Verification per move

```bash
dart format .
flutter analyze          # must be ≤ baseline, 0 new issues
flutter test             # must be ≥ previous pass count, 0 failures
grep -rn "app/modules/<feature>" lib   # must return nothing after the feature moves
```

**No duplicate implementation may survive its phase** (rule §41). If a file is moved,
the original is deleted in the same commit — never left behind "just in case".

---

## Hasil eksekusi — 2026-09-01

Struktur akhir, diverifikasi terhadap kode:

```
lib/  144 berkas Dart
├── main.dart              12 baris
├── bootstrap.dart
├── app/                   app.dart · bindings/initial_binding.dart · routing/app_pages.dart
├── core/                  boot · config · network · services · storage · tenancy · theme · ui · utils
├── features/              auth · home · attendance · permit · notification · profile
│                          masing-masing data/{models,repositories,services}
│                          + presentation/{bindings,controllers,routes,views,widgets}
├── generated/assets.dart  (tanpa pemakai — lihat dead-code A2)
└── utils/                 my_http_overrides.dart (R-02) · notification/ (Fase 7)
```

Angka: **22 view · 17 controller · 7 repository · 6 API service · 6 binding fitur ·
22 route · 18 berkas test / 171 test lulus · `flutter analyze` 0 issue.**

Tiga deviasi dari peta ini, semuanya disengaja dan tercatat di `05-progress.md`:

1. **Route name dipisah dari route page.** Peta menaruh keduanya di satu
   `<f>_routes.dart`; pemisahan menjadi `<f>_routes.dart` (konstanta, tanpa import)
   + `<f>_pages.dart` (GetPage + binding) adalah yang menjaga nama route tetap
   *leaf* — tanpa itu, view yang hanya mengeja `/home` akan menarik seluruh view
   home secara transitif.
2. **Tidak ada kelas `Routes` terpusat.** Tujuan dinamai pemiliknya
   (`HomeRoutes.home`, `PermitRoutes.create`), sehingga route sebuah fitur dapat
   dihapus bersama fiturnya.
3. **`api_response.dart` dan `network_constants.dart` tidak dibuat** — lihat
   ADR-0004 Outcome.

**Path route tidak berubah satu karakter pun**, dan itu sekarang dijaga test
(`test/app/routing/app_pages_test.dart` menyebut 22 path verbatim) karena string-nya
hidup di payload FCM.

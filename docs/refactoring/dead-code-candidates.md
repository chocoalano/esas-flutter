# Dead Code Candidates

> **Diperbarui 2026-09-01.** Sebagian besar entri sudah dieksekusi di Fase 5–6.
> Status per entri ada di tabel **Status 2026-09-01** di akhir berkas; grep di
> setiap entri di bawah tetap harus dijalankan ulang sebelum menghapus apa pun.

> Per rule §32: **nothing here is deleted yet.** Each entry records the reference
> analysis that was actually run. Deletion happens in the phase named, and only after
> the analysis is re-run against the code at that time.

Commands used:
```bash
grep -rn "<symbol>" lib test
grep -rln "package:esas/<path>" lib test
```

---

## A. Confirmed unused — safe to delete (0 references)

### A1. `lib/utils/notification/firebase_services.dart` — `DefaultFirebaseOptions`

```
$ grep -rn "DefaultFirebaseOptions\|firebase_services" lib test
lib/utils/notification/firebase_services.dart:5:   class DefaultFirebaseOptions {
lib/utils/notification/firebase_services.dart:21:  'DefaultFirebaseOptions have not been configured for linux - '
lib/utils/notification/firebase_services.dart:26:  'DefaultFirebaseOptions are not supported for this platform.'
```
Only self-references. `main.dart:45` calls bare `Firebase.initializeApp()`; config
comes from the native `google-services.json` / `GoogleService-Info.plist`.

**Additional reason to remove rather than keep:** the file is not merely unused, it is
**wrong**. It spans three Firebase projects (`esasa-app`, `esas-44d5d`, `esas-7d76f`)
and an iOS bundle id (`com.sas.esasFlutter`) matching neither platform — while the
live native config is uniformly `esas-44d5d` / `com.example.esas`. Anyone who wires it
up breaks Firebase.

**Action:** delete, or regenerate with `flutterfire configure`. **Do not leave as-is.**
**Phase:** 7 (P7-7) · **Risk:** LOW

---

### A2. `lib/generated/assets.dart` — `Assets`

```
$ grep -rn "generated/assets\|Assets\." lib test | grep -v "^lib/generated"
(no output)
```
The codebase uses raw string paths (`'assets/images/logo-removebg.png'`) instead.

**Action:** delete. If the project later adopts generated asset constants, regenerate
and document the command in the README.
**Phase:** 9 (P9-3) · **Risk:** LOW

---

### A3. `lib/main.dart:69-129` — two unused dialogs

```
$ grep -rn "showInAppNotification\|showCustomExplainerDialog" lib test
lib/main.dart:69:  void showInAppNotification(String message, Future<bool> Function() onPressed) {
lib/main.dart:89:  Future<void> showCustomExplainerDialog() async {
```
Definitions only, no call sites. Both are App Tracking Transparency leftovers; recent
commits (`0466cf4 new update app tracking transparency removed`) removed the ATT
integration but left the dialogs behind.

**Action:** delete both (61 lines).
**Phase:** 2 (P2-5) · **Risk:** LOW

---

### A4. `ApiProvider.externalGet` / `externalPost` / `externalPostFormData`

```
$ grep -rn "externalGet\|externalPost\|externalPostFormData" lib | grep -v "^lib/app/services/"
(no output)
```
All external traffic goes through `ApiExternalProvider.postExternal`
(`attendance_controller.dart:280`). These three methods (lines 173-226, 54 lines)
duplicate a class that already exists.

**Action:** delete during the `ApiClient` refactor.
**Phase:** 1 (P1-5) · **Risk:** LOW

---

## B. Duplicate implementations — consolidate, don't just delete

### B1. `AnnouncementDetailBinding` is identical to `AnnouncementBinding`

```dart
// announcement_binding.dart AND announcement_detail_binding.dart — byte-identical bodies
Get.lazyPut<AnnouncementController>(() => AnnouncementController());
Get.lazyPut<ApiProvider>(() => ApiProvider());
```
Two classes, same dependencies. Note the detail route's view uses
`AnnouncementDetailController` — which **neither binding registers**;
`announcement_detail_view.dart:14` self-registers it with `Get.put` (HIGH-06).

**Action:** create a correct `AnnouncementDetailBinding` registering
`AnnouncementDetailController`, then remove the view's `Get.put`. This is a **fix**,
not a deletion.
**Phase:** 5 · **Risk:** MEDIUM

---

### B2. Three `clearStorage()` implementations

`login_controller.dart:137`, `splash_controller.dart:118`,
`profile_controller.dart:158`. The splash copy omits `userJson` and `userAvatar`
(MED-05).

**Action:** replace all three with `SessionRepository.clear()`.
**Phase:** 3 (P3-2) · **Risk:** LOW

---

### B3. Three status→message `switch` blocks

`login_controller.dart:71-115`, `home_controller.dart:209-223`, `helper.dart:48-75`.
Same codes, different Indonesian strings.

**Action:** replace with `ApiErrorMapper`. Preserve the **exact user-facing strings**
per screen where they differ — this is an internal consolidation, not a copy rewrite.
**Phase:** 1 (P1-4) · **Risk:** LOW-MEDIUM

---

### B4. Five sub-controllers each fetching `/general-module/auth` independently

`profile_personal_controller.dart:21`, `profile_worked_controller.dart:21`,
`profile_education_controller.dart:34`, `profile_family_controller.dart:26`,
`profile_experience_controller.dart:29` — five identical network calls for the same
user object, one per profile sub-tab.

**Action:** one `ProfileRepository.getCurrentUser()` shared across the five.
**Phase:** 5 · **Risk:** MEDIUM — check whether any tab currently relies on a *fresh*
fetch to see edits made on another tab. If so, keep an explicit refresh rather than
caching blindly.

---

## C. Requires a product decision — DO NOT DELETE YET

### C1. `Routes.INTRODUCTION` and the onboarding gate

```
app_routes.dart:9,28   → Routes.INTRODUCTION = '/introduction'   (no GetPage registered)
splash_controller.dart:46 → _storage.write(onboardingCompleted, true)
splash_controller.dart:52 → _storage.remove(onboardingCompleted)
```
`onboardingCompleted` is **written and removed but never read** — nothing gates on it.
`autoLogin()` runs immediately in `onInit`, so the `IntroductionScreen` inside
`SplashView` is effectively unreachable. `onIntroEnd` / `onBackToIntro` are wired to
the widget but the widget never shows.

**Question 8 in `05-progress.md`:** is onboarding meant to be reachable?

- If **yes** → this is a **bug**: restore the gate (`if (!onboardingCompleted) show intro`).
- If **no** → delete `Routes.INTRODUCTION`, `onboardingCompleted`, `introKey`,
  `onIntroEnd`, `onBackToIntro`, the intro UI, and the `introduction_screen` dependency.

**Do not delete before this is answered** — deleting a feature the product wants is
not a cleanup.
**Phase:** 6 (P6-5) · **Risk:** MEDIUM

---

### C2. `StorageKeys.tokenType`

```
$ grep -rn "tokenType" lib
login_controller.dart:126   write('Bearer')
login_controller.dart:139   remove
splash_controller.dart:120  remove
profile_controller.dart:160 remove
```
Written and cleared, **never read**. `ApiProvider` hardcodes `'Bearer $token'`
(line 54) rather than consulting it.

**Action:** likely deletable, but keep it if the backend may return a non-Bearer
scheme in future. Cheap to retain; decide in Phase 3 alongside `TokenStorage`.
**Phase:** 3 · **Risk:** LOW

---

### C3. `attendance_controller.dart:212` — dead route comparison

```dart
if (Get.currentRoute == '/attendance_scanner') { await mobileScannerController.start(); }
```
No such route exists (`grep` confirms one hit, this line). The real route is
`/attendance`. The scanner therefore **never restarts** after a scan.

**This is a bug, not dead code.** Fixing it *enables* previously-dead behaviour.

**Action:** change to `Routes.ATTENDANCE`, then verify the restart does not cause
repeat submissions of the same QR code.
**Phase:** 4 (P4-9) · **Risk:** MEDIUM — test the rescan path deliberately.

---

### C4. `.dart_tool/`, `.flutter-plugins-dependencies`

`.flutter-plugins-dependencies` (16 KB) is present in the working tree. `.gitignore`
already lists it, and `git ls-files` confirms it is **not** tracked. No action needed.

---

## D. Commented-out code to remove during migration

| File | Lines | Content |
|---|---|---|
| `utils/api_constants.dart` | 2-4 | 3 alternate base URLs (production, office wifi, phone hotspot) → replaced by `AppConfig` (MED-10) |
| `attendance_controller.dart` | 53, 57, 62 | Hardcoded home coordinates used for testing |
| `attendance_controller.dart` | 144-146, 290 | Commented-out debug prints |
| `firebase_messaging_services.dart` | 133-138 | Example navigation logic in a comment |
| `firebase_services.dart` | 31-34, 46, 58 | `--- THIS IS THE CORRECTED ANDROID CONFIG ---` banners |
| `api_provider.dart` | 1-2, 26-27 | `// Ensure this path is correct` (paths are correct) |
| `android/app/build.gradle.kts` | debug signingConfig | Empty block with 6 lines of commented guidance |

**Phase:** with each file's migration · **Risk:** NONE

---

## Summary

| Class | Count | Lines (approx) | Deletable now? |
|---|---|---|---|
| A — confirmed unused | 4 | ~215 | Yes, in the named phase |
| B — duplicates to consolidate | 4 | ~150 | No — consolidate, don't delete |
| C — needs a decision | 4 | ~60 | **No — blocked on product/backend** |
| D — comment noise | 7 sites | ~40 | Yes, opportunistically |

**Nothing in this file has been deleted.** Re-run each grep before acting.

---

## Status 2026-09-01

Diverifikasi ulang terhadap kode hari ini.

### A — dikonfirmasi tidak terpakai

| ID | Isi | Status |
|---|---|---|
| A1 | `DefaultFirebaseOptions` di `utils/notification/firebase_services.dart` | 🟡 **masih ada, masih nol referensi** — P7-7. Hapus, atau regenerasi dengan FlutterFire CLI bila memang dibutuhkan iOS |
| A2 | `lib/generated/assets.dart` | 🟡 **masih ada, masih nol referensi** — kandidat hapus di Fase 9 (P9-3) |
| A3 | Dua dialog di `main.dart` (`showInAppNotification`, `showCustomExplainerDialog`) | ✅ **dihapus** (P2-5, 61 baris) |
| A4 | `ApiProvider.externalGet/externalPost/externalPostFormData` | ✅ **dihapus bersama seluruh kelas `ApiProvider`** (Fase 5) |

### B — duplikasi

| ID | Isi | Status |
|---|---|---|
| B1 | `AnnouncementDetailBinding` duplikat | ✅ ditutup di Fase 5 — binding yang salah controller diperbaiki, lalu dipatok test route↔binding |
| B2 | Tiga `clearStorage()` | ✅ satu `SessionRepository.clear()` (MED-05) |
| B3 | Tiga blok `switch (statusCode)` | ✅ satu `ApiErrorMapper` (MED-07) |
| B4 | Lima sub-controller memanggil `/auth` sendiri-sendiri | ✅ satu `ProfileRepository.currentUser()` dengan cache + de-duplikasi |

### C — menunggu keputusan

| ID | Isi | Status |
|---|---|---|
| C1 | Gerbang onboarding | 🔴 **masih terbuka** — konstanta `Routes.INTRODUCTION` sudah dihapus, tetapi `splash_controller.dart` **masih menulis** `onboardingCompleted` yang tidak pernah dibaca siapa pun. Keputusan produk **M-D5** |
| C2 | `StorageKeys.tokenType` | 🟡 kini hanya dipakai `_mirrorToLegacy`, yang **tidak terjangkau** karena `legacyMirrorEnabled = false`. Hapus bersama mirrornya di Fase 9, atau pertahankan sampai pemindahan API selesai |
| C3 | Perbandingan route mati di attendance | ✅ dihapus (LOW-03, P4-9) |
| C4 | `.dart_tool/`, `.flutter-plugins-dependencies` | 🟡 artefak build, tidak disentuh |

### D — noise comment

🟡 Sebagian dibersihkan bersama penghapusan `utils/api_constants.dart` (termasuk IP
LAN yang dikomentari). Sisanya menjadi P9-5.

### Tambahan yang lahir setelah daftar ini ditulis

| Isi | Alasan masih ada |
|---|---|
| `utils/my_http_overrides.dart` | **Bukan dead code** — masih dipanggil `bootstrap.dart`, dan sengaja tidak ditandai `@Deprecated`. Hilang ketika R-02 selesai |
| `SessionRepository._mirrorToLegacy` | Tidak terjangkau (`legacyMirrorEnabled = false`), dipertahankan agar perilaku yang dikendalikannya tetap dapat ditemukan di riwayat. Hapus di Fase 9 |
| `core/network/dev_http_overrides.dart` | Sudah ditulis dan diuji, **belum dipasang**. Bukan dead code melainkan pengganti yang menunggu gerbangnya |

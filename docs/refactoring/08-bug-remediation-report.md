# 08 — Laporan Akhir Remediasi Bug ESAS Mobile

Tanggal: 2026-11-11 · Repo: `esas-selfservices` (branch `main`, baseline `5e8927f`) + `tenancy-app` (hanya kontrak device binding)
Sumber temuan: [audit 2026-11-11](../audit/2026-11-11-bug-audit.md) · Detail per baris: [tracker](07-bug-remediation-tracker.md)

> Tidak ada commit, push, deploy, atau perubahan database produksi. Semua perubahan ada di working tree.

## 1. Ringkasan eksekutif

- **102/102 temuan audit berstatus `VERIFIED`.** Setiap perbaikan punya test regresi otomatis. Hampir semua test dibuktikan gagal (RED) dulu terhadap kode lama; pengecualiannya dicatat di §3.
- **Temuan tambahan selama remediasi:** W4-FACE-202. Respons 202 `face_pending_review` sebelumnya tampil sebagai absensi berhasil; sekarang tampil sebagai struk "menunggu konfirmasi". Respons 201 tetap dianggap sukses.
- **Test suite:** 2 test baseline yang gagal (TEST-01/02) sudah diperbaiki. Satu test yang lolos tanpa menguji klaimnya (TEST-03) ditulis ulang dan terbukti menangkap mutasi. Satu test yang terlalu longgar (TEST-04) dikencangkan.
- **Hasil akhir:** `flutter test` **4703 lulus · 3 skip · 0 gagal**. `dart analyze` **0 issue**. Backend: 13/13 Pest lulus.
- **Belum bisa diklaim:** perilaku native di perangkat nyata belum diuji (DEVICE_TEST_REQUIRED, §9), dan ada tiga keputusan produk yang masih terbuka.
- **Verdict: `READY_FOR_INTERNAL_UAT`.** Belum `PRODUCTION_READY` (alasannya di §10).

## 2. Closure matrix — 102 temuan

| Modul | Critical | High | Medium | Low | Total | Status |
|---|---|---|---|---|---|---|
| CORE | 2 | 2 | 2 | 3 | 9 | 9/9 VERIFIED |
| UI | – | – | 2 | 2 | 4 | 4/4 VERIFIED |
| AUTH | – | 2 | 2 | 1 | 5 | 5/5 VERIFIED |
| SETUP | – | – | 1 | 2 | 3 | 3/3 VERIFIED |
| HOME | – | 1 | 7 | 7 | 15 | 15/15 VERIFIED |
| ATTD | – | 1 | 2 | 3 | 6 | 6/6 VERIFIED |
| ATTP | – | 3 | 9 | 8 | 20 | 20/20 VERIFIED |
| PRMT | – | 6 | 7 | 3 | 16 | 16/16 VERIFIED |
| PROF | 1 | 2 | 2 | 7 | 12 | 12/12 VERIFIED |
| NOTIF | – | – | – | 2 | 2 | 2/2 VERIFIED |
| INBOX | – | – | 1 | 1 | 2 | 2/2 VERIFIED |
| AI | – | 1 | 1 | 1 | 3 | 3/3 VERIFIED |
| GAMS | – | 1 | 1 | 2 | 4 | 4/4 VERIFIED |
| ITMS | – | – | – | 1 | 1 | 1/1 VERIFIED |
| **Total** | **3** | **19** | **37** | **43** | **102** | **102/102 VERIFIED** |

Alias deduplikasi audit (bukan defect terpisah, sudah tertutup lewat induknya): AUTH-03 → CORE-03 · NOTIF-01 → CORE-04 · HOME-07 → CORE-06 · HOME-13 → UI-01.

Temuan tambahan: **W4-FACE-202** (High) — 202 `face_pending_review` ditampilkan sebagai absensi berhasil → VERIFIED (attendance_repository_test.dart (2), attendance_view_test.dart).

<details>
<summary>Matriks per ID (102 baris)</summary>

| ID | Sev | Status | Bukti regresi |
|---|---|---|---|
| CORE-01 | C | VERIFIED | test/utils/notification/notification_icon_test.dart; build apk --debug + merged manifest diperiksa |
| CORE-02 | C | VERIFIED | test/core/storage/install_identity_test.dart (5) |
| PROF-01 | C | VERIFIED | test/features/profile/profile_session_privacy_test.dart (4), test/app/platform_privacy_test.dart |
| CORE-03 | H | VERIFIED | Flutter: device_info_service_test (7), device_binding_migration_test (4). Backend: MobileDeviceBindingMigrati… |
| CORE-04 | H | VERIFIED | api_client_session_test, auth_repository_test, splash_controller_test, login_connection_lost_test (diubah ke… |
| AUTH-01 | H | VERIFIED | test/features/auth/change_password_test.dart (2) |
| AUTH-02 | H | VERIFIED | test/features/auth/session_teardown_test.dart (5) |
| AI-01 | H | VERIFIED | test/features/ai_chat/ai_chat_conversation_test.dart |
| PRMT-01 | H | VERIFIED | test/features/permit/permit_approval_test.dart (6) |
| PRMT-02 | H | VERIFIED | test/features/permit/permit_variant_test.dart (3 baru) |
| PRMT-03 | H | VERIFIED | test/core/network/api_client_bytes_test.dart (4, server HTTP lokal), test/features/permit/permit_attachment_t… |
| PRMT-04 | H | VERIFIED | test/features/permit/permit_approval_test.dart (2) |
| PRMT-05 | H | VERIFIED | test/features/permit/permit_list_controller_test.dart |
| PRMT-06 | H | VERIFIED | permit_create_controller_test.dart (2, test lama yang mengunci bug diganti) |
| HOME-01 | H | VERIFIED | test/features/home/shift_track_progress_test.dart (6) |
| ATTD-01 | H | VERIFIED | liveness_platform_test.dart (2) |
| ATTP-01 | H | VERIFIED | attendance_controller_test.dart (grup remediasi wave 4) |
| ATTP-02 | H | VERIFIED | attendance_controller_test.dart (grup remediasi wave 4) |
| ATTP-03 | H | VERIFIED | attendance_list_controller_test.dart |
| GAMS-01 | H | VERIFIED | test/features/gams/gams_create_test.dart (8) |
| PROF-02 | H | VERIFIED | test/features/profile/profile_header_test.dart (3) |
| PROF-03 | H | VERIFIED | user_model_test.dart |
| CORE-05 | M | VERIFIED | api_client_session_test.dart (2) |
| CORE-06 | M | VERIFIED | test/app/routing/registry_routes_test.dart (2) |
| UI-01 | M | VERIFIED | bottom_nav_controller_test.dart (4) |
| UI-02 | M | VERIFIED | test/core/ui/app_error_state_scroll_test.dart |
| GAMS-02 | M | VERIFIED | test/features/gams/gams_dashboard_test.dart (2) |
| ATTD-02 | M | VERIFIED | liveness_gestures_test.dart (2) |
| ATTD-03 | M | VERIFIED | liveness_platform_test.dart (2) |
| ATTP-04 | M | VERIFIED | attendance_controller_test.dart (grup remediasi wave 4) |
| ATTP-05 | M | VERIFIED | attendance_controller_test.dart (grup remediasi wave 4) |
| ATTP-06 | M | VERIFIED | attendance_controller_test.dart (grup remediasi wave 4) |
| ATTP-07 | M | VERIFIED | attendance_controller_test.dart (grup remediasi wave 4) |
| ATTP-08 | M | VERIFIED | attendance_controller_test.dart (grup remediasi wave 4) |
| ATTP-09 | M | VERIFIED | attendance_controller_test.dart (grup remediasi wave 4), attendance_view_test.dart |
| ATTP-10 | M | VERIFIED | attendance_list_controller_test.dart |
| ATTP-11 | M | VERIFIED | attendance_controller_test.dart (grup remediasi wave 4) |
| ATTP-12 | M | VERIFIED | attendance_controller_test.dart (grup remediasi wave 4), attendance_view_test.dart |
| HOME-02 | M | VERIFIED | test/features/home/announcement_back_test.dart (2) |
| HOME-03 | M | VERIFIED | home_controller_test.dart (2) |
| HOME-04 | M | VERIFIED | home_controller_test.dart |
| HOME-05 | M | VERIFIED | home_controller_test.dart (2) |
| HOME-06 | M | VERIFIED | home_controller_test.dart |
| HOME-08 | M | VERIFIED | test/features/home/leave_balance_parsing_test.dart (2) |
| HOME-09 | M | VERIFIED | test/features/home/recent_activity_date_test.dart |
| PROF-04 | M | VERIFIED | profile_session_privacy_test.dart |
| PROF-05 | M | VERIFIED | test/features/profile/experience_period_test.dart |
| PRMT-07 | M | VERIFIED | permit_create_view_test.dart (2) |
| PRMT-08 | M | VERIFIED | permit_create_view_test.dart (2) |
| PRMT-09 | M | VERIFIED | test/features/permit/permit_show_route_test.dart |
| PRMT-10 | M | VERIFIED | permit_show_route_test.dart (2) |
| PRMT-11 | M | VERIFIED | permit_create_view_test.dart (2) |
| PRMT-12 | M | VERIFIED | permit_approval_test.dart |
| PRMT-13 | M | VERIFIED | permit_create_controller_test.dart (3) |
| AUTH-04 | M | VERIFIED | test/features/auth/login_errors_test.dart (3) |
| AUTH-05 | M | VERIFIED | test/features/auth/login_errors_test.dart |
| AI-02 | M | VERIFIED | test/features/ai_chat/ai_chat_conversation_test.dart (5) |
| SETUP-01 | M | VERIFIED | setup_controller_test.dart, test/features/auth/login_setup_link_test.dart |
| INBOX-01 | M | VERIFIED | test/features/inbox/inbox_decide_test.dart |
| CORE-07 | L | VERIFIED | test/core/utils/app_logger_test.dart (2 test baru) |
| CORE-08 | L | VERIFIED | dev_tls_client_test.dart (RED: compile; GREEN 2). Handshake nyata ke server dev self-signed belum diuji (ENV_… |
| CORE-09 | L | VERIFIED | server_config_test.dart |
| UI-03 | L | VERIFIED | test/core/ui/app_avatar_aspect_test.dart |
| UI-04 | L | VERIFIED | bottom_nav_text_scale_test.dart (3 skala: tanpa overflow DAN tinggi 60–61dp pada 1.0, <200 pada AX); home_vie… |
| GAMS-03 | L | VERIFIED | gams_dashboard_test.dart 'active means open…' (RED: member not found → GREEN) |
| GAMS-04 | L | VERIFIED | gams_dashboard_back_test.dart (RED dengan Get.back: halaman tetap; GREEN) |
| ATTD-04 | L | VERIFIED | attendance_controller_test.dart (grup remediasi wave 4) |
| ATTD-05 | L | VERIFIED | wave4_small_fixes_test.dart (2) |
| ATTD-06 | L | VERIFIED | wave4_small_fixes_test.dart |
| ATTP-13 | L | VERIFIED | attendance_view_test.dart |
| ATTP-14 | L | VERIFIED | attendance_controller_test.dart (grup remediasi wave 4) |
| ATTP-15 | L | VERIFIED | attendance_controller_test.dart (grup remediasi wave 4) |
| ATTP-16 | L | VERIFIED | wave4_small_fixes_test.dart (2) |
| ATTP-17 | L | VERIFIED | test/features/attendance/history_back_test.dart (2) |
| ATTP-18 | L | VERIFIED | attendance_list_controller_test.dart |
| ATTP-19 | L | VERIFIED | wave4_small_fixes_test.dart |
| ATTP-20 | L | VERIFIED | wave4_small_fixes_test.dart |
| HOME-10 | L | VERIFIED | schedule_calendar_month_test.dart (RED: compile; GREEN 2 — Feb 2028 kabisat, batas tengah malam Jakarta vs UT… |
| HOME-11 | L | VERIFIED | test/features/home/home_small_fixes_test.dart (3) |
| HOME-12 | L | VERIFIED | home_small_fixes_test.dart (2) |
| HOME-14 | L | VERIFIED | home_leave_balance_more_test.dart (RED: onOpen terpanggil, saldo tersembunyi tak terlihat; GREEN) |
| HOME-15 | L | VERIFIED | test/features/home/announcement_controller_test.dart (2) |
| HOME-16 | L | VERIFIED | announcement_controller_test.dart |
| HOME-17 | L | VERIFIED | home_controller_test.dart |
| PROF-06 | L | VERIFIED | profile_section_error_test.dart (RED 2 gagal: 503 & TypeError; GREEN 3) |
| PROF-07 | L | VERIFIED | payroll_test.dart 'a failed download says why, above the open slip' (RED: 0 widget hit-testable; GREEN) |
| PROF-08 | L | VERIFIED | bug_report_submit_test.dart 4 test (RED: compile, idempotencyKey belum diteruskan; GREEN) |
| PROF-09 | L | VERIFIED | profile_avatar_url_test.dart (RED dengan logika lama: prefix CDN pada URL absolut & '//avatars'; GREEN 3) |
| PROF-10 | L | VERIFIED | logout_guard_test.dart grup 'the profile sign-out' (ketukan kedua → auth.logout 1x, navigasi ke masuk; signed… |
| PROF-11 | L | VERIFIED | avatar_pick_test.dart (RED dengan logika lama: maxWidth null, picker dibuka 2x; GREEN 2) |
| PROF-12 | L | VERIFIED | payroll_test.dart 'a period with no dates…' (RED: compile; GREEN) |
| PRMT-14 | L | VERIFIED | test/features/permit/permit_list_controller_test.dart (3) |
| PRMT-15 | L | VERIFIED | test/features/permit/permit_list_controller_test.dart (2) |
| PRMT-16 | L | VERIFIED | permit_create_controller_test.dart (2), permit_create_view_test.dart |
| AUTH-06 | L | VERIFIED | logout_guard_test.dart grup 'a 401 during a deliberate sign-out' (RED: compile, expireSession void; GREEN) |
| SETUP-02 | L | VERIFIED | setup_controller_test.dart |
| SETUP-03 | L | VERIFIED | setup_controller_test.dart |
| NOTIF-02 | L | VERIFIED | notification_open_test.dart 'opening a row from the list…' (RED: compile; GREEN: 0 request, revision 0) |
| NOTIF-03 | L | VERIFIED | notification_open_test.dart 'a generic push opens the Notifikasi tab as a tab' (RED: canPop true; GREEN) + 'a… |
| INBOX-02 | L | VERIFIED | inbox_models_test.dart |
| AI-03 | L | VERIFIED | test/features/ai_chat/ai_chat_conversation_test.dart |
| ITMS-01 | L | VERIFIED | itms_ticket_test.dart 5 test (RED: compile; GREEN) + app_pages_test diperbarui |

</details>

## 3. Test closure

| ID | Masalah | Penyelesaian | Status |
|---|---|---|---|
| TEST-01 | `app_pages_test` "registers exactly the paths…" gagal: set rute usang | Set diperbarui dengan rute yang sah; assertion kesetaraan dipertahankan; `/itms/tickets/create` ditambahkan (ITMS-01) | VERIFIED |
| TEST-02 | `/inbox/approvals` merender `UnifiedInboxView` dengan `InboxBinding` | Binding diganti nama `UnifiedInboxBinding` (konvensi XView↔XBinding dipertahankan) | VERIFIED |
| TEST-03 | `attendance_controller_test` "an answer that never arrived KEEPS the key" lolos tanpa menguji klaimnya | Terbukti lolos juga saat kode dimutasi. Ditulis ulang lewat getter read-only `attemptKey` dan sekarang gagal terhadap mutasi. Perilaku domain tidak diubah | VERIFIED |
| TEST-04 | Test UI-04 hanya mengecek overflow | Ditambah assertion tinggi bilah (lihat §8, regresi) | VERIFIED |

Test lama yang mengunci perilaku salah dan diubah bersama perbaikannya (tidak ada yang dihapus):

- `api_client_session_test`, `login_connection_lost_test` → CORE-04
- `payroll_test` → PROF-01
- test 4xx pengajuan → PRMT-08
- test kebijakan tanggal → PRMT-06
- `module_registry_test` (tile MTMS) → CORE-06

**Pengecualian RED terpisah:**

- ATTD-05 dan ATTD-06: test ditulis bersama perbaikannya.
- PROF-09: logika lama diekstrak dulu ke fungsi, dibuktikan RED, baru diganti.
- Perbaikan yang murni ekstraksi juga diperlakukan seperti PROF-09: logika lama diekstrak dan dibuktikan RED.

## 4. Perbaikan keamanan & privasi

| ID | Ringkasan |
|---|---|
| PROF-01 | Rekam `/profile` (gaji, rekening, NIK, keluarga) tidak lagi disimpan plaintext. Sesi memakai allow-list field, data lama dibersihkan saat restore, dan `allowBackup`/`fullBackupContent` = false di Android. |
| CORE-02 | Reinstall iOS tidak lagi login sebagai pengguna sebelumnya. Marker instalasi dipakai untuk menghapus token, tenant, dan server dari Keychain pada instalasi baru. |
| CORE-03 | ID binding perangkat sekarang ANDROID_ID / IDFV / UUID instalasi, bukan `Build.ID`. Migrasi `legacy_device_id` di backend hanya berlaku untuk kecocokan persis dan bisa dimatikan lewat `HRMS_API_MIGRATE_LEGACY_DEVICE_ID`. |
| AUTH-02 | Semua jalur berakhirnya sesi (logout, 401, sesi kedaluwarsa saat start) melepas token FCM dan sign-out Google/Firebase. |
| AUTH-06, PROF-10 | 401 saat logout tidak lagi mengakhiri sesi dua kali. Logout dijaga dari ketukan ganda. |
| PRMT-03 | Lampiran izin tidak lagi dibuka lewat URL CDN publik. Sekarang diunduh lewat `GET /permits/{id}/file` dengan sesi dan tenant, tanpa berkas sementara publik. |
| PROF-04 | Respons upload avatar yang datang setelah sesi berganti tidak diterapkan ke sesi baru. |
| CORE-05 | Galat TLS tidak lagi disamarkan sebagai "tidak ada internet". |
| CORE-07 | Warning/error tercatat juga di release, setelah redaksi. |
| CORE-08 | Bypass TLS dev hanya berlaku untuk host pengembangan. Ia sekarang tidak bisa ditimpa GetConnect dan tetap dikompilasi keluar dari release. |
| AUTH-05 | Password dikirim apa adanya, tanpa `trim()`. |
| PRMT-13 | Berkas besar tidak lagi dimuat penuh ke RAM sebelum ukurannya dicek. |

Kebijakan presensi tidak diubah: threshold wajah, liveness, dan geofence tetap seperti semula.

## 5. Perbaikan domain

- **Absensi wajah/QR** (W4-FACE-202, ATTD-01..06, ATTP-01..20):
  - 202 tampil sebagai "menunggu konfirmasi".
  - Kontinuitas wajah baru dihitung setelah wajah pertama terlihat.
  - Foto hanya diambil bila wajah tunggal masih utuh.
  - Kamera QR pulih setelah masalah lokasi teratasi atau metode diganti.
  - Riwayat tidak lagi melompati halaman.
  - Shift malam lintas tengah malam dikenali.
  - Strip hari aman terhadap DST.
  - 423/429 dijelaskan dengan benar.
  - QR dengan `exp` ekstrem tidak lagi crash.
- **Izin/cuti** (PRMT-01..16):
  - Satu Idempotency-Key per niat; key dipertahankan bila hasilnya tidak diketahui.
  - Approver multi-tier bisa menjawab tier yang aktif.
  - Fallback varian form diperbaiki.
  - Tanggal lampau bisa diajukan dalam jendela 30 hari (keputusan produk).
  - Shift malam lolos validator.
  - Waktu keputusan memakai jam workspace.
  - Race antara refresh dan load-more diperbaiki.
- **Beranda & jadwal** (HOME-01..17):
  - Rel progres shift benar di luar jendela shift.
  - Cuti yang disetujui mengalahkan roster.
  - Tanggal aktivitas tidak lagi bergeser satu hari.
  - Saldo cuti pecahan dipertahankan; semua saldo bisa dilihat (HOME-14).
  - Bulan kalender dari jam workspace.
  - Durasi kerja tahan jam perangkat yang meleset.
- **Profil & payroll** (PROF-02..12):
  - Jabatan dan tanggal bergabung benar.
  - Gaji desimal terbaca.
  - Periode slip tanpa tanggal tidak lagi tampil "null – null".
  - Galat unduh terlihat di atas bottom sheet dan memakai pesan server.
  - Avatar diperkecil sebelum diunggah.
  - Laporan bug memakai satu key per laporan.
- **GAMS/ITMS/Inbox** (GAMS-01..04, ITMS-01, INBOX-01/02):
  - Form pembuatan nyata untuk 4 jenis GAMS dan tiket ITMS.
  - Hitungan "aktif" hanya item yang belum selesai, dengan "20+" bila halaman penuh.
  - `can_decide` dihormati.
  - Keputusan dijaga dari pengiriman ganda.

## 6. Perbaikan kontrak API

| ID | Kontrak |
|---|---|
| AI-01 / AI-03 | `conversation_id` dipisah dari `message_id`. Pesan 503 dibaca dari `text`. |
| AI-02 | Deadline panjang untuk giliran AI. Idempotency-Key per pertanyaan; "Kirim ulang" memakai key yang sama. |
| PRMT-03 | Lampiran lewat `GET /permits/{id}/file` (endpoint sudah ada di backend). |
| PRMT-05 | `GET /permits` tanpa `type` dari Beranda. |
| HOME-08, PROF-03 | Saldo dan gaji dibaca sebagai angka, termasuk string desimal. |
| INBOX-02 | `can_decide` dibaca. |
| ATTD-05, W4-FACE-202 | 423/429 dan 202 `face_pending_review` dipetakan dengan benar. |
| PROF-08 | Field `status` tidak termasuk kontrak bug report (server yang menetapkannya), jadi checkbox yang tidak pernah terkirim dihapus. |
| ITMS-01 | `POST /itms/tickets` (`service_id`, `subject` ≤255, `description` ≤4000) sekarang punya layar. Endpoint ini tidak menerima Idempotency-Key, jadi pengiriman ganda dicegah dengan guard. |
| CORE-03 (**satu-satunya perubahan backend**) | `legacy_device_id` opsional di LoginRequest/FirebaseLoginRequest. `AuthController::issueToken` memindahkan binding lama hanya bila cocok persis. Dikendalikan `config/hrms.php` → `migrate_legacy_device_id`. |

Prinsip "1 tenant = 1 company" dipertahankan.

## 7. Perubahan per repo

**esas-selfservices**: sekitar 155 berkas diubah dan 53 berkas/direktori baru (`git diff --shortstat`: +5544 / −1272). Sebaran berkas `lib/` + platform per area:

| Area | Berkas |
|---|---|
| features/gams | 17 |
| features/home, features/attendance | 15 masing-masing |
| features/itms | 13 |
| features/permit | 12 |
| features/ai_chat | 11 |
| features/profile | 10 |
| features/inbox, features/auth | 8 masing-masing |
| core/ui | 4 |
| app | 4 |
| core/storage | 3 |
| core lain (network, services, config, utils, registry) | 8 |
| setup, notification, utils | 2 masing-masing |
| android | 2 |

Ditambah 69 entri di `test/` (berkas baru atau diubah). Daftar berkas per temuan ada di kolom "Files Changed" pada tracker.

Berkas baru yang penting:

- `core/storage/install_identity.dart`
- `app/routing/not_found_view.dart`
- `ai_chat/data/models/ai_chat_reply.dart`
- `gams_create_controller.dart` / `gams_create_view.dart`
- `itms_ticket_create_controller.dart` / `itms_ticket_create_view.dart`

**tenancy-app**: `app/Http/Controllers/Api/AuthController.php`, `app/Http/Requests/Api/LoginRequest.php`, `app/Http/Requests/Api/FirebaseLoginRequest.php`, `config/hrms.php`, dan berkas baru `tests/Feature/Api/MobileDeviceBindingMigrationTest.php`. Perubahan lain di working tree backend (GAMS/ITMS starter, `routes/api.php`, dll.) milik sesi developer lain dan tidak disentuh.

## 8. Hasil test aktual

| Perintah | Hasil |
|---|---|
| `flutter test` (seluruh suite) | **4703 lulus · 3 skip · 0 gagal** |
| `dart analyze` | **No issues found** |
| `vendor/bin/pest` MobileAuthTest + MobileDeviceBindingTest + MobileDeviceBindingMigrationTest | **13/13 lulus** (64 assertion) |
| Run backend sebelumnya (+ FirebaseSignInTest) | 23/23 lulus |
| `flutter build apk --debug` + merged manifest (CORE-01) | Ikon dan meta-data FCM ada di APK |

**Regresi yang tertangkap selama remediasi (sudah diperbaiki):**

- Versi pertama UI-04 mengganti `SizedBox(height: 60)` dengan `ConstrainedBox(minHeight: 60)`. Akibatnya bilah navigasi memakan seluruh tinggi layar, dan 87 test `home_view_test` gagal.
- Perbaikannya: `IntrinsicHeight`, plus assertion tinggi (TEST-04).
- Test ITMS-01 juga menangkap crash `Get.toNamed<bool>` pada rute `GetPage` sebelum dikirim.

## 9. Blocker & yang belum bisa diverifikasi

**DEVICE_TEST_REQUIRED** — logikanya sudah diuji unit/widget, tetapi perilaku native harus dicoba di perangkat:

| ID | Yang perlu dicoba |
|---|---|
| CORE-01 | Notifikasi FCM benar-benar tampil di Android 13/14 dengan ikon baru |
| CORE-02 | Hapus lalu instal ulang di iOS → harus kembali ke layar setup/login |
| CORE-03 | Channel `esas/device` mengembalikan ANDROID_ID; migrasi binding pada login pertama setelah update |
| AUTH-02 | Token FCM dihapus setelah 401/logout; tidak ada push untuk pengguna sebelumnya |
| ATTD-01..03, ATTP-* | Seluruh pipeline kamera + ML Kit (liveness, wajah ramai, kontinuitas) dan pemindaian QR di perangkat kelas bawah |
| CORE-08 | Handshake TLS ke server dev ber-sertifikat self-signed (build debug) |

**Keputusan produk terbuka:**

1. **PRMT-06:** jendela pengajuan tanggal lampau diset 30 hari (`lookbackDays`). Perlu konfirmasi HR.
2. **HOME-10:** kalender kini memakai bulan workspace, tetapi navigasi antar bulan tidak ditambahkan karena itu permintaan fitur.
3. **PROF-08:** checkbox "Bug Aktif" dihapus karena backend sengaja tidak menerima status. Bila produk ingin informasi ini, perlu field baru di kontrak.

**Catatan lain:**

- Klien masih mewajibkan screenshot pada laporan bug, padahal backend menerimanya opsional. Ini bukan temuan audit dan tidak diubah.
- Rute `/itms/tickets`, `/itms/catalog`, dan `/itms/knowledge` masih alias dashboard ITMS; layar khusus untuk ketiganya belum ada.

## 10. Verdict rilis

**`READY_FOR_INTERNAL_UAT`**

- Semua temuan Critical/High/Medium/Low tertutup dengan test regresi.
- Suite penuh hijau, analyzer bersih.
- Satu-satunya perubahan kontrak backend teruji dan bisa dimatikan lewat konfigurasi.

Belum `PRODUCTION_READY` karena:

- Perilaku native pada §9 belum dicoba di perangkat nyata. Tiga di antaranya menyangkut temuan Critical (CORE-01, CORE-02) dan identitas perangkat (CORE-03).
- Keputusan produk PRMT-06 belum dikonfirmasi.
- Perubahan belum di-commit/di-review, dan migrasi binding backend belum dijalankan di staging.

Langkah berikut yang disarankan:

1. Review diff, lalu commit atas instruksi.
2. Deploy backend ke staging dengan `HRMS_API_MIGRATE_LEGACY_DEVICE_ID` aktif.
3. Jalankan UAT dengan checklist §9 di satu Android (13+) dan satu iOS.
4. Konfirmasi PRMT-06 dengan HR.

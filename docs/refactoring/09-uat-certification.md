# 09 — ESAS Mobile: Diff Review, Staging Preflight & Device UAT

Tanggal: 2026-11-11 · Mobile `esas-selfservices` (branch `main`, baseline `5e8927f`, belum di-commit) · Backend `tenancy-app` (branch `main`, HEAD `15188a98`, belum di-commit)
Masukan: [08 — laporan remediasi](08-bug-remediation-report.md) · [07 — tracker](07-bug-remediation-tracker.md)

> Dokumen ini adalah **bukti rilis**, bukan laporan remediasi baru. Setiap skenario yang belum dijalankan di perangkat nyata berstatus `NOT_RUN` atau `BLOCKED` — tidak ada hasil perangkat yang dikarang.

## Keputusan

**`READY_FOR_INTERNAL_UAT`**: status tidak berubah. Belum ada satu skenario perangkat atau staging pun yang dijalankan, sehingga belum ada bukti yang mendukung `UAT_IN_PROGRESS` atau status di atasnya.

| Gate | Hasil |
|---|---|
| A. Diff review | **`DIFF_REVIEW_PARTIAL`**. 25 temuan baru: 20 diperbaiki & diverifikasi, 1 OPEN (H7), 2 diterima, 1 menunggu keputusan produk (H3). Rinciannya di bawah. |
| B. Kompatibilitas device binding | Lulus untuk data yang ada. Ada 3 test baru; `MobileDeviceBindingMigrationTest` 8/8. |
| C. Staging preflight | **BLOCKED**: URL staging, akun uji, dan lingkungan terisolasi tidak tersedia/terdokumentasi. |
| D. UAT Android | **NOT_RUN**: tidak ada perangkat fisik. |
| E. UAT iOS | **NOT_RUN**: tidak ada perangkat fisik. Build iOS baru bisa setelah perbaikan Podfile. |
| F. Business journeys | **NOT_RUN**: butuh staging. |
| Rilis produksi | **Terblokir**: keystore R-01, penanda R-02, `com.example.esas`, versi 1.0.0+1, dan tree yang sedang diedit sesi lain (§G). |

## A. Diff review — `DIFF_REVIEW_PARTIAL`

Diff dibagi tiga area, masing-masing direview read-only oleh reviewer independen: presensi+izin, core+auth+platform, beranda+profil+GAMS+ITMS+inbox+AI. Setiap temuan diverifikasi ulang terhadap kode sebelum ditindaklanjuti. Tabel lengkap ada di [tracker §Temuan diff review UAT](07-bug-remediation-tracker.md).

**Yang paling penting:**

- **UAT-A1 (High) — regresi dari remediasi sendiri (ATTP-05).**
  - Saat aplikasi di-resume, absen wajah bisa terkirim dengan koordinat lama yang masih di dalam geofence, walaupun orangnya sudah di luar.
  - Perbaikan: absen wajah tidak dimulai, dan tidak dikirim, selama lokasi masih diperiksa ulang.
- **UAT-C1 (Medium, keamanan).**
  - "Ganti workspace" dari layar login menyimpan token workspace lama, lalu token itu terkirim ke server workspace baru.
  - Perbaikan: sesi diakhiri lebih dulu, ke server lama.
- **UAT-H1 (Medium) — regresi INBOX-01.** Menolak tugas ikut menutup layar inbox.
- **UAT-H2 (Medium) — GAMS.** Setelah submit, muncul dasbor kedua yang basi.
- **UAT-A2/A3/A4 (Medium):**
  - kamera QR macet;
  - prompt izin lokasi muncul lagi saat resume;
  - baris riwayat ganda.
- **UAT-IOS (High, pra-eksisting).**
  - Di Xcode 27 tidak ada build iOS yang bisa jadi, baik device maupun simulator.
  - Penyebabnya target deployment pod 9–13, yang sekarang jadi error.
  - Diperbaiki di `ios/Podfile`. `flutter build ios --debug --no-codesign` sekarang ✓.

**Jawaban atas pertanyaan review:**

| # | Pertanyaan | Jawaban |
|---|---|---|
| 1 | Sesuai akar masalah? | Umumnya ya. Pengecualian yang ditemukan sudah diperbaiki: CORE-05 dan CORE-08 parsial (UAT-C2/C3), HOME-11 memakai ejaan yang salah (UAT-H5), GAMS-03/ITMS-01 tanpa `cancelled` (UAT-H4). |
| 2 | Di luar scope? | `getBytes`, `awaitsModel` dan `mayAsk` milik ID lain. Selebihnya churn `dart format` dan rename `UnifiedInboxBinding`; tidak berbahaya. A4 versi awal adalah perubahan perilaku di luar ATTP-10 dan sudah dikoreksi. |
| 3 | Test regresi relevan? | Sebagian besar akan gagal bila perbaikannya di-revert. Utang kualitas test yang tersisa: HOME-09 hanya RED dengan `TZ=Asia/Makassar`; HOME-06 tidak mengunci gerbang view; ATTP-18 memakai jam asli; ATTD-03 hanya menguji fungsi statis; ATTP-16 melewatkan diri dekat tengah malam. |
| 4 | Package berubah? | Tidak. `pubspec.yaml`/`pubspec.lock` tidak berubah. `ios/Podfile.lock` berubah karena `pod install` setelah perbaikan Podfile. |
| 5 | Build konsisten? | APK debug ✓, termasuk setelah UAT-C7; `dataExtractionRules` ada di manifest hasil merge. iOS device (no-codesign) ✓ setelah perbaikan Podfile. iOS **simulator** ✗ karena keterbatasan arm64 ML Kit `MLImage` yang sudah didokumentasikan di Podfile; uji iOS harus di perangkat. |
| 6 | Data sensitif? | Terlindungi. Allow-list sesi lengkap, tidak ada gaji/rekening/NIK/keluarga di GetStorage atau log, dan backup cloud serta transfer perangkat Android 12+ kini dikecualikan (UAT-C7). |
| 7 | Rute GAMS/ITMS membuka transaksi? | **Sebagian.** Empat form GAMS dan "Lapor" ITMS berfungsi, dan field-nya cocok dengan validasi backend. **"Katalog IT" dan "Bantuan IT" tidak** bisa melakukan yang dijanjikan labelnya, dan QR pass tamu GAMS tidak pernah ditampilkan (UAT-H3, keputusan produk). |
| 8 | Regresi presensi/izin? | Ada 4 dan semuanya sudah diperbaiki (A1–A4). 201/202/409 benar. Threshold wajah, liveness dan geofence tidak dilonggarkan. |
| 9 | Konfigurasi/provisioning tambahan? | Ada dua. iOS: `pod install` di mesin build (Podfile berubah). Android: tidak ada; channel `esas/device` ada di `MainActivity`. Selain itu, **APNs key di Firebase** untuk staging/prod harus dikonfirmasi operator. |
| 10 | Kredensial di diff? | Tidak ada; hanya password fixture test. |

## B. Device binding — kompatibilitas data existing

Perubahan backend: `legacy_device_id` opsional, flag `hrms.api.migrate_legacy_device_id`, dan `migrateLegacyBinding()`. Tidak ada migrasi skema.

| Skenario | Perilaku (dari kode + test) |
|---|---|
| Collision ID | ANDROID_ID unik per perangkat+user+kunci penandatangan; IDFV per vendor; UUID instalasi sebagai cadangan, yang kini lengket (UAT-C4). Kolom `device_id` tidak unik dan tidak diubah. |
| Migrasi berulang | Login berikutnya mengirim legacy yang sama. Binding sudah ANDROID_ID, jadi tidak terjadi apa-apa dan tetap satu token. *Test baru.* |
| Legacy tidak cocok | Tidak ada yang dipindah. Akun yang di-bind sebelum update OS (`Build.ID` berubah setiap update OS) tetap butuh HR release, sama seperti sebelumnya. |
| Firmware sama, ponsel lain | Ponsel pertama yang update mengambil binding; ponsel kedua dianggap perangkat lain. *Test baru.* Risiko operasional: siapa pun yang memegang password karyawan dan ponsel ber-firmware sama bisa "mengklaim" binding lebih dulu. Ini tidak memberi akses baru dibanding build lama, tetapi pemilik asli lalu butuh HR release. |
| Akun pindah perangkat | Tidak berubah: self-service jalan, absensi ditolak sampai HR release. |
| Token perangkat lama | Token yang dinamai legacy dicabut saat migrasi. Token lama tetap berlaku sampai login ulang atau kedaluwarsa (30 hari). Absensi tidak ditolak tepat setelah upgrade, karena izin absensi melekat di token, bukan dicek per request. |
| Login Google/Firebase | Jalur sama dengan login NIP. *Test baru.* |
| Flag `=false` | Legacy diabaikan, perilaku seperti backend lama. Field tetap diterima (nullable). |
| Urutan deploy | Bebas (lihat Lampiran A.2). |

Hasil: `MobileDeviceBindingMigrationTest` **8/8** (40 assertion). Run sebelumnya: MobileAuthTest + MobileDeviceBindingTest + migrasi 13/13.

## C. Staging preflight (read-only)

| Item | Status | Temuan |
|---|---|---|
| URL API build mobile | BLOCKED | Tidak ada URL staging di repo. Host adalah seed `--dart-define API_BASE_URL` atau diketik di layar Setup. |
| HTTPS/TLS | BLOCKED | Tidak bisa dicek tanpa URL. Di kode: TLS ketat di release (bypass hanya debug+development). Penanda R-02 di risk register ("removing the TLS bypass takes the app offline") masih **OPEN**: sertifikat server harus diverifikasi valid sebelum rilis. |
| Tenant, akun uji, entitlement HRMS/GAMS/ITMS | BLOCKED | Tidak ada akses/daftar. |
| Versi backend | Diketahui sebagian | Lokal `15188a98` + perubahan belum di-commit (milik sesi ini dan sesi lain). Versi staging tidak diketahui. |
| Versi build mobile | Risiko | `pubspec.yaml` masih `1.0.0+1`. `applicationId com.example.esas` ditolak Play Store (risk register). |
| Firebase Messaging | Sebagian | `google-services.json` dan `GoogleService-Info.plist` di-track. Entitlement `aps-environment` dev/prod ada. APNs key di proyek Firebase belum dikonfirmasi. |
| Konfigurasi migrasi binding | Siap | `HRMS_API_MIGRATE_LEGACY_DEVICE_ID` default `true`; rollback via flag (Lampiran A.3). |
| Logging aman | Siap | Redaksi AppLogger ditinjau; tidak ada token/PII di warning/error. |
| DB staging terisolasi | **Risiko** | Runbook backend hanya menyebut "staging tenant" di host produksi. Isolasi central DB tidak terkonfirmasi. |
| Rollback | Siap (prosedur) | Lampiran A.3. Rollback mobile setelah migrasi butuh HR release massal. |

## C. Android native UAT — target: 1 perangkat fisik Android 13+

Status perangkat: **tidak ada perangkat fisik terhubung** (`adb`/`flutter devices` kosong; hanya emulator `Medium Phone API 36.1`). Semua skenario `NOT_RUN`. Bukti emulator, bila ada, dicatat terpisah dan tidak menggantikan perangkat fisik.

| UAT ID | Temuan | Langkah | Expected | Result |
|---|---|---|---|---|
| AND-PUSH-01 | CORE-01 | Instal, login, izinkan notifikasi (Android 13 prompt) | Prompt POST_NOTIFICATIONS muncul; token FCM terdaftar (server menerima `fcm_token`) | NOT_RUN |
| AND-PUSH-02 | CORE-01 | Kirim push saat app di foreground | Notifikasi lokal tampil dengan ikon `ic_launcher_foreground` (siluet, bukan kotak putih) | NOT_RUN |
| AND-PUSH-03 | CORE-01 | Kirim push saat app di background/terminated | Notifikasi FCM tampil dengan ikon & kanal `esas_attendance` | NOT_RUN |
| AND-PUSH-04 | NOTIF-03 | Tap push generik dari system tray | Tab Notifikasi terbuka sebagai tab (Back menawarkan keluar, tidak ada halaman tersembunyi di bawahnya) | NOT_RUN |
| AND-PUSH-05 | NOTIF-02 | Tap push izin/slip dari tray | Detail izin/slip terbuka di atas halaman aktif; Back kembali | NOT_RUN |
| AND-PUSH-06 | AUTH-02 | Logout akun A, login akun B, kirim push ke A | Tidak ada push A yang tampil di perangkat | NOT_RUN |
| AND-DEV-01 | CORE-03 | Login dengan build baru | Request login membawa `device_id` = ANDROID_ID (16 hex), bukan `Build.ID` | NOT_RUN |
| AND-DEV-02 | CORE-03 | Akun terikat `Build.ID` (dari build lama) → update app → login ulang | `is_registered_device=true`, `can_record_attendance=true`; binding pindah ke ANDROID_ID | NOT_RUN |
| AND-DEV-03 | CORE-03 | Login kedua di perangkat yang sama | Binding tidak berubah; satu token per perangkat | NOT_RUN |
| AND-DEV-04 | CORE-03 | Perangkat lain dengan firmware sama, akun yang sama | Dianggap perangkat lain (`is_registered_device=false`) | NOT_RUN |
| AND-DEV-05 | CORE-03 | Flag `HRMS_API_MIGRATE_LEGACY_DEVICE_ID=false`, ulangi AND-DEV-02 | Binding tidak pindah; absensi ditolak sampai HR release | NOT_RUN |
| AND-ATT-01 | ATTP-01/02 | QR check-in di dalam geofence | Struk sukses dengan jam tercatat server | NOT_RUN |
| AND-ATT-02 | — | QR check-out | Struk pulang | NOT_RUN |
| AND-ATT-03 | ATTD-01..03 | Face check-in, ikuti challenge liveness | 201 → "Absensi berhasil" | NOT_RUN |
| AND-ATT-04 | W4-FACE-202 | Face dengan hasil 202 `face_pending_review` | Struk "menunggu konfirmasi" (jam pasir), BUKAN sukses | NOT_RUN |
| AND-ATT-05 | ATTD-03 | Wajah keluar frame / dua wajah saat challenge | Ditolak sebelum foto; tidak ada request presensi | NOT_RUN |
| AND-ATT-06 | ATTP-04/05/09 | Tolak izin lokasi; tolak izin kamera permanen | Pesan + tombol pengaturan; resume tidak meminta ulang | NOT_RUN |
| AND-ATT-07 | — | Di luar geofence | Ditolak dengan pesan server; tidak ada sukses palsu | NOT_RUN |
| AND-ATT-08 | ATTP-02 | Ganti Face ↔ QR setelah penolakan | Scanner/kamera kembali aktif | NOT_RUN |
| AND-ATT-09 | ATTP-05/06/15 | Background/resume saat kamera aktif dan saat submit | Lokasi divalidasi ulang dulu; submit yang berjalan tidak diklaim berhenti | NOT_RUN |
| AND-ATT-10 | ATTP-11 | Putus jaringan sebelum submit (challenge) | Penolakan transient dengan tombol ulang | NOT_RUN |
| AND-ATT-11 | TEST-03 | Putus jaringan setelah submit | "Belum pasti", tidak ada sukses palsu; tidak ada submit kedua otomatis | NOT_RUN |
| AND-ATT-12 | — | Absen dua kali (duplikat) | 409/penolakan domain; tidak ada sukses palsu | NOT_RUN |

## D. iOS native UAT — target: 1 perangkat fisik iOS

Status perangkat: **tidak ada iPhone/iPad fisik** (`xcrun devicectl` hanya simulator). Semua `NOT_RUN`.

| UAT ID | Temuan | Langkah | Expected | Result |
|---|---|---|---|---|
| IOS-REI-01 | CORE-02 | Login A → uninstall tanpa logout → install ulang → buka | Layar Setup/Login; sesi A tidak pulih | NOT_RUN |
| IOS-REI-02 | CORE-02 | Login A → update ke build berikutnya (TestFlight) | Sesi A tetap (upgrade bukan instalasi baru) | NOT_RUN |
| IOS-SES-01 | AUTH-02 | Logout normal | Kembali ke login; token FCM dilepas; Google sign-out | NOT_RUN |
| IOS-SES-02 | AUTH-02/06 | Logout dalam mode pesawat | Keluar lokal sekali (tanpa navigasi ganda); pesan "keluar dari perangkat ini" | NOT_RUN |
| IOS-SES-03 | AUTH-02 | Token kedaluwarsa / 401 di tengah sesi | Satu kali ke login; token FCM & identitas dilepas | NOT_RUN |
| IOS-SES-04 | AUTH-02 | A logout → B login → push ke A | Tidak ada notifikasi/data A terlihat | NOT_RUN |
| IOS-SES-05 | AUTH-02 | "Masuk dengan Google" oleh B setelah A | Pemilih akun Google muncul, bukan akun A otomatis | NOT_RUN |

## E. Business journeys — staging, data sintetis

Tidak ada E2E yang bisa diberi PASS dari widget test. Semua `NOT_RUN` sampai staging dan akun uji tersedia.

| UAT ID | Persona | Journey | Verifikasi end-to-end | Result |
|---|---|---|---|---|
| BIZ-HR-01 | Employee HRMS | Login → presensi → roster → ajukan izin (termasuk tanggal lampau ≤30 hari) → slip gaji → profil | UI → API → transaksi → DB staging → status → riwayat/notifikasi | NOT_RUN |
| BIZ-HR-02 | Supervisor HRMS | Approve/reject izin (termasuk approver multi-tier), QR departemen | Keputusan tercatat sekali; notifikasi ke pemohon | NOT_RUN |
| BIZ-GA-01 | Employee GAMS | Buat permintaan layanan, reservasi ruang, pinjam kendaraan, daftar tamu | Masing-masing tercatat dan tampil di dasbor GAMS | NOT_RUN |
| BIZ-GA-02 | Approver GAMS | Buka dan putuskan request yang ditugaskan | Hanya yang `can_decide` bisa diputuskan | NOT_RUN |
| BIZ-IT-01 | Employee ITMS | Buat tiket → pantau status → baca knowledge base | Tiket tercatat; hitungan aktif benar | NOT_RUN |
| BIZ-IT-02 | Approver ITMS | Putuskan approval yang diizinkan | Tiket yang tidak bisa diputuskan di mobile tidak menampilkan tombol | NOT_RUN |
| BIZ-TEN-01 | Tenant HRMS-only | Login | Tidak ada tile/rute GAMS/ITMS; rute tak dikenal → "belum tersedia" | NOT_RUN |
| BIZ-TEN-02 | Tenant + GAMS/ITMS | Login | Hanya modul ber-entitlement & berizin yang tampil | NOT_RUN |

## F. Defect baru & perbaikannya

Lihat §A dan tracker. Ringkasan per status:

| Status | Temuan |
|---|---|
| **VERIFIED** (20) | A1, A2, A3, A4, A5, A7, A8, H1, H2, H4, H5, H6, H8, H9, C1, C2, C3, C4, C6, C7 |
| **VERIFIED** (build) | UAT-IOS |
| **OPEN** | H7 |
| **NOT_APPLICABLE** | A6 (desain yang dikunci test), C5 (trade-off) |
| **BLOCKED (produk)** | H3 |

## G. Blocker yang tersisa

1. **Keystore R-01.**
   - `esas-keystore.jks` ada di riwayat Git (`65f3b84`, `22a202b`), dan kata sandi literalnya ada di baris yang dikomentari pada `android/app/build.gradle.kts` di `65f3b84`.
   - Remediasi lokal selesai: keystore baru dibuat dan sertifikat publiknya diekspor.
   - **Upload-key reset di Google Play Console belum terkonfirmasi.** Bila aplikasi tidak memakai Play App Signing, kunci yang bocor adalah kunci penandatangan aplikasi itu sendiri.
   - Remote GitHub; visibilitasnya tidak bisa dicek di sini (`gh` tidak terpasang).
   - Rewrite riwayat dan reset kunci hanya dengan persetujuan operator.
2. **Sesi lain sedang mengedit tree yang sama (2026-11-11 ±20:50).**
   - `lib/core/theme/app_theme.dart` saat ini **tidak terkompilasi**: `NoTransitionsBuilder` belum ada. Tidak ada build UAT yang bisa dibuat sampai itu selesai.
   - Hasil test pada §H diambil dari salinan scratch dengan berkas itu di-reset ke HEAD; tree yang sebenarnya tidak disentuh.
   - Sesi itu juga menambahkan batas skala teks 0,8–1,3 di `lib/app/app.dart`. Ini meniadakan dukungan Dynamic Type yang menjadi alasan UI-04 dan perlu direkonsiliasi.
3. **Staging dan perangkat** (§C–§E).
4. **Commit.** Perubahan backend device binding harus di-commit terpisah dari pekerjaan sesi lain di `tenancy-app` (Lampiran A.1).
5. **Produk:** UAT-H3 (Katalog IT, Bantuan IT, QR pass tamu).

## H. Hasil test aktual

| Perintah | Hasil |
|---|---|
| `flutter test`, seluruh suite, di salinan scratch (semua perubahan sesi ini + edit sesi lain yang terkompilasi; `app_theme.dart` = HEAD) | **4726 lulus · 3 skip · 0 gagal** |
| `dart analyze lib test` (salinan) | No issues found |
| `dart analyze lib` (tree asli) | 7 error, semuanya `app_theme.dart` milik sesi lain |
| `vendor/bin/pest tests/Feature/Api/MobileDeviceBindingMigrationTest.php` | 8/8 lulus |
| `flutter build apk --debug` | ✓ (2×, termasuk setelah UAT-C7) |
| `flutter build ios --debug --no-codesign` | ✗ sebelum perbaikan Podfile → ✓ sesudahnya (sebelum edit sesi lain) |
| `flutter build ios --simulator --debug` | ✗ (keterbatasan ML Kit arm64 simulator, didokumentasikan) |

**3 test yang di-skip:** `home_visual_qa_test`, `attendance_visual_qa_test`, `attendance_history_visual_qa_test`.

- Ketiganya diberi tag `visual` dan dilewati secara sengaja oleh `dart_test.yaml`, karena hasil rasterisasi berbeda antar mesin.
- Ini **expected skip**: alat diagnostik yang dijalankan manual dengan `--update-goldens`, bukan gerbang CI.
- Konsekuensinya, tidak ada **regresi visual** otomatis. Perubahan UI pada remediasi ini hanya terjaga oleh test perilaku dan probe overflow.

## I. Keputusan Product Owner (dicatat)

- **PRMT-06:** lookback 30 hari adalah baseline UAT sementara, bukan kebijakan produksi. Backend tetap otoritatif dan tidak ada bypass.
- **PROF-08:** penghapusan checkbox "Bug Aktif" diterima.
- **HOME-10:** perbaikan zona waktu diterima. Navigasi bulan masuk backlog sebagai enhancement terpisah.


## Lampiran A — Prosedur staging untuk operator

Tidak dijalankan oleh engineering. Dieksekusi oleh operator berwenang setelah ada instruksi commit/deploy.

### A.1 Prasyarat (go/no-go sebelum deploy)

1. Ada lingkungan staging **terpisah** dari produksi (host dan database central sendiri), atau — bila hanya ada tenant staging di host produksi — keputusan tertulis bahwa itu diterima. Runbook backend saat ini hanya menyebut "staging tenant where one exists" di host produksi.
2. Commit backend yang dideploy berisi **hanya** perubahan yang sudah direview. Working tree `tenancy-app` saat ini mencampur 5 berkas device binding dengan pekerjaan sesi lain yang belum di-commit (GAMS/ITMS starter, `routes/api.php`, migrasi tenant ITMS baru). Perubahan device binding harus di-commit terpisah:
   - `app/Http/Controllers/Api/AuthController.php`
   - `app/Http/Requests/Api/LoginRequest.php`
   - `app/Http/Requests/Api/FirebaseLoginRequest.php`
   - `config/hrms.php`
   - `tests/Feature/Api/MobileDeviceBindingMigrationTest.php`
3. Akun uji sintetis per persona (§E) dengan entitlement yang benar, tanpa data karyawan nyata.
4. Build mobile staging dibuat dengan `--dart-define`:
   - `API_BASE_URL=<origin staging, https>`
   - `ENVIRONMENT=staging` — bukan `development`: bypass TLS dev hanya aktif untuk `development` di build debug.
   - `TENANT=<tenant staging>` bila tidak memakai layar Setup.
5. Proyek Firebase untuk staging: FCM terhubung dengan APNs key/cert untuk iOS, dan `google-services.json`/`GoogleService-Info.plist` sesuai bundle `com.example.esas`.

### A.2 Urutan deploy

Perubahan device binding **tidak punya migrasi database**.

1. Deploy backend (commit device binding). Set `HRMS_API_MIGRATE_LEGACY_DEVICE_ID=true`, lalu `php artisan config:cache`.
2. Smoke backend: login NIP dari build lama (tanpa `legacy_device_id`) tetap 200 dan perilakunya tidak berubah.
3. Distribusikan build mobile staging ke perangkat uji.
4. Jalankan §C–§E.

Urutan deploy mobile/backend bebas:
- Backend lama mengabaikan field `legacy_device_id` (validasi Laravel membuang field tak dikenal).
- Aplikasi lama tidak pernah mengirimnya.

### A.3 Rollback

| Situasi | Langkah | Efek samping |
|---|---|---|
| Migrasi binding memindahkan binding yang salah | `HRMS_API_MIGRATE_LEGACY_DEVICE_ID=false` + `php artisan config:cache`. Berlaku seketika, tanpa deploy | Binding yang sudah dipindah tetap di ID baru. Akun yang salah dilepas lewat aksi HR "Release attendance device" yang sudah ada |
| Backend perlu di-revert | Revert commit device binding, deploy | Tidak ada perubahan data. Aplikasi baru tetap bisa login. Binding yang sudah pindah tetap valid untuk aplikasi baru |
| Aplikasi mobile perlu di-rollback ke build lama | Distribusikan build lama | Build lama mengirim `Build.ID`. Akun yang sudah pindah ke ANDROID_ID dianggap perangkat lain, jadi absensi ditolak sampai HR melepas binding. **Rencanakan HR release massal sebelum rollback mobile** |

Mengenali akun yang sudah pindah tanpa log khusus:
- `Build.ID` berbentuk label firmware (mis. `XXXX.YYMMDD.NNN`).
- ANDROID_ID adalah 16 karakter heksadesimal.

Query dijalankan oleh DBA di database tenant. Jangan menyalin nilai ke laporan.

## Lampiran B — Format bukti UAT

Setiap baris di §C–§E diisi per skenario:

| Field | Isi |
|---|---|
| UAT ID | Identifier skenario |
| Device | Model dan versi OS |
| App Build | Versi / commit |
| Backend | Versi / commit staging |
| Tenant | Label sintetis |
| Persona | Employee / Manager / Operator |
| Steps | Langkah reproduksi |
| Expected | Perilaku yang diharapkan |
| Actual | Perilaku nyata |
| Evidence | Log / screenshot / video / respons API tersanitasi |
| Result | `PASS` / `FAIL` / `BLOCKED` / `NOT_RUN` |

Larangan dalam bukti: token, kredensial, NIK, data gaji, dan data personal nyata.

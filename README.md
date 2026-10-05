# MOBILE SELF-SERVICE APPLICATION BLUEPRINT
## Human Capital & Workforce Operating System — Employee Mobile Experience v1.1

**Status:** Product / UX / Domain / Technical Blueprint — **diselaraskan dengan kode nyata pada 2026-09-01**  
**Target:** Android & iOS — seluruh karyawan dalam satu aplikasi  
**Product context:** Human Capital & Workforce Operating System Indonesia-first  
**Client repository:** `esas-selfservices` — Flutter 3.35.5 / Dart 3.9.2, GetX 4.7 (dokumen ini tinggal di dalamnya)  
**Backend repository:** `tenancy-app` — Laravel 13 / PHP 8.3, `stancl/tenancy` 3.10, Sanctum 4, panel Central + HRMS  
**Sibling client:** `esas_attendance` — kiosk absensi, **sudah live di `/api/v1`**  
**Face service:** `supports` — FastAPI stateless scoring  
**Source basis:**
- `tenancy-app/app/Panels/Hrms/plans/blueprint.md` — Master Product Blueprint Foundation v1.0 (termasuk §0 Keadaan Nyata Proyek)
- `tenancy-app/app/Panels/Hrms/plans/implement_prompts/` — Wave 0–11, 128 module plan, ADR 001–010
- `esas-selfservices/docs/adr/0001…0006` dan `docs/refactoring/00…06`

**Architecture rule:** Satu aplikasi, capability berbeda berdasarkan persona + entitlement + permission + organization scope + feature flag.

### Aturan interpretasi dokumen ini

1. **§0 adalah kenyataan kode; sisanya rancangan.** Bila keduanya berbeda, §0 yang berlaku untuk perencanaan — aturan yang sama dipakai Master Blueprint §0 dan `implement_prompts/000-README.md`.
2. **Setiap capability punya penopang backend.** Tidak ada layar yang boleh masuk sprint sebelum module plan penopangnya selesai. Pemetaannya di **Lampiran A**.
3. **Kontrak API yang mengikat ada di Lampiran B**, bukan di badan dokumen. Badan dokumen menjelaskan *mengapa*; lampiran menetapkan *apa*.
4. **Nilai policy tenant-specific** (threshold, SLA, jumlah tingkat approval, retensi) tidak di-hardcode; ia configurable dan diselesaikan lewat domain specification.
5. **Penomoran §1–§151 dipertahankan** dari v1.0 supaya rujukan lama tetap valid; penyesuaian dilakukan di dalam bagian, bukan dengan menomori ulang.

---

# 0. CURRENT PROJECT REALITY & DESIGN CONSTRAINTS

> **Diverifikasi terhadap kode pada 2026-09-01**, bukan disalin dari rencana.
> Sumber: `tenancy-app/routes/api.php`, `app/Http/Controllers/Api/*`,
> `app/Models/Hrms/*`, `database/migrations/tenant/*`, `app/Panels/Hrms/Resources/*`;
> `esas-selfservices/lib/**`, `docs/adr/*`, `docs/refactoring/*`, dan hasil
> `flutter test` (**171 test lulus**) serta `flutter analyze` (**0 issue**).
>
> Sisa dokumen ini adalah **rancangan**. Bagian ini adalah **kenyataan**.
> Ketika keduanya berbeda, yang berlaku untuk perencanaan adalah bagian ini.

## 0.1 Peta repositori

| Repo | Peran | Kondisi terverifikasi |
|---|---|---|
| `tenancy-app` | Backend tunggal untuk seluruh client mobile | 20 route `/api/v1`, 9 controller API, 23 Filament resource HRMS, 39 model `Hrms`, 25 migrasi tenant |
| `esas-selfservices` | **Aplikasi ini** | 144 berkas Dart, 6 fitur, 22 route, 22 view, 17 controller, 18 berkas test / 171 test hijau; refactor Fase 0–6 **selesai**, Fase 7–9 belum |
| `esas_attendance` | Client kiosk absensi | **Sudah berjalan di `/api/v1`** — referensi implementasi tenancy, sesi, dan HTTP client yang diadopsi ADR-0005 |
| `supports` | Face scoring stateless (FastAPI) | Dipanggil hanya oleh `App\Support\Hrms\FaceApiClient` |

Empat repositori, **satu backend**. Itu keputusan ADR-0006, dan sudah dibuktikan
oleh `esas_attendance` yang berjalan di atasnya — bukan asumsi.

## 0.2 Yang benar-benar dilayani backend hari ini

Seluruh 20 route berada di bawah `/api/v1`. Tenant di-resolve **sebelum routing**
oleh `IdentifyTenantByHeader` (`X-Tenant`), karena token Sanctum disimpan di
database tenant sendiri; permintaan tanpa workspace ditolak tanpa fallback.

```text
publik (tanpa token)
  GET  /api/v1/workspace                does this name reach a workspace, and which
  POST /api/v1/auth/login               identifier + password + device_id → token

handset karyawan (auth:sanctum)         ← permukaan milik aplikasi ini
  GET  /api/v1/auth/me
  POST /api/v1/auth/logout              opsional fcm_token → handset itu dilepas
  GET  /api/v1/attendance/context       shift, status clock, geofence, izin QR
  POST /api/v1/attendance/face/challenge
  POST /api/v1/attendance/face
  POST /api/v1/attendance/qr
  GET  /api/v1/qr-presences/context
  POST /api/v1/qr-presences
  POST /api/v1/qr-presences/redeem
  POST /api/v1/push-tokens
  POST /api/v1/push-tokens/forget

mesin absensi (auth:kiosk-device)       ← 7 route, milik esas_attendance, bukan aplikasi ini
```

Panel HRMS menopangnya dengan 23 resource: Attendance 5, Employee 2,
Organization 5, Payroll 4, Permit 2, Support 5.

**Kesimpulan yang penting untuk perencanaan:** absensi, sesi, tenancy, dan push
sudah punya kontrak nyata dan sudah dipakai satu client produksi. Cuti, slip gaji,
profil, pengumuman, dan notifikasi **belum punya API** — walaupun **datanya sudah
ada** sebagai model dan tabel.

## 0.3 Yang benar-benar ada di aplikasi ini

```text
lib/
├── app/          app.dart · bindings/initial_binding.dart · routing/app_pages.dart
├── core/         boot · config · network · services · storage · tenancy · theme · ui · utils
├── features/     auth · home · attendance · permit · notification · profile
└── utils/        my_http_overrides.dart (menunggu R-02) · notification/ (Fase 7)
```

Enam fitur, masing-masing `data/{models,repositories,services}` +
`presentation/{bindings,controllers,routes,views,widgets}`. 22 route dipatok oleh
test verbatim karena string-nya dipakai payload FCM.

| Sudah jadi dan terbukti | Belum |
|---|---|
| `ApiClient` tunggal, origin di-resolve per request, 401 → sesi berakhir | Fase 7 platform services (FCM iOS, background handler) |
| `ServerConfig` + `TenantContext` + header `X-Tenant` (ADR-0005) | Fase 8 testing, Fase 9 dokumentasi |
| Token di keychain/EncryptedSharedPreferences, mirror `GetStorage` **sudah mati** | Offline cache apa pun — belum ada sama sekali |
| `BootPipeline` dengan klasifikasi fatal/optional per langkah | Entitlement, feature flag, persona switching |
| `AppLogger` dengan redaksi token/password/NIP/FCM | Deep link `app://` — belum ada handler |
| Route ↔ binding diuji, `ignore_for_file` nol di `lib/` | Step-up auth, screenshot protection |

Enam fitur itu memetakan ke ESS: `home`, `attendance`, `permit` (= leave),
`profile`, `notification`, `auth`. **Tidak ada** schedule, overtime, pay, requests,
inbox/approvals, documents, skills, learning, performance, team, atau AI.

## 0.4 Satu kontradiksi yang harus diputuskan sebelum apa pun dibangun — M-D1

Repositori ini memberi **dua jawaban berbeda** untuk pertanyaan yang sama: di
namespace mana self-service dilayani?

| Sumber | Jawaban |
|---|---|
| ADR-0006 + `docs/refactoring/06-api-migration-map.md` | `/api/v1` — 24 endpoint sudah dipetakan ke sana |
| `lib/core/config/env.dart` (kode yang berjalan) | `/api/selfservice` — nilai default `Env.apiPrefix` |
| `tenancy-app/routes/api.php` (kenyataan server) | **`/api/selfservice` tidak ada**, dan 18 dari 24 endpoint belum ada di `/api/v1` |

Instruksi owner pada Fase 4 adalah "path tidak lagi menyebut layout modul
backend". **Kedua opsi memenuhi instruksi itu** — `/api/v1/permits` sama tidak
menyebut `hris-module` seperti `/api/selfservice/permits`.

**Rekomendasi: satu permukaan, `/api/v1`.** Alasannya bukan estetika:

- tenancy, guard, rate limiter, penamaan route, dan versioning sudah terpasang di
  grup `v1`; namespace kedua menduplikasi semuanya dan menjadi tempat kedua untuk
  salah — terutama urutan middleware tenancy-sebelum-Sanctum yang menjadi syarat
  keamanan, bukan preferensi;
- `esas_attendance` sudah di `/api/v1`: dua client, satu kontrak auth, satu
  siklus token;
- biaya pindah di sisi Flutter adalah **satu konstanta**, dan itu memang alasan
  lapisan konfigurasi dibangun.

Bila owner tetap memilih `/api/selfservice`, yang berubah hanyalah prefix; seluruh
Lampiran B berlaku apa adanya. Yang tidak boleh terjadi adalah **keduanya hidup**.

> **M-D1 — status OPEN. Pemilik keputusan: owner. Memblokir Lampiran B dan Gate B.**

## 0.5 Empat asumsi versi sebelumnya yang ternyata sudah dijawab backend

1. **Geofence tidak perlu ikut payload login.** `GET /attendance/context` sudah
   mengirim `location.required`, `latitude`, `longitude`, `radius_metres`, plus
   `server_time`, `schedule.crosses_midnight`, `next_presence`,
   `attendance_enabled`, dan `face_enrolled`. Gap **G-1 tinggal separuh**: yang
   tersisa kebutuhan layar profil, bukan kebutuhan clock.
2. **Department check bukan tanggung jawab client.** `QrPresenceController::redeem`
   memeriksa departemen, kedaluwarsa, dan single-use di server. Cek di client
   adalah UX, bukan kontrol.
3. **Hari kerja sudah milik server.** `AttendanceDay` menyelesaikan clock ke hari
   **roster**, memenangkan shift lintas tengah malam yang sedang berjalan, dan
   meninggalkan baris yang lewat grace period. §14 tidak memerlukan logika lokal.
4. **Siklus push token sudah lengkap** — `push-tokens`, `push-tokens/forget`, dan
   `auth/logout` yang melepas handset. Kebocoran "handset yang logout tetap
   menerima notifikasi karyawan sebelumnya" tertutup begitu client memakainya.

Konsekuensi: **Gate A dan sebagian besar attendance dapat dikerjakan sekarang**,
tanpa menunggu 18 endpoint.

## 0.6 Gap nyata yang memblokir mobile

**A. 18 endpoint self-service belum ada.** Semuanya controller + resource di atas
model yang **sudah** ada — bukan domain yang harus dirancang. Kontraknya di
Lampiran B.

**B. Domain yang belum ada sama sekali di backend.** Layar untuknya tidak boleh
dijadwalkan sebelum module plan-nya selesai:

| Kebutuhan blueprint mobile | Kondisi backend | Module plan penopang |
|---|---|---|
| Overtime request | tidak ada tabel/model | `122-overtime` (Wave 2) |
| Schedule employee-facing | `UserTimeworkSchedule` ada; belum ada API | `118-scheduling-foundation` (Wave 2) |
| Payslip untuk karyawan | run payroll + `PayrollItem` ada; **publikasi ke karyawan belum** | `142-payslip` (Wave 4) |
| Expense, cash advance, travel, loan | tidak ada | `149`–`152` (Wave 5) |
| Documents, e-signature | `Documentation` hanya artikel panel | `129`, `197`, `198` |
| Approval generik multi-tier | hanya `PermitApprove`, khusus izin | `125-approval-engine` (Wave 3) |
| Skills, learning, performance, career | tidak ada | Wave 6 & Wave 8 |
| Helpdesk, knowledge base | tidak ada (`BugReport` bukan tiket) | `194`, `196` (Wave 8) |
| Entitlement / feature flag | tidak ada; `Tenant::DATA_SHAPE` mengunci 8 kunci kredensial | `217`, `227` (Wave 11) |
| Effective dating, audit engine, outbox | nol kolom, nol tabel | `100`, `101`, `104` (Wave 0) |

**C. Fondasi Wave 0 belum ada.** Tanpa audit engine dan outbox, klaim §102 (audit
setiap aksi sensitif) dan §99 (notifikasi event-driven) belum dapat dipenuhi:
notifikasi hari ini dikirim langsung dari kode domain, bukan dari domain event.

## 0.7 Risiko terbuka yang membatasi rollout

| ID | Risiko | Sisi | Dampak ke mobile |
|---|---|---|---|
| CRIT-01 | Keystore rilis ter-commit | client | Play App Signing belum dijawab; memblokir rilis publik |
| CRIT-02 / TEN-03 | Validasi TLS dimatikan global (`MyHttpOverrides`) | client | **Harus mati sebelum Gate A**; menunggu sertifikat wildcard |
| CRIT-05 | Token/PII pada log rilis | client | `AppLogger` siap; pemasangan di Fase 7 |
| HIGH-03 / HIGH-05 | iOS tak pernah mendaftarkan FCM token; background handler memakai plugin belum ter-init | client | Push iOS mati; Fase 7 |
| HIGH-08 | `com.example.esas` sebagai application id | client | Ditolak Play Store |
| G-2 | Device binding: satu akun satu handset, dilepas HR | backend | **Keputusan produk**, belum diambil untuk self-service |
| G-3 | Token abilities hanya `['attendance']` | backend | **Dugaan ini terbantah oleh observasi runtime 2026-09-03**: `announcements` dan `permits` berhasil pada token yang sama sementara `attendance/context` menjawab 403 — kebalikan dari yang diramalkan G-3. Penyebab 403 belum diketahui; sumber backend tidak tersedia. Lihat `docs/HOME_DASHBOARD.md` §8 |
| AUTHZ | `WorkspacePermissions::isEnforced()` fail-open pada workspace tanpa role | backend | Deny-by-default yang diasumsikan §84 belum berlaku |
| QR-DEPT | `redeem` meloloskan karyawan yang tidak punya departemen | backend | Fail-open kecil; harus fail-closed sebelum QR dibuka luas |
| LICENSE | Model wajah `buffalo_l` non-komersial | supports | Memblokir komersialisasi fitur wajah |

## 0.8 Konsekuensi untuk dokumen ini

1. **Ambisi tidak dipangkas.** Yang ditambahkan adalah status per capability dan
   modul backend yang menopangnya — Lampiran A.
2. **Urutan eksekusi diikat ke Wave**, menggantikan urutan v1.0 yang menjadwalkan
   Skills dan AI sebagai "fase 4–5" tanpa menyebut Wave 6 dan Wave 10.
3. **MVP-A dipersempit ke apa yang backend-nya nyata** (§126); sisanya pindah ke
   MVP-B.
4. **Mobile tidak boleh menjadi jalur bypass** terhadap workflow, rule, approval,
   atau domain service — dan tidak boleh menjadi tempat pertama sebuah aturan
   ditulis.

---

# 1. PRODUCT PURPOSE

Mobile Self-Service adalah employee operating interface untuk seluruh workforce.

Aplikasi tidak diposisikan hanya sebagai:

```text
absensi + cuti + slip gaji
```

tetapi sebagai:

```text
Employee Identity
+
Daily Work
+
Requests
+
Approvals
+
Schedule
+
Pay
+
Skills
+
Learning
+
Performance
+
Career
+
Employee Services
+
Workforce Operations
+
AI
```

dalam satu employee experience.

---

# 2. PRODUCT GOAL

Aplikasi harus memungkinkan mayoritas kebutuhan harian karyawan selesai tanpa:

- membuka HR back-office;
- menghubungi HR untuk pertanyaan sederhana;
- menggunakan spreadsheet;
- mengirim approval melalui WhatsApp;
- membuka banyak aplikasi perusahaan.

Target experience:

> kebutuhan rutin employee selesai dalam 1–3 taps apabila prosesnya sederhana.

---

# 3. NON-GOALS

Mobile Self-Service **bukan**:

- pengganti seluruh HR Admin desktop;
- payroll configuration tool;
- organization design tool;
- formula/rule builder;
- workflow designer;
- regulatory package editor;
- bulk import/export workstation;
- advanced report builder;
- tenant subscription administration.

Administrative complexity tetap berada di web/admin workspace.

---

# 4. CORE PRODUCT PRINCIPLES

## M01 — One Employee App

Tidak membuat aplikasi berbeda untuk:

- employee;
- manager;
- supervisor;
- approver;
- trainer;
- interviewer;
- executive.

Semua menggunakan aplikasi yang sama.

Capability berubah berdasarkan context.

---

## M02 — Persona-Aware

Mobile surface diturunkan dari:

```text
Persona
+
Entitlement
+
Permission
+
Organization Scope
+
Feature Flag
```

---

## M03 — Action First

Home tidak menjadi mini desktop dashboard.

Prioritas:

```text
Apa yang harus saya lakukan sekarang?
```

---

## M04 — 1–3 Tap Daily Actions

Target untuk:

- Clock In / Clock Out
- Leave
- Overtime
- Schedule
- Payslip
- Expense
- Approval

---

## M05 — Domain Services, Not Direct Data Writes

Mobile hanya berbicara dengan authorized application services/API.

Tidak boleh:

```text
mobile
→ direct database-like CRUD
```

Harus:

```text
mobile
→ API
→ authorization
→ application service
→ domain
→ audit/event
```

---

## M06 — Sensitive by Default

Data berikut diperlakukan sebagai high sensitivity:

- biometrics;
- salary;
- payslip;
- bank account;
- tax;
- BPJS;
- health/medical claims;
- employee relations;
- disciplinary information.

---

## M07 — Explain, Don’t Hide

Jika request gagal atau employee tidak eligible:

jangan hanya:

```text
Request rejected.
```

Tampilkan alasan yang aman:

```text
Tidak dapat mengajukan cuti karena saldo tidak mencukupi.
Saldo tersedia: 0,5 hari.
Kebutuhan: 1 hari.
```

---

## M08 — Deterministic Before AI

AI tidak menentukan eligibility.

Urutan:

```text
Rules
→ Eligibility
→ Permissions
→ Valid Data
→ AI explanation / recommendation
```

---

# 5. MOBILE PERSONAS

## P1 — Employee

Semua worker yang mempunyai mobile access.

Primary needs:

- clock;
- schedule;
- leave;
- overtime;
- payslip;
- requests;
- documents;
- personal data;
- learning;
- performance;
- help.

---

## P2 — Manager / People Manager

Employee dengan reporting responsibility.

Additional needs:

- team overview;
- absence;
- schedule;
- approvals;
- goals;
- performance;
- team skills;
- team requests.

---

## P3 — Frontline / Plant Worker

Needs:

- very fast attendance;
- next shift;
- assigned line/crew;
- overtime;
- open shift;
- qualification status;
- mandatory training;
- announcements.

---

## P4 — Supervisor / Shift Leader

Additional needs:

- crew attendance;
- shift coverage;
- replacements;
- line assignment visibility;
- skill/certification gaps;
- overtime requests/assignment;
- exceptions.

---

## P5 — Approver

Role may be manager, finance, HR, director, etc.

Needs:

- unified approval inbox;
- context;
- supporting document;
- approve/reject/comment;
- delegation visibility.

---

## P6 — Interviewer

Needs:

- interview schedule;
- candidate summary;
- scorecard;
- feedback submission.

Sensitive recruitment fields remain scope-controlled.

---

## P7 — Trainer / Assessor

Needs:

- class list;
- attendance;
- assessment;
- skill/certification validation where authorized.

---

## P8 — Executive

Mobile needs are intentionally narrow:

- executive workforce snapshot;
- attention items;
- critical approvals;
- high-level trends.

No administrative task clutter.

---

# 6. APPLICATION INFORMATION ARCHITECTURE

Bottom navigation is fixed at a maximum of five:

```text
┌────────┬────────┬──────────┬────────┬─────────┐
│ Home   │ Work   │ Requests │ Inbox  │ Profile │
└────────┴────────┴──────────┴────────┴─────────┘
```

Global AI action:

```text
Floating / Global AI Action
```

AI only appears if entitled + permitted.

---

# 7. NAVIGATION RULE

Navigation visibility:

```text
CanSee(feature)
=
Entitlement
AND Permission
AND Persona Relevance
AND Org Scope
AND Feature Flag
```

Navigation is **not** security.

API must independently authorize every request.

---

# 8. HOME

Home answers:

```text
What do I need now?
What changed?
What is next?
```

## Employee Home

Components:

1. Greeting + current work status
2. Clock In / Clock Out primary CTA
3. Next shift
4. Attendance status today
5. Quick actions
6. Pending requests
7. Approval/task summary if applicable
8. Payslip/new document notification
9. Training/certification alert
10. Announcement
11. Birthday/work anniversary optional
12. AI shortcut if enabled

### Quick Actions

Maximum first row:

```text
Clock
Leave
Overtime
Expense
Payslip
Schedule
```

User may personalize secondary shortcuts later.

---

# 9. MANAGER HOME

Additional cards:

- Team present today
- Absent
- Late
- On leave
- Upcoming shifts
- Pending approvals
- Coverage warning
- Certification expiry
- Pending performance task
- Hiring interview task
- Team request exceptions

Home must answer:

```text
What needs my attention?
Who is absent?
Where is coverage low?
What needs approval?
```

---

# 10. SUPERVISOR / PLANT HOME

Priority cards:

1. Current shift
2. Crew attendance
3. Planned vs present workers
4. Line assignments
5. Shortage
6. Replacement recommendations
7. Overtime
8. Qualification warning
9. Safety/training expiry
10. Production manpower alert

---

# 11. WORK HUB

`Work` contains work-related features.

Dynamic sections:

```text
Today
Time & Attendance
Schedule
Team
Workforce
Performance
Learning
Skills
Pay
```

Not every employee sees every section.

---

# 12. ATTENDANCE MODULE

## Screens

```text
Attendance Home
Attendance Action
Attendance History
Attendance Detail
Attendance Exception
Correction Request
Face Enrollment
Attendance Consent
Attendance Device Status
```

## Attendance Home

Displays:

- today shift;
- scheduled start/end;
- current status;
- last clock;
- clock CTA;
- work location;
- clock method available;
- exception/warning.

---

# 13. CLOCK IN FLOW

```text
Open Home
↓
Tap Clock In
↓
Fetch trusted server time / challenge
↓
Evaluate allowed attendance method
↓
Location/device/biometric checks
↓
User confirms
↓
Server validates
↓
AttendanceRecorded
↓
Success receipt
```

Success screen shows:

- timestamp;
- attendance method;
- location label;
- scheduled shift;
- request ID/reference.

---

# 14. CLOCK OUT FLOW

Clock-out must close the actual open attendance row associated with the correct roster day.

This is especially critical for:

```text
cross-midnight shift
```

Example:

```text
Shift:
22:00 → 06:00

Clock Out:
05:55 next calendar day

Attendance day:
previous roster day
```

Mobile should not derive this logic locally.

Server is source of truth.

---

# 15. ATTENDANCE METHODS

Metode yang **benar-benar ada** di backend hari ini, dan siapa pemakainya:

| Metode | Endpoint | Pemakai | Status di aplikasi ini |
|---|---|---|---|
| Face (handset) | `POST /attendance/face/challenge` → `/attendance/face` | karyawan | ⬜ belum diimplementasi |
| QR dari mesin | `POST /attendance/qr` | karyawan | 🟨 client punya scanner; endpoint belum dipakai |
| QR presence departemen | `POST /qr-presences/redeem` | karyawan | 🟨 idem |
| Terbitkan QR presence | `GET /qr-presences/context` → `POST /qr-presences` | pemegang permission `qr presences` | ⬜ |
| Face / QR kiosk | `kiosk/*` | mesin absensi | ✖ milik `esas_attendance` |

Dua saklar menentukan apa yang tampil, dan keduanya **dibaca dari server, bukan
ditebak client**:

- `settings` per perusahaan menyalakan face dan/atau QR; workspace yang belum
  pernah membuka form itu mendapat keduanya;
- `attendance/context` mengembalikan `attendance_enabled`, `face_enrolled`,
  `can_issue_qr`, `next_presence`, dan `location.required`.

> **Aturan UI:** tombol yang hanya bisa gagal lebih buruk daripada tidak ada
> tombol. Setiap kondisi di atas sudah dijawab server sebelum layar digambar —
> aplikasi menjelaskan ketiadaannya, bukan menawarkan aksi yang pasti ditolak.

Dua penolakan di luar wajah itu sendiri, dan keduanya harus punya teks sendiri:
`attendance_disabled` (flag `is_attendance` mati) dan `outside_geofence` /
`location_required` (perusahaan menetapkan `radius`).

---

# 16. FACE ATTENDANCE FLOW

Alurnya **tiga permintaan, dan sengaja bukan satu** — persis seperti yang sudah
berjalan di `esas_attendance`:

```text
1. POST /attendance/face/challenge   server menerbitkan daftar gestur acak,
                                     bertanda tangan HMAC, sekali pakai
2. (di perangkat)                    perekaman sambil melakukan gestur,
                                     atestasi ML Kit di sisi client
3. POST /attendance/face             klip + token challenge → dinilai → dicatat
```

Urutan itu adalah kontrol keamanannya: aksi diterbitkan **setelah** orangnya
meminta clock, sehingga rekaman yang dibuat sebelumnya tidak menjawabnya.

Yang **sudah dikerjakan server** dan tidak boleh diduplikasi di client:

- `challenge_id` unik dan barisnya ditulis **sebelum** layanan penilaian dipanggil
  — dua permintaan yang berlomba pada satu rekaman tidak bisa dua-duanya lolos;
- id diambil dari token yang ditandatangani, bukan dari body permintaan;
- `inconclusive` diantrekan ke *Kehadiran → Verifikasi wajah* untuk ditinjau HR,
  tidak ditolak otomatis; skor tidak pernah ditulis ulang;
- retensi: klip dibuang setelah dinilai kecuali `HRMS_FACE_KEEP_VIDEO`, frame
  disimpan sampai `HRMS_FACE_MEDIA_RETENTION_DAYS`.

Pendaftaran wajah (lima foto referensi + consent) dilakukan **HR di panel**
(*Karyawan → Pendaftaran wajah*), bukan di aplikasi ini. Selama belum terdaftar,
`face_enrolled: false` dan aplikasi mengatakannya di muka.

## Mandatory UX

Sebelum consent maupun sebelum perekaman pertama, tampilkan:

- alasan biometrik dipakai;
- data apa yang diproses dan siapa yang dapat melihatnya;
- retensi (klip vs frame vs baris verifikasi);
- status consent dan cara menariknya;
- tautan kebijakan privasi.

Data biometrik adalah data pribadi spesifik di bawah **UU PDP 27/2022**; consent
tercatat di `hrms_user_face_references` dan enrolment tanpa consent tidak dapat
dipakai.

> **Risiko komersial yang belum selesai:** model `buffalo_l` yang dipakai layanan
> `supports` berlisensi non-komersial. Ini harus diselesaikan sebelum monetisasi
> fitur wajah, bukan sesudah — lihat §0.7.

---

# 17. ATTENDANCE CORRECTION

**Status: rancangan. Tidak ada penopang backend hari ini.**

Tidak ada tabel koreksi, tidak ada state machine koreksi, dan tidak ada approval
engine generik — `PermitApprove` melayani izin, bukan koreksi absensi. Modul yang
menopangnya adalah `120-attendance-policy` dan `125-approval-engine` (Wave 2–3).

Ketika dibangun, bentuknya:

```text
Attendance Detail
↓
Report Problem
↓
Pilih alasan
↓
Isi waktu/data yang benar
↓
Lampirkan bukti bila policy meminta
↓
Submit
↓
Approval
↓
AttendanceCorrected
```

Dua aturan yang tidak boleh dilanggar implementasi apa pun:

1. **Baris asli tetap dapat ditelusuri.** Koreksi adalah catatan baru dengan
   alasan dan penyetuju, bukan `UPDATE` di tempat.
2. **Mobile tidak pernah menimpa histori absensi secara diam-diam.** Yang dikirim
   aplikasi adalah *permintaan*, bukan hasil.

Sampai audit engine (`101-audit-engine`) ada, koreksi tidak boleh dirilis: koreksi
tanpa jejak tak terbantahkan justru menghapus nilai bukti dari absensi itu sendiri.

---

# 18. ATTENDANCE HISTORY

Filters:

- week;
- month;
- status;
- exception.

Each row:

```text
Date
Shift
Clock In
Clock Out
Status
Exception
```

Detailed calculation explanations remain server-driven.

---

# 19. SCHEDULE MODULE

Screens:

```text
My Schedule
Schedule Detail
Calendar View
Shift Detail
Roster
Open Shift
Shift Swap
Shift Bid
Availability
```

Features surface based on workforce entitlement.

---

# 20. MY SCHEDULE

Views:

- Today
- Week
- Calendar

Each shift displays:

- date;
- start/end;
- location;
- plant/site;
- team/crew;
- position/role;
- assigned line if applicable.

---

# 21. OPEN SHIFT

If Workforce Advanced Scheduling enabled:

```text
Open Shift
↓
Eligibility evaluated server-side
↓
Employee sees only eligible opportunities
↓
Bid / Accept depending policy
↓
Approval/auto assignment
↓
Schedule updated
```

Employee cannot bypass:

- skill;
- certification;
- fatigue;
- conflict;
- location;
- policy.

---

# 22. SHIFT SWAP

Flow:

```text
My Shift
↓
Request Swap
↓
Eligible target shifts/workers
↓
Counterparty response if required
↓
Manager approval if required
↓
Schedule changed
```

Rule engine determines allowed flow.

---

# 23. AVAILABILITY

Employee can submit future availability only if tenant enables this capability.

Examples:

```text
Available
Unavailable
Preferred
```

Availability is not the same as leave.

---

# 24. LEAVE MODULE

Screens:

```text
Leave Overview
Leave Balances
Leave Request
Leave Detail
Leave Calendar
Team Leave Calendar (manager)
Leave History
```

---

# 25. LEAVE OVERVIEW

Displays ledger-derived balances.

Never treat one mutable balance field as source of truth.

Example:

```text
Annual Leave
Available    7 days
Pending      2 days
Used         3 days
Expiring     1 day
```

---

# 26. LEAVE REQUEST FLOW

```text
Select Leave Type
↓
Select Date/Duration
↓
Rule Evaluation
↓
Balance / Entitlement Preview
↓
Conflict Check
↓
Approver Preview
↓
Submit
↓
Workflow / Approval
↓
Result
```

Explain failure reasons.

---

# 27. OVERTIME MODULE

Screens:

```text
Overtime Overview
Overtime Request
Assigned Overtime
Overtime Detail
Overtime History
Manager Overtime
```

Flow supports:

```text
Plan
→ Request/Assignment
→ Approval
→ Schedule
→ Attendance
→ Actual
→ Payroll
```

---

# 28. OVERTIME REQUEST

Employee sees:

- date;
- proposed start/end;
- reason;
- calculated planned hours;
- policy warning;
- approver path.

Actual paid overtime remains based on approved business rule + actual data, not employee-entered number alone.

---

# 29. PAY MODULE

Employee-facing pay screens:

```text
Payslips
Payslip Detail
Explain Pay
Payroll History
THR
Final Pay
Loan Deductions
Total Rewards (future)
```

Only entitled features appear.

---

# 30. PAYSLIP LIST

Displays:

- period;
- run type;
- net pay;
- publication date;
- status.

Run types:

```text
Regular
THR
Off-Cycle
Final Pay
Bonus
Correction
```

---

# 31. PAYSLIP DETAIL

Example:

```text
Basic Salary
Fixed Allowance
Overtime
Incentive
----------------
Gross

Attendance Deduction
BPJS
PPh21
Loan
Adjustment
----------------
Net Pay
```

Payslip reads a published payroll result.

It does not recalculate.

---

# 32. EXPLAIN PAY

If Calculation Trace enabled:

Employee can tap a component.

Example:

```text
Overtime
Rp450.000
```

Then show safe explanation:

```text
Approved overtime hours: X
Rate/formula version: V
Payroll period: P
Result: Rp450.000
```

Do not expose admin-only formula internals if field permission denies it.

---

# 33. REQUESTS HUB

Request categories:

```text
Time
Finance
HR Services
Travel
Documents
Profile/Data Changes
```

Potential requests:

- Leave
- Overtime
- Attendance Correction
- Expense
- Reimbursement
- Cash Advance
- Travel
- Employee Loan
- HR Request
- Letter Request
- Document Request
- Data Change
- Employment Verification
- Facility Request

---

# 34. GENERIC REQUEST PATTERN

Reusable mobile UX:

```text
Select Request
↓
Context-aware Form
↓
Validation
↓
Policy Preview
↓
Approver Preview
↓
Attachments
↓
Submit
↓
Track Status
```

All request types retain their own bounded context.

A generic UI does not mean generic business logic.

---

# 35. EXPENSE & REIMBURSEMENT

Screens:

```text
Expense List
New Expense
Receipt Capture
Expense Detail
Reimbursement Status
```

Flow:

```text
Capture receipt
↓
Add amount/category/date
↓
Policy validation
↓
Submit
↓
Approval
↓
Settlement
↓
Reimbursement
```

---

# 36. CASH ADVANCE

Screens:

- Advance request
- Approved advance
- Settlement
- Difference due/refund
- History

---

# 37. TRAVEL

Screens:

- Travel request
- Trip detail
- Allowance
- Expenses
- Settlement
- itinerary/integration later

---

# 38. EMPLOYEE LOAN

Employee surface:

- request;
- agreement;
- approved amount;
- installments;
- outstanding;
- payroll deductions;
- settlement.

Sensitive details require re-authentication if configured.

---

# 39. INBOX

Unified Inbox:

```text
Approvals
Tasks
Notifications
Announcements
System Alerts
```

Optional future:

```text
HR Helpdesk conversation
```

---

# 40. APPROVAL INBOX

Cards show enough context to decide.

Not just:

```text
Alan requested leave.
```

Better:

```text
Alan
Annual Leave
12–13 Sep
2 days
Balance after approval: 5 days
Team coverage: OK
```

if manager is authorized to see that context.

---

# 41. APPROVAL DETAIL

Common controls:

```text
Approve
Reject
Request Information
Comment
```

depending policy.

High-impact approvals may require step-up authentication.

---

# 42. APPROVAL HISTORY

Shows:

- requester;
- workflow;
- current step;
- prior approvers;
- timestamps;
- comments;
- decision.

Sensitive internal rule details may be hidden.

---

# 43. TASKS

Examples:

- complete onboarding document;
- sign policy;
- finish mandatory training;
- submit performance review;
- validate interview scorecard;
- renew certification;
- settle cash advance.

Tasks originate from Workflow/Automation engines.

---

# 44. NOTIFICATION CENTER

Notification taxonomy:

```text
Action Required
Approved / Rejected
Reminder
Schedule Change
Pay
Learning
Certification
Company Announcement
Security
System
```

Deep-link directly to the relevant object.

---

# 45. PROFILE

Profile is employee-owned information + secure account settings.

Sections:

```text
Personal
Employment
Assignment
Contact
Emergency Contact
Dependents
Education
Experience
Bank
Tax
BPJS
Documents
Skills
Certifications
Privacy
Security
Settings
```

Some fields:

- editable directly;
- request-change only;
- read-only.

Policy determines behavior.

---

# 46. PERSONAL DATA CHANGE

Never let mobile directly edit sensitive workforce master data if approval is required.

Pattern:

```text
Current Value
↓
Request Change
↓
New Value
↓
Evidence
↓
Approval / Verification
↓
Effective-Dated Update
```

---

# 47. EMPLOYMENT PROFILE

Read-only employee view:

- legal entity;
- employment status;
- join date;
- employment type;
- contract;
- probation/confirmation;
- current assignment.

Historical timeline can be added after effective dating is stable.

---

# 48. EMPLOYEE TIMELINE

Future/after temporal model:

```text
Hired
Transferred
Promoted
Salary Change
Contract Renewal
Manager Change
Location Change
Exit/Rehire
```

Each item shows:

- effective date;
- change type;
- safe description.

---

# 49. BANK INFORMATION

Security:

- masked display by default;
- step-up auth for view/edit;
- change workflow;
- immutable audit;
- no sensitive value in notification content.

---

# 50. TAX & BPJS

Employee view:

- profile/status;
- identifiers masked when appropriate;
- program membership;
- safe payroll-relevant information.

Regulatory configuration remains admin-side.

---

# 51. DOCUMENTS

Screens:

```text
My Documents
Document Detail
Expiring Documents
Generated Letters
Payslips
Contracts
Certificates
```

Actions:

- view;
- download;
- acknowledge;
- sign;
- request renewal/update.

---

# 52. E-SIGNATURE

Pattern:

```text
Document
↓
Review
↓
Identity / re-auth
↓
Sign through provider adapter
↓
Signature evidence
↓
DocumentSigned
```

Mobile must not bind domain to one provider.

---

# 53. HR HELPDESK

Screens:

```text
Help Home
New Ticket
My Tickets
Ticket Detail
Knowledge Suggestions
```

Before submitting ticket, system may suggest knowledge articles.

---

# 54. KNOWLEDGE BASE

Employee-facing:

- policy;
- FAQ;
- SOP;
- benefits;
- payroll guides;
- attendance guides;
- company information.

Articles are audience-scoped.

---

# 55. SKILLS

Employee screens:

```text
My Skills
Skill Detail
Evidence
Validation Status
Skill Gap
Recommended Learning
```

Employee may:

- view;
- self-declare where policy allows;
- attach evidence;
- request validation.

Official skill state belongs to Skills context.

---

# 56. CERTIFICATION

Screens:

```text
My Certifications
Certification Detail
Upload/Renew
Expiry
Required Certifications
```

Alerts:

- expiring soon;
- expired;
- blocks assignment if hard requirement.

---

# 57. QUALIFICATION

Employee sees operational qualification:

```text
Qualified
Pending
Expired
Not Qualified
```

Example:

```text
Filling Machine A Operator
Status: Qualified
Valid until: 30 Nov
```

Do not expose sensitive evaluation internals unnecessarily.

---

# 58. LEARNING

Screens:

```text
Learning Home
My Learning
Course Catalog
Course Detail
Learning Path
Training Calendar
Class Detail
Quiz/Exam
Certificate
```

---

# 59. MANDATORY TRAINING

Home can surface:

```text
Action Required
Safety Training expires in 7 days.
```

Training completion emits event.

Skills domain decides resulting skill/certification.

---

# 60. PERFORMANCE

Employee screens:

```text
My Goals
Goal Detail
Performance Cycle
Self Review
Feedback
1-on-1
Review Result
Development Plan
```

Manager gets additional team views.

---

# 61. GOALS

Features:

- KPI;
- OKR;
- goal progress;
- evidence;
- check-in;
- comments.

Goal formula/calculation remains server-side.

---

# 62. PERFORMANCE REVIEW

Employee flow:

```text
Review Opened
↓
Self Review
↓
Manager Review
↓
Calibration
↓
Finalized
↓
Employee View
```

Only relevant stages surface to employee.

---

# 63. FEEDBACK & 1-ON-1

Mobile actions:

- give feedback;
- request feedback;
- view permitted feedback;
- create 1-on-1 agenda;
- action items.

Confidentiality rules apply.

---

# 64. CAREER

Employee surface:

```text
Career Path
Target Role
Readiness
Skill Gaps
Development Plan
Suggested Learning
```

Succession nomination may remain hidden depending policy.

---

# 65. INTERNAL OPPORTUNITIES

This is a **future product extension**, not explicitly defined as a current blueprint capability.

Potential surface:

```text
Internal Jobs
Projects
Open Shifts
Cross-Training
```

Only implement after corresponding domain ownership is defined.

---

# 66. ENGAGEMENT

Screens:

```text
Surveys
Pulse
eNPS
Recognition
Rewards
Suggestions
Company News
Announcements
```

Survey anonymity must be explicit.

---

# 67. RECOGNITION

Employee can:

- give recognition;
- receive recognition;
- view allowed recognition feed;
- nominate rewards if enabled.

---

# 68. EMPLOYEE RELATIONS

Do **not** expose full ER administration on employee mobile.

Potential employee surface:

```text
Raise confidential concern
View own case status
Provide requested evidence
```

Only if privacy/legal design has been approved.

---

# 69. RECRUITMENT — EMPLOYEE-SIDE CAPABILITY

For regular employee:

- internal referral;
- interview tasks if interviewer;
- hiring approval if approver.

Internal job marketplace is future unless separately specified.

---

# 70. INTERVIEWER MODE

Screens:

```text
Upcoming Interviews
Candidate Brief
Interview Guide
Scorecard
Submit Feedback
```

Candidate data is restricted by recruitment scope.

---

# 71. MANAGER — MY TEAM

Screens:

```text
Team Overview
Team Member
Team Attendance
Team Schedule
Team Leave
Team Overtime
Team Goals
Team Skills
Team Learning
Team Documents — limited
```

Manager never automatically gains payroll access.

---

# 72. TEAM MEMBER VIEW

Manager sees only authorized fields.

Possible:

- role;
- assignment;
- attendance;
- schedule;
- leave;
- goals;
- skills;
- certification.

Salary remains separately controlled.

---

# 73. WORKFORCE COVERAGE

For authorized supervisor/manager:

```text
Required: 12
Scheduled: 12
Present: 10
Shortage: 2
```

Then:

```text
Find Replacement
```

---

# 74. REPLACEMENT MOBILE FLOW

```text
Coverage Shortage
↓
Find Replacement
↓
Server runs:
availability
schedule conflict
skill
certification
location
fatigue
working hours
↓
Eligible candidates
↓
Optional ranking/cost
↓
Supervisor selects/proposes
↓
Approval/assignment
```

AI may explain/rank **after** deterministic eligibility.

---

# 75. MANUFACTURING LINE ASSIGNMENT

Authorized supervisor view:

```text
Shift
↓
Production Line
↓
Required Roles
↓
Assigned Workers
↓
Qualification Status
```

Hard violation:

```text
BLOCK ASSIGNMENT
```

not merely a yellow warning.

---

# 76. CREW MATRIX MOBILE

Mobile should present a simplified matrix/card version.

Example:

```text
Alan
Filling    L3
Packing    L2
Machine A  Qualified
Safety     Valid
```

Desktop remains preferred for large matrix analysis.

---

# 77. EXECUTIVE MOBILE

Executive Home:

- headcount;
- labor cost;
- turnover;
- overtime;
- absence;
- capacity;
- critical skill coverage;
- workforce risk;
- open positions.

Avoid full admin navigation.

---

# 78. AI COPILOT

Global AI button if enabled.

Example employee questions:

```text
Berapa saldo cuti saya?
Kapan shift saya berikutnya?
Kenapa overtime saya bulan ini berbeda?
Apa training wajib saya yang belum selesai?
```

Manager:

```text
Siapa yang cuti besok?
Apakah Shift B kekurangan operator?
Siapa eligible untuk menggantikan Alan?
```

---

# 79. AI TOOL ARCHITECTURE

```text
Mobile
↓
AI Gateway
↓
Authorization
↓
Approved Tools
↓
Application Services
↓
Domain
```

No arbitrary SQL.

---

# 80. AI ACTION POLICY

AI may:

- query authorized data;
- summarize;
- explain;
- recommend;
- draft;
- simulate.

AI cannot autonomously:

- terminate employee;
- change salary;
- publish payroll;
- approve expense;
- reject candidate;
- issue discipline.

---

# 81. SEARCH

Global search may search only authorized resources.

Examples:

- knowledge article;
- own documents;
- own requests;
- employee directory if permitted;
- team members;
- course catalog.

Sensitive payroll data should not appear in generic search previews.

---

# 82. EMPLOYEE DIRECTORY

Optional based on tenant policy.

Fields:

- name;
- profile photo;
- job;
- department;
- work contact;
- location.

No private contact or personal data unless explicitly allowed.

---

# 83. ANNOUNCEMENTS & COMPANY NEWS

Features:

- targeted audience;
- read state;
- attachments;
- priority;
- deep links;
- expiry;
- mandatory acknowledgement where required.

---

# 84. MOBILE PERMISSION MODEL

Every API action evaluates:

```text
Authentication
↓
Tenant Context
↓
RBAC
↓
ABAC
↓
Organization Scope
↓
Record Scope
↓
Field Permission
```

Examples:

### Employee

```text
VIEW own payslip
VIEW own schedule
CREATE own leave request
```

### Manager

```text
VIEW team attendance
APPROVE team leave
```

### Supervisor

```text
VIEW assigned crew
MANAGE authorized shift assignment
```

### Payroll Admin

Mobile payroll admin capabilities are intentionally limited unless explicitly designed.

---

# 85. DATA OWNERSHIP

Mobile does not own domain data.

| Mobile Surface | System of Record |
|---|---|
| Profile | People / Employment |
| Schedule | Scheduling |
| Attendance | Attendance |
| Leave | Leave |
| Overtime | Overtime |
| Payslip | Payroll |
| Expenses | Expense |
| Skills | Skills |
| Certifications | Skills/Qualification |
| Learning | Learning |
| Performance | Performance |
| Requests | Owning domain / workflow |
| Notifications | Notification Platform |
| Tasks | Workflow/Automation |
| AI | No SoR — governed consumer/action layer |

---

# 86. MOBILE API BOUNDARY

Penamaan ini **bukan lagi pertanyaan terbuka**. Backend sudah melayani `/api/v1`,
sudah dipakai satu client produksi, dan sudah memiliki hal-hal yang mahal untuk
diduplikasi:

```text
/api/v1
├── tenancy di-resolve sebelum routing (X-Tenant)   ← urutan ini syarat keamanan
├── guard terpisah: auth:sanctum vs auth:kiosk-device
├── rate limiter per-endpoint (login, face, qr, push)
└── versi dari baris pertama — APK yang sudah terpasang tidak bisa ikut deploy
```

Rekomendasi arsitektur: **self-service menempati `/api/v1` yang sama**, sebagai
kelompok resource baru — bukan namespace kedua. Keputusan formalnya M-D1 (§0.4)
dan masih menunggu owner.

Yang tidak berubah apa pun keputusannya:

> Kontrak mobile harus stabil dan **tidak boleh mencerminkan tabel**.
> `hrms_permits` adalah tabel; `leave-requests` adalah resource.

Aturan yang mengikat setiap endpoint baru:

1. **Versi ada di path**, dan penghapusan field adalah perubahan versi.
2. **Tenant tidak pernah datang dari body.** Ia datang dari routing/header
   tepercaya, dan token dari satu workspace tidak berarti apa pun di workspace lain.
3. **Tidak ada endpoint yang menulis tanpa melewati application service** — mobile
   bukan jalur pintas ke Eloquent.
4. **Setiap penolakan punya kode mesin**, bukan hanya kalimat Indonesia
   (`attendance_disabled`, `outside_geofence`, `device_mismatch`).

---

# 87. API RESOURCE GROUPS

Kelompok resource, dengan status nyata — inilah peta yang menggantikan daftar
konseptual v1.0:

| Group | Endpoint | Status | Penopang |
|---|---|---|---|
| `/workspace` | probe workspace | ✅ ada | — |
| `/auth` | login, me, logout | ✅ ada | — |
| `/auth/password` | ganti sandi | ⬜ 18-endpoint | `Settings/SecurityController` |
| `/attendance` | context, face, qr | ✅ ada | `AttendanceDay`, `Geofence` |
| `/attendances` | riwayat absensi | ⬜ 18-endpoint | `UserAttendance` |
| `/attendance/summary` | ringkasan bulanan | ⬜ 18-endpoint | `UserAttendance` |
| `/qr-presences` | terbit + redeem | ✅ ada | permission `qr presences` |
| `/push-tokens` | daftar + lepas | ✅ ada | `FcmModel` |
| `/announcements` | daftar, aktif, detail | ⬜ 18-endpoint | `Announcement` |
| `/notifications` | daftar, tandai dibaca | ⬜ 18-endpoint | tabel `notifications` |
| `/activities` | log aktivitas | ⬜ 18-endpoint | `ActivityLog` |
| `/bug-reports` | lapor masalah | ⬜ 18-endpoint | `BugReport` |
| `/permit-types`, `/permits` | jenis, daftar, form, ajukan, detail, approval | ⬜ 18-endpoint | `Permit`, `PermitApprove` |
| `/profile` | profil bersarang | ⬜ 18-endpoint | 8 tabel satelit karyawan |
| `/payroll` | komponen upah karyawan | ⬜ 18-endpoint | `PayrollItem`, `PayrollPeriod` |
| `/schedules` | jadwal karyawan | ⛔ Wave 2 | `118-scheduling-foundation` |
| `/overtime` | lembur | ⛔ Wave 2 | `122-overtime` |
| `/payslips` | slip gaji terbit | ⛔ Wave 4 | `142-payslip` |
| `/requests`, `/approvals`, `/tasks`, `/inbox` | permintaan generik | ⛔ Wave 3 | `125-approval-engine` |
| `/expenses`, `/travel`, `/loans` | keuangan karyawan | ⛔ Wave 5 | `149`–`152` |
| `/documents`, `/e-sign` | dokumen | ⛔ Wave 3/8 | `129`, `197`, `198` |
| `/skills`, `/certifications`, `/learning`, `/performance` | talenta | ⛔ Wave 6/8 | — |
| `/team`, `/workforce` | manager & manufaktur | ⛔ Wave 2/7 | `116-mss`, Wave 7 |
| `/ai` | copilot | ⛔ Wave 10 | `207-ai-gateway` |

✅ ada · ⬜ dipetakan, belum dibangun (Lampiran B) · ⛔ menunggu module plan.

---

# 88. BFF OPTION

**Rekomendasi saat ini: jangan.**

BFF terpisah dibenarkan ketika beberapa backend harus dijahit untuk satu layar.
Di sini backend-nya satu, dan lapisan yang diperlukan sudah ada bentuknya:
controller API di `app/Http/Controllers/Api` yang memanggil application service.

```text
Flutter App
    ↓ HTTP + X-Tenant + Bearer
/api/v1  (controller + resource, agregasi diperbolehkan)
    ↓
Application Services
    ↓
Domain Modules
```

Agregasi untuk Home (§89, §117) dibangun sebagai **satu controller** di dalam
`/api/v1`, bukan proses terpisah. Menambah proses berarti menambah deployment,
observability, dan tempat kedua untuk bug tenancy.

Revisit bila salah satu terjadi: layar mobile mulai memanggil lebih dari satu
sistem, atau backend dipecah menjadi service. Sampai itu terjadi, aturan lamanya
tetap: **tidak ada business rule di lapisan agregasi.**

---

# 89. API RESPONSE PRINCIPLE

Bentuk yang **sudah dipakai** hari ini adalah objek JSON polos, tanpa pembungkus
`data`, dan galat validasi memakai bentuk standar Laravel:

```jsonc
// 200
{ "token": "...", "user": { ... } }

// 422 — inilah yang membawa device_mismatch, kredensial salah, dsb.
{ "message": "...", "errors": { "identifier": ["..."] } }
```

Endpoint baru **mengikuti bentuk yang sudah ada** — konsistensi dengan client yang
sudah berjalan lebih berharga daripada envelope yang lebih rapi tetapi
memecah `esas_attendance`. Untuk koleksi, tambahkan paginasi Laravel standar
(`data`, `links`, `meta`).

Agregasi Home tetap boleh:

```json
{
  "work_status": {},
  "next_shift": {},
  "quick_actions": [],
  "attention_items": [],
  "pending_counts": {}
}
```

dengan satu syarat: **perhitungan tetap milik domain.** Home adalah pembaca, bukan
sumber kebenaran baru. Angka cuti tersisa di Home dan angka di layar cuti harus
berasal dari satu perhitungan yang sama, bukan dua.

---

# 90. MOBILE TENANT CONTEXT

Sudah terpasang di kedua sisi, dan bentuknya begini:

```text
Layar setup  →  GET /api/v1/workspace  (X-Tenant: acme)
                 ↓ nama workspace dikembalikan
        orang melihat perusahaan yang ia harapkan, bukan sekadar "OK"
                 ↓
        TenantContext.remember('acme')  → keychain
                 ↓
   setiap request: origin di-resolve per-request + header X-Tenant
```

Sisi client: `ServerConfig` (alamat server) dan `TenantContext` (workspace)
disimpan terpisah dari sesi, di secure storage. **Logout tidak menghapus
workspace** — keluar mengakhiri kredensial, bukan memindahkan handset ke
perusahaan lain.

Sisi server: token Sanctum hidup di database tenant itu sendiri. Karena itu
mengganti `X-Tenant` **tidak** membuka data tenant lain — token yang dicetak di
satu workspace tidak bernilai apa pun di workspace lain, dan permintaan tanpa
workspace ditolak tanpa fallback.

Dua mode yang keduanya didukung dan harus tetap didukung:

| Mode | Kapan | Bentuk |
|---|---|---|
| Header | alamat berupa IP/host tunggal, atau DNS wildcard belum ada | `http://host:8000` + `X-Tenant: acme` |
| Subdomain | produksi dengan wildcard DNS + TLS | `https://acme.hrms.example.com` + `X-Tenant` tetap dikirim |

> **TEN-03 masih terbuka:** selama `MyHttpOverrides` mematikan validasi TLS
> global, mode subdomain tidak boleh dinyatakan aman. Ini syarat Gate A.

---

# 91. MULTI-COMPANY / MULTI-EMPLOYMENT

**Belum ada penopangnya, dan jangan dirancang ke UI sekarang.**

Skema hari ini: satu `User` memiliki satu `company_id` dan satu `UserEmploye`
(unique pada `user_id`) — satu penugasan per orang, ditimpa di tempat. Model
kanonis `Person → Worker → Employment → Assignment` adalah ADR-002 yang masih
**terbuka**, dan effective dating (`100-effective-dating`) belum ada satu kolom pun.

Yang harus disiapkan sekarang hanyalah **bentuknya**, bukan layarnya:

- `GlobalEmployeeContext` (§141) menyimpan employment context sebagai objek, bukan
  sebagai field-field lepas di controller;
- semua permintaan sudah membawa workspace, sehingga penambahan employment context
  kelak adalah penambahan field, bukan pembongkaran.

Ketika multi-employment tiba: context switcher terkendali, dan **catatan sensitif
tidak pernah digabung antar konteks**.

---

# 92. AUTHENTICATION

Kontrak yang **berlaku hari ini**:

```jsonc
POST /api/v1/auth/login
{ "identifier": "1234 atau email", "password": "…", "device_id": "…" }
→ { "token": "…", "user": { id, name, nip, email, avatar, company,
                            departement, job_position,
                            attendance_enabled, face_enrolled } }
```

Yang sudah dijamin server, dan tidak boleh diulang atau dilemahkan client:

- **satu pesan** untuk "orang tidak ada" dan "sandi salah" — membedakannya
  mengubah endpoint ini menjadi alat enumerasi NIP;
- **waktu respons disamakan** untuk kedua kasus;
- `nip` **tidak unik** di skema acuan, jadi seluruh kandidat dicoba, bukan baris
  pertama;
- akun non-aktif ditolak dengan pesan tersendiri;
- **satu token per device**: login ulang di handset yang sama menggantikan token
  lama;
- batas laju per akun-dan-handset, dengan plafon lebih lebar per alamat sumber —
  karena satu kantor adalah satu NAT.

Tiga hal yang **belum** selesai dan berdampak langsung ke aplikasi ini:

| Gap | Isi | Keputusan |
|---|---|---|
| **G-2** | `device_id` mengikat akun ke satu handset; handset kedua ditolak sampai HR membebaskan | Produk. Wajar untuk kiosk absensi; belum tentu untuk karyawan yang membuka slip gaji dari ponsel cadangan |
| **G-3** | Token dicetak dengan abilities `['attendance']` | Backend. Setiap endpoint self-service akan ditolak sampai diperlebar |
| **G-1** | Payload `user` datar: tanpa `company.latitude/longitude`, `employee.departement_id`, `sign_date` | Sebagian sudah dijawab `attendance/context` (§0.5); sisanya dijawab `GET /profile` (Lampiran B) |

Belum ada dan perlu keputusan tersendiri: refresh token (Sanctum di sini
berumur panjang tanpa rotasi), MFA, biometric **local unlock** (berbeda dari face
attendance — yang satu membuka aplikasi, yang lain mencatat kehadiran), SSO, serta
daftar sesi/perangkat yang dapat dicabut sendiri oleh karyawan.

---

# 93. STEP-UP AUTHENTICATION

**Belum ada penopangnya di backend, dan itu memblokir tiga layar sekaligus.**

Aksi yang tidak boleh dirilis tanpa step-up:

- melihat/mengubah rekening bank;
- data pajak dan BPJS;
- e-sign;
- approval berdampak tinggi;
- pengaturan keamanan dan pemulihan akun.

Konsekuensi jadwal: **§49–§51 (Bank, Pajak & BPJS) tidak masuk MVP-A.** Tanpa
step-up dan tanpa field-level authorization, satu ponsel yang tidak terkunci sama
dengan akses penuh ke data finansial karyawan.

Bentuk yang direkomendasikan ketika dibangun: ulang-sandi atau biometrik lokal
menghasilkan **token aksi berumur pendek** yang diminta server untuk kelompok
endpoint sensitif — bukan sekadar dialog di client.

---

# 94. LOCAL DATA SECURITY

Yang **sudah** berlaku di aplikasi ini:

- token di `flutter_secure_storage` (Keychain / EncryptedSharedPreferences);
  mirror `GetStorage` sudah dimatikan dan instalasi lama dibersihkan saat upgrade;
- `AppLogger` meredaksi token, password, `Authorization`, NIP, dan FCM token;
  level debug/info dikompilasi keluar pada rilis;
- 18 `print` berisi PII di alur absensi sudah dihapus;
- `SessionRepository.clear()` menyebut setiap kunci, termasuk kunci legacy.

Yang **belum** dan menjadi syarat gate:

| Item | Status | Gate |
|---|---|---|
| Validasi TLS aktif (hapus bypass global) | ⛔ CRIT-02/TEN-03 | A |
| Redaksi terpasang di seluruh jalur log rilis | 🟨 CRIT-05, Fase 7 | A |
| Tidak ada cache slip gaji/bank/pajak dalam bentuk polos | ⬜ belum relevan — fiturnya belum ada | C |
| Screenshot protection untuk layar finansial | ⬜ keputusan produk | C |
| Hapus cache sensitif saat logout/ganti akun | 🟨 sesi sudah; cache domain belum ada | B |

Catatan yang mudah terlewat: **cache user record sengaja dipertahankan** saat
restore sesi — kehilangannya hanya berarti satu refresh, bukan sesi yang putus.

---

# 95. OFFLINE STRATEGY

**Hari ini tidak ada cache offline apa pun.** Setiap layar memanggil server.

Itu bukan kekurangan yang harus segera ditutup; ini keputusan yang harus diambil
sadar, karena offline pada absensi adalah masalah anti-fraud, bukan masalah UX.

## Cacheable read-only

- jadwal;
- pengumuman terbaru;
- knowledge base;
- ringkasan profil non-sensitif.

## Online-required by default

- aksi apa pun yang menyentuh payroll;
- approval;
- perubahan bank/pajak;
- absensi biometrik;
- clock yang harus berintegritas tinggi;
- pengiriman akhir sebuah permintaan.

> Antrean absensi offline **tidak boleh** diperkenalkan tanpa rancangan anti-fraud
> dan rekonsiliasi tersendiri. Waktu perangkat dapat diubah; `server_time` di
> `attendance/context` ada justru karena itu.

---

# 96. NETWORK RESILIENCE

Yang sudah ada di `core/network/`:

- satu `ApiClient`, timeout 30 detik, origin di-resolve per request. Kiriman absensi
  wajah diberi 75 detik, karena backend menunggu servis Face (hingga 10 + 45 detik)
  sebelum menjawab; tenggat yang lebih pendek berarti absensi tercatat tanpa ada
  yang menerima jawabannya;
- `ApiErrorMapper`: satu peta status → exception; **401 ≠ 403**, dan kegagalan
  transport bukan penolakan;
- 401 pada request terautentikasi → sesi berakhir **sekali**, terpusat. Sebelumnya
  tiga controller masing-masing menampilkan kalimatnya sendiri dan tidak satu pun
  mengakhiri sesi;
- restore sesi membedakan `authenticated` / `expired` / `offline` / `absent` —
  gangguan jaringan tidak lagi menghancurkan sesi (HIGH-02).

Yang masih harus ditambahkan per fitur: skeleton loading, retry yang tidak
menduplikasi write, state "pending" eksplisit, dan draf form yang tidak hilang.

---

# 97. IDEMPOTENCY

Server sudah menegakkan sekali-pakai untuk dua jalur paling berbahaya, **lewat
indeks unik, bukan lewat pemeriksaan**:

- `attendance_face_verifications.challenge_id` — barisnya ditulis sebelum layanan
  penilaian dipanggil;
- `qr_redemptions` — barisnya diklaim sebelum clock dicoba, sehingga dua permintaan
  yang berlomba pada satu kode tidak bisa dua-duanya lolos;
- satu baris absensi per orang per hari roster, dijamin transaksi + row lock +
  indeks unik.

Untuk write self-service yang belum ada, kontraknya ditetapkan sekarang supaya
tidak menjadi tambalan nanti: **`Idempotency-Key` wajib** pada pengajuan izin,
lembur, expense, keputusan approval, dan inisiasi e-sign. Ketukan ganda tidak
boleh menghasilkan dua permintaan cuti.

---

# 98. PUSH NOTIFICATIONS

Yang sudah berjalan:

```text
POST /api/v1/push-tokens          { token, platform }
POST /api/v1/push-tokens/forget   { token }
POST /api/v1/auth/logout          { fcm_token }   ← melepas handset ini saja
```

Satu proyek Firebase untuk seluruh tenant — dipaksa oleh kenyataan bahwa token FCM
dicetak terhadap proyek yang disebut `google-services.json` milik APK. Isolasi
tenant tidak melemah karenanya: pesan dialamatkan ke token, dan token hidup di
tabel `fcm_models` masing-masing tenant.

Registrasi dikunci pada **token, bukan orang** — ponsel yang diwariskan ke
karyawan pengganti melaporkan token yang sama, sehingga registrasi
*memindahkan*, bukan menambah pendengar kedua.

Deep link hari ini memakai **string route aplikasi** (22 path yang dipatok test),
bukan skema `app://` — payload FCM membawa path, dan instalasi yang diperbarui
saat navigasi tetap dapat menyelesaikan string yang sudah dipegangnya. Skema
`app://` di §121 adalah rancangan, dan menggantinya kelak adalah perubahan
berversi, bukan penggantian diam-diam.

Aturan isi: **teks push tidak memuat detail finansial atau personal.** "Slip gaji
Agustus tersedia", bukan nominalnya.

---

# 99. EVENT-DRIVEN MOBILE NOTIFICATION

Bentuk yang **diinginkan**:

```text
Domain Event → Outbox → Notification Rule → Template → Push/In-App → Deep Link
```

Bentuk yang **berlaku hari ini**: tiga notifikasi dikirim langsung dari kode
domain, tanpa event dan tanpa outbox (`104-domain-events-and-transactional-outbox`
masih Wave 0 dan belum dikerjakan):

| Kejadian | Yang mendengar |
|---|---|
| rantai izin sampai pada seseorang | peninjau itu saja — rantainya berurutan |
| rantai izin selesai | pengaju |
| pengumuman diterbitkan | orang di perusahaan itu |

Kegagalan dibedakan: perangkat yang dilaporkan `UNREGISTERED` dihapus barisnya,
perangkat yang gagal karena Firebase sedang mati tidak — menghapus token satu
workforce saat gangguan adalah cara push berhenti bekerja selamanya.

Event yang menyusul begitu outbox ada: `LeaveApproved`, `ShiftAssigned`,
`AttendanceCorrected`, `PayslipPublished`, `CertificationExpired`,
`TrainingAssigned`, `ApprovalRequested`.

---

# 100. PRIVACY

Data catalog classification applies equally to mobile.

High protection:

```text
Biometric
Health
Financial
Bank
Payroll
Tax
Employee Relations
```

For each feature define:

```text
Purpose
Legal Basis
Retention
Encryption
Access
Masking
Export
```

---

# 101. CONSENT CENTER

Profile > Privacy:

- biometric attendance consent;
- applicable data processing notices;
- consent history where legally/applicably required;
- privacy policy;
- device/data permissions;
- data request contact/process.

Consent model must not falsely imply every processing activity relies on consent.

---

# 102. AUDIT

Mobile-sensitive actions produce server-side audit.

Required context:

```text
WHO
WHAT
WHEN
WHERE
WHY
BEFORE
AFTER
SOURCE = MOBILE
REQUEST_ID
DEVICE/SESSION CONTEXT where appropriate
```

---

# 103. DEVICE CONTEXT

Sinyal perangkat yang **sudah** dikirim/dipakai hari ini:

| Sinyal | Dari | Dipakai untuk |
|---|---|---|
| `device_id` | `device_info_plus` saat login | Mengikat akun ke satu handset (G-2) |
| Push token + platform | FCM | Menyalakan notifikasi; dilepas saat logout |
| Atestasi ML Kit | perangkat, saat absensi wajah | Menandai rekaman yang gagal liveness di sisi client |
| Koordinat | `geolocator` | Geofence; server tetap yang memutuskan |
| Deteksi mock GPS | `LocationService` | Anti-fraud absensi |

Yang belum dikirim dan sebaiknya ada sebelum Gate B: versi aplikasi dan versi OS —
keduanya prasyarat force-update (§137) dan diagnosis lapangan.

Dua batas yang tidak boleh dilanggar:

1. **Sinyal perangkat menghormati prinsip privasi.** Dikumpulkan untuk tujuan yang
   dinyatakan, disimpan sependek mungkin, tidak dipakai untuk memprofil orang.
2. **Perangkat bukan identitas.** `device_id` menyempitkan siapa yang boleh masuk;
   yang menetapkan siapa orangnya tetap token, dan pada absensi wajah tetap
   wajahnya.

---

# 104. ERROR UX

Errors grouped:

## User-correctable

```text
Saldo cuti tidak cukup.
```

## Policy block

```text
Shift ini tidak dapat diambil karena waktu istirahat minimum belum terpenuhi.
```

## Permission

```text
Anda tidak memiliki akses ke data ini.
```

## System/integration

```text
Permintaan belum berhasil dikirim.
Coba lagi.
Reference: ABC123
```

Never expose stack traces.

---

# 105. ACCESSIBILITY

Minimum target:

- scalable text;
- proper contrast;
- screen-reader labels;
- large touch targets;
- not color-only status;
- clear error focus;
- Indonesian language clarity.

---

# 106. LOCALIZATION

Architecture-ready for:

- language;
- date format;
- time format;
- timezone;
- currency;
- number format;
- country-specific terminology.

Indonesia is first.

---

# 107. TIMEZONE

Server stores canonical timestamps.

Mobile displays according to authorized/company/user timezone rules.

Attendance must not trust device time as business truth.

---

# 108. DESIGN SYSTEM

Core mobile components:

- AppBar
- BottomNav
- ContextSwitcher
- QuickAction
- StatusCard
- SummaryCard
- Timeline
- ApprovalCard
- RequestCard
- EmployeeCard
- ShiftCard
- PayslipComponent
- MoneyRow
- SkillBadge
- CertificationBadge
- EmptyState
- ErrorState
- Skeleton
- BottomSheet
- Stepper
- SecureField
- AttachmentPicker
- Audit/History row

---

# 109. STATUS LANGUAGE

Use human language.

Avoid:

```text
APPROVAL_STATE_PENDING_L2
```

Display:

```text
Menunggu Persetujuan Finance
```

But retain technical state internally.

---

# 110. COLOR IS NOT STATE

Status requires text/icon, not only color.

Example:

```text
Approved ✓
Rejected ✕
Pending ⏱
```

---

# 111. FORM STANDARD

Every request form supports:

- draft;
- validation;
- attachment;
- policy helper;
- approver preview if allowed;
- submit confirmation;
- idempotent submit;
- error preservation.

---

# 112. ATTACHMENTS

Files must:

- validate type/size;
- malware scan server-side;
- classify sensitivity;
- use secure object storage;
- use authorized signed access;
- follow retention rules.

---

# 113. ANALYTICS — PRODUCT TELEMETRY

Track app experience without leaking sensitive content.

Examples:

- active users;
- feature adoption;
- clock success rate;
- request completion;
- form abandonment;
- approval turnaround;
- crash rate;
- API latency;
- push open;
- offline/error rate.

Do not log payroll values or sensitive form contents into product analytics.

---

# 114. BUSINESS METRICS

Employee mobile KPIs:

```text
ESS Adoption
Monthly Active Employee %
Clock Success Rate
Leave Self-Service Rate
Payslip Digital Access %
Request Processing Time
Approval Turnaround
HR Ticket Deflection
Training Completion
Mobile Crash-Free Sessions
```

---

# 115. TECHNICAL OBSERVABILITY

Every request should correlate:

```text
mobile_session_id
request_id
tenant_id
user_id
app_version
API route
domain operation
```

Sensitive values excluded.

---

# 116. PERFORMANCE TARGETS

Align platform targets:

- Core read API P95 ≤ ~400 ms target
- Core write API P95 ≤ ~700 ms target
- Online attendance ACK ~1 sec target

Mobile UX should not assume perfect network.

---

# 117. HOME AGGREGATION PERFORMANCE

Home should use one/few optimized aggregate endpoints, not 15 sequential API calls.

Example:

```text
GET /mobile/home
```

aggregates only authorized summary information.

---

# 118. MOBILE STATE MANAGEMENT

Lapisan yang **sudah berlaku** di `esas-selfservices`, dan sudah ditegakkan test
serta pemeriksaan layering:

```text
View (GetView, tanpa Get.put)
↓
Controller (GetxController, satu per layar)
↓
Repository            ← keputusan domain sisi client tinggal di sini
↓
ApiService            ← path saja, dari ApiRoutes
↓
ApiClient (satu)      ← origin per request, X-Tenant, 401 terpusat
↓
Secure storage / cache
```

Aturan yang sudah dipatok, bukan sekadar dianjurkan:

- `core/` tidak mengimpor `features/` maupun `app/`; `features/` tidak mengimpor
  `app/`;
- view tidak mendaftarkan controller-nya sendiri — binding yang melakukannya, dan
  pasangan route↔binding diuji;
- infrastruktur tidak menampilkan UI; controller boleh;
- `ignore_for_file` **nol** di seluruh `lib/`.

GetX dipertahankan secara sadar (ADR-0001): yang diperbaiki adalah cara
pemakaiannya, bukan pustakanya.

Business rule tetap milik server. Client boleh memvalidasi untuk UX; server selalu
memvalidasi ulang — dan pada absensi, server bahkan menentukan hari kerjanya.

---

# 119. FLUTTER FEATURE STRUCTURE

Struktur **nyata** hari ini, bukan usulan:

```text
lib/
├── main.dart                    12 baris: ensureInitialized → bootstrap() → runApp
├── bootstrap.dart               pipeline boot berurutan, fatal/optional per langkah
├── app/
│   ├── app.dart
│   ├── bindings/initial_binding.dart      satu composition root
│   └── routing/app_pages.dart             agregator; enam spread
├── core/
│   ├── boot/ config/ network/ services/ storage/ tenancy/ theme/ ui/ utils/
└── features/
    ├── auth/ home/ attendance/ permit/ notification/ profile/
    │   ├── data/{models,repositories,services}
    │   └── presentation/{bindings,controllers,routes,views,widgets}
```

Fitur yang **akan** ditambahkan mengikuti bentuk yang sama, satu direktori per
fitur, dan **hanya setelah** endpoint-nya ada:

```text
schedule · overtime · pay · requests · approvals · inbox · documents
expense · travel · loan · skills · certification · learning · performance
team · workforce · knowledge · ai
```

Tidak ada direktori `shared/`. Yang dipakai bersama tinggal di `core/ui/`,
`core/utils/`, `core/config/` — dan pemisahan itu yang membuat sebuah fitur dapat
dihapus bersama route-nya.

---

# 120. FEATURE MODULE CONTRACT

Setiap fitur wajib punya, dan inilah yang sudah dipenuhi enam fitur yang ada:

```text
features/<f>/
├── data/models/                fromJson lewat json_parsers (asInt/asString/asDate…)
├── data/services/              path dari ApiRoutes — tidak ada URL inline
├── data/repositories/          keputusan, cache, de-duplikasi
└── presentation/
    ├── routes/<f>_routes.dart  konstanta path — leaf, tanpa import
    ├── routes/<f>_pages.dart   GetPage + binding
    ├── bindings/               XView dibind XBinding (diuji)
    ├── controllers/            dispose setiap controller teks/scroll
    ├── views/                  GetView; tanpa Get.put
    └── widgets/
```

Ditambah, untuk fitur baru:

```text
permission guard      ← kemampuan dari server, bukan dari peran yang ditebak client
error mapping         ← kode mesin dari server → kalimat Indonesia di satu tempat
analytics events      ← §135
tests                 ← model, repository, dan matriks keputusan
```

Dua kegagalan nyata yang membuat kontrak ini ada: `/permit/create` pernah dibind
`PermitShowBinding` dan hanya bekerja karena route lain kebetulan masih hidup
(HIGH-01), dan cek departemen QR pernah **fail-open** karena `null == null`
(CRIT-04). Keduanya sekarang dijaga test, bukan ingatan.

---

# 121. DEEP LINK STANDARD

**Hari ini:** payload FCM membawa **string route aplikasi**, dan 22 path itu
dipatok test verbatim justru karena instalasi yang diperbarui di tengah navigasi
harus dapat menyelesaikan string yang sudah dipegangnya.

```text
/home · /home/announcement · /home/announcement/detail · /home/activity
/attendance · /attendance/list
/permit · /permit/list · /permit/show · /permit/create
/notification
/profile · /profile/personal · /profile/worked · /profile/family
/profile/education · /profile/experience · /profile/payroll
/profile/change-password · /profile/bug-report
/splash · /login
```

**Rancangan:** skema berbasis resource ketika deep link keluar dari push dan mulai
datang dari email/web:

```text
app://attendance/{id}   app://leave/{id}      app://approval/{id}
app://payslip/{id}      app://schedule/{id}   app://document/{id}
app://task/{id}
```

Dua aturan yang berlaku untuk keduanya:

1. **Otorisasi diperiksa ulang setelah layar dibuka.** Tautan bukan izin.
2. **Perubahan path adalah perubahan berversi**, karena payload lama masih hidup
   di ponsel dan di pusat notifikasi.

---

# 122. SCREEN INVENTORY — CORE EMPLOYEE

**Legenda:** ✅ sudah ada di `esas-selfservices` · 🟨 sebagian / menunggu endpoint ·
⬜ belum ada dan backend-nya sudah dipetakan · ⛔ menunggu module plan Wave berikutnya.

Dari 93 layar baseline, **22 sudah ada**. Itu bukan kekurangan — itu ukuran jarak
yang harus dipakai untuk menganggarkan, menggantikan kesan "tinggal menambah layar".

## Home
1. Home — ✅
2. Quick Actions — 🟨 (kartu ringkasan + aktivitas terakhir sudah ada; aksi cepat belum berbasis kapabilitas)
3. Attention Detail — ⬜

## Attendance
4. Attendance Home — ✅
5. Clock Action — 🟨 (pemindai QR ada; `attendance/qr` belum dipakai; wajah belum)
6. Attendance History — ✅
7. Attendance Detail — ✅ (bottom sheet)
8. Correction Request — ⛔ Wave 2/3 (§17)
9. Face Enrollment — ⛔ dilakukan HR di panel; keputusan produk bila ingin di mobile
10. Consent — ⛔ mengikuti §9

## Schedule — ⛔ Wave 2 (`118-scheduling-foundation`)
11. Schedule Calendar · 12. Shift Detail · 13. Open Shifts · 14. Shift Bid · 15. Shift Swap · 16. Availability

> Jadwal hari ini **sudah** tampil di Home dan di `attendance/context`; yang belum ada adalah modul jadwal sebagai layar tersendiri.

## Leave — dilayani fitur `permit`
17. Leave Overview — ✅
18. Leave Balances — ⬜ (butuh perhitungan saldo di domain, bukan di client)
19. New Leave — ✅
20. Leave Detail — ✅
21. Leave History — ✅
22. Leave Calendar — ⬜

## Overtime — ⛔ Wave 2 (`122-overtime`, belum ada tabel)
23. Overtime Overview · 24. New Overtime · 25. Assigned Overtime · 26. Overtime Detail · 27. Overtime History

## Pay — ⛔ Wave 4 (`142-payslip`)
28. Payslips · 29. Payslip Detail · 30. Explain Pay · 31. THR/Off-cycle Detail · 32. Loan Deduction

> `/profile/payroll` sudah ada dan menampilkan komponen upah dari payload profil — itu **bukan** slip gaji terbit, dan tidak boleh dinamai demikian di UI.

## Requests — ⛔ Wave 3 (`125-approval-engine`)
33. Requests Home · 34. Generic Request Form · 35. Request Detail · 36. Request History

## Expense — ⛔ Wave 5
37. Expense List · 38. New Expense · 39. Receipt Capture · 40. Expense Detail

## Travel / Advance / Loan — ⛔ Wave 5
41. Travel · 42. Travel Detail · 43. Cash Advance · 44. Settlement · 45. Loan Overview · 46. Loan Detail

## Inbox
47. Inbox — ⬜
48. Approval Detail — 🟨 (`permits/{id}/approval` dipetakan; inbox generik menunggu Wave 3)
49. Tasks — ⛔ Wave 3
50. Notification Detail — 🟨 (daftar notifikasi ✅; detail belum)
51. Announcements — ✅ (daftar + detail)

## Documents — ⛔ Wave 3/8
52. Documents · 53. Document Detail · 54. Sign Document

## Profile
55. Profile — ✅
56. Personal Data — ✅
57. Employment — ✅
58. Assignment — ⛔ butuh model kanonis (ADR-002) + effective dating
59. Emergency Contact — ⬜
60. Dependents — ✅ (keluarga)
61. Education — ✅
62. Experience — ✅
63. Bank — ⛔ butuh step-up (§93) + field-level authorization
64. Tax — ⛔ idem
65. BPJS — ⛔ idem
66. Security — ✅ (ganti sandi)
67. Privacy / Consent — ⬜
68. Settings — 🟨 (tema ada; preferensi notifikasi belum)

Ada satu layar yang **sudah ada tetapi tidak tercantum di baseline v1.0**:
**Bug Report** (`/profile/bug-report`, model `BugReport`). Ia dipertahankan dan
kelak menjadi jalan masuk ke Helpdesk (§53).

## Employee Services — ⛔ Wave 8
69. Help Center · 70. New Ticket · 71. Ticket Detail · 72. Knowledge Base · 73. Article Detail

## Skills/Learning — ⛔ Wave 6 & 8
74. My Skills · 75. Skill Detail · 76. Certifications · 77. Certification Detail · 78. Learning Home · 79. Course Detail · 80. Training Detail · 81. Quiz/Assessment

## Performance/Career — ⛔ Wave 8
82. Goals · 83. Goal Detail · 84. Performance Cycle · 85. Self Review · 86. Feedback · 87. 1-on-1 · 88. Development Plan · 89. Career Path

## Engagement
90. Surveys — ⛔ Wave 8 · 91. Survey Form — ⛔ · 92. Recognition — ⛔ · 93. Company News — ✅

Total baseline: **93 layar**, dengan visibilitas nyata ditentukan capability.
Terpasang hari ini: **22**.

---

# 123. SCREEN INVENTORY — MANAGER / SUPERVISOR EXTENSIONS

**Seluruhnya ⛔.** Tidak ada satu pun layar manajer di aplikasi ini hari ini, dan
penopangnya adalah `116-mss` (Wave 2) untuk 94–103 serta Wave 7 untuk 104–114.

94. My Team · 95. Team Member · 96. Team Attendance · 97. Team Schedule · 98. Team Leave · 99. Team Overtime · 100. Approval Queue · 101. Team Goals · 102. Team Performance · 103. Team Skills

104. Coverage · 105. Replacement Candidates · 106. Crew · 107. Crew Matrix · 108. Line Assignment · 109. Qualification Alert

110. Interview Schedule · 111. Candidate Brief · 112. Interview Scorecard — ⛔ Wave 8
113. Training Attendance · 114. Skill Validation — ⛔ Wave 8

> Persyaratan yang berlaku untuk **semua** layar di atas: organization scope datang
> dari server. Filter di layar bukan pembatas akses (§142).

---

# 124. GLOBAL SEARCH / AI / UTILITY

115. Global Search — ⬜
116. AI Copilot — ⛔ Wave 10 (`207-ai-gateway`)
117. Search Results — ⬜
118. QR Scanner — ✅ (`mobile_scanner`, di dalam fitur absensi)
119. Attachment Viewer — 🟨 (lampiran izin sudah diunggah; peninjau belum)
120. Context Switcher — ⛔ butuh multi-employment (§91)
121. Session / Devices — ⬜ (bergantung G-2; hari ini satu akun satu handset)
122. About / App Version — ⬜ **dan ini prasyarat force-update (§137)**

---

# 125. FEATURE VISIBILITY MATRIX

Matriks ini adalah **rancangan produk**, dan hari ini belum ada mekanisme yang
menegakkannya di mobile: aplikasi belum menerima daftar kapabilitas dari server
(§140), sehingga visibilitas masih ditentukan kode.

| Capability | Employee | Manager | Supervisor | Executive |
|---|:---:|:---:|:---:|:---:|
| Attendance | ✓ | ✓ | ✓ | optional |
| Schedule | ✓ | ✓ | ✓ | — |
| Leave | ✓ | ✓ | ✓ | — |
| Overtime | ✓ | ✓ | ✓ | analytics |
| Payslip | own | own | own | own |
| Approvals | if approver | ✓ | ✓ | critical |
| Team | — | ✓ | ✓ | — |
| Skills | own | team scope | crew scope | summary |
| Learning | own | team | crew | summary |
| Performance | own | team | team | summary |
| Workforce Coverage | — | optional | ✓ | summary |
| AI | entitlement | entitlement | entitlement | entitlement |

Peran yang **benar-benar ada** di database tenant hari ini adalah lima:
`super-admin`, `admin`, `hr-admin`, `manager`, `employee`. Persona di dokumen ini
(§5) lebih halus daripada itu — Supervisor, Approver, Interviewer, Trainer,
Executive belum punya padanan. Persona **tidak boleh** diturunkan client dari nama
peran; ia datang bersama daftar kapabilitas dari server.

> **Dua peringatan yang mengikat:**
>
> 1. **Menyembunyikan menu bukan keamanan.** Setiap endpoint tetap menolak sendiri.
> 2. **Otorisasi backend masih fail-open** pada workspace yang belum pernah
>    di-seed role (`WorkspacePermissions::isEnforced()`). Sampai
>    `102-authorization-hardening` selesai, matriks ini adalah niat, bukan kontrol
>    — dan itulah sebabnya ia menjadi syarat Gate A.

---

# 126. MVP-A MOBILE — OPERATIONAL ESS

MVP-A v1.0 memuat Schedule, Overtime, Inbox, Approvals, dan Documents. **Tidak satu
pun punya domain di backend hari ini**, jadi lingkupnya dipersempit ke yang
benar-benar dapat dikirim — bukan diperkecil ambisinya, melainkan dijadwalkan
ulang ke tempat yang benar.

**MVP-A (dapat dikerjakan dengan backend hari ini + 18 endpoint):**

```text
Authentication + Tenant Context         ✅ ada, tinggal dipasang ke Gate A
Attendance (context, QR, wajah)         ✅ endpoint ada
Home                                    ⬜ 3 endpoint
Profile (personal, employment, keluarga,
         pendidikan, pengalaman)        ⬜ 1 endpoint /profile
Leave / Permit (jenis, ajukan, daftar,
         detail, approval)              ⬜ 6 endpoint
Announcements                           ⬜ 3 endpoint
Notifications                           ⬜ 2 endpoint
Bug report                              ⬜ 1 endpoint
Ganti sandi                             ⬜ 1 endpoint
Push lifecycle penuh                    ✅ endpoint ada
Security & privacy dasar (TLS, redaksi,
         secure storage)                🟨 syarat Gate A
```

**Dipindahkan ke MVP-A′ (setelah Wave 2–3 backend):**

```text
Schedule Basic          ← 118-scheduling-foundation
Overtime Request        ← 122-overtime
Inbox + Approvals       ← 125-approval-engine
Documents Basic         ← 129-document-platform
ESS API sebagai kontrak resmi + audit  ← 101-audit-engine
```

Prinsipnya tidak berubah: **jangan menunggu seluruh modul HCM.** Yang berubah:
jangan pula menjanjikan layar yang domainnya belum ada.

---

# 127. MVP-B MOBILE — COMMERCIAL HRIS

Menambahkan, dan setiap baris punya prasyarat yang tidak bisa dilompati:

| Kemampuan | Prasyarat |
|---|---|
| Payslip | `142-payslip` — publikasi slip ke karyawan (hari ini payroll berhenti di panel) |
| THR | `138-thr` |
| Explain Pay Lite | `133-calculation-trace` — tanpa jejak perhitungan, "explain" hanyalah label |
| Bank / Tax / BPJS Profile | **step-up auth (§93) + field-level authorization** |
| Employee Requests | `195-employee-request` + Approval Engine |
| Expense / Reimbursement | `150-expense` |
| Helpdesk | `194-hr-helpdesk` (Bug Report menjadi jalan masuknya) |
| Knowledge Base | `196-knowledge-base` |
| E-Sign | `198-e-signature` + step-up |

> Tidak ada layar finansial yang dirilis sebelum field-level authorization ada.
> Kebocoran yang sudah tercatat di §0 blueprint induk — field gaji tergerbang di
> relation manager tetapi terbuka di tab Payroll form karyawan — adalah bukti
> bahwa ini kelas kesalahan yang benar-benar terjadi.

---

# 128. MVP-C MOBILE — MANUFACTURING PILOT

Irisan vertikal tipis, dan **seluruhnya bergantung Wave 6–7**:

```text
Current Shift          ← 118 / 161
Crew                   ← 165-crew-matrix
Line                   ← 167-line-assignment
Qualification          ← 156-qualification
Certification          ← 155-certification
Coverage               ← 159-workforce-supply
Replacement            ← 162-replacement-engine
Open Shift             ← 161-advanced-scheduling
Shift Swap/Bid         ← 161
Overtime               ← 122-overtime
```

North-star mobile:

> Supervisor membuka shift berjalan, melihat kekurangan 2 operator, menekan Find
> Replacement, dan menerima **hanya** pekerja yang lolos pemeriksaan deterministik
> atas skill, sertifikasi, jadwal, dan batas jam kerja.

Ini pembeda utama produk — dan justru karena itu ia tidak boleh didahulukan:
tanpa Skills Foundation (Wave 6) daftar kandidatnya adalah tebakan yang terlihat
meyakinkan.

---

# 129. PHASE 4 — TALENT MOBILE

Menambahkan, seluruhnya **Wave 8**, dan sebagian bergantung Wave 6:

```text
Goals · Performance · Feedback        ← 178, 179, 180
Learning                              ← 183–187
Skills · Certification                ← 154, 155  (Wave 6)
Development · Career                  ← 188, 190
Survey · Recognition                  ← 191, 192
```

---

# 130. PHASE 5 — INTELLIGENT MOBILE

Menambahkan, seluruhnya **Wave 10**, dan hanya setelah data serta rule
deterministik matang:

```text
AI Copilot                 ← 208
Payroll Explanation        ← 209 + 133-calculation-trace
Workforce Assistant        ← 210
Analytics Q&A              ← 212 + 200-semantic-metric-layer
Usulan aksi terkendali     ← 213
```

ADR-009 mengikat: **AI hanya bekerja lewat governed tools.** Hari ini belum ada AI
sama sekali di repositori mana pun — itu status, bukan kekurangan yang harus
segera ditutup.

---

# 131. RELEASE GATES

Setiap gate menyebut **siapa** yang harus menyelesaikan apa, karena sebagian besar
penghambatnya bukan di aplikasi ini.

## Mobile Gate A — Safe Identity

| Syarat | Pemilik | Status |
|---|---|---|
| Autentikasi + tenant isolation | mobile + backend | ✅ tersedia |
| **M-D1 namespace API diputuskan** | owner | ⛔ terbuka |
| Validasi TLS aktif (bypass global dihapus) | mobile + infra | ⛔ CRIT-02 / TEN-03 |
| Keystore & application id layak rilis | owner | ⛔ CRIT-01 / HIGH-08 |
| Redaksi log rilis terpasang | mobile | 🟨 CRIT-05 |
| Secure storage untuk kredensial | mobile | ✅ |
| Otorisasi fail-closed | backend | ⛔ `102-authorization-hardening` |
| Token abilities memadai (G-3) | backend | ⛔ |
| Kebijakan device binding diputuskan (G-2) | produk | ⛔ |
| Audit atas aksi sensitif | backend | ⛔ `101-audit-engine` |

## Mobile Gate B — Operational ESS

- 18 endpoint self-service ada dan berkontrak (Lampiran B);
- attendance, leave, notifikasi, pengumuman, profil berjalan end-to-end;
- pelacakan status permintaan;
- `Idempotency-Key` pada setiap write;
- schedule dan overtime **setelah** Wave 2.

## Mobile Gate C — Payroll Safe

- field-level authorization atas gaji/bank/pajak;
- step-up authentication (§93);
- publikasi payslip (`142-payslip`);
- sumber angka adalah hasil perhitungan domain, bukan hitungan client;
- audit atas setiap pembacaan data finansial.

## Mobile Gate D — Manufacturing

- skills, qualification, certification (Wave 6);
- scheduling lanjutan, fatigue, kelayakan replacement (Wave 7).

## Mobile Gate E — AI

- AI Gateway + kontrak tool berotorisasi;
- audit;
- semantic metrics / calculation trace untuk domain yang harus dijelaskan;
- **lisensi model** untuk setiap komponen yang dikomersialkan — termasuk
  penyelesaian lisensi model wajah yang sudah dipakai hari ini.

---

# 132. DEFINITION OF READY — MOBILE FEATURE

Feature cannot enter sprint without:

1. Business problem
2. Persona
3. User flow
4. Screen states
5. Domain owner
6. API contract
7. Permission
8. Error cases
9. Audit requirement
10. Privacy classification
11. Analytics event
12. Acceptance criteria

---

# 133. DEFINITION OF DONE — MOBILE FEATURE

Done requires:

- UI complete;
- API/domain integration complete;
- loading/empty/error states;
- authorization tests;
- tenant isolation tests;
- retry/idempotency behavior;
- offline behavior defined;
- accessibility review;
- analytics events;
- audit verified;
- security/privacy review;
- unit/widget/integration tests;
- device QA;
- documentation.

---

# 134. TEST STRATEGY

## Unit

- presentation/state logic;
- validation;
- permission presentation guard;
- formatting.

## Widget

- screen states;
- action visibility;
- errors;
- accessibility.

## Integration

- authentication;
- tenant context;
- clock in/out;
- leave submission;
- approval;
- payslip;
- file upload;
- push deep link.

## Domain-contract

Server tests remain authoritative for:

- eligibility;
- payroll;
- fatigue;
- effective dating;
- approval policy.

## Critical regression

- cross-midnight attendance;
- duplicate clock;
- duplicate request submit;
- tenant switching;
- revoked permission;
- expired session;
- biometric consent;
- push to unauthorized resource;
- employee transfer mid-request;
- payroll unpublished/locked states.

---

# 135. ANALYTICS EVENT NAMING

Example product telemetry:

```text
mobile_home_viewed
attendance_clock_started
attendance_clock_succeeded
attendance_clock_failed
leave_request_started
leave_request_submitted
approval_opened
approval_decided
payslip_viewed
learning_started
task_completed
```

Never include sensitive business values in telemetry names/properties.

---

# 136. VERSIONING & BACKWARD COMPATIBILITY

Mobile releases cannot be synchronized perfectly with backend deployment.

Therefore:

- API is versioned;
- additive changes preferred;
- server publishes minimum supported app version;
- graceful unsupported-feature response;
- feature flags control rollout.

---

# 137. FORCE UPDATE POLICY

Use only when necessary for:

- critical security;
- incompatible API;
- legal/compliance requirement.

Routine feature releases should not force-update without reason.

---

# 138. FEATURE FLAGS VS ENTITLEMENT

```text
Entitlement
= customer/company is commercially allowed to use capability.

Feature Flag
= technical rollout/control state.

Permission
= this user may perform action.

Persona
= UX relevance.

Org Scope
= data boundary.
```

All are separate.

---

# 139. APP STARTUP SEQUENCE

Urutan yang **sudah berjalan** di `bootstrap.dart`, dengan klasifikasi kegagalan
per langkah — bukan `try/catch` yang menelan segalanya seperti `main()` lama:

```text
WidgetsFlutterBinding.ensureInitialized()
↓
local storage            FATAL   — tema, sesi, dan cache user ada di sini
↓
server config + tenancy  opsional — jatuh ke seed yang dikompilasi
↓
Firebase                 opsional — push mati untuk sesi ini; aplikasi tetap jalan
↓
dependencies             FATAL   — kegagalan di sini adalah kesalahan programmer
↓
notifications            opsional — TIDAK digerbangi Firebase (ia yang meminta izin Android 13+)
↓
messaging                opsional — digerbangi Firebase + local notifications
↓
system UI                opsional — kosmetik
↓
runApp
```

Yang **belum** ada dan menjadi pekerjaan Gate A–B, disisipkan setelah tenancy:

```text
↓ restore sesi (three-way: authenticated / expired / offline / absent)   ✅ ada, di splash
↓ GET /bootstrap        entitlement · permission · persona · feature flag  ⬜ belum ada
↓ Home
```

Bootstrap harus ringkas dan aman untuk di-cache. Yang tidak boleh: menjadikannya
tempat mengirim master data sensitif hanya karena "sekalian".

---

# 140. APP BOOTSTRAP CONTRACT

Endpoint yang diusulkan — **belum ada di backend**, dan ia adalah prasyarat §125
serta §7 (navigasi yang dibangkitkan kapabilitas, bukan ditulis di client):

```jsonc
GET /api/v1/bootstrap
{
  "user": { },                    // identitas, bukan seluruh rekaman karyawan
  "employment_context": { },      // company, departement, position, atasan
  "tenant": { },                  // nama tampilan workspace, zona waktu, locale
  "persona": [ ],                 // employee | manager | approver | …
  "permissions": [ ],             // kapabilitas, bukan nama peran
  "entitlements": [ ],            // menunggu 217-entitlement (Wave 11)
  "feature_flags": { },           // menunggu 227-feature-flags
  "navigation_capabilities": [ ],
  "notification_count": 0,
  "app_policy": { }               // versi minimum, force update (§137)
}
```

Tiga aturan:

1. **Kapabilitas, bukan peran.** Client tidak boleh menyimpulkan "manager" lalu
   menampilkan menu; server yang menyebut apa yang boleh dilakukan.
2. **Jangan kirim master data sensitif saat startup.** Gaji, bank, dan pajak
   diambil saat layarnya dibuka, di belakang step-up.
3. **Cache boleh, kadaluarsa wajib.** Perubahan peran harus terasa tanpa
   pemasangan ulang aplikasi.

Sampai endpoint ini ada, `attendance_enabled`, `face_enrolled`, dan `can_issue_qr`
dari `attendance/context` adalah satu-satunya kapabilitas yang benar-benar datang
dari server — dan pola itulah yang diperluas, bukan diganti.

---

# 141. GLOBAL EMPLOYEE CONTEXT

Yang aplikasi ketahui hari ini: `user` (id, nama, NIP, email, avatar, perusahaan,
departemen, jabatan) plus workspace. Itu **datar**, dan sengaja: model kanonis
`Person → Worker → Employment → Assignment` (ADR-002) masih terbuka di backend dan
effective dating belum ada satu kolom pun.

Yang harus disiapkan sekarang adalah **bentuk**, supaya penambahannya kelak adalah
penambahan field:

```text
GlobalEmployeeContext
├── person            (kelak)
├── worker            (kelak)
├── employment        company · departement · position · effective range (kelak)
├── assignment        (kelak)
└── tenant            ✅ ada sekarang
```

Satu objek, dibaca semua fitur. Tidak ada fitur yang menyimpulkan identitas
sendiri dari payload yang kebetulan ia terima — itulah cara lima tab profil dulu
memanggil `/auth` lima kali untuk satu objek yang sama.

---

# 142. WORKSPACE CONTEXT

Untuk layar manajer/supervisor (⛔ Wave 2, `116-mss`), konteks tambahan:

```text
Organization Scope
Team Scope
Plant/Site Scope
Shift/Crew Scope
```

Aturannya satu, dan ia sudah dilanggar sekali di produk ini sehingga layak ditulis
tebal:

> **Scope tidak pernah diturunkan dari filter di layar.** Filter adalah kenyamanan;
> pembatas akses ada di server. Backend hari ini masih fail-open pada workspace
> tanpa role — sampai `102-authorization-hardening` selesai, tidak ada layar
> manajer yang boleh dirilis.

---

# 143. MANUFACTURING NORTH-STAR MOBILE JOURNEY

Scenario:

> Filling Line 3 membutuhkan 12 operator Shift B, tetapi hanya 10 eligible/present.

Flow:

```text
Supervisor Home
↓
Coverage Alert: Shortage 2
↓
Filling Line 3
↓
Required Roles
↓
Find Replacement
↓
Server checks:
- availability
- skill level
- certification
- safety training
- area authorization
- work-hour limit
- schedule conflict
↓
Eligible Candidates
↓
Rank / Compare
↓
Assign / Request OT / Open Shift
↓
Schedule updated
↓
Worker notified
```

This is the key mobile differentiation pilot.

---

# 144. PAYROLL NORTH-STAR MOBILE JOURNEY

Employee:

```text
Payslip
↓
Net Pay
↓
Explain
↓
Component changes
↓
Safe calculation explanation
```

Manager/payroll admin visibility remains separately permissioned.

---

# 145. AI NORTH-STAR MOBILE JOURNEY

Manager asks:

```text
Kenapa overtime Packaging naik?
```

AI:

1. checks authorization;
2. reads semantic metrics;
3. identifies drivers;
4. links absence/vacancy/skills/demand;
5. explains;
6. proposes safe next action.

AI does not mutate schedule/payroll automatically.

---

# 146. PRIORITY IMPLEMENTATION ORDER

Urutan v1.0 benar arahnya tetapi tidak menyebut siapa yang mengerjakan apa, dan
menempatkan pekerjaan backend yang belum ada sebagai langkah mobile. Urutan ini
menyebut **pemilik** dan **penghambat**.

### Blok 0 — dapat dikerjakan sekarang, tanpa menunggu siapa pun

| # | Pekerjaan | Pemilik |
|---|---|---|
| 1 | **M-D1: putuskan namespace API** (§0.4) | owner |
| 2 | Fase 7 client: FCM iOS (HIGH-03), background handler (HIGH-05), redaksi log rilis (CRIT-05) | mobile |
| 3 | Jawab CRIT-01 (Play App Signing) dan HIGH-08 (application id) | owner |
| 4 | Sertifikat valid → matikan bypass TLS (CRIT-02/TEN-03) | infra + mobile |
| 5 | Putuskan G-2 (device binding) dan G-3 (token abilities) | produk + backend |

### Blok 1 — Gate A: identitas yang aman

| # | Pekerjaan | Pemilik |
|---|---|---|
| 6 | `102-authorization-hardening` — hentikan fail-open | backend |
| 7 | `101-audit-engine` — audit ditulis application service | backend |
| 8 | Pindahkan auth client ke kontrak `/api/v1` (identifier + device_id, logout POST + fcm_token) | mobile |
| 9 | Absensi: pakai `attendance/context`, `attendance/qr`, wajah | mobile |

### Blok 2 — Gate B: ESS operasional

| # | Pekerjaan | Pemilik |
|---|---|---|
| 10 | 18 endpoint self-service, **satu fitur per kali**, urutan Lampiran B | backend |
| 11 | Home · Profil · Izin · Pengumuman · Notifikasi · Bug report ke kontrak baru | mobile |
| 12 | `GET /bootstrap` (§140) dan navigasi berbasis kapabilitas | backend + mobile |
| 13 | `Idempotency-Key` pada seluruh write | keduanya |
| 14 | `118-scheduling-foundation` → layar Schedule | backend → mobile |
| 15 | `122-overtime` → layar Overtime | backend → mobile |
| 16 | `125-approval-engine` → Inbox + Approvals + Tasks | backend → mobile |
| 17 | `129-document-platform` → Documents | backend → mobile |

### Blok 3 — Gate C: aman untuk payroll

18. Field-level authorization · 19. Step-up auth (§93) · 20. `142-payslip` →
Payslip + Explain Pay · 21. Bank/Pajak/BPJS · 22. `150-expense` → Expense ·
23. `194-hr-helpdesk` + `196-knowledge-base`.

### Blok 4 — Gate D: manufaktur

24. Wave 6 Skills → My Skills, Certification, Qualification ·
25. Wave 7 → Coverage, Replacement, Crew, Line ·
26. `116-mss` → My Team dan turunannya.

### Blok 5 — Gate E: AI

27. `207-ai-gateway` · 28. Copilot, Explain Pay penuh, Workforce Assistant.

---

# 147. WHY THIS ORDER

Karena kenyataan proyek — diverifikasi di §0 — adalah:

```text
+ absensi matang, dan lebih dalam daripada yang diklaim rancangan
+ tenancy, sesi, dan push sudah terbukti oleh satu client produksi
+ seluruh data HRIS sudah ada sebagai model dan tabel
+ client mobile sudah punya lapisan yang benar (Fase 0–6 selesai, 171 test hijau)

- 18 endpoint self-service belum ada
- effective dating, audit engine, outbox: nol
- rule/formula/approval/workflow belum menjadi engine
- entitlement dan feature flag belum ada tempat penyimpanannya
- otorisasi masih fail-open pada workspace tanpa role
```

Tiga alasan urutan ini, bukan urutan yang terlihat lebih menarik:

1. **Domain yang andal dulu, lewat API yang aman** — bukan membuat layar untuk
   domain yang belum ada. Layar tanpa domain adalah utang yang terlihat seperti
   kemajuan.
2. **Gate A mendahului segalanya** karena setiap fitur berikutnya memperluas
   permukaan yang sama. Memperlebar akses mobile di atas otorisasi fail-open
   memperbanyak, bukan menunda, kerusakannya.
3. **Yang menghambat sebagian besar bukan Flutter.** Dari 28 langkah, 14 milik
   backend dan 5 adalah keputusan owner/produk. Menjadwalkan tim mobile seolah
   merekalah jalur kritis akan menghasilkan aplikasi yang menunggu.

---

# 148. MOBILE BACKLOG EPIC STRUCTURE

Epic tetap seperti v1.0, ditambah kolom yang membuatnya dapat dijadwalkan:

| Epic | Gate | Penopang backend | Status |
|---|---|---|---|
| MOB-00 Foundation | A | — | ✅ Fase 0–6 selesai |
| MOB-01 Authentication & Tenant | A | ada | 🟨 pindah kontrak |
| MOB-02 App Bootstrap & Navigation | B | `GET /bootstrap` | ⬜ |
| MOB-03 Home | B | 3 endpoint | ⬜ |
| MOB-04 Attendance | A/B | ✅ ada | 🟨 |
| MOB-05 Schedule | B | `118` | ⛔ |
| MOB-06 Leave | B | 6 endpoint | ⬜ |
| MOB-07 Overtime | B | `122` | ⛔ |
| MOB-08 Inbox & Approvals | B | `125` | ⛔ |
| MOB-09 Profile | B | `/profile` | ⬜ |
| MOB-10 Documents | B | `129` | ⛔ |
| MOB-11 Payroll | C | `142`, `133` | ⛔ |
| MOB-12 Requests & Helpdesk | C | `194`, `195` | ⛔ |
| MOB-13 Expense & Finance | C | `149`–`152` | ⛔ |
| MOB-14 Skills & Certification | D | Wave 6 | ⛔ |
| MOB-15 Learning | D | Wave 8 | ⛔ |
| MOB-16 Performance | D | Wave 8 | ⛔ |
| MOB-17 Manager Workspace | D | `116` | ⛔ |
| MOB-18 Manufacturing Workforce | D | Wave 7 | ⛔ |
| MOB-19 Engagement | D | Wave 8 | ⛔ |
| MOB-20 AI | E | Wave 10 | ⛔ |
| MOB-21 Security & Privacy | A | `102`, `101` | 🟨 |
| MOB-22 Observability | B | — | ⬜ |
| MOB-23 Accessibility & Localization | B | — | 🟨 locale `id` sudah dipasang |

Epic ber-status ⛔ **tidak boleh masuk sprint planning**. Ia masuk ke dependency
board bersama module plan yang menopangnya.

---

# 149. ACCEPTANCE CRITERIA — APPLICATION LEVEL

Kriteria v1.0 dipertahankan seluruhnya, tetapi dikelompokkan per gate — sebuah
daftar 23 kotak centang yang tidak dapat diurutkan bukan kriteria penerimaan,
melainkan harapan. Yang sudah tercapai ditandai.

## Gate A — Safe Identity

- [x] Karyawan dapat masuk dan terikat ke tenant yang benar (`X-Tenant`, token di database tenant).
- [x] Sesi selamat dari gangguan jaringan; 401 mengakhiri sesi sekali, terpusat.
- [x] Kredensial berada di secure storage, bukan di penyimpanan biasa.
- [ ] Validasi TLS aktif — bypass global dihapus.
- [ ] Otorisasi backend fail-closed pada seluruh workspace.
- [ ] Setiap mutasi kritis dari mobile ter-audit di server.
- [ ] Menyembunyikan navigasi tidak diperlakukan sebagai keamanan (setiap endpoint menolak sendiri).
- [ ] Uji kebocoran lintas-tenant lulus.

## Gate B — Operational ESS

- [ ] Kontrak API self-service yang stabil menggantikan ketidakcocokan namespace (§0.4, Lampiran B).
- [ ] Navigasi dibangkitkan dari entitlement + permission + persona + feature flag.
- [ ] Karyawan melihat profil kanonis miliknya.
- [x] Karyawan dapat clock in/out sesuai kebijakan server.
- [x] Absensi lintas tengah malam tetap benar (diputuskan server, bukan client).
- [x] Absensi wajah mempertahankan consent, liveness, dan tata kelola retensi.
- [ ] Karyawan dapat melihat jadwal.
- [ ] Karyawan dapat mengajukan dan melacak cuti/izin.
- [ ] Karyawan dapat mengajukan dan melacak lembur.
- [ ] Approver dapat bertindak dari Inbox dalam scope yang diizinkan.
- [ ] Notifikasi membawa deep link yang otorisasinya diperiksa ulang saat dibuka.
- [ ] Setiap write bersifat idempoten.
- [ ] Layar kritis punya state loading/empty/error.
- [ ] Aplikasi menangani jaringan buruk dengan retry yang tidak menduplikasi write.
- [ ] Kapabilitas yang tidak didukung tidak terlihat **dan** tidak dapat diakses.

## Gate C — Payroll Safe

- [ ] Karyawan dapat melihat slip gaji terbit secara aman.
- [ ] Field sensitif memiliki field-level authorization.
- [ ] Aksi finansial berada di belakang step-up authentication.
- [ ] Telemetri produk tidak memuat konten sensitif.

## Gate D–E

- [ ] Kelayakan replacement dihitung deterministik di server, bukan diperingkat client.
- [ ] AI tidak dapat melewati rule, otorisasi, atau persetujuan manusia.

---

# 150. PRODUCT SUCCESS CRITERIA

Mobile succeeds if an employee can answer and act on:

### WHO AM I?

```text
Profile
Employment
Assignment
```

### WHEN DO I WORK?

```text
Schedule
Shift
Attendance
```

### WHAT DO I NEED TO DO?

```text
Tasks
Approvals
Training
Requests
```

### WHAT AM I ENTITLED TO?

```text
Leave
Benefits
Payroll
Documents
```

### WHAT CAN I DO?

```text
Skills
Qualification
Career
```

### WHAT CHANGED?

```text
Inbox
Timeline
Notifications
```

### WHY?

```text
Explainable status
Rules
Calculation trace
AI explanation
```

---

# 151. FINAL MOBILE NORTH STAR

The mobile application should feel simple even though the platform behind it is complex.

Employee experience:

```text
Home
Work
Requests
Inbox
Profile
```

Platform behind it:

```text
Identity
Tenant
Authorization
People
Employment
Organization
Scheduling
Attendance
Leave
Overtime
Payroll
Skills
Workforce
Talent
Workflow
Approval
Rules
Formula
Automation
Analytics
AI
```

The goal is not to expose every platform module.

The goal is:

> **memberikan setiap employee tindakan, informasi, dan keputusan yang relevan untuk dirinya pada saat yang tepat—dari satu aplikasi yang aman, explainable, dan terhubung penuh ke Human Capital & Workforce Operating System.**

---

# LAMPIRAN A — MATRIKS TRACEABILITY

Setiap capability mobile, modul backend yang menopangnya, dan status nyatanya.
**Inilah yang menentukan apa yang boleh masuk sprint** — bukan §122.

| § | Capability mobile | Module plan penopang | Wave | Backend | Mobile |
|---|---|---|---|---|---|
| 8–11 | Home / persona home | `115-ess`, `GET /bootstrap` | 2 | ⬜ | 🟨 |
| 12–18 | Attendance | `119-attendance`, `120-attendance-policy` | 2 | ✅ | 🟨 |
| 16 | Face attendance | `103-biometric-attendance-governance` | 0 | ✅ | ⬜ |
| 17 | Attendance correction | `120`, `125-approval-engine` | 2–3 | ⛔ | ⛔ |
| 19–23 | Schedule, open shift, swap | `117-calendar`, `118-scheduling-foundation`, `161` | 2, 7 | ⛔ | ⛔ |
| 24–26 | Leave | `121-leave` (data & panel sudah ada) | 2 | 🟨 | 🟨 |
| 27–28 | Overtime | `122-overtime` | 2 | ⛔ | ⛔ |
| 29–32 | Pay, payslip, explain pay | `142-payslip`, `133-calculation-trace` | 4 | ⛔ | ⛔ |
| 33–34 | Requests hub | `195-employee-request`, `125` | 3, 8 | ⛔ | ⛔ |
| 35–38 | Expense, advance, travel, loan | `149`–`152` | 5 | ⛔ | ⛔ |
| 39–44 | Inbox, approvals, tasks, notifikasi | `125`, `128-notification-platform` | 3 | 🟨 push saja | 🟨 |
| 45–51 | Profile, timeline, bank, pajak | `106`–`110`, `100-effective-dating` | 0–1 | 🟨 | 🟨 |
| 52 | Documents | `129-document-platform`, `197` | 3, 8 | ⛔ | ⛔ |
| 52.1 | E-signature | `198-e-signature` | 8 | ⛔ | ⛔ |
| 53–54 | Helpdesk, knowledge base | `194`, `196` | 8 | ⛔ | ⛔ |
| 55–57 | Skills, certification, qualification | `153`–`156` | 6 | ⛔ | ⛔ |
| 58–59 | Learning | `183`–`187` | 8 | ⛔ | ⛔ |
| 60–63 | Performance, goals, feedback | `178`–`181` | 8 | ⛔ | ⛔ |
| 64–65 | Career, internal opportunity | `188`–`190` | 8 | ⛔ | ⛔ |
| 66–68 | Engagement, recognition, ER | `191`–`193` | 8 | ⛔ | ⛔ |
| 69–70 | Recruitment, interviewer mode | `170`–`176` | 8 | ⛔ | ⛔ |
| 71–72 | My team | `116-mss` | 2 | ⛔ | ⛔ |
| 73–76 | Coverage, replacement, crew, line | `158`–`167` | 7 | ⛔ | ⛔ |
| 77 | Executive mobile | Wave 9 analytics | 9 | ⛔ | ⛔ |
| 78–80 | AI copilot & tool policy | `207`–`213` | 10 | ⛔ | ⛔ |
| 81–83 | Search, direktori, pengumuman | `115-ess` | 2 | 🟨 | 🟨 |
| 84–85 | Permission model, data ownership | `102-authorization-hardening` | 0 | ⛔ | ⬜ |
| 86–89 | API boundary | `215-public-api`, `019-api-architecture` | 11 | 🟨 `/api/v1` | 🟨 |
| 90–91 | Tenant & multi-employment | `022-multi-tenancy`, `107`, `108` | — , 1 | ✅ / ⛔ | ✅ / ⛔ |
| 92–94 | Auth, step-up, local security | `020-security-architecture` | — | 🟨 | 🟨 |
| 98–99 | Push & event-driven | `128`, `104-outbox` | 3, 0 | 🟨 | 🟨 |
| 100–102 | Privacy, consent, audit | `021`, `101-audit-engine` | 0 | ⛔ | ⬜ |
| 138 | Feature flag vs entitlement | `217`, `227` | 11 | ⛔ | ⛔ |

✅ siap dipakai · 🟨 sebagian · ⬜ dipetakan, belum dibangun · ⛔ menunggu Wave.

---

# LAMPIRAN B — KONTRAK API SELF-SERVICE (24 ENDPOINT)

> **Prasyarat: M-D1 (§0.4).** Prefix di bawah ditulis `/api/v1` sesuai rekomendasi;
> bila owner memilih `/api/selfservice`, hanya prefix yang berubah.
>
> Sumber: `docs/refactoring/06-api-migration-map.md`, disesuaikan dengan kenyataan
> `routes/api.php` per 2026-09-01.

## B.1 Sudah ada (6)

| Kebutuhan client | Endpoint | Catatan kontrak |
|---|---|---|
| Login | `POST /auth/login` | `identifier` (NIP **atau** email) + `password` + `device_id`. Bukan `nip` + `device_info` |
| Sesi saat ini | `GET /auth/me` | `{ user }` — bentuk datar; lihat G-1 |
| Logout | `POST /auth/logout` | **POST**, bukan GET. Body opsional `{ fcm_token }` melepas handset ini |
| Daftar push token | `POST /push-tokens` | `{ token, platform }`; `POST /push-tokens/forget` untuk melepas |
| Absen QR | `POST /attendance/qr` atau `POST /qr-presences/redeem` | Menggantikan IP cleartext yang lama; single-use dijaga indeks unik |
| Konteks absensi | `GET /attendance/context` | Menjawab shift, status clock, `next_presence`, geofence, `attendance_enabled`, `face_enrolled`, `can_issue_qr`, `server_time` |

## B.2 Harus dibangun (18)

Urutan kolom **Urut** adalah urutan yang direkomendasikan: satu fitur selesai
end-to-end sebelum fitur berikutnya dimulai.

| Urut | Endpoint | Model penopang | Menggantikan pemakaian client |
|:--:|---|---|---|
| 1 | `GET /profile` | `UserDetail`, `UserEmploye`, `UserFamily`, `UserFormalEducation`, `UserAddress`, `UserWorkExperience`, `UserSalary` | 5 tab profil yang dulu memanggil `/auth` masing-masing |
| 2 | `POST /auth/password` | `User` | `/auth/change-password` |
| 3 | `GET /announcements` · `GET /announcements/{id}` | `Announcement` | daftar + detail; `?active=1` menggantikan `/announcements/active` |
| 4 | `GET /notifications` · `PATCH /notifications/{id}/read` | tabel `notifications` | daftar + tandai dibaca |
| 5 | `GET /activities` | `ActivityLog` | `/auth/activity` |
| 6 | `GET /attendances` | `UserAttendance` | `/user-attendances` |
| 7 | `GET /attendance/summary` | `UserAttendance` | `/auth/summary-absen` |
| 8 | `GET /permit-types` | `PermitType` | `/permit-types/list` |
| 9 | `GET /permits` (`?type=`) | `Permit` | `/permits/list/{typeId}` |
| 10 | `GET /permits/form` | `TimeWork`, `UserAttendance` | `/permits/create` |
| 11 | `POST /permits` | `Permit` | pengajuan izin — **wajib `Idempotency-Key`** |
| 12 | `GET /permits/{id}` | `Permit`, `PermitApprove` | detail + rantai persetujuan |
| 13 | `POST /permits/{id}/approval` | `PermitApprove` | keputusan approver — **wajib `Idempotency-Key`** |
| 14 | `POST /bug-reports` | `BugReport` | lapor masalah (multipart lampiran) |
| 15 | `GET /payroll` | `PayrollItem`, `PayrollPeriod`, `PayrollGrade` | tab payroll di profil — **bukan** slip gaji |

Lima belas baris untuk 18 endpoint karena tiga di antaranya adalah pasangan
daftar/detail pada resource yang sama.

## B.3 Bentuk `GET /profile` — yang menutup G-1

Endpoint inilah yang membuat aplikasi berhenti bergantung pada payload login untuk
data domain. Payload login menyatakan **siapa Anda**; ia tidak membawa seluruh
rekaman karyawan.

```jsonc
{
  "user":     { "id": 1, "name": "…", "nip": "…", "email": "…", "avatar": "…", "status": "…" },
  "company":  { "id": 1, "name": "…", "latitude": -6.2, "longitude": 106.8, "radius": 150 },
  "employee": {
    "user_id": 1, "departement_id": 3, "departement": "…",
    "job_position": "…", "job_level": "…",
    "sign_date": "2021-03-01", "resign_date": null
  },
  "addresses": [], "families": [], "educations": [], "experiences": []
}
```

Catatan yang menghemat perdebatan nanti: koordinat perusahaan **sudah** dikirim
`attendance/context`, jadi kehadirannya di sini untuk layar profil, bukan untuk
geofence. Absensi tidak boleh mengambilnya dari sini.

## B.4 Aturan yang berlaku untuk seluruh 18 endpoint

1. **Resource berbasis domain, bukan tabel.** `permits` boleh dipertahankan karena
   sudah menjadi istilah produk; `user-attendances` tidak — ia nama tabel.
2. **Koleksi dipaginasi** dengan bentuk paginator Laravel standar.
3. **Setiap write menerima `Idempotency-Key`** dan mengembalikan hasil yang sama
   untuk kunci yang sama.
4. **Setiap penolakan membawa kode mesin**, bukan hanya kalimat Indonesia.
5. **Otorisasi diperiksa di server, per record dan per field** — bukan dengan
   mengandalkan client hanya meminta miliknya sendiri.
6. **Setiap mutasi menulis audit** begitu `101-audit-engine` ada; sampai itu, tidak
   ada endpoint tulis baru yang dirilis untuk data finansial.

## B.5 Yang berubah di sisi Flutter

| Lapisan | Dampak |
|---|---|
| `Env.apiPrefix` | satu konstanta |
| `ApiRoutes` | seluruh path — satu berkas |
| `AuthApiService` | `identifier`/`device_id`, logout POST, `fcm_token` saat keluar |
| `SessionRepository` | jalur galat device binding (G-2), abilities (G-3) |
| Model | setiap `fromJson` diarahkan ulang; fixture test **diambil dari API baru**, bukan dari yang lama |
| Repository | path berubah; **call site di controller tidak** — itulah gunanya lapisan ini |

---

# LAMPIRAN C — KEPUTUSAN TERBUKA

Enam keputusan yang menghambat pekerjaan nyata. Masing-masing menyebut pemilik,
apa yang tertahan, dan apa yang terjadi bila jawabannya tertunda.

| ID | Pertanyaan | Pemilik | Menahan | Rekomendasi |
|---|---|---|---|---|
| **M-D1** | `/api/v1` atau `/api/selfservice`? (§0.4) | owner | Lampiran B, Gate B, seluruh pekerjaan backend ESS | **`/api/v1`** — satu permukaan, tenancy dan guard tidak diduplikasi |
| **M-D2** | Device binding berlaku untuk self-service? (G-2) | produk | Login pada handset kedua; Gate A | Wajar untuk kiosk; untuk self-service **longgarkan** menjadi daftar perangkat yang dapat dicabut sendiri |
| **M-D3** | Abilities token untuk self-service? (G-3) | backend | Setiap endpoint ESS | Satu ability per kelompok resource, bukan satu ability untuk semuanya |
| **M-D4** | Play App Signing aktif? application id diganti? (CRIT-01/HIGH-08) | owner | Rilis publik | Jawab sebelum rilis pertama; rotasi kunci mahal setelahnya |
| **M-D5** | Onboarding (`IntroductionScreen`) dipertahankan? | produk | `onboardingCompleted` yang ditulis tetapi tidak pernah dibaca | Hapus atau aktifkan; jangan tinggalkan tulisan tanpa pembaca |
| **M-D6** | Skema deep link `app://` menggantikan path route? (§121) | produk + backend | Deep link dari email/web | Tunda sampai ada pengirim di luar FCM; perubahannya berversi |

Dua hal yang **bukan** keputusan terbuka, dan sudah dijawab kode — ditulis di sini
supaya tidak dibuka kembali:

- **Backend mana?** `tenancy-app`. ADR-0006, dan `esas_attendance` sudah
  membuktikannya di produksi.
- **Bagaimana workspace ditentukan?** `X-Tenant`, di-resolve sebelum routing, dengan
  token yang hidup di database tenant. Mengganti header tidak membuka tenant lain.

---

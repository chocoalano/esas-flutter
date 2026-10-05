# 06 — API Migration Map: `esas-erp-api-modulars` → `tenancy-app`

> **Diperbarui 2026-09-01** setelah `tenancy-app` diperiksa langsung. Tiga hal
> berubah: permukaan backend diverifikasi (20 route, bukan perkiraan), **G-1
> separuh terjawab** sehingga absensi tidak lagi terblokir, dan prefix yang dipakai
> kode ternyata menyimpang dari peta ini. Lihat **Pembaruan 2026-09-01** di akhir
> berkas; kontrak yang mengikat kini ada di **README Lampiran B**.

> **Decision (2026-09-01):** ESAS self-services migrates onto the `tenancy-app`
> backend, the same one `esas_attendance` uses. See [ADR-0006](../adr/0006-migrate-to-tenancy-app-api.md).
>
> This map is the equivalent of `03-migration-map.md` for the API surface. It is the
> input to Phases 3–5, which cannot start on a feature until that feature's endpoints
> exist.

---

## What each side actually is

| | Current | Target |
|---|---|---|
| Project | `/Users/ict/Documents/Laravel/esas-erp-api-modulars` | `/Users/ict/Documents/esas/tenancy-app` |
| Tenancy | **none** — no package, no tenant refs, single DB | `stancl/tenancy ^3.10`, subdomain identification, DB-per-tenant |
| API root | `/api` | `/api/v1` |
| Surface | `/general-module/*` (101 routes), `/hris-module/*` (125 routes) | `/api/v1/*` — **20 route** di 9 controller (2 publik, 11 handset, 7 kiosk) |
| Auth | Sanctum | Sanctum + `X-Tenant`, device-bound |

**The finding that decides the cost:** `tenancy-app` already carries the whole HRIS
domain as models and migrations. What is missing is the API layer over it, not the
data.

Models present: `Permit`, `PermitApprove`, `PermitType`, `UserAttendance`,
`LogUserAttendance`, `TimeWork`, `Announcement`, `ActivityLog`, `BugReport`,
`UserDetail`, `UserEmploye`, `UserFamily`, `UserFormalEducation`, `UserAddress`,
`Company`, `Departement`, `JobLevel`, `JobPosition`, `PayrollGrade`, `PayrollItem`,
`PayrollPeriod`, `PayrollSetting`, `QrPresence`, `QrRedemption`, `Setting`.

Migrations present: `create_hrms_permit_tables`, `create_hrms_attendance_tables`,
`create_hrms_employee_tables`, `create_hrms_organization_tables`,
`create_hrms_payroll_tables`, `create_hrms_support_tables`, `create_notifications_table`.

So each missing endpoint is a controller and a resource over an existing model —
not a domain to design.

---

## Endpoint mapping — all 24

### Already there (6)

| Self-services today | `tenancy-app` | Contract change |
|---|---|---|
| `POST /general-module/auth/login` | `POST /api/v1/auth/login` | **`nip` → `identifier`** (accepts nip *or* email); **`device_info` → `device_id`**; response `{token, user}` but `user` is reshaped — see gap G-1 |
| `GET /general-module/auth` | `GET /api/v1/auth/me` | Returns `{user}`; same reshape |
| `GET /general-module/auth/logout` | `POST /api/v1/auth/logout` | **GET → POST** |
| `POST /general-module/auth/set-token` | `POST /api/v1/push-tokens` | Body shape differs; `POST /push-tokens/forget` also available for logout |
| `POST http://128.199.111.239:3000/attmachine/qr-presence` | `POST /api/v1/attendance/qr` (or `qr-presences/redeem`) | **Kills HIGH-09 outright** — the hardcoded cleartext IP disappears, replaced by a tenant-resolved TLS endpoint inside the same API |
| `GET /general-module/auth/current-attendance/{id}` + `/auth/schedule` | `GET /api/v1/attendance/context` | Partially covers both; confirm the payload carries today's in/out times *and* the schedule |

### To be added (18)

Each is a new controller over a model that already exists.

| Self-services today | Suggested `tenancy-app` route | Backing model |
|---|---|---|
| `POST /general-module/auth/change-password` | `POST /api/v1/auth/password` | `User` (logic exists in `Settings/SecurityController`) |
| `GET /general-module/auth/summary-absen` | `GET /api/v1/attendance/summary` | `UserAttendance` |
| `GET /general-module/auth/activity` | `GET /api/v1/activities` | `ActivityLog` |
| `GET /general-module/announcements` | `GET /api/v1/announcements` | `Announcement` |
| `GET /general-module/announcements/active` | `GET /api/v1/announcements?active=1` | `Announcement` |
| `GET /general-module/announcements/{id}` | `GET /api/v1/announcements/{id}` | `Announcement` |
| `GET /general-module/notifications` | `GET /api/v1/notifications` | `notifications` table |
| `PATCH /general-module/notifications/{id}` | `PATCH /api/v1/notifications/{id}/read` | `notifications` table |
| `POST /general-module/bug-reports` | `POST /api/v1/bug-reports` | `BugReport` |
| `GET /hris-module/user-attendances` | `GET /api/v1/attendances` | `UserAttendance` |
| `GET /hris-module/permit-types/list` | `GET /api/v1/permit-types` | `PermitType` |
| `GET /hris-module/permits/list/{typeId}` | `GET /api/v1/permits?type={id}` | `Permit` |
| `GET /hris-module/permits/create` | `GET /api/v1/permits/form` | `TimeWork`, `UserAttendance` |
| `POST /hris-module/permits` | `POST /api/v1/permits` | `Permit` |
| `GET /hris-module/permits/{id}` | `GET /api/v1/permits/{id}` | `Permit`, `PermitApprove` |
| `POST /hris-module/permits/{id}/approval` | `POST /api/v1/permits/{id}/approval` | `PermitApprove` |
| *(profile sub-tabs read `/general-module/auth`)* | `GET /api/v1/profile` | `UserDetail`, `UserEmploye`, `UserFamily`, `UserFormalEducation`, `UserAddress` |
| *(payroll tab)* | `GET /api/v1/payroll` | `PayrollGrade`, `PayrollItem`, `PayrollPeriod` |

---

## Contract gaps that block features

### G-1 — the `user` payload is flattened and loses fields the app needs

`tenancy-app`'s `AuthController::profile()` returns:

```php
'company'       => $user->company?->name,        // a string
'departement'   => $user->employe?->departement?->name,
'job_position'  => $user->employe?->jobPosition?->name,
```

Self-services reads a **nested** object and needs fields that are not in it:

| Read by | Path | Present? |
|---|---|---|
| `AttendanceController` geofence | `user.company.latitude` / `.longitude` | **No** — blocks attendance entirely |
| `AttendanceController` QR dept check (CRIT-04) | `user.employee.departement_id`, `user.employee.user_id` | **No** |
| `PermitCreateController` | `user.company_id`, `user.employee.departement_id` | **No** |
| `ProfileController` | `user.employee.job_position.name`, `user.employee.sign_date`, `user.status` | Partly — flattened, `sign_date` absent |
| `HomeController` | `user.name`, `user.avatar` | Yes |

~~**This is the single most blocking gap.**~~ **Direvisi 2026-09-01 — sebagian besar
gap ini tidak pernah ada.** `GET /api/v1/attendance/context` sudah mengirim
`location.required`, `latitude`, `longitude`, `radius_metres`, dan pemeriksaan
departemen QR dilakukan server di `qr-presences/redeem`. Absensi **tidak** perlu
mengambil keduanya dari payload login, dan memang tidak boleh — koordinat yang
di-cache dari sesi lama adalah geofence yang salah setelah kantor pindah.

Yang tersisa dari G-1 adalah kebutuhan **layar profil** (`sign_date`, jabatan,
status, alamat, keluarga, pendidikan, pengalaman), dan itu dijawab `GET /profile`.

**Resolution:** either extend `profile()` to carry the nested company/employee objects
self-services needs, or add a dedicated `GET /api/v1/profile` and have the app stop
depending on the login payload for domain data. The second is better architecture —
the login response should say who you are, not carry the whole employee record — and
it is what the repository layer in Phase 5 wants anyway.

### G-2 — device binding is a new rule

```php
if (is_string($user->device_id) && $user->device_id !== '' && $user->device_id !== $deviceId) {
    'device_id' => 'Akun ini sudah terdaftar di perangkat lain. Hubungi HR untuk memindahkannya.'
}
```

`tenancy-app` locks an account to one handset; signing in on a second is refused until
HR clears `device_id`. **Self-services has no such rule today** — an employee can sign
in anywhere.

This is a **policy change, not a technical one**, and it needs a product decision
before migration. It is defensible for an attendance app and possibly unwanted for
self-service (payslips, permit submission from a spare phone). Recorded as Q12.

### G-3 — token abilities

Login mints `createToken($deviceId, ['attendance'])`. Self-services needs more than
attendance — permits, payroll, profile writes. The ability set must be widened, or a
second ability granted per client.

### G-4 — logout verb and push-token lifecycle

Logout moves GET → POST, and `tenancy-app` forgets the push token as part of logout
(`forgetPushToken`). Self-services currently never unregisters its FCM token. Adopting
this fixes a real leak: a device that logs out keeps receiving another employee's
notifications.

---

## What this does to the Flutter side

**The Phase 1 core layer survives unchanged.** It was built transport-agnostic, so the
only edit is one constant:

```dart
// core/config/env.dart
static const String apiPrefix = String.fromEnvironment('API_PREFIX', defaultValue: '/api');
//                                                                                  ^^^^ → '/api/v1'
```

That is the payoff for putting the address behind configuration rather than a constant.

**What does change**, in Phases 3–5:

| Layer | Impact |
|---|---|
| `AuthApiService` | New paths, `identifier`/`device_id` fields, POST logout |
| `SessionRepository` | Token abilities; device-binding error path (G-2) |
| Models | Reshaped `user` payload (G-1); every `fromJson` retargeted |
| Repositories | New paths — but the *call sites* in controllers stay, because they go through repositories |
| `AttendanceController` | Blocked on G-1 until geofence coordinates are exposed |
| **HIGH-09** | **Closed by the migration** — no more hardcoded cleartext IP |

**Rule §2 of the brief — "DO NOT change endpoint paths" — is now overridden by this
decision.** That was a constraint to protect a refactor from scope creep; the owner has
chosen a backend migration instead, which is a legitimate call that changes the
constraint. It is recorded here so nobody later reads the brief and thinks the
migration violated it.

---

## Sequencing

The Flutter refactor and the backend port are separable, and should stay separable.

```
Phase 2  bootstrap                     ✅ selesai
Phase 3  auth      ✅ selesai di backend LAMA; pemindahan kontrak = Fase 10b
Phase 4  attendance✅ selesai di backend LAMA; pemindahan = Fase 10b, TIDAK diblokir G-1
Phase 5  permit / profile / notification / home ✅ selesai di backend LAMA
Phase 10 cutover   ← menunggu ADR-0007, lalu 18 endpoint satu per satu
```

**Diperbarui:** Fase 2–6 sudah selesai seluruhnya, dikerjakan di atas backend lama
supaya temuan keamanan tertutup sekarang alih-alih menunggu pengiriman backend.
Yang tersisa adalah pemindahan kontraknya, dan penghalangnya bukan lagi G-1
melainkan **ADR-0007 (prefix), G-2 (device binding), dan G-3 (abilities)**.

**Recommended:** run the backend endpoint work in parallel with Phase 2, feature by
feature, in the order Phase 5 consumes them. The Flutter side should not wait, and the
backend should not be asked for all 18 at once.

---

## Pembaruan 2026-09-01

### 1. Permukaan backend, terverifikasi

`routes/api.php` — 20 route, seluruhnya di `/api/v1`, tenant di-resolve **sebelum
routing** oleh `IdentifyTenantByHeader`:

```text
publik      GET  workspace · POST auth/login
handset     GET  auth/me · POST auth/logout
            GET  attendance/context
            POST attendance/face/challenge · POST attendance/face · POST attendance/qr
            GET  qr-presences/context · POST qr-presences · POST qr-presences/redeem
            POST push-tokens · POST push-tokens/forget
kiosk       7 route di bawah auth:kiosk-device — milik esas_attendance
```

Sebelas route handset itulah yang menjadi milik aplikasi ini. Enam pemetaan di
bagian *Already there* di atas tetap benar; yang berubah adalah bahwa
`attendance/context` menjawab **lebih banyak** daripada yang diperkirakan peta ini:
`server_time`, `schedule.crosses_midnight`, `next_presence`, `attendance_enabled`,
`face_enrolled`, `can_issue_qr`, dan seluruh blok `location`.

### 2. Prefix belum diputuskan — dan itu menahan 18 endpoint

Peta ini menulis `/api/v1`. Kode memakai `/api/selfservice`. Server tidak punya
`/api/selfservice` sama sekali.

Pertanyaannya diangkat menjadi **[ADR-0007](../adr/0007-self-service-api-namespace.md)**
(status *Proposed*, pemilik: owner), dengan rekomendasi `/api/v1`. **Tidak ada
endpoint yang dibangun sebelum status itu *Accepted*** — 18 endpoint di prefix yang
salah berarti membangun dua kali.

Apa pun keputusannya, tabel pemetaan di atas tetap berlaku; hanya prefiksnya yang
berbeda.

### 3. Kontrak pindah ke README Lampiran B

Peta ini menjawab *"endpoint lama menjadi endpoint apa"*. Yang tidak dijawabnya —
dan yang dibutuhkan backend untuk mulai bekerja — adalah bentuk payload, urutan
pengerjaan, dan aturan lintas endpoint. Semuanya kini ada di **README Lampiran B**,
satu sumber yang dibaca backend dan mobile:

- bentuk `GET /profile` yang menutup sisa G-1;
- urutan 18 endpoint (profile → change-password → announcements → notifications →
  activities → attendances → summary → permit ×6 → bug-reports → payroll);
- **`Idempotency-Key` wajib** pada setiap write — pengajuan izin dan keputusan
  approval tidak boleh terduplikasi oleh ketukan ganda;
- paginasi Laravel standar untuk koleksi;
- kode galat mesin, bukan hanya kalimat Indonesia;
- resource berbasis domain: `permits` boleh, `user-attendances` tidak — itu nama tabel.

### 4. Yang perlu diketahui backend sebelum mulai

| Hal | Kenyataan | Konsekuensi |
|---|---|---|
| Abilities token | login mencetak `['attendance']` | Setiap endpoint ESS akan ditolak sampai diperlebar (G-3) |
| Device binding | satu akun satu handset, dilepas HR | Keputusan produk untuk self-service (G-2 / M-D2) |
| Otorisasi | fail-open pada workspace tanpa role | Endpoint ESS baru **mewarisi** sifat itu; `102-authorization-hardening` harus lebih dulu untuk data finansial |
| Audit | belum ditulis application service | Tidak ada endpoint tulis data finansial yang dirilis sebelum `101-audit-engine` |
| Payslip | belum ada publikasi ke karyawan | `GET /payroll` di daftar 18 adalah **komponen upah untuk tab profil**, bukan slip gaji. Jangan menamainya payslip di UI |

### 5. Dampak ke sisi Flutter — tidak berubah, dan itu buktinya bekerja

Tabel *What this does to the Flutter side* di atas masih akurat setelah enam fase:
call site di controller tidak berubah karena semuanya melewati repository, dan path
hidup di satu berkas (`core/config/api_routes.dart`). Yang tersisa persis seperti
yang diperkirakan — satu konstanta, satu berkas path, `AuthApiService`, dan setiap
`fromJson` yang harus diarahkan ulang dengan fixture dari **API baru** (R-10).

---

## Pembaruan 2026-09-02 — kontrak perizinan setelah audit formulir

Audit formulir izin menemukan tiga tempat di mana model Flutter dan jawaban
`tenancy-app` tidak sama bentuknya. Semuanya sudah diperbaiki; dicatat di sini
karena inilah jenis selisih yang R-10 minta diuji dengan fixture API baru, bukan
dengan tebakan.

| Endpoint | Yang dikira klien | Yang benar-benar dikirim |
|---|---|---|
| `GET /permits/form` | `schedules[].user_id`, `schedules[].time_work_id` (dua-duanya `as int` non-null) | `{id, work_day, shift_id, shift, in, out, attended}` — **tidak ada** `user_id` maupun `time_work_id` |
| `GET /permits/form` | rentang tanggal bebas | `from`/`to` di badan jawaban: hari ini → +30 hari, dibatasi 90. `POST /permits` menolak tanggal tanpa baris roster (`permit_no_schedule`) |
| `GET /permits/{id}` | tidak dibaca | `current_shift`/`adjust_shift` (nama shift) sudah dikirim sejak awal dan tidak pernah ditampilkan |

Akibat baris pertama bukan satu baris yang hilang: **setiap** baris jadwal gagal
diurai, `asModelList` melewatinya satu per satu, dan dropdown jadwal kerja selalu
kosong dengan pesan "Jadwal kerja wajib diisi" di bawah daftar yang tidak mungkin
diisi.

**Yang bertambah pada kontrak** (aditif, lihat [ADR-0008](../adr/0008-permit-type-semantic-codes.md)):

| Endpoint | Kunci baru |
|---|---|
| `GET /permit-types` | `code`, `variant` |
| `GET /permits/{id}` | `permit_type.code`, `permit_type.variant`, `shift_from`, `shift_to` (`{id, name, in, out}`) |

**Batas yang sudah dijaga server dan wajib dijaga formulir lebih dulu** — bukan
supaya validasi ganda, melainkan supaya penolakan bisa dijelaskan sebelum berkas
5 MB terlanjur diunggah:

| Aturan `StorePermitRequest` | Sisi Flutter |
|---|---|
| `end_date` `after_or_equal:start_date` | izin sehari sah; aturan "harus setelah" dihapus |
| `start_time`, `end_time`, `timein_adjust`, `timeout_adjust` `date_format:H:i` | semuanya lewat `PermitCreateController.canonicalTime` |
| `file` `mimetypes:pdf,jpeg,png`, `max:5120` | pemilih berkas tidak lagi menawarkan `doc`/`docx`/`xlsx`; ukuran ditolak sebelum unggah |
| `notes` `max:2000` | batas 255 di formulir dinaikkan ke 2000 |

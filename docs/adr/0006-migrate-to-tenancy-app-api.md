# 0006 — Migrate self-services onto the `tenancy-app` API

## Status

Accepted — 2026-09-01
**Resolves the open question in [0005](0005-subdomain-multi-tenancy.md).**
**Overrides brief rule §2** ("DO NOT change endpoint paths") — see Consequences.
**Amended 2026-09-01** — lihat *Amendment* di akhir dokumen: permukaan API yang
dipakai kode menyimpang dari ADR ini, G-1 sudah separuh terjawab, dan pertanyaan
namespace dipindahkan ke [0007](0007-self-service-api-namespace.md).

## Context

ADR-0005 adopted subdomain multi-tenancy but left one question open, because it
defined the scope of everything after Phase 1:

> Does the self-services backend gain tenancy, or does self-services migrate onto the
> tenancy backend?

The owner has decided: **the backend must be the tenancy app, the same one
`esas_attendance` uses.**

### What was found on inspection

Two backends, and my first reading of them was wrong in a way worth recording.

**Current — `/Users/ict/Documents/Laravel/esas-erp-api-modulars`**
Serves `:9443`. `app/GeneralModule/routes.php` (101 routes) and
`app/HrisModule/routes.php` (125 routes). **No tenancy whatsoever**: no package in
`composer.json`, no tenant reference in `app/` or `config/`, one database, Sanctum.
Making it multi-tenant means retrofitting tenancy into 226 routes and a single-tenant
schema.

**Target — `/Users/ict/Documents/esas/tenancy-app`**
`stancl/tenancy ^3.10`, subdomain identification, `CENTRAL_DOMAINS` from env, reserved
subdomains, database-per-tenant. API at `/api/v1`.

I initially assessed migrating to it as HIGH risk — "every endpoint, model and
repository changes; a rewrite of the data layer". **That was too pessimistic, and the
correction matters to the decision**, so it is recorded rather than quietly dropped.

`tenancy-app` already carries the entire HRIS domain as models and migrations:
`Permit`, `PermitApprove`, `PermitType`, `UserAttendance`, `LogUserAttendance`,
`TimeWork`, `Announcement`, `ActivityLog`, `BugReport`, `UserDetail`, `UserEmploye`,
`UserFamily`, `UserFormalEducation`, `UserAddress`, `Company`, `Departement`,
`JobPosition`, the payroll tables and a notifications table — created by
`create_hrms_permit_tables`, `create_hrms_attendance_tables`,
`create_hrms_employee_tables`, `create_hrms_organization_tables`,
`create_hrms_payroll_tables`, `create_hrms_support_tables`.

**The data model is already there. What is missing is the API layer over it.** Of the
24 endpoints self-services uses, 6 exist or map directly and 18 need a controller and
a resource over a model that already exists. That is materially cheaper than designing
a domain, and it changes the risk assessment from HIGH to MEDIUM.

## Decision

**Self-services migrates onto `tenancy-app` `/api/v1`.** `esas-erp-api-modulars` is
not extended with tenancy and, once migration completes, is no longer the
self-services backend.

Consequences that follow directly:

1. **`Env.apiPrefix` becomes `/api/v1`.** One constant. The Phase 1 core layer was
   built transport-agnostic precisely so this would be the only edit it needs.
2. **The 18 missing endpoints are backend work**, mapped in
   [`06-api-migration-map.md`](../refactoring/06-api-migration-map.md), to be built in
   the order Phase 5 consumes them — not all at once.
3. **The hardcoded attendance machine disappears.**
   `http://128.199.111.239:3000/attmachine/qr-presence` is replaced by
   `POST /api/v1/attendance/qr` inside the tenant-resolved, TLS-terminated API. This
   closes **HIGH-09** completely rather than merely relocating it to configuration.
4. **Both Flutter apps talk to one backend**, so tenancy, auth and push-token
   behaviour are defined once.

### Not decided here

Three contract gaps block specific features and need answers before the phases that
depend on them. They are questions, not decisions, and are recorded as Q12–Q14:

- **G-1** — `AuthController::profile()` flattens the user payload and omits
  `company.latitude/longitude` and `employee.departement_id`. Attendance cannot
  geofence or run its department check without them. **Blocks Phase 4.**
- **G-2** — `tenancy-app` binds an account to one `device_id` and refuses a second
  handset until HR clears it. Self-services has no such rule. **A policy decision.**
- **G-3** — login mints `['attendance']` abilities; self-services needs permits,
  payroll and profile writes too.

## Consequences

**Positive**

- Tenancy is not retrofitted into 226 single-tenant routes; it is inherited from a
  backend where it already works and is already proven by a shipping client.
- One backend for both Flutter apps: one tenancy model, one auth contract, one push
  lifecycle.
- HIGH-09 is closed by construction.
- Adopting `forgetPushToken` on logout fixes a leak self-services has today — a
  handset that signs out keeps receiving the previous employee's notifications.
- The Phase 1 core layer needs one constant changed. That is the whole argument for
  having built it behind configuration.

**Negative**

- **18 backend endpoints must be written before the features that need them.**
  Phases 3–5 now gate on backend delivery, which the Flutter side does not control.
- **Endpoint paths change.** Brief rule §2 froze them to keep a refactor from becoming
  a migration. The owner has chosen a migration, which is a legitimate call — but the
  protection that rule provided is gone, so the mitigation now has to come from tests
  and from migrating one feature at a time.
- **Every model's `fromJson` retargets** to the new payload shapes. R-10 (defaults
  turning a loud failure into a quiet wrong value) applies to all of them, and the
  fixture tests must be captured from the **new** API, not the old one.
- **Device binding may be unwanted here** (G-2). An attendance kiosk should be bound
  to a handset; an employee checking a payslip from a spare phone arguably should not.
- Two backends run in parallel during migration, and for that period a bug can live in
  either.

**Revisit if:** the backend team cannot staff the 18 endpoints, in which case the
fallback is to add tenancy to `esas-erp-api-modulars` after all — a decision that
should be taken deliberately and early, not discovered halfway through Phase 5.

---

# Amendment — 2026-09-01

Ditulis setelah `tenancy-app` diperiksa langsung, bukan dibaca dari catatan.
Tiga hal berubah, dan dua di antaranya membuat pekerjaan **lebih ringan** daripada
yang dituliskan ADR ini semula.

## A-1 — Permukaan yang dipakai kode menyimpang dari keputusan ini

Consequence 1 di atas menulis: *"`Env.apiPrefix` becomes `/api/v1`. One constant."*
**Kode tidak melakukannya.** `lib/core/config/env.dart` memakai
`/api/selfservice`, atas instruksi owner pada Fase 4, sementara `routes/api.php`
tidak punya namespace itu sama sekali.

Ini bukan pelanggaran diam-diam yang perlu diperbaiki begitu saja — kedua opsi
memenuhi instruksi owner ("path tidak lagi menyebut layout modul backend").
Pertanyaannya dipisahkan menjadi keputusan tersendiri:
**[ADR-0007](0007-self-service-api-namespace.md)**, status *Proposed*, menunggu
owner. Sampai itu dijawab, tidak ada endpoint backend baru yang boleh dibangun,
karena prefiksnya belum pasti.

## A-2 — Permukaan backend yang terverifikasi

`routes/api.php` berisi **20 route**, seluruhnya di bawah `/api/v1`:

| Kelompok | Jumlah | Guard |
|---|---|---|
| Publik (`workspace`, `auth/login`) | 2 | — |
| Handset karyawan | 11 | `auth:sanctum` |
| Mesin absensi (`kiosk/*`) | 7 | `auth:kiosk-device` |

Sebelas route handset itulah permukaan milik aplikasi ini: `auth/me`,
`auth/logout`, `attendance/context`, `attendance/face/challenge`,
`attendance/face`, `attendance/qr`, `qr-presences/context`, `qr-presences`,
`qr-presences/redeem`, `push-tokens`, `push-tokens/forget`.

## A-3 — G-1 tidak lagi memblokir attendance

ADR ini menulis G-1 "**Blocks Phase 4**" karena payload login tidak membawa
`company.latitude/longitude` dan `employee.departement_id`. Setelah diperiksa:

- **`GET /api/v1/attendance/context` sudah mengirim geofence** —
  `location.required`, `latitude`, `longitude`, `radius_metres` — plus
  `server_time`, `schedule.crosses_midnight`, `next_presence`,
  `attendance_enabled`, dan `face_enrolled`. Aplikasi tidak perlu mengambilnya
  dari payload login, dan memang **tidak boleh**.
- **Pemeriksaan departemen QR dilakukan server** di `QrPresenceController::redeem`,
  bersama kedaluwarsa dan single-use. Cek di client adalah UX, bukan kontrol.
  (Catatan: pemeriksaan server itu **fail-open** untuk karyawan tanpa
  `departement_id` — dicatat sebagai temuan backend BE-02 di `01-architecture-audit.md`.)

Yang **tersisa** dari G-1 adalah kebutuhan layar profil (`sign_date`, jabatan,
status, alamat, keluarga, pendidikan, pengalaman) — dan itu dijawab
`GET /profile`, bukan dengan melebarkan payload login. Arsitektur yang sudah
disarankan ADR ini ("login response should say who you are") ternyata juga yang
lebih murah.

**Akibatnya untuk penjadwalan:** attendance dapat dipindahkan ke `/api/v1`
**sekarang**, tanpa menunggu 18 endpoint. Yang tersisa sebagai penghalang nyata
adalah G-3 (abilities token) dan keputusan G-2 (device binding).

## A-4 — Di mana kontraknya hidup sekarang

Peta 24 endpoint tetap di [`06-api-migration-map.md`](../refactoring/06-api-migration-map.md).
**Kontrak yang mengikat** — bentuk payload, urutan pengerjaan, aturan
`Idempotency-Key`, paginasi, kode galat — pindah ke **README Lampiran B**
(`../../README.md`), supaya backend dan mobile membaca satu sumber yang sama dan
bukan dua salinan yang perlahan berbeda.

# 0002 — Feature-first architecture, domain layer only where earned

## Status

Accepted — 2026-08-31 · **Implemented — 2026-09-01** (Fase 0–6). Lihat Outcome di bawah.

## Context

Today a single business feature is spread across three unrelated top-level trees:

```
lib/app/data/attendance/          ← models
lib/app/modules/attendance/       ← controller, view, binding
lib/utils/                        ← helpers the feature depends on
```

The same holds for Permit, Profile, Notification, Activity and Announcement. A
developer changing attendance edits three trees and cannot tell from the structure
what belongs to the feature (MED-08).

Folder naming is also inconsistent — `data/Notification/`, `data/Permit/`,
`data/Profile/` are PascalCase while `data/activity/`, `data/announcement/`,
`data/attendance/` are snake_case. Beyond style, case-only differences break builds
on case-sensitive filesystems such as Linux CI (MED-09).

The obvious counter-proposal is full Clean Architecture: `domain/entities`,
`domain/repositories`, `domain/usecases`, and `data/` implementing domain interfaces,
uniformly for every feature.

Measured against this codebase, that is disproportionate. ESAS is 14,504 lines with
24 controllers and 22 models. Most features are thin: `ActivityController` fetches a
list from one endpoint and renders it. A `GetActivityUseCase` wrapping a
`ActivityRepository` interface implemented by exactly one class, called by exactly one
controller, adds three files and one indirection to deliver nothing. The brief is
explicit: *"A 30-line feature does not need 15 interfaces."*

## Decision

**Feature-first, with a pragmatic two-layer default.**

```
features/<feature>/
├── data/
│   ├── models/
│   ├── services/          # <feature>_api_service.dart — owns endpoints
│   └── repositories/      # application-facing source of truth
└── presentation/
    ├── bindings/
    ├── controllers/
    ├── views/
    └── widgets/
```

Truly shared infrastructure lives in `core/`; the application shell lives in `app/`.

**A `domain/` layer is added only when a feature earns it.** The bar:

- business rules exist independently of any screen or endpoint, **and**
- those rules are used by more than one controller, **or**
- more than one data source must be reconciled behind one contract.

On today's code, **no feature meets that bar**. Attendance comes closest — geofence
validation, mock-GPS rejection, and the department match are genuine business rules
(and CRIT-04 shows the department check is currently wrong). But they are used by one
controller and are better expressed as a tested `AttendanceRepository` method than as
a use-case class hierarchy. Revisit if approval workflows or offline reconciliation
arrive.

Folder and file naming: `snake_case` throughout. The `.m.dart` suffix is dropped —
`models/leave_type.dart`, not `Permit/leave_type.m.dart`.

## Consequences

**Positive**
- Finding attendance code means opening `features/attendance/`. That is the whole point.
- Feature boundaries make one-feature-per-commit migration possible, which is the
  primary mitigation for R-06 (no test safety net).
- Repositories give controllers a seam for injecting fakes, which is what makes tests
  writable at all.
- Consistent snake_case removes the case-sensitivity CI hazard.

**Negative**
- Two structural shapes may coexist if one feature later gains `domain/`. Accepted:
  a uniform shape that is wrong for most features is worse than a mostly-uniform one
  that is right for each.
- "Has this feature earned a domain layer?" is a judgement call and will need
  deciding in review. The bar above exists to make that conversation short.
- Case-only renames need the two-step `git mv` on macOS (R-09).

**Revisit if:** a feature accumulates rules used by several controllers, or ESAS
grows a second data source (offline cache, second backend) that must be reconciled.

---

## Outcome — 2026-09-01

Struktur target tercapai. `lib/app/` kini **tiga berkas** (`app.dart`,
`bindings/initial_binding.dart`, `routing/app_pages.dart`), dan enam fitur berdiri
lengkap dengan `data/` + `presentation/`:

```
features/{auth,home,attendance,permit,notification,profile}/
├── data/{models,services,repositories}
└── presentation/{bindings,controllers,routes,views,widgets}
```

Penamaan `snake_case` konsisten, sufiks `.m.dart` hilang, dan `lib/app/widgets/`
(LOW-01) dihapus — isinya bukan widget.

**Tidak ada fitur yang mendapat `domain/`, dan itu masih jawaban yang benar.**
Attendance — kandidat terkuat — menyelesaikan aturan bisnisnya sebagai tipe yang
diuji, bukan hierarki use-case:

- `QrPayload.matchesDepartment` — 13 test pada matriks id numerik/string/null;
- `AttendanceRepository` — keputusan pindai dan pencarian geofence;
- `LocationService` — izin, deteksi mock GPS, jarak. Mengembalikan hasil, tidak
  menampilkan apa pun.

Ambang "earned" tidak berubah. Kandidat serius berikutnya sudah terlihat: begitu
**Requests + Approvals** tiba (Wave 3 backend, `125-approval-engine`), satu alur
persetujuan akan dipakai beberapa controller sekaligus — di situ `domain/` layak
dibuka, dan bukan sebelumnya.

Satu tambahan aturan yang lahir dari Fase 6 dan layak dicatat di sini: **route
name adalah leaf**. `features/<f>/presentation/routes/<f>_routes.dart` tidak
mengimpor apa pun, `<f>_pages.dart` yang mengimpor view + binding. Tanpa pemisahan
itu, view yang hanya ingin mengeja `/home` akan menarik seluruh view home secara
transitif.

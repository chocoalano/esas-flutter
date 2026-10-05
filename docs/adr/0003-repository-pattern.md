# 0003 — Repository pattern, hand-written models

## Status

Accepted — 2026-08-31 · **Implemented — 2026-09-01**, dengan satu utang terbuka (fixture dari API baru). Lihat Outcome di bawah.

## Context

Controllers currently do everything between the screen and the socket:

```dart
// permit_list_controller.dart:111 — endpoint, query string, and HTTP in a ViewModel
'/hris-module/permits/list/${permitType.value?.id}?page=${page.value}&limit=$pageSize';
```

Consequences measured in the audit:

- 24 endpoint strings embedded in controllers (MED-01)
- query parameters built by string concatenation, so an unescaped value corrupts the request
- 12 files constructing `GetStorage()` directly (CRIT-03, MED-06)
- five profile sub-controllers independently fetching the same `/general-module/auth` (B4)
- no controller is unit-testable without a real HTTP client and the native storage plugin

Separately, the 22 models use two incompatible styles: all-nullable fields with
unchecked map reads (`attendance.m.dart`), and non-null casts that throw on null
(`notification.m.dart` — 40 such casts, MED-04).

Two questions follow: what sits between controller and network, and how are models
written.

## Decision

### Repositories

Introduce one repository per feature as the application-facing source of truth:

```
AuthRepository · SessionRepository · AttendanceRepository
PermitRepository · ProfileRepository · NotificationRepository · HomeRepository
```

Below each, a thin `<Feature>ApiService` owns that feature's endpoints and returns
typed models. Above, controllers depend on the repository only.

```
Controller → Repository → ApiService → ApiClient
                       ↘ LocalStorage
```

Repositories own: DTO→model mapping, caching, refresh policy, and repository-level
error translation. Controllers own: presentation state and orchestration.

Dependencies are **constructor-injected**, not located:

```dart
class AttendanceController extends GetxController {
  AttendanceController(this._repository);
  final AttendanceRepository _repository;
}
```

Bindings supply them — that is where `Get.find` belongs, and nowhere else.

### Models: hand-written, null-safe

**No code generation.** `json_serializable` and `freezed` are not adopted now.

At 22 models, generation would add `build_runner`, a `.g.dart` file per model, a
generation step in every build and CI pipeline, and a rebuild loop during
development — to save boilerplate the team already has written. It would also make
the *migration itself* harder: moving and renaming 22 models while a generator
rewrites them is more moving parts, not fewer, and R-06 says we have no test net.

Instead, standardise on shared null-safe accessors in `core/utils/json_parsers.dart`:

```dart
int?      asInt(dynamic v);
String?   asString(dynamic v);
double?   asDouble(dynamic v);
DateTime? asDate(dynamic v);
```

Every `fromJson` uses these. No bare `json['x'] as String`.

Defaults must be **visibly empty** (`null`, `'—'`, `0`) — never plausible-looking
data. A field that today throws will tomorrow return a default; if that default looks
real, a loud failure becomes a silent wrong value, which for an HRMS is worse (R-10).

**Revisit code generation when** the model count roughly doubles (~45) or models gain
`copyWith`/equality/union requirements that are genuinely tedious by hand.

## Consequences

**Positive**
- Controllers become testable: inject a fake repository, no HTTP, no native plugins.
- Endpoints live in one file per feature; renaming one no longer means grepping.
- The five duplicate `/general-module/auth` calls collapse into one cached read.
- Query parameters go through the `query:` map and get encoded properly.
- Null-safe parsing removes 40 crash sites and makes parse failures diagnosable —
  today they surface as `FormatException('Response format tidak sesuai')` with the
  field name erased (MED-04).

**Negative**
- Roughly 14 new files (7 services + 7 repositories). For the thinnest features this
  is close to pass-through — accepted for uniformity and testability, and the
  alternative (endpoints in controllers) is what we are fixing.
- Hand-written `fromJson` stays verbose and can drift from the API. Mitigated by
  fixture tests built from **real captured responses**.
- Default values are a behaviour change and must be chosen deliberately (R-10).

**Revisit if:** model count roughly doubles, or a second data source appears and
repositories need to reconcile cache and network.

---

## Outcome — 2026-09-01

Terbangun: **7 repository** di atas **6 API service** — `auth` memiliki dua
repository (`AuthRepository` untuk alur, `SessionRepository` untuk penyimpanan
sesi) di atas satu service, dan itu pemisahan yang terbukti berguna saat CRIT-03
ditutup.

```
AuthRepository · SessionRepository · AttendanceRepository
PermitRepository · ProfileRepository · NotificationRepository · HomeRepository
```

Yang terbukti benar:

- **`json_parsers.dart` menghapus 40 cast tak terperiksa** (MED-04). Kegagalan
  parse kini dapat didiagnosis, bukan muncul sebagai `FormatException` dengan nama
  field terhapus.
- **Lima panggilan `/auth` yang duplikat menjadi satu.** `ProfileRepository.currentUser()`
  melakukan cache dan de-duplikasi pemanggil bersamaan; sebelumnya berjalan lima
  tab profil berarti lima permintaan untuk satu objek yang sama.
- **Endpoint tidak lagi di controller.** Seluruh path ada di `core/config/api_routes.dart`
  (MED-01), dan itulah yang membuat pemindahan backend menjadi editan satu berkas.
- **Code generation tetap tidak diadopsi**, dan ambangnya belum tersentuh: jumlah
  model masih di kisaran 30-an, jauh dari ~45.

**Utang yang masih terbuka, dan sengaja tidak ditutup lebih awal:** fixture test
model harus diambil dari **API baru**, bukan API lama (R-10). Selama 18 endpoint
self-service belum ada, fixture yang ditulis sekarang hanya akan mengabadikan
bentuk payload yang akan diganti. Ini menjadi pekerjaan pertama Fase 8 setelah
kontrak di README Lampiran B dilayani.

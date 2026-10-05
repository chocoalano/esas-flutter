# 0001 — Retain GetX

## Status

Accepted — 2026-08-31 · **Implemented — 2026-09-01** (Fase 0–6). Lihat Outcome di bawah.

## Context

ESAS uses GetX for four separate concerns simultaneously:

- reactive state (`.obs`, `Obx`) — ~52 `Obx` sites across 33 views
- controller lifecycle (`GetxController`, `onInit`/`onClose`) — 24 controllers
- dependency injection (`Get.put`, `Get.find`, `Get.lazyPut`) — 21 bindings
- routing (`GetMaterialApp`, `GetPage`, `Get.toNamed`) — 22 routes

80 of 117 files in `lib/` import `package:get/get.dart`. It is not a library the app
uses; it is the substrate the app is written in.

There is a common instinct to replace GetX with Riverpod or BLoC during a refactor of
this kind, on the grounds that GetX encourages the coupling seen in this codebase —
service location from anywhere, implicit global state, navigation without context.

The audit tested that claim against the actual findings. The serious problems are:

- HIGH-07 — `ApiProvider` registered four different ways
- HIGH-06 — eight views calling `Get.put` inside `build()`
- MED-01 — endpoint strings inline in controllers
- CRIT-03 — controllers constructing `GetStorage()` directly
- MED-03 — services showing snackbars

**None of these are caused by GetX.** Each is a missing boundary: no composition
root, no repository layer, no storage abstraction, no separation between
infrastructure and presentation. The same codebase written in Riverpod with the same
missing boundaries would have the same defects, expressed as providers reading
`SharedPreferences` directly instead of controllers reading `GetStorage` directly.

Replacing the state-management library would mean rewriting all 24 controllers, all
21 bindings, all 33 views, and the routing layer — with **one failing starter test**
as the safety net (R-06). That is a rewrite, and the brief explicitly excludes one.

## Decision

**Retain GetX.** Use it for reactive state, controller lifecycle, DI wiring, and
routing.

Constrain it with explicit rules:

1. Bindings declare dependencies. Nothing else registers anything.
2. `Get.put` never appears in a view or a `build()` method.
3. `Get.find` never appears inside a repository, service, or model method —
   constructor injection instead. It is acceptable in a binding, which *is* the
   composition root.
4. Controllers are ViewModels: presentation state and orchestration. No endpoints,
   no JSON parsing, no `GetStorage`, no HTTP.
5. Infrastructure never calls `Get.snackbar` or `Get.toNamed`. It returns results or
   throws; controllers decide presentation.
6. `permanent: true` requires a written justification (see `02-refactoring-plan.md` P2-4).

GetX wires the application. It is not the architecture.

## Consequences

**Positive**
- No rewrite. Refactoring stays incremental and reviewable, one feature per commit.
- The team's existing GetX knowledge stays valid.
- Risk stays proportionate: boundaries can be introduced behind unchanged public APIs.
- If the boundaries hold, a future migration becomes *possible* — controllers that
  depend on repositories rather than on `Get.find` are far easier to port than
  today's controllers.

**Negative**
- GetX's service locator still permits `Get.find` from anywhere. The rules above are
  convention, not compile-time enforcement; they need code review to hold.
- Testing GetX controllers requires `Get.reset()` between tests and care with the
  global registry.
- GetX's maintenance cadence is a known ecosystem concern. This decision should be
  revisited if the package becomes unmaintained — the boundaries established here are
  precisely what would make that revisit affordable.

**Revisit if:** GetX is abandoned upstream, or the constraint rules prove
unenforceable in review over a sustained period.

---

## Outcome — 2026-09-01

Keputusan ini sudah dijalankan sampai Fase 6. Angka konteks di atas adalah angka
**pra-refactor**; angka sekarang:

| | Saat ADR ditulis | Sekarang |
|---|---|---|
| Berkas `lib/` | 117 | 144 |
| View | 33 | 22 |
| Controller | 24 | 17 |
| Berkas binding | 21 | 6 fitur + 1 `InitialBinding` |
| Route | 22 | 22 (path **tidak berubah**, dipatok test) |

Status enam aturan pembatas:

| Aturan | Status | Bukti |
|---|---|---|
| 1. Binding yang mendaftarkan dependensi | ✅ | `InitialBinding` satu-satunya composition root; `ApiProvider` dihapus |
| 2. `Get.put` tidak pernah di view/`build()` | ✅ | HIGH-06 tertutup; seluruh view `GetView` |
| 3. `Get.find` tidak di repository/service/model | ✅ | Constructor injection di seluruh fitur |
| 4. Controller = ViewModel | ✅ | Endpoint pindah ke `ApiRoutes`, JSON ke `json_parsers`, storage ke `LocalStorage`/`TokenStorage` |
| 5. Infrastruktur tidak menampilkan UI | 🟨 | Snackbar `FirebaseMessagingService` dihapus; snackbar `ThemeController` **sengaja dipertahankan** — ia controller presentasi, bukan infrastruktur |
| 6. `permanent: true` beralasan tertulis | ✅ | Tabel justifikasi di dalam `initial_binding.dart` |

Tambahan yang tidak ada di ADR asli tetapi memperkuatnya: **nol `ignore_for_file`
di seluruh `lib/`**, dan pasangan route↔binding dijaga test (`app_pages_test.dart`)
setelah HIGH-01 membuktikan konvensi saja tidak cukup.

Yang membuat "revisit" tetap terjangkau: controller sekarang bergantung pada
repository, bukan pada `Get.find` — porting ke pustaka lain menjadi penggantian
lapisan wiring, bukan penulisan ulang aplikasi.

# 04 — Risk Register

> **Diperbarui 2026-09-01.** Status per risiko dan empat risiko baru (R-20…R-23)
> ada di **Pembaruan 2026-09-01** di akhir berkas. Tabel *Summary* di tengah
> dokumen adalah keadaan saat Fase 0 dan dipertahankan sebagai pembanding.

> Live document. Update status as each risk is retired.
> **Likelihood** = chance the bad outcome occurs if we proceed without the mitigation.

| Scale | Meaning |
|---|---|
| Critical | Security breach, data loss, or app-wide outage |
| High | A core journey (login, attendance, permit) breaks |
| Medium | A screen or feature degrades |
| Low | Cosmetic or developer-only impact |

---

## R-01 — Committed release keystore  🔴 OPEN — BLOCKED ON OWNER

| | |
|---|---|
| **Source** | CRIT-01 |
| **Likelihood** | Certain (already occurred — the file is public) |
| **Impact** | **Critical** |
| **Status** | **Escalated. Requires a human decision. Must not be automated.** |

`esas-keystore.jks` has been public since `65f3b84` (2025-08-26) on
`github.com/chocoalano/esas-flutter`. Passwords are **not** exposed —
`key.properties` appears nowhere in the working tree or history — so the immediate
threat is offline brute-force of the keystore passphrase, not instant compromise.

**Decision the owner must make before any remediation:**

> Has this keystore signed a build distributed to the Play Store or to employees?

| Answer | Consequence |
|---|---|
| Never released | Cheapest path. Generate a new keystore, destroy this one, purge history. |
| Released **with Play App Signing** | Committed key is the *upload* key only. Reset it in Play Console. Users unaffected. |
| Released **self-signed / sideloaded** | Signing identity cannot rotate without breaking in-place upgrades. Requires a coordinated reinstall across the workforce. |

**Mitigation sequence (owner-driven):**
1. Answer the question above.
2. Rotate per the matrix.
3. Purge with `git filter-repo`; force-push; every clone must be re-cloned.
4. Assume permanent public disclosure regardless — GitHub retains unreachable objects and forks.
5. Move the new keystore to a CI secret store.

**Done in Phase 0:** `.gitignore` now blocks future keystores.
**Explicitly NOT done:** the file is still tracked. Ignoring does not untrack.

**Update 2026-09-01 — the owner has confirmed this is a real keystore that was
genuinely created, and multi-tenancy raises the stakes.** Under ADR-0005 a single
signed binary serves every tenant on the platform, so a forged build is a forged
build for **all** hosted companies, not one. Two consequences:

1. Accepting the residual risk is no longer a per-company decision. It is a
   platform-level control.
2. The one remaining question is now the *only* thing gating remediation:

   > **Is Play App Signing enabled for this application?**

   If yes, the committed file is an *upload* key: reset it in Play Console, cheap,
   users unaffected. If no, the signing identity itself is exposed and rotation
   breaks in-place upgrades for every installed handset across every tenant.

**Status: still blocked on that one answer.** Everything else about the remediation
is already decided.

---

## R-02 — Removing the TLS bypass takes the app offline  🔴 OPEN — GATED

| | |
|---|---|
| **Source** | CRIT-02 · **Blocks** P1-9 |
| **Likelihood** | **High** |
| **Impact** | **Critical** (total network failure) |

`HttpOverrides.global` currently accepts every certificate. If
`:9443` serves an invalid or self-signed chain — the most likely reason
this code exists — removing the bypass breaks **every** request instantly.

**Mandatory gate before P1-9 merges:**
```bash
openssl s_client -connect :9443 -servername  </dev/null
# must report: Verify return code: 0 (ok)
```

**Mitigation:** fix the server certificate first (Let's Encrypt). Only then remove
the override. If the certificate cannot be fixed in this cycle, ship P1-9 as
*dev-only isolation* and keep a **scoped, documented** release bypass with a tracked
follow-up — a narrow known exception is strictly better than a silent global one.

**Do not** ship a client-side "fix" that keeps trusting bad certificates.

---

## R-03 — Removing the stored password breaks auto-login and change-password  🟡 MITIGATED BY ORDERING

| | |
|---|---|
| **Source** | CRIT-03 · P3-4 → P3-8 |
| **Likelihood** | High **if done out of order**; Low if sequenced |
| **Impact** | High |

Two consumers depend on the plaintext password:
`SplashController.autoLogin()` (precondition) and
`ProfileChangePasswordController` (client-side comparison).

**Mitigation — the ordering *is* the mitigation:**
`P3-4` (restore logic) → `P3-5` (drop the precondition) → `P3-6` (server-side
current-password check) → `P3-7` (stop writing) → `P3-8` (migrate existing installs).

**Open dependency:** P3-6 needs the backend's response for a wrong current password.
If the server does **not** validate it, that is a backend finding — stop and escalate
rather than keeping the client-side check.

---

## R-04 — Fixing the fail-open department check rejects valid scans  🟡 MITIGATED

| | |
|---|---|
| **Source** | CRIT-04 · P4-7 |
| **Likelihood** | Medium |
| **Impact** | High (attendance is the app's daily core) |

`int.tryParse` requires a `String`. If production QR codes encode
`departement_id` as a **number**, today's code throws; a naive fix that only handles
strings would newly *reject* those scans instead.

**Mitigation:** confirm the real JSON types with the backend team; handle `int`,
`num`, and `String`; write P4-1's test matrix **before** the fix; verify against a
real production QR code.

---

## R-05 — Removing view-level `Get.put` breaks screens  🟡 MITIGATED

| | |
|---|---|
| **Source** | HIGH-06 (8 views) · P4-11, P5, P6-4 |
| **Likelihood** | Medium |
| **Impact** | High (white/red error screen) |

Some views may be the *only* thing registering their controller.
`/permit/create` provably is (HIGH-01).

**Mitigation:** never remove a `Get.put` without first confirming the route's binding
registers that controller. Fix HIGH-01 first. One view per commit, each with a
manual smoke test. Rollback is a one-line revert.

---

## R-06 — Behaviour drift with no test safety net  🔴 OPEN — the dominant structural risk

| | |
|---|---|
| **Source** | Testing gap · every phase |
| **Likelihood** | **High** |
| **Impact** | High |

The suite is one failing starter test. Nothing detects a regression introduced by a
move. **This is the single largest risk in the whole programme** — every other
mitigation ultimately depends on it.

**Mitigation:**
- Phase 1 delivers the abstractions (`LocalStorage`, `ApiClient`) that make
  controllers testable at all — this is *why* Phase 1 precedes every feature move.
- Characterisation tests **before** each feature migration, not after.
- Fixtures must be **real captured responses**; invented fixtures would encode the
  same wrong assumptions the unchecked casts already make and would prove nothing.
- Manual smoke test of the critical journey after every phase.

---

## R-07 — Global 401 logout ejects users unexpectedly  🟡 MITIGATED

| | |
|---|---|
| **Source** | MED-07 · P3-9 |
| **Likelihood** | Medium |
| **Impact** | Medium |

Today a 401 shows a message and the user stays put. A global handler is correct, but
if any endpoint returns 401 for a *permission* problem (where 403 is correct), a
single call would log the whole session out.

**Mitigation:** treat only 401 as session expiry, never 403. Audit each endpoint's
actual 401 semantics. Ship behind a small allowlist if uncertain.

---

## R-08 — Large-scale file moves break imports  🟢 LOW

| | |
|---|---|
| **Source** | MED-08 · Phases 4-5 |
| **Likelihood** | High (occurs) · **Impact** Low (analyzer catches all of it) |

**Mitigation:** one feature per commit; `flutter analyze` after each;
`grep -rn "app/modules/<feature>" lib` must return nothing before the commit lands.

---

## R-09 — Case-only folder renames silently lost  🟡 MITIGATED

| | |
|---|---|
| **Source** | MED-09 · Phases 4-5 |
| **Likelihood** | Medium · **Impact** Medium (CI-only failure) |

macOS is case-insensitive; `git mv Permit permit` can be a no-op in the index, so the
repo keeps `Permit/` and a Linux CI build fails on imports that work locally.

**Mitigation:** two-step rename via a temporary name; verify with `git ls-files`
after each. Ideally run one Linux CI build before Phase 5 ends.

---

## R-10 — Model default values change what users see  🟡 MITIGATED

| | |
|---|---|
| **Source** | MED-04 (40 unchecked casts) · Phases 4-5 |
| **Likelihood** | Medium · **Impact** Medium |

A field that currently throws will start returning a default. The throw is caught
upstream and shown as an error; the default renders as real data. That converts a
loud failure into a **silent wrong value** — arguably worse for an HRMS.

**Mitigation:** choose defaults that are visibly empty (`'—'`, `null`, `0`), never
plausible-looking data. Log a warning on fallback. Fixture tests per model from real
responses.

---

## R-11 — iOS FCM fix depends on unverified APNs configuration  🟡 MITIGATED

| | |
|---|---|
| **Source** | HIGH-03 · P7-2 |
| **Likelihood** | Medium · **Impact** Medium |

The fix assumes the APNs auth key is correctly configured in Firebase. If it is not,
the fix surfaces a new (correct) error where there was previously silence.

**Mitigation:** verify the APNs key in the Firebase console first. Test on a
**physical** iPhone — the simulator cannot obtain an APNs token. A newly visible
error is progress, not a regression; label it as such.

---

## R-12 — Notification changes are hard to verify  🟡 MITIGATED

| | |
|---|---|
| **Source** | HIGH-05 · P7-3 |
| **Likelihood** | Medium · **Impact** Medium |

Six states must be checked: {foreground, background, terminated} × {Android, iOS}.
Easy to under-test, and the double-notification behaviour depends on the server's
message type.

**Mitigation:** a written 6-case checklist executed on real devices. **Do not change
the FCM message type server-side** — that is out of scope; keep the current contract.

---

## R-13 — Application id is `com.example.esas`  🔴 ESCALATED — now a release blocker

| | |
|---|---|
| **Source** | LOW-09 → **HIGH-08** |
| **Likelihood** | Certain · **Impact** High — blocks SaaS distribution |

**Escalated 2026-09-01 by ADR-0005.** A multi-tenant SaaS product must be
distributable, and the Play Store **rejects** the reserved `com.example.*` namespace.
What was cosmetic in a single-company sideloaded app is now a blocker.

The tension: renaming requires new Firebase registrations and, for an app already
published, a **new store listing** — existing installs cannot be upgraded across an
application-id change. This is the same question as R-01: *has this been
distributed, and how?* One answer settles both.

`com.example.*` is Google's reserved sample namespace and is rejected by the Play
Store. But if the app is already distributed, the id **cannot** be changed without a
new store listing and new Firebase registrations.

**Mitigation:** product decision, not an engineering one. Documented here so it is
not "fixed" during a refactor. Investigate distribution status alongside R-01 — the
same question answers both.

---

## R-14 — Refactoring scope creep  🟡 ACTIVE CONTROL

| | |
|---|---|
| **Likelihood** | High · **Impact** Medium |

The audit surfaced 5 critical, 7 high, 13 medium and 11 low findings. The temptation
is to fix everything at once, producing an unreviewable diff.

**Mitigation:** rule §42 — one logical change per commit. Bug fixes are **separate,
labelled** commits, never folded into a move (rule §43). `05-progress.md` tracks what
is actually done, so partial progress stays legible.

---

## Summary

| Status | IDs |
|---|---|
| 🔴 **Open / blocking** | R-01 (Play App Signing?), R-02 (server cert), R-06 (no tests), R-13 (app id), R-15 (backend contract) |
| 🟡 Mitigated by plan | R-03, R-04, R-05, R-07, R-09, R-10, R-11, R-12, R-14, R-16, R-17 |
| 🟢 Low | R-08 |

**Five risks cannot be resolved by this refactor**, and multi-tenancy added two of
them. R-01 needs one answer (Play App Signing yes/no). R-02 and R-17 need server-side
certificates. R-13 needs a product decision on the application id. R-15 defines the
scope of the whole programme and must be answered before Phase 1 completes.

Note that **R-01 and R-13 share one underlying question** — has this app been
distributed, and through which channel? That single answer unblocks both.


---

## R-15 — Backend migration to `tenancy-app`  🟡 RESOLVED AS A DECISION, NOW A DELIVERY RISK

**Resolved 2026-09-01:** self-services migrates onto `tenancy-app` (ADR-0006). The
scope question is answered; what remains is a delivery dependency.

| | |
|---|---|
| **Likelihood** | Certain — 18 endpoints do not exist yet |
| **Impact** | High — Phases 3–5 gate on backend delivery |

**Reassessed downward.** I first called this a rewrite of the data layer. On
inspection `tenancy-app` already holds the whole HRIS domain as models and
migrations; only the API layer over it is missing. 6 of 24 endpoints exist, 18 are
controllers over existing models. HIGH not CRITICAL.

**Mitigation:** build the 18 in the order Phase 5 consumes them, in parallel with
Phase 2 (which has no backend dependency). Do not ask for all 18 at once, and do not
let the Flutter side idle waiting.

**New sub-risks:** R-18 (payload gap), R-19 (device binding).

---

## R-18 — The login payload omits fields attendance cannot work without  🔴 OPEN — BLOCKS PHASE 4

| | |
|---|---|
| **Source** | ADR-0006 G-1 |
| **Likelihood** | Certain today |
| **Impact** | High |

`tenancy-app`'s `profile()` flattens company and employee to strings and omits
`company.latitude`/`.longitude` and `employee.departement_id`. Attendance needs the
first pair to geofence and the second to run the department check that CRIT-04 is
about. Neither is optional.

**Mitigation:** add `GET /api/v1/profile` returning the nested employee record, rather
than widening the login payload. Better separation — login says who you are, it does
not carry the employee file — and it is what the Phase 5 repository wants anyway.

---

## R-19 — Device binding is a policy change nobody has agreed to  🟡 OPEN — NEEDS A DECISION

| | |
|---|---|
| **Source** | ADR-0006 G-2 |
| **Likelihood** | Certain if migrated as-is |
| **Impact** | Medium — user-visible, and support-visible |

`tenancy-app` locks an account to one `device_id` and refuses a second handset until
HR clears it. Self-services has no such rule. Defensible for attendance; questionable
for an employee opening a payslip on a spare phone, and it generates HR tickets.

**Mitigation:** decide before Phase 3 (Q12). If self-services should not be bound,
the binding needs to be per-ability or per-client rather than per-account.

---

## R-15-original — Backend tenancy contract was unknown  ⚪ SUPERSEDED

| | |
|---|---|
| **Source** | TEN-05 · ADR-0005 open question |
| **Likelihood** | Certain (unresolved today) |
| **Impact** | **Critical to scope** |

`esas_attendance` talks to `stancl/tenancy` Laravel over `/api/v1`. ESAS
self-services talks to `:9443` over `/general-module/*` and
`/hris-module/*` — verified absent from the `esas-tenancy` backend.

| If | Consequence |
|---|---|
| The current backend gains tenancy | Client-side change; the plan holds |
| Self-services migrates to `esas-tenancy` | Every endpoint, model and repository changes — **a larger programme than this refactor** |

**Mitigation:** answer Q9 before Phase 1 completes. If it is the second case, decide
sequencing explicitly — refactor onto the current API and migrate later, or migrate
first and refactor onto the new surface. Doing both at once with no test net (R-06)
would be the worst available option.

**Not assumed.** The plan is written for the first case with divergence points marked.

---

## R-16 — Enabling subdomain mode breaks authentication silently  🟡 MITIGATED BY ORDERING

| | |
|---|---|
| **Source** | TEN-02 · P1-12 |
| **Likelihood** | **Certain** if P1-11 ships before P1-12 |
| **Impact** | High |

`_isInternalUri` attaches the bearer token only when the request host equals the
configured base host. In subdomain mode the request goes to
`acme.hrms.example.com` and the base is `hrms.example.com`. The hosts differ, so
**no `Authorization` header is sent** — and the code treats that as normal, not as an
error. It would present as "the backend is rejecting our tokens".

**Mitigation:** P1-12 (explicit `authenticated:` flag) **before** P1-11 (per-request
origin). Test the auth-injection matrix in both modes.

---

## R-17 — Subdomain mode needs a wildcard certificate  🟡 MITIGATED BY STAGING

| | |
|---|---|
| **Source** | TEN-03 · compounds R-02 |
| **Likelihood** | Medium · **Impact** High |

Subdomain tenancy requires `*.domain` DNS **and** a wildcard TLS certificate. The
global bypass (CRIT-02) hides a missing or non-wildcard certificate completely, so it
would surface only when the bypass is removed — breaking every tenant at once, and
looking like the refactor's fault.

**Mitigation:** ship **single-host mode + `X-Tenant` first** — the fallback
`esas_attendance` already supports, and byte-identical to today's behaviour with one
tenant. Enable subdomain mode only after:
```bash
openssl s_client -connect acme.hrms.example.com:443 -servername acme.hrms.example.com
```
verifies clean.

---

## Pembaruan 2026-09-01

Setelah Fase 0–6. Status setiap risiko, lalu empat risiko baru.

| ID | Risiko | Status sekarang | Catatan |
|---|---|---|---|
| R-01 | Keystore ter-commit | 🔴 **terbuka** | Satu pertanyaan yang belum dijawab: Play App Signing aktif? Ia yang menentukan rotasi kunci murah atau merusak upgrade setiap tenant |
| R-02 | Mencabut bypass TLS membuat aplikasi offline | 🔴 **terbuka** | Pengganti sudah ditulis + diuji, **belum dipasang**. Menjadi gerbang keluar Fase 10 |
| R-03 | Menghapus password tersimpan merusak auto-login | ✅ **selesai** | Urutan P3-4→P3-8 bekerja; server memvalidasi password lama, jadi cek client bisa dihapus penuh |
| R-04 | Memperbaiki cek departemen menolak scan yang sah | ✅ **selesai** | 13 test matriks; fail-**closed** |
| R-05 | Menghapus `Get.put` di view merusak layar | ✅ **selesai** | — |
| R-06 | Drift perilaku tanpa jaring test | 🟡 **jauh berkurang** | 1 test gagal → **171 lulus**. Belum nol: belum ada widget/integration test, dan fixture model belum dari API baru |
| R-07 | Logout global karena 401 mengeluarkan user | ✅ **selesai** | 401 saja, request terautentikasi saja; 403 tidak mengakhiri sesi |
| R-08 | Pemindahan berkas merusak import | ✅ **selesai** | — |
| R-09 | Rename beda-kapital hilang di macOS | ✅ **selesai** | — |
| R-10 | Nilai default model mengubah yang dilihat user | 🟡 **aktif** | Default sengaja "terlihat kosong". **Berlaku ulang** untuk setiap `fromJson` yang diarahkan ke API baru di Fase 10c |
| R-11 | Perbaikan FCM iOS bergantung APNs yang belum diverifikasi | 🔴 **terbuka** | Fase 7 |
| R-12 | Perubahan notifikasi sulit diverifikasi | 🔴 **terbuka** | Fase 7 |
| R-13 | `com.example.esas` | 🔴 **terbuka** | Keputusan produk |
| R-14 | Scope creep | 🟡 **terkendali** | Deviasi tercatat satu per satu di `05-progress.md` |
| R-15 | Delivery risk migrasi backend | 🔴 **terbuka dan membesar** | 18 endpoint belum ada, **dan** prefiksnya belum diputuskan (R-20) |
| R-16 | Subdomain merusak autentikasi diam-diam | ✅ **selesai** | `authenticated:` host-independen |
| R-17 | Subdomain butuh wildcard certificate | 🔴 **terbuka** | Sama dengan R-02 |
| R-18 | Payload login tanpa field yang dibutuhkan absensi | 🟡 **separuh selesai** | `attendance/context` menjawab geofence; sisanya `GET /profile`. **Tidak lagi memblokir absensi** |
| R-19 | Device binding adalah perubahan kebijakan | 🔴 **terbuka** | M-D2 |

### R-20 — Dua permukaan API hidup bersamaan  🔴 OPEN — BLOKIR PEKERJAAN BACKEND

Kode memakai `/api/selfservice`; ADR-0006 dan peta migrasi menyebut `/api/v1`;
server tidak punya keduanya secara lengkap.

**Kenapa ini risiko, bukan sekadar inkonsistensi:** 18 endpoint akan dibangun di
salah satu dari keduanya. Membangunnya di tempat yang salah berarti membangun dua
kali, dan bila keduanya sempat hidup — dua tempat untuk memperbaiki bug tenancy.

**Mitigasi:** ADR-0007 mengangkatnya menjadi keputusan eksplisit dengan pemilik
(owner) dan rekomendasi. **Tidak ada endpoint yang dibangun sebelum status ADR itu
*Accepted*.**

### R-21 — Otorisasi backend fail-open  🔴 OPEN — DI LUAR REPOSITORI INI

`WorkspacePermissions::isEnforced()` memberi setiap user setiap aksi pada workspace
yang belum di-seed role — termasuk database hasil adopsi, yang justru pelanggan
migrasi.

**Dampak ke client:** memperluas permukaan mobile di atas otorisasi fail-open
memperbanyak kerusakan, bukan menundanya. Matriks visibilitas di README §125 adalah
niat, bukan kontrol, sampai ini selesai.

**Mitigasi:** dijadikan syarat Gate A; tidak ada layar manajer/finansial yang
dirilis sebelumnya. Pekerjaannya `102-authorization-hardening` di backend.

### R-22 — Satu APK belum benar-benar melayani banyak tenant  ✅ **DITUTUP 2026-09-01**

Seluruh lapisan tenancy siap, tetapi **layar setup workspace tidak pernah dibuat**
(ADR-0005 §4, temuan CLI-01). Workspace hari ini hanya datang dari
`--dart-define=TENANT` atau nilai tersimpan — yang secara praktis berarti satu build
per perusahaan, persis yang ADR-0005 hendak hilangkan.

**Ditutup oleh P10-1…P10-4.** Fitur `features/setup/` mengasi workspace sebelum
sesi: route `/setup`, probe tanpa token ke `GET /api/v1/workspace`, penyimpanan
hanya setelah server mengonfirmasi, gerbang boot di `SplashController`, dan aksi
"Pindah Workspace" yang terpisah dari logout. 26 test baru.

Satu risiko turunan yang **tetap terbuka**: layar ini menerima alamat `http://`
dan mengatakannya tidak terenkripsi, tetapi selama bypass TLS global masih
terpasang (R-02) peringatan itu adalah satu-satunya perlindungan yang ada.

### R-23 — Lisensi model wajah menghambat komersialisasi  🔴 OPEN — DI LUAR REPOSITORI INI

`buffalo_l` (InsightFace) berlisensi non-komersial menurut README layanannya
sendiri, dan ia duduk di dalam fitur paling matang dari platform.

**Dampak ke client:** absensi wajah boleh dibangun dan diuji, tetapi tidak boleh
dijadikan bagian dari penawaran komersial sebelum lisensi diselesaikan.

**Mitigasi:** dinaikkan sebagai syarat Gate E di README §131; keputusan pemilik
produk, bukan keputusan teknis.

---

## Summary — 2026-09-01

| Status | IDs |
|---|---|
| 🔴 Terbuka / memblokir | R-01, R-02, R-11, R-12, R-13, R-15, R-17, R-19, **R-20**, **R-21**, **R-23** |
| 🟡 Aktif / sebagian | R-06, R-10, R-14, R-18 |
| ✅ Selesai | R-03, R-04, R-05, R-07, R-08, R-09, R-16, **R-22** |

Perubahan yang paling berarti sejak Fase 0: **tujuh risiko selesai, dan tidak satu
pun risiko terbuka yang tersisa dapat diselesaikan sendiri oleh tim mobile** —
kecuali R-22, yang justru karena itu harus dikerjakan lebih dulu.

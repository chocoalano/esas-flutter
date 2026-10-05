# 0007 — Namespace API self-service

## Status

**Proposed — 2026-09-01. Menunggu keputusan owner.**
Diturunkan dari [0006](0006-migrate-to-tenancy-app-api.md) §A-1.
Direferensikan sebagai **M-D1** di README §0.4 dan Lampiran C.

> Selama status ini masih *Proposed*, **tidak ada endpoint backend self-service
> yang boleh dibangun**: prefiksnya belum pasti, dan membangun 18 endpoint di
> tempat yang salah lebih mahal daripada menunggu satu jawaban.
>
> **Yang tidak ikut tersandera:** layar setup (P10-1…P10-4, terkirim 2026-09-01).
> Probe workspace memakai `Env.platformApiPrefix` — permukaan platform yang sudah
> menjawab hari ini — bukan `Env.apiPrefix`. Bila ADR ini memilih Opsi A kedua
> nilai itu menyatu dan konstanta kedua berhenti menarik; bila memilih Opsi B
> keduanya tetap terpisah dan tetap benar. Itulah gunanya seam tersebut.

## Context

Repositori ini memberi dua jawaban berbeda untuk satu pertanyaan.

| Sumber | Jawaban |
|---|---|
| ADR-0006 dan `06-api-migration-map.md` | `/api/v1` — 24 endpoint sudah dipetakan ke sana |
| `lib/core/config/env.dart` (kode yang berjalan) | `/api/selfservice` — nilai default `Env.apiPrefix`, dipasang di Fase 4 |
| `tenancy-app/routes/api.php` (kenyataan server) | `/api/selfservice` **tidak ada**; 18 dari 24 endpoint juga belum ada di `/api/v1` |

Instruksi owner pada Fase 4 adalah: path tidak boleh lagi menyebut layout modul
backend (`/general-module/*`, `/hris-module/*`). **Kedua opsi memenuhi instruksi
itu** — `/api/v1/permits` sama-sama tidak menyebut `hris-module`.

Yang sudah terpasang di grup `v1` dan tidak gratis untuk diduplikasi:

```text
/api/v1
├── IdentifyTenantByHeader dijalankan SEBELUM routing   ← syarat keamanan, bukan urutan kebetulan
├── guard terpisah: auth:sanctum vs auth:kiosk-device
├── rate limiter per endpoint (login, face, qr, push, workspace)
├── penamaan route (api.auth.login, api.attendance.context, …)
└── versi di path — APK terpasang tidak ikut ter-deploy
```

`esas_attendance` sudah berjalan di atas semua itu, di produksi.

## Options

### Opsi A — satu permukaan, `/api/v1` (**direkomendasikan**)

Self-service menjadi kelompok resource baru di dalam grup `v1` yang sudah ada.

- Tenancy, guard, rate limiter, dan versioning **diwarisi**, bukan ditulis ulang.
- Dua client, satu kontrak auth, satu siklus token.
- Biaya di sisi Flutter: **satu konstanta** (`Env.apiPrefix`) — dan itu memang
  alasan lapisan konfigurasi dibangun.
- Risiko: nama `v1` menampung dua jenis pemakai (kiosk dan handset). Sudah
  ditangani dengan guard terpisah, dan sudah berjalan hari ini.

### Opsi B — namespace kedua, `/api/selfservice`

- Memisahkan permukaan per client secara eksplisit.
- Harus **menduplikasi** urutan middleware tenancy-sebelum-Sanctum, guard, rate
  limiter, dan kebijakan versi. Setiap duplikasi adalah tempat kedua untuk salah,
  dan yang paling mahal untuk salah adalah urutan tenancy.
- Tidak ada versi di path (`/api/selfservice/...`) kecuali ditambahkan — yang
  berarti mengulang keputusan yang sudah diambil `v1`.
- Biaya di sisi Flutter: nol (kode sudah di sana).

## Decision

*(Menunggu owner.)*

Rekomendasi: **Opsi A.** Alasannya bukan estetika penamaan, melainkan bahwa
namespace kedua menyalin ulang properti keamanan yang sudah terbukti — dan properti
itu (tenancy di-resolve sebelum `auth:sanctum`) adalah satu-satunya yang menjaga
token satu workspace tidak berlaku di workspace lain.

## Consequences

**Bila Opsi A dipilih**

- `Env.apiPrefix` → `/api/v1`; `ApiRoutes` tetap relatif terhadap prefix, jadi tidak
  berubah bentuknya.
- Backend menambah controller di grup `v1` yang sudah ada, mengikuti urutan di
  README Lampiran B.
- ADR-0006 Consequence 1 kembali benar apa adanya.

**Bila Opsi B dipilih**

- Backend membangun grup route baru, dan **wajib** menyalin: middleware tenancy
  dengan prioritas yang sama, guard `auth:sanctum`, rate limiter, dan strategi versi.
- Perlu ADR turunan yang menyatakan bagaimana versi dinyatakan di namespace itu.
- README Lampiran B berlaku apa adanya; hanya prefix yang berbeda.

**Yang tidak boleh terjadi pada kedua opsi:** dua permukaan hidup bersamaan tanpa
tanggal pensiun. Itu berarti dua tempat memperbaiki bug tenancy.

**Revisit if:** muncul client ketiga dengan kebutuhan auth berbeda, atau backend
dipecah menjadi beberapa service — dua-duanya alasan sah untuk meninjau ulang
pemisahan permukaan.

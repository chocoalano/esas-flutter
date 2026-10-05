# 0008 — Identitas jenis izin dibawa oleh kode, bukan oleh id

## Status

**Accepted — 2026-09-02.**
Menutup risiko yang ditemukan pada audit formulir perizinan (2026-09-02).
Mengubah kontrak `GET /permit-types` dan `GET /permits/{id}` secara **aditif**.

## Context

Formulir pengajuan izin di `esas-selfservices` melayani tiga permintaan yang
berbeda dengan satu layar:

| Varian | Field tambahan |
|---|---|
| Izin biasa | — |
| Penyesuaian jam | `timein_adjust`, `timeout_adjust` |
| Penyesuaian shift | `current_shift_id`, `adjust_shift_id` |

Varian mana yang berlaku dibaca dari **kunci primer** jenis izinnya:

```dart
final bool isTimeAdjustment  = controller.selectedPermitTypeId.value == 15;
final bool isShiftAdjustment = controller.selectedPermitTypeId.value == 16;
```

Dua angka itu benar pada satu basis data — basis data tempat barisnya kebetulan
dihitung. `permit_types` adalah tabel milik tenant: setiap perusahaan yang
mengadopsi aplikasi ini membuat jenis izinnya sendiri, dan `id` 15 dan 16 akan
menunjuk apa pun yang kebetulan dibuat kelima belas dan keenam belas. Akibatnya
bukan galat yang terlihat, melainkan formulir yang salah: karyawan yang memilih
"Tukar shift" disuguhi dua kolom jam, mengisinya, dan mengirim pengajuan yang
tidak pernah menyebut shift mana pun.

Ini melanggar batas yang sama dengan ADR-0005: data tenant tidak boleh menjadi
makna aplikasi.

### Apa yang sudah ada, dan apa yang tidak

`LeaveType` di sisi Flutter sudah punya field `code` — tetapi `code` itu berasal
dari skema `leave_types` pada aplikasi cuti yang lain
(`/Users/ict/Documents/Laravel/esas-tenancy`), bukan dari API yang benar-benar
dipanggil aplikasi ini. Pada `tenancy-app`, tabel `permit_types` **tidak punya
kolom `code`** sama sekali; kolom terdekat adalah `category`
(`leave|dispensation|permit|sick`), dan itu menjawab pertanyaan yang berbeda:
di kolom absensi mana sebuah hari dihitung pada slip gaji.

Jadi tidak ada kode kanonik yang bisa dipakai. Ia harus dibuat.

## Decision

**`permit_types.code` menjadi identitas bisnis sebuah jenis izin, dan varian
formulir diturunkan darinya.**

1. Kolom `code` — nullable, unik bila terisi — ditambahkan ke `permit_types`.
2. `App\Enums\Hrms\PermitVariant` menyebut dua kode yang mengubah perilaku:
   `TIME_ADJUSTMENT` dan `SHIFT_ADJUSTMENT`. Kode lain — `ANNUAL`, `SICK`, atau
   tidak ada kode sama sekali — adalah izin biasa.
3. `GET /permit-types` dan objek `permit_type` di dalam detail pengajuan
   mengirim `code` **dan** `variant` (hasil hitungan server).
4. Sisi Flutter menurunkan varian sekali, di `LeaveType.fromJson`, lewat
   `PermitVariant.resolve`. Layar formulir, layar detail, penyusunan payload dan
   validasi memakai hasil yang sama.

### Urutan pembacaan, dan jalan keluarnya

```text
variant kiriman server  →  code  →  pemetaan id peninggalan (15/16)
```

Cabang ketiga sengaja ada dan sengaja usang. Tidak ada satu pun tenant yang
sudah mengisi `code` pada hari ADR ini ditulis; menghapus pemetaan id lebih dulu
berarti mematikan dua jenis izin yang hari ini berfungsi. Cabang itu mencatat
setiap kali dipakai (`AppLogger.warning`), jadi selesainya perpindahan bisa
**dilihat**, bukan diduga.

### Yang sengaja tidak dilakukan: backfill

Tidak ada aturan jujur untuk menebak kode sebuah baris yang sudah ada. Skema ini
tidak pernah punya kode, jenis izin bawaannya tidak memuat satu pun jenis
penyesuaian, dan satu-satunya pegangan pada baris lama adalah namanya — teks
bebas yang ditulis tiap perusahaan dalam bahasanya sendiri. Menebak dari nama
akan memberi sebuah perusahaan formulir yang tidak diminta: persis kegagalan
yang ADR ini ada untuk mengakhirinya.

Maka: setiap baris lama tetap tanpa kode dan tetap berperilaku seperti hari ini.
Operator HR mengisi kode pada dua baris yang ia maksud, dari konsol HRMS.

## Consequences

**Yang menjadi mungkin.** Sebuah tenant boleh punya penyesuaian jam pada id 52
dan penyesuaian shift pada id 87; keduanya tetap membuka formulir yang benar.
Dijaga oleh tes penerimaan di `test/features/permit/permit_variant_test.dart`
dan `tests/Feature/Api/SelfServicePermitTest.php`.

**Payload menyempit.** Server hanya menerima kolom milik varian sebuah jenis
izin — tetapi **hanya untuk jenis yang sudah punya kode**. Tenant yang belum
memindahkan kodenya tidak berubah perilakunya sedikit pun; menyempitkannya
berdasarkan varian yang saat ini terbaca `general` justru akan membuang kolom
yang menjadi seluruh isi permintaan itu.

**Kontrak bertambah, tidak berubah.** `code` dan `variant` adalah kunci baru.
`current_shift`/`adjust_shift` yang lama tetap dikirim apa adanya di samping
`shift_from`/`shift_to` yang baru, karena aplikasi yang sudah terpasang di
ponsel orang tidak ikut dirilis ulang bersama server.

**Yang harus dilakukan sebelum pemetaan id bisa dihapus.**

1. Migrasi dijalankan pada seluruh basis data tenant.
2. Operator mengisi `code` pada jenis penyesuaian jam dan penyesuaian shift di
   tiap tenant.
3. Log peringatan "memakai pemetaan id peninggalan" berhenti muncul.
4. `PermitVariant._legacyIdFallback` dihapus — ia hanya punya satu pemanggil,
   dan menghapusnya tidak mengubah apa pun yang lain.

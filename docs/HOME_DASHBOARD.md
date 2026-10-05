# Beranda ESS — keputusan yang mengikat

Berkas ini mencatat keputusan yang **tidak terbaca dari source code**: mengapa
sebuah bagian ada di tingkat tertentu, dari mana sebuah angka datang, dan berapa
permintaan yang boleh ditembakkan layar ini. Yang bisa dibaca langsung dari kode
tidak diulang di sini.

---

## 1. Tiga tingkat, dan tiap tingkat punya BENTUK

Beranda pernah menjadi delapan bagian yang berat visualnya nyaris sama — semuanya
kartu putih, garis 1px, radius sama, dipisahkan jarak 24 yang identik. Mata tidak
punya tempat mendarat.

### Panel protagonis adalah STRUKTUR, bukan sebuah cabang

Pelajaran termahal dari layar ini, dan ia ditemukan di simulator — bukan oleh
satu pun dari 3.800 tes yang lulus saat itu.

Sebuah gelombang sebelumnya menukar seluruh `TodayWorkCard` dengan satu
`AppInlineNotice` begitu absensi gagal dimuat. Secara teknis benar: kalimatnya
tepat, nadanya tepat, tombolnya tepat. Secara produk ia menghancurkan halaman —
pada akun yang absensinya dijawab **403**, Beranda menjadi kepala halaman, satu
kalimat abu-abu, lalu langsung akses cepat. Dasbor kehilangan jangkarnya persis
pada saat sesuatu sedang salah, dan akses cepat naik menjadi isi utama layar.

**Aturannya sekarang: tidak ada cabang yang boleh menghapus panel itu.** Yang
berubah hanya isinya.

| Keadaan | Isi panel |
|---|---|
| hari kerja | shift, angka protagonis, rel jadwal, dua fakta jam, tombol |
| hari libur / cuti / tanpa jadwal | tanggal, judul, kalimat, tautan riwayat |
| absensi tidak diizinkan (403 / `attendance_enabled: false`) | tanggal, "Absensi belum tersedia", **tanpa tombol** |
| sesi berakhir (401) | tanggal, "Sesi perlu diperbarui", "Masuk kembali" |
| jaringan / server | tanggal, "Absensi belum dapat dimuat", "Coba lagi" |

Anatominya sama di setiap baris — eyebrow, tanggal, judul, kalimat, aksi
opsional — dan hanya kekayaannya yang berbeda. Tidak ada `AttendanceHero` dan
`UnavailableHero` yang terpisah; satu widget, beberapa varian.

Kapabilitas yang tidak diberikan **bukan galat**: tidak ada yang rusak, tidak
ada yang perlu dicoba lagi, dan mencoba lagi hanya akan ditolak lagi. Ia netral,
seperti hari libur — bukan merah.

---

### Zona keempat: konteks pribadi

Beranda pernah berhenti mendadak sesudah korsel pengumuman, dan pada layar
tinggi sisanya kosong sampai bilah navigasi. Penyebabnya **bukan** artefak tata
letak — tidak ada `Spacer`, `Expanded`, atau tinggi tetap yang mendorong apa
pun. Penyebabnya adalah aritmetika bagian: zona di bawah pengumuman hanya berisi
SATU bagian ("Ringkasan bulan ini"), dan bagian itu menyembunyikan dirinya
sendiri begitu datanya kosong. Nol bagian menghasilkan nol tinggi.

Dua perubahan menutupnya, keduanya tanpa satu permintaan baru:

1. **"Sisa cuti" pindah ke bawah pengumuman.** Tempatnya dulu di atas, berdempet
   dengan akses cepat — salah dua kali: ia bukan aksi, dan ia bukan kabar
   perusahaan. Ia konteks pribadi, dan urutannya datang sesudah keduanya.
2. **Kosong ≠ gagal ≠ ada.** Ketiganya sekarang tiga keadaan yang berbeda:

| Keadaan | Yang digambar |
|---|---|
| ada isinya | ubin metrik |
| berhasil dimuat, isinya kosong | judul bagian + **satu baris** tenang |
| gagal dimuat | **hilang sama sekali**, tanpa satu kata pun |

Kegagalan bagian sekunder sengaja senyap. Kegagalannya sudah tercatat di log
oleh `HomeController._load`, dan sebuah dasbor yang memasang peringatan di
setiap bagian sekunder mengajari orang untuk mengabaikan semua peringatannya —
termasuk yang penting.

Urutan akhirnya: **hari ini → aksi → kabar perusahaan → konteks pribadi.**

---

| Tingkat | Isi | Bentuknya |
|---|---|---|
| 1 — mendominasi | `TodayWorkCard` + `TodayTimeline` | rim brand, kilau `brandGlow`, satu angka besar, satu tombol; keduanya berjarak 12 sehingga terbaca sebagai satu blok, sementara semua tetangganya jauh. **Tanpa `AppSectionHeader`** — hal terpenting tidak diperkenalkan micro-label yang sama dengan semua yang lain |
| 2 — menopang | akses cepat, sisa cuti | di atas kanvas yang sama, dipisahkan jarak saja; **tidak ada satu pun nada warna di dalamnya**. Pita `surfaceSubtle` yang sempat menampungnya sudah dihapus: bedanya dengan kanvas hanya 1,02:1, jadi yang benar-benar terlihat darinya cuma dua garis rambut selebar layar — dan dua garis itu membuat halaman terbaca seperti halaman pengaturan yang dikelompokkan |
| 3 — mundur | pengumuman, rekap bulanan | kembali ke kanvas telanjang, didahului jarak 32 karena ini pergantian topik |

Aturan warna yang berlaku di seluruh halaman: **sebuah hitungan adalah fakta, dan
fakta digambar redup. Warna disediakan untuk keadaan yang menuntut tindakan, dan
satu-satunya tempat keadaan dinyatakan adalah panel protagonis.**

Pengecualian gradient/radius untuk panel protagonis dicatat di
[DESIGN_GUIDE.md](./DESIGN_GUIDE.md) aturan 2.

---

## 2. `HomeTodayState` adalah satu-satunya sumber kebenaran

Kesimpulan tentang hari ini diambil **sekali**, di `HomeController.todayState`.
Sebelum ada enum ini, empat widget masing-masing menyusun ulang cabangnya sendiri
dari `timeIn`, `timeOut` dan `attendanceError`, dan ketiganya sempat tidak
sepakat di layar yang sama: panel utama menggambar "Belum Absen" merah sementara
strip di bawahnya menggambar em dash bertuliskan "absen tidak terbaca".

Urutan cabangnya bagian dari kontrak:

1. `loading` — pembukaan dingin.
2. `working` / `done` — **ketukan yang sudah tercatat mengalahkan galat.** Jam
   yang sudah sampai tetap benar walaupun penyegaran berikutnya gagal.
3. `unavailable` — galat, dan tidak ada satu pun jam yang sempat sampai.
4. `notClockedIn` — **ada jadwal.** Jadwal mengalahkan kalender: orang yang
   dirosterkan pada hari raya tetap melihat shiftnya dan tombolnya.
5. `holiday` / `dayOff` / `onLeave` — tidak ada jadwal, dan server mengatakan
   hari apa ini.
6. `noSchedule` — tidak ada jadwal, dan server tidak mengatakan apa-apa.

### Narasi bukan izin

`todayState` menentukan KALIMAT. Ia tidak pernah menentukan apakah seseorang
boleh mengabsen. Itu dijawab `canPunchNow`, yang hanya membaca dua fakta milik
server: `attendance_enabled` dan `next_presence`. Sebuah layar yang menyimpulkan
"hari libur, berarti tidak boleh absen" akan mengunci orang yang benar-benar
masuk kerja.

---

## 3. `day_context` — perluasan yang backward-compatible

Dibaca dari respons `GET /attendance/context` yang **sudah dipanggil** Beranda.
Tidak ada permintaan tambahan.

```jsonc
{
  "attendance": { … },
  "schedule":   { … },
  "attendance_enabled": true,
  "next_presence": "in",

  "day_context": {                 // ← tambahan, opsional
    "type": "workday | day_off | holiday | leave",
    "label": "Hari libur nasional",     // opsional, siap tampil
    "holiday_name": "Hari Kemerdekaan"  // opsional
  }
}
```

Tiga aturan yang mengikat pembacaannya, dan semuanya sudah dites:

- **Blok yang tidak ada bukan kesalahan.** `day_context: null` mengembalikan
  layar ke perilaku lama (`noSchedule`), karena aplikasi ponsel hidup lebih lama
  daripada satu rilis backend.
- **Tipe yang tidak dikenali menjadi `null`, bukan `workday`.** Menebak "hari
  kerja" untuk nilai yang belum dimengerti adalah cara tercepat menyodorkan
  tombol absen pada hari orang tidak bekerja.
- **Ejaannya dibaca longgar** (`PUBLIC_HOLIDAY`, `public-holiday`, `holiday`),
  karena penamaan enum di backend belum final.

Nama hari libur ditampilkan **apa adanya dari server**. Kalender hari libur milik
tenant; aplikasi ponsel tidak punya daftar yang bisa dipercaya.

---

## 4. Hitungan notifikasi — dari sesi, tidak pernah dari Beranda

```
payload sesi (/auth/login, /auth/me)
        │  unread_notification_count
        ▼
SessionRepository.unreadNotifications ◄── layar notifikasi menerbitkan
        │                                  `unread_count` yang memang sudah
        ▼                                  dibawa setiap halamannya
HomeRepository → HomeController → HomeHeader (dan bilah navigasi, bila perlu)
```

**Beranda tidak memanggil endpoint notifikasi dan tidak akan.** Satu permintaan
HTTP untuk sebuah titik merah adalah harga yang salah di jaringan pabrik.

Semantiknya, dan ini bagian dari kontrak:

| Pertanyaan | Jawaban |
|---|---|
| Namanya | `unread_notification_count`, bukan `notification_count` — yang digambar lencana adalah yang **belum dibaca**, dan nama yang tidak menyebutkannya akan diisi jumlah seluruh notifikasi cepat atau lambat. Ejaan pendek tetap diterima sebagai cadangan |
| Cakupannya | notifikasi milik karyawan yang sedang masuk, pada tenant yang sedang aktif. Tidak pernah lintas tenant |
| Yang diarsipkan | tidak dihitung |
| Yang sudah dibaca | tidak dihitung |
| Setelah membuka notifikasi | layar notifikasi menerbitkan hitungan barunya ke sesi, jadi lencana Beranda menyusul tanpa permintaan tambahan |
| `null` | **belum diketahui**, dan lencananya tidak digambar sama sekali. Nol yang dikarang akan berbohong setiap pagi |
| Ganti akun | dibuang di `SessionRepository.clear()` — hitungan orang sebelumnya tidak menyeberang ke sesi berikutnya di handset yang sama |

---

## 5. Strategi permintaan

Empat panel berjalan **bersamaan**, masing-masing dengan slot galatnya sendiri.
Satu panel yang gagal tidak menjatuhkan tiga lainnya, dan tidak satu pun memakai
toast — empat toast berturut-turut saat sinyal hilang adalah cara memberi tahu
orang bahwa aplikasinya rusak.

| Jawaban | Di-cache? | Alasan |
|---|---|---|
| `attendance/context` | tidak | alasan layar ini dibuka. Sesudah absen, jawaban berumur sepuluh menit akan menggambar "belum absen" |
| `announcements?active=1` | tidak | satu-satunya kanal kabar mendadak |
| `me/leave-balance` | tidak | berubah karena tindakan **di dalam aplikasi ini**: seseorang mengajukan izin lalu kembali ke Beranda |
| `attendance/summary` | ya, 10 menit | berubah paling banyak sekali sehari. Konsekuensi yang diterima: sesudah absen pulang, rekap bisa tertinggal sampai sepuluh menit — bagian paling sekunder di halaman, dan tarik-untuk-menyegarkan memaksanya seketika |

Cache-nya **dikunci ke id karyawan**, bukan hanya ke waktu. Satu handset dipakai
lebih dari satu orang di pabrik; yang salah bukan umur jawabannya, melainkan
pemiliknya.

`refresh: true` hanya dikirim oleh dua gestur yang artinya "saya tidak percaya
angka di layar": tarik-untuk-menyegarkan, dan tombol coba lagi.

### Anggaran permintaan

| Skenario | Permintaan | Isinya |
|---|:--:|---|
| Peluncuran dingin | 5 | `/auth/me` + empat panel |
| Kembali ke Beranda dari tab lain (≤10 mnt) | 3 | context, announcements, leave-balance |
| Tarik-untuk-menyegarkan | 4 | keempatnya, dipaksa |
| Kembali dari absen | 3 | context ikut, dan memang harus |
| Kembali dari pengajuan izin | 3 | saldo cuti ikut, dan memang harus |

### Penyegaran yang saling mendahului

`refreshDashboard` memberi nomor urut pada setiap penyegaran, dan hanya yang
**terbaru** boleh menulis. Urutan yang ditutupnya nyata dan tidak jarang:
`onInit` memulai A, pengguna menarik untuk menyegarkan sebelum A selesai, B
selesai lebih dulu, lalu A mendarat membawa data basi.
`RefreshIndicator` menahan tarikan kedua karena ia menunggu future-nya — tetapi
ia tidak tahu apa-apa tentang permintaan yang dimulai `onInit`.

---

## 6. Kegagalan dibaca dari STATUS, bukan dari kalimat

Slot galat bertipe `ApiException`, sehingga status HTTP-nya utuh sampai ke layar.

| Status | Kalimat di layar | Tombol |
|---|---|---|
| transport (tanpa status) | "Tidak ada koneksi. Data terakhir tetap ditampilkan." | Coba lagi |
| 401 | "Sesi Anda perlu diperbarui untuk melanjutkan." | Masuk kembali |
| 403 | "Fitur ini tidak tersedia untuk akun Anda." | **tidak ada** |
| 5xx | "Server sedang bermasalah. Coba lagi sebentar lagi." | Coba lagi |
| lainnya | kalimat cadangan milik panel | Coba lagi |

**Kalimat server tidak pernah ditampilkan di Beranda.** Yang benar-benar dikirim
backend hari ini berbunyi *"Sesi ini dibuat sebelum fitur tersebut ada"* — rincian
implementasi yang tidak berarti apa pun bagi staf pabrik.

Versi pertama memilih tombolnya dengan mencocokkan substring bahasa Indonesia.
Itu penopang sementara yang pecah pada tiga hal yang wajar terjadi: seseorang
memperbaiki tata bahasa sebuah pesan, sebuah instalasi menjawab dalam bahasa
lain, dan sebuah backend menjawab 401 tanpa menyebut kata "sesi".

---

### Status transport bukan fakta produk

Aturan yang lahir dari sebuah laporan lapangan: akun yang absensinya **jelas
aktif** tetap dikabari Beranda bahwa fiturnya belum aktif.

Datanya tidak salah. **Kesimpulannya** yang salah: layar memetakan `403` menjadi
kalimat *"Fitur absensi belum aktif untuk akun ini."* — sebuah pernyataan
tentang konfigurasi karyawan yang aplikasi tidak punya buktinya sama sekali.

Sebuah `403` pada `attendance/context` bisa berarti abilities token yang terlalu
sempit (README gap **G-3**: token dicetak dengan `['attendance']` saja, sehingga
endpoint self-service ditolak sampai diperlebar), guard rute, kebijakan tenant,
atau konfigurasi deployment. Tidak satu pun dari itu berarti "HR mematikan
absensi untuk orang ini".

| Sumber | Boleh mengklaim kapabilitas? |
|---|---|
| `attendance_enabled: false` pada respons **200** | **Ya.** Servernya sendiri yang mengatakannya |
| `403` | **Tidak.** Yang diketahui hanya bahwa permintaannya ditolak |
| `401`, 5xx, transport | Tidak |

Kalimat untuk `403` karena itu tidak menyebut akun sama sekali: *"Absensi belum
dapat dimuat / Data absensi sedang tidak dapat diakses."*, dengan **Coba lagi** —
sebabnya ada di server dan bisa berubah tanpa aplikasi dipasang ulang. Yang
sengaja tidak ditawarkan adalah *Masuk kembali*: mengakhiri sesi untuk menebak
sebuah penolakan yang tidak dimengerti adalah kerusakan yang pasti demi
perbaikan yang belum tentu.

### Cara membedakannya di lapangan

Setiap panel yang gagal sekarang menulis satu baris ke log — `AppLogger.warning`
bertahan di build rilis, dan token/NIP/sandi sudah diredaksi:

```
Panel beranda gagal dimuat {status: 403, code: …, transport: false}
```

- `status: 403` → urusan server (abilities/guard/tenant). Absensi karyawan
  kemungkinan besar **aktif**; yang ditolak adalah permintaannya.
- tidak ada baris log, dan panel berkata "Fitur absensi belum aktif untuk akun
  ini" → respons **berhasil** dan servernya sendiri mengirim
  `attendance_enabled: false`. Ini yang perlu diperiksa di panel HR.

---

## 7. Pengumuman: dua hal yang harus dijaga

**Entitas HTML.** `excerpt` dan `content` sama-sama dikirim server sebagai
potongan HTML. Baris daftar dulu memakai `excerpt` **apa adanya** dan hanya
membersihkan `content` — dan karena `excerpt` lebih didahulukan, jalur yang
bersih justru tidak pernah terpakai. Hasilnya `&nbsp;BERIKUT LINK UNTUK
MENGAKSES FILE TERSEBUT` tergambar ke layar. Keduanya sekarang melewati
`htmlToPlainText`, yang juga mendekode entitas **numerik** (`&#160;`, `&#x201C;`)
sebelum menormalisasi spasi — urutannya penting, karena spasi mati yang baru
menjadi karakter harus ikut diratakan.

**Perataan carousel.** `padEnds: false` + `viewportFraction: 0.88` + margin kiri
dari halaman berarti kartu pertama rata dengan margin dan kartu berikutnya
mengintip di kanan. Perilaku itu sudah benar dan sekarang **dipaku sebuah tes**
yang mengukur tepi kiri kartu pertama; potongan kartu sebelumnya di sisi kiri
hanya muncul kalau deretannya memang sedang digeser.

---

## 8. Yang MASIH menjadi gap — status per audit backend

Audit dijalankan terhadap seluruh repositori di mesin ini. Ringkasnya: **backend
kanonis yang melayani aplikasi ini TIDAK ada di workspace.**

### Backend mana yang ada, dan mana yang tidak

| Repositori | Apa itu | Melayani `attendance/context`? |
|---|---|---|
| `esas-api` | backend LAMA (`auth/profile-current-attendance/{userId}` — endpoint ber-id yang sudah ditinggalkan ADR-0006) | tidak |
| `esas-erp-api-modulars` | backend modular yang diretire ADR-0006 | tidak |
| `esas-tenancy` | panel HRMS Laravel 12 + Inertia. **Memiliki domain HR-nya**, tetapi permukaan API-nya hanya `auth/login`, `auth/logout`, `attendance/face/*` | tidak |
| lainnya | tidak berkaitan | tidak |

`grep -rl "attendance/context"` dan `grep -rl "next_presence"` di seluruh
`~/Documents` **tidak menghasilkan satu berkas pun** di luar aplikasi ini.
Kesimpulannya bukan "belum ketemu" melainkan **tidak ada di sini**; endpoint yang
dipanggil aplikasi dilayani deployment (`:9443/api/v1`) yang sumbernya
tidak tersedia untuk dibaca maupun diubah.

Karena itu tidak ada satu baris backend pun yang ditulis pada audit ini, dan
tidak ada rute Laravel palsu yang dibuat agar sesuatu tampak selesai.

### 403 pada `attendance/context`

**Yang diketahui pasti** (bukti runtime, bukan dugaan):

- Payload sesi akun yang bersangkutan berisi `"attendance_enabled": true`.
  Servernya sendiri menyatakan absensi AKTIF untuk orang ini.
- `announcements` dan `permits` **berhasil** pada token yang sama, pada
  pembukaan Beranda yang sama.
- Hanya `attendance/context` yang menjawab **403**.

**Yang TIDAK bisa ditentukan:** middleware, guard, ability, atau policy mana yang
menolaknya — sumbernya tidak ada di mesin ini. Menebak lebih jauh tidak berguna.

> **Koreksi terhadap catatan lama.** Dokumen sebelumnya menduga penyebabnya
> adalah gap **G-3** (token dicetak dengan abilities `['attendance']` saja).
> Observasi di atas **membantah dugaan itu**: kalau token hanya punya ability
> `attendance`, yang gagal seharusnya `announcements` dan `permits`, bukan
> `attendance/context`. Yang terjadi persis kebalikannya. Dugaan itu tidak boleh
> lagi dikutip sebagai fakta.

### Kontrak yang menunggu backend

| Gap | Sumber kanonis | Status |
|---|---|---|
| `day_context` | **ADA** di `esas-tenancy`: `roster_schedules.is_day_off`, tabel `holidays` + `employee_holidays`, `leave_requests` | domainnya lengkap; **API-nya tidak ada di sini** |
| `unread_notification_count` | payload sesi (`auth/login`, `auth/me`) | belum dikirim; jalur mobile sudah siap ujung ke ujung |
| Jam istirahat | **ADA**: `shift_breaks` (`shift_id`, `name`, `start_time`, `end_time`, `duration_minutes`, `is_paid`) — satu shift boleh punya beberapa istirahat | domainnya lengkap; belum ada API |
| Lokasi kerja hari ini | **TIDAK ADA.** `work_locations` ada dan `employees.work_location_id` ada, tetapi `roster_schedules` **tidak menyimpan lokasi per hari** | hanya "lokasi induk karyawan" yang bisa diketahui, dan itu bukan "lokasi kerja hari ini" — jadi tidak ditampilkan |

Aturan yang berlaku untuk semuanya: **field baru harus opsional.** Aplikasi
ponsel bisa lebih baru daripada backend, dan sebaliknya. Pembacaan `day_context`
dan `unread_notification_count` di sisi mobile sudah ditulis dan dites dengan
sifat itu, jadi backend dapat menyusul kapan saja tanpa rilis mobile baru.

### Precedence `day_context` ketika backend dibangun

Narasi dan izin adalah dua hal berbeda, dan pemisahan itu sudah berlaku di
aplikasi: `day_context` hanya memilih KALIMAT, sementara tombol absen diatur
`attendance_enabled` + `next_presence`. Karena itu sebuah hari raya yang tetap
dirosterkan harus tetap mengirim `next_presence`, apa pun `day_context`-nya —
dan aplikasi sudah menggambar tombolnya (diuji: "jadwal mengalahkan kalender").

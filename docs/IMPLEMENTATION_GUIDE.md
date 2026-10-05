# Panduan Implementasi — redesain "Instrumen"

Dokumen ini menjelaskan cara mengerjakan redesain: urutannya, batas-batasnya,
dan jaminan yang dipegang test suite. Aturan visualnya ada di
[DESIGN_GUIDE.md](./DESIGN_GUIDE.md), API komponennya di
[COMPONENT_REFERENCE.md](./COMPONENT_REFERENCE.md).

## Menilai perubahan UI di simulator

**Jangan menilai perubahan sumber dengan meluncurkan ulang aplikasi yang sudah
terpasang di simulator.** Pada build debug iOS seluruh kode Dart berada di
`App.framework`; membuka aplikasi dari layar utama simulator memutar ulang
cuplikan yang terakhir dipasang, bukan yang terakhir ditulis.

Empat gelombang redesain Beranda pernah tampak "tidak berubah sama sekali"
karena ini: binari yang berjalan delapan jam lebih tua daripada sumbernya.
Pemeriksaan yang membuktikannya satu baris —

```bash
find lib -name '*.dart' -newer build/ios/iphonesimulator/Runner.app/Frameworks/App.framework/App
```

Apa pun yang keluar dari perintah itu belum ada di layar. Pakai `flutter run`,
atau pasang ulang:

```bash
flutter build ios --simulator --debug
xcrun simctl install booted build/ios/iphonesimulator/Runner.app
```

## Push notification iOS — apa yang bisa dan tidak bisa dibuktikan di sini

`aps-environment` diatur per konfigurasi, mengikuti konvensi macOS yang sudah
ada di repositori ini:

| Konfigurasi | Berkas | Nilai |
|---|---|---|
| Debug, Profile | `ios/Runner/DebugProfile.entitlements` | `development` |
| Release | `ios/Runner/Release.entitlements` | `production` |

Diverifikasi dengan `xcodebuild -showBuildSettings` pada ketiga konfigurasi,
bukan dengan membaca berkasnya saja.

**`APNs Token: null` di simulator BUKAN bukti kerusakan.** Simulator iOS tidak
pernah menerbitkan token APNs sungguhan, jadi nilai itu wajar di sana dan tidak
mengatakan apa pun tentang perangkat nyata. Bukti yang dipakai untuk memperbaiki
konfigurasi ini adalah tidak adanya `CODE_SIGN_ENTITLEMENTS`, tidak adanya
berkas entitlements iOS, dan tidak adanya `aps-environment` di seluruh
repositori — ketiganya fakta konfigurasi.

Yang **tidak** bisa dibuktikan dari repositori: profil provisioning yang memuat
kapabilitas Push, kunci APNs di Firebase Console, dan apakah server benar-benar
menyimpan token yang didaftarkan. Ketiganya perangkat nyata dan akun, bukan
berkas.

## Prinsip kerja

1. **Kode adalah kebenaran.** Dokumen menyusul kode. Versi dokumen sebelumnya
   meresepkan gradient, hover shadow, dan palet status Tailwind yang tidak ada
   di `app_colors.dart` — dan sebuah layar benar-benar mengimplementasikan
   resep itu. Kalau sebuah aturan di dokumen tidak bisa ditunjuk ke
   `lib/core/theme/`, aturan itulah yang salah.
2. **Token lebih dulu, lalu komponen, lalu layar.** Membalik urutan ini membuat
   aplikasi terlihat lebih buruk di tengah jalan: komponen padat yang dibangun
   di atas kontras teks lama menghasilkan lebih banyak teks yang tidak terbaca,
   bukan lebih sedikit.
3. **Kompatibel API atau penerus tipis.** Komponen yang sudah punya call site
   tidak boleh berubah tanda tangannya dalam satu langkah dengan layarnya.
   Kalau perlu digabung, tinggalkan penerus tipis dan hapus setelah semua
   pemanggil pindah — tanpa anotasi `@Deprecated`, supaya `flutter analyze`
   tetap bersih.
4. **Nol suppression baru.** Tidak ada `// ignore:`, tidak ada tambahan di
   `analysis_options.yaml`.
5. **Nol dependensi baru.** Sparkline, strip hari, dan bar bersegmen digambar
   dengan `CustomPainter` dan `Row of Container`; tidak ada pustaka chart.

## Urutan pengerjaan

| Gelombang | Isi | Catatan |
|---|---|---|
| 0 — Fondasi | `app_colors.dart`, `app_palette.dart`, `app_typography.dart`, `app_dimens.dart`, `app_theme.dart`, `app.dart`, `theme_controller.dart` | Mendarat sendirian. Menggeser bobot setiap tepi kartu, divider, dan baris metadata secara bersamaan |
| 1 — Pembersihan dan dokumen | hapus file yatim, koreksi dokumen | Paralel dengan Gelombang 0; tidak berbagi satu file pun |
| 2 — Komponen | `lib/core/ui/**` | Tidak boleh menyentuh `lib/features` |
| 3 — Layar | `lib/features/**` per fitur | Satu implementer per fitur |
| 4 — Penutupan | hapus penerus tipis, tambah probe overflow | Setelah semua pemanggil pindah |

Setiap gelombang wajib disertai lintasan manual berdampingan pada dua layar
terpadat (riwayat absensi dan detail izin) di **kedua** tema, mode terang lebih
dulu. Tidak ada golden test di repo ini; lintasan manual adalah satu-satunya
pertahanan terhadap regresi visual.

## Gelombang 1 — sudah dikerjakan

### File yang dihapus

- `lib/core/ui/examples/modern_home_screen_example.dart` — tidak dirutekan dan
  tidak diimpor apa pun, tetapi ikut ter-compile ke biner rilis dan dijadikan
  contoh acuan oleh dokumen, sehingga pelanggaran paletnya menular.
- `lib/core/ui/components/app_stat_card.dart` — nol call site produksi; satu-
  satunya konsumennya adalah file contoh di atas.
- `lib/features/home/presentation/widgets/summary_grid.dart`,
  `summary_card.dart`, `recent_activity.dart`, `quick_actions.dart`,
  `activity_tile.dart` — yatim setelah Beranda dibangun ulang di atas komponen
  inti; tidak ada satu pun yang diimpor dari mana pun.

Sebelum penghapusan, dua potong logika dipanen untuk dipakai kembali oleh
Beranda: pemetaan teks status menjadi `AppBadgeTone` (`summaryStatusTone`) dan
pemetaan aksi audit (`created`/`updated`/`deleted`) menjadi nada palet.

### Dokumen yang dikoreksi

`DESIGN_GUIDE.md`, `DESIGN_SYSTEM.md`, `COMPONENT_REFERENCE.md`, dan dokumen
ini. Yang dihapus dari dokumen: palet status Tailwind (`#10B981`, `#F59E0B`,
`#EF4444`, `#3B82F6`) yang tidak pernah ada di kode, "gradient background
subtle", setiap saran hover, contoh format `08:15 AM` dan `8h 45m`, serta baris
tabel untuk komponen yang dihapus. Yang ditambahkan: aturan sebenarnya
(elevasi 0, tanpa shadow, tanpa gradient, radius maksimum 12, warna status dari
`AppTone`) dan kolom call site yang jujur pada tabel komponen.

## Gelombang 4 — penutupan

### File yang dihapus

- `lib/core/ui/components/app_enhanced_section_header.dart` — penerus tipis ke
  `AppSectionHeader` yang hanya ada supaya gelombang 2 tidak perlu menyentuh
  tujuh layar sekaligus. Nol pemanggil setelah gelombang 3.
- `lib/core/ui/components/app_status_badge.dart` — penerus tipis ke `AppBadge`,
  bersama `AppBadgeVariant`. Nol pemanggil setelah `profile_view.dart` pindah.
  Dengan hilangnya berkas ini, `AppBadgeTone` hanya punya satu definisi, jadi
  `profile_view.dart` tidak lagi mengimpor `app_badge.dart` dengan prefiks —
  prefiks itu hanya pernah ada untuk menghindari tabrakan nama enum kembar.
- `lib/features/home/data/models/summary_card.dart` — yatim setelah
  `HomeController` berhenti menyemai jam sebagai empat kartu dengan sentinel
  `--:--`.

### Yang sengaja TIDAK dihapus

- `AppDetailRow` / `AppDetailPanel` (`dialogs/app_bottom_sheet.dart`) masih
  dipakai `permit_show_view.dart` (6 baris) dan `attendance_detail_sheet.dart`
  (2 panel). Nilai kosongnya adalah em dash `—`, dan em dash itu dipatok tes
  widget izin. `AppDataRow` adalah penerusnya untuk kode baru; migrasinya
  adalah pekerjaan berikutnya, bukan penghapusan sekarang.
- `app_timeline.dart` — nol pemanggil, tetapi lihat catatan di
  `DESIGN_SYSTEM.md`: konektornya sudah benar dan ia adalah bentuk yang harus
  diadopsi `permit_show_view.dart`, bukan dibuang.

## Yang tidak boleh disentuh

Ini bukan preferensi; masing-masing punya alasan yang sudah diperiksa.

- **Struktur formulir izin.** `permit_create_view.dart` harus tetap memakai
  `SingleChildScrollView` + `Column`. Mengganti dengan `ListView` atau widget
  malas lain melepaskan field di luar layar dari `Form`, dan test membuktikan
  validator field di luar layar tetap berjalan. Jangan pula memendekkan form,
  mengubah urutan field, atau membuat dua kolom untuk pasangan waktu.
- **String validator dan label yang dikunci test.** Termasuk
  `Kirim pengajuan`, `Jam masuk penyesuaian`, `Jam selesai`,
  `Shift saat ini`, `Jam Selesai wajib diisi`, `Shift saat ini wajib diisi`,
  `Pilih shift yang berbeda dari shift saat ini`,
  `Tidak boleh sebelum tanggal mulai`, `Di luar jadwal kerja Anda`,
  `Harus setelah 08:45`, `Harus setelah 17:00`,
  `Tidak ada jadwal kerja pada tanggal itu`, `Gagal memuat data`, serta
  `07:00 – 15:00` dan `23:00 – 07:00` yang memakai **en dash berspasi**.
- **Kapitalisasi `AppSectionHeader`.** `PENYESUAIAN JAM` dan
  `PENYESUAIAN SHIFT` tidak ada di source; keduanya diproduksi
  `title.toUpperCase()` dan dipatok tujuh assertion.
- **Em dash sebagai nilai kosong.** `AppDetailRow` menulis `—`.
- **Id shift tidak boleh muncul di layar.** Test menegaskan `find.text('3')` dan
  `find.text('5')` `findsNothing` di detail izin.
- **Perilaku navigasi.** Mengubah `Get.offAllNamed` menjadi `Get.toNamed` adalah
  perubahan perilaku dengan nol cakupan test; kerjakan terpisah dari perubahan
  visual, satu lintasan manual per fitur.

## Yang ditolak dan tidak boleh diusulkan ulang

- Glassmorphism, `BackdropFilter`, gradient mesh, aurora, Lottie, Rive, dan
  pustaka chart apa pun. Blur berbiaya `saveLayer` per frame pada perangkat yang
  sudah memegang kamera hidup dan detektor barcode dua kali sehari.
- `BoxShadow` dalam bentuk apa pun, termasuk yang dibungkus token bernama
  "elevation". Sistem ini tesisnya elevasi selalu nol.
- Setiap aparatus hover. Ini produk sentuh; hover menghasilkan afordans yang
  dikirim permanen dalam keadaan redup.
- `AppCircularProgress` dan cincin progres pada umumnya.
- `AppBadgeVariant.solid`.
- Cross-fade `AnimatedSwitcher` dari skeleton ke konten: skeleton memakai
  `..repeat(reverse: true)`, dan menahan controller berulang di dalam jendela
  `pumpAndSettle` akan **menggantung** test, bukan menggagalkannya.
- Kurva pegas tulis tangan, stagger, dan `Hero` — anggaran GPU dan ketiadaan
  assertion membuat semuanya meleset diam-diam.

## Cara memigrasikan satu layar

1. Baca ulang pengendalinya lebih dulu. Sebagian besar cacat visual di aplikasi
   ini sebenarnya cacat kejujuran data: nilai yang sudah diambil lalu dibuang,
   `isLoading` yang ditulis tetapi tidak pernah dibaca, sentinel `--:--` yang
   membuat guard `if (value != null)` tidak pernah menyala.
2. Pasang tiga keadaan daftar dalam urutan memuat → error → kosong.
3. Ganti `Container` + `BoxDecoration` buatan sendiri dengan `AppCard`.
4. Ganti kalimat status berwarna dengan `AppBadge` bertone, dan pastikan kata
   Indonesianya tetap ada.
5. Alirkan setiap warna lewat `theme.palette`; hapus setiap `Colors.*` dan
   `Color(0x...)` yang tersisa di layar itu.
6. Lewatkan setiap angka jam dan durasi lewat `AppTypography.mono`, dengan
   format 24 jam dan `8j 45m`.
7. Periksa target sentuh tetap ≥ 48dp setelah baris dipadatkan.
8. Jalankan `flutter analyze lib test` dan `flutter test`, lalu lihat layarnya
   di kedua tema pada skala teks 1.0 dan 1.5.

## Aksesibilitas

- Kontras WCAG AA di **kedua** mode, bukan hanya mode gelap.
- Batas yang menyatakan keadaan (fokus, terpilih, error, outline input) wajib
  lolos 3:1 sendirian; garis pengelompokan boleh lebih lemah karena ditopang
  selisih permukaan.
- Warna tidak pernah menjadi satu-satunya pembawa makna.
- Skala teks pengguna didukung sampai 1.5; tata letak yang pecah pada 1.5 adalah
  tata letak yang salah.
- Target sentuh minimal 48dp.

## Sebelum menyatakan selesai

- [ ] `flutter analyze lib test` bersih, nol suppression baru
- [ ] `flutter test` lulus seluruhnya (302 test hari ini)
- [ ] Lintasan manual dua layar terpadat, kedua tema, mode terang lebih dulu
- [ ] 320 / 360 / 375 / 412dp, skala teks 1.0 / 1.3 / 1.5
- [ ] Tidak ada string Indonesia yang berubah tanpa alasan tertulis

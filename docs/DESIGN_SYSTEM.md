# Design System ESAS — ringkasan

Titik masuk dokumentasi desain. Arah desain yang berlaku bernama **Instrumen**:
panel baca yang padat, angka tabular, garis 1px sebagai gridline, nol efek.

> Dokumen menyusul kode, bukan sebaliknya. Kalau sebuah aturan di sini tidak bisa
> ditunjuk ke `lib/core/theme/` atau `lib/core/ui/`, aturan itu salah dan harus
> dihapus dari dokumen — bukan diimplementasikan di layar.

## Dokumen

### 1. [DESIGN_GUIDE.md](./DESIGN_GUIDE.md)
Filosofi, aturan yang tidak bisa ditawar, token, pola, dan daftar periksa
sebelum mengirim layar. **Mulai di sini.**

### 2. [COMPONENT_REFERENCE.md](./COMPONENT_REFERENCE.md)
API setiap komponen yang benar-benar ada di `lib/core/ui/`, beserta call
site-nya. Dipakai sebagai lookup saat membangun layar.

### 3. [IMPLEMENTATION_GUIDE.md](./IMPLEMENTATION_GUIDE.md)
Urutan pengerjaan redesain, apa yang boleh dan tidak boleh disentuh, serta
jaminan yang dipegang test suite.

---

## Aturan inti

| Aturan | Nilai |
|---|---|
| Elevasi | selalu 0 — tanpa `elevation`, tanpa `BoxShadow` |
| Gradient | tidak ada, di mana pun |
| Hover | tidak ada — ini produk sentuh |
| Radius | maksimum 12 (`AppRadii.xl`); 16 hanya untuk sheet dan dialog |
| Kedalaman | garis 1px `borderSubtle` + selisih permukaan |
| Warna status | `AppTone` di `app_palette.dart` (`success`/`warning`/`danger`/`info`/`neutral`) |
| Hex di layar | dilarang di `lib/features` — selalu lewat `theme.palette` |
| Format waktu | 24 jam (`17:32`), durasi `8j 45m`, tanggal `2 Sep 2026` |
| Target sentuh | minimal 48dp |
| Skala teks | didukung sampai 1.5 |

Tidak ada palet Tailwind di produk ini. Nilai seperti `#10B981`, `#F59E0B`,
`#EF4444`, atau `#3B82F6` **tidak ada** di `app_colors.dart`; menyalinnya ke
sebuah layar menghasilkan warna yang tidak pernah ikut berubah saat tema
berganti. Hijau brand adalah `#3ECF8E` (`brand500`), dan di mode terang teks
hijau memakai `brand700`.

---

## Pustaka komponen

Lokasi: `lib/core/ui/components/` dan `lib/core/ui/dialogs/`.

Kolom **Call site** adalah jumlah pemakaian nyata di `lib/features` hari ini.
Komponen tanpa call site bukan komponen siap pakai — ia kode yang belum
terbukti, dan status itu ditulis apa adanya supaya tidak ada yang membangun di
atasnya karena mengira ia sudah matang.

| Komponen | File | Fungsi | Call site |
|---|---|---|---|
| `AppCard`, `AppIconBox` | `app_card.dart` | permukaan dasar: isian, garis 1px, radius, ripple | banyak |
| `AppBadge`, `AppStatusDot` | `app_badge.dart` | lencana status bertone tipis | banyak |
| `AppSectionHeader`, `AppPageTitle` | `app_section_header.dart` | judul section (HURUF KAPITAL) dan judul halaman | banyak |
| `AppEmptyState` | `app_empty_state.dart` | keadaan kosong dengan aksi opsional | 10 |
| `AppSkeleton`, `AppSkeletonRow`, `AppSkeletonList` | `app_skeleton.dart` | keadaan memuat | banyak |
| `appInputDecoration`, `AppFieldLabel` | `app_input_decoration.dart` | dekorasi field seragam | 10 |
| `AppAvatar` | `app_avatar.dart` | avatar karyawan dengan fallback inisial | 2 |
| `CustomBottomNavBar` | `custom_bottom_navbar.dart` | bilah navigasi utama | 4 layar |
| `AttendanceSummaryPanel` | `app_attendance_summary.dart` | panel absensi hari ini di Beranda | 1 |
| `AppTimeline` | `app_timeline.dart` | urutan langkah/aktivitas | 0 — lihat catatan di bawah |
| `AppLinearProgress` | `app_progress.dart` | bar progres berlabel | 1 |
| `showAppBottomSheet`, `AppDetailRow`, `AppDetailPanel` | `dialogs/app_bottom_sheet.dart` | sheet detail dan baris label–nilai | 10+ |
| `showAppConfirmDialog`, `confirmExitApp` | `dialogs/app_dialogs.dart` | konfirmasi | 2 |
| `showSuccessSnackbar` dan kerabatnya | `dialogs/app_snackbar.dart` | notifikasi sementara | banyak |

> **`AppTimeline` sedang tanpa pemanggil.** Satu-satunya call site-nya adalah
> lini masa audit di Beranda, yang dihapus bersama empat hex hardcoded yang
> dipakainya; log itu hidup di `activity_view.dart`. Komponennya sengaja
> dipertahankan — konektornya sudah benar (`IntrinsicHeight` + `Expanded`,
> bukan tunggul tetap) dan ia adalah bentuk yang benar untuk timeline
> berikutnya. Layar persetujuan izin masih menggambar lini masanya sendiri di
> `permit_show_view.dart`; menyatukan keduanya adalah pekerjaan berikutnya,
> bukan menghapus komponennya.

### Sudah dihapus / dijadwalkan dihapus

Jangan menghidupkan kembali salah satu dari ini. Semuanya dihapus karena nol
call site produksi, bukan karena belum sempat dipakai.

| Item | Status | Alasan |
|---|---|---|
| `app_stat_card.dart` (`AppStatCard`) | dihapus | nol call site; memakai hover dan aksen bebas. Kartu metrik yang benar dibangun dari `AppCard` + `AppTypography.mono` |
| `lib/core/ui/examples/modern_home_screen_example.dart` | dihapus | tidak dirutekan, tidak diimpor, tetapi ikut ter-compile ke biner rilis dan menjadi contoh yang menularkan pelanggaran palet |
| `AppCircularProgress` (`app_progress.dart`) | dihapus | nol call site, meluap pada ukuran defaultnya sendiri, dan memancarkan dua node progress untuk satu nilai. Bar berlabel melayani setiap kasus di aplikasi ini |
| `AppEnhancedSectionHeader`, `AppDividerSection`, `_ActionButton` (`app_enhanced_section_header.dart`) | dihapus | seluruh berkas dihapus setelah ketujuh pemanggilnya pindah ke `AppSectionHeader`; `_ActionButton` adalah aparatus hover di produk sentuh |
| `AppStatusBadge`, `AppBadgeVariant` (`app_status_badge.dart`) | dihapus | penerus tipis ke `AppBadge` yang hanya ada demi kompatibilitas sumber selama migrasi; berkasnya dihapus setelah `profile_view.dart` memakai `AppBadge` langsung |
| `SummaryCard` (`features/home/data/models/summary_card.dart`) | dihapus | yatim setelah `HomeController` berhenti menyemai jam sebagai empat kartu ber-sentinel `--:--` |
| `AppBadgeVariant.solid` | tidak diporting | lencana status di aplikasi ini tidak pernah berupa blok warna pekat |
| Widget Home lama: `summary_grid.dart`, `summary_card.dart`, `recent_activity.dart`, `quick_actions.dart`, `activity_tile.dart` | dihapus | yatim setelah Beranda dibangun ulang di atas komponen inti |

---

## Struktur

```
lib/core/
├── theme/
│   ├── app_colors.dart      nilai warna mentah (ramp netral, brand, status)
│   ├── app_palette.dart     peran semantik + AppTone, diakses via theme.palette
│   ├── app_typography.dart  skala teks dan AppTypography.mono (angka tabular)
│   ├── app_dimens.dart      AppSpacing, AppRadii, AppDurations
│   └── app_theme.dart       ThemeData terang dan gelap
└── ui/
    ├── components/          komponen visual
    ├── controllers/         bottom_nav_controller
    └── dialogs/             sheet, dialog, snackbar
```

---

## Referensi token singkat

**Jarak (4pt)**: `xxs` 2 · `xs` 4 · `sm` 8 · `md` 12 · `lg` 16 · `xl` 20 ·
`xxl` 24 · `xxxl` 32 · `huge` 48 · `page` 20 · `bottomSafe` 32

**Radius**: `xs` 4 · `sm` 6 · `md` 8 · `lg` 10 · `xl` 12 (kartu) ·
`xxl` 16 (sheet/dialog saja) · `pill` 999

**Durasi**: `fast` 120ms · `normal` 200ms · `slow` 320ms · `shimmer` 1400ms

**Tipografi**: display 40 · headline 26–19 · title 17–13.5 · body 15–12 ·
label 14–11. Angka dan jam lewat `AppTypography.mono`.

---

## Uji sebelum menyatakan selesai

- [ ] `flutter analyze lib test` bersih, tanpa `// ignore:` baru
- [ ] `flutter test` lulus seluruhnya
- [ ] Mode terang **dan** gelap dilihat berdampingan
- [ ] Lebar 320 / 360 / 375 / 412dp
- [ ] Skala teks 1.0 / 1.3 / 1.5 tanpa overflow
- [ ] Data kosong, data error, dan data panjang (nama dan status Indonesia yang panjang)

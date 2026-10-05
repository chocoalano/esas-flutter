# Referensi Komponen ESAS

API komponen yang **benar-benar ada** di `lib/core/ui/`. Setiap entri menyebut
call site nyatanya; komponen tanpa call site ditandai apa adanya supaya tidak
ada yang membangun layar di atas kode yang belum pernah dijalankan.

Aturan visual yang mengikat setiap komponen di halaman ini ada di
[DESIGN_GUIDE.md](./DESIGN_GUIDE.md): elevasi 0, tanpa shadow, tanpa gradient,
radius maksimum 12, warna status dari `AppTone`, dan tidak ada state hover.

## Daftar isi

1. [AppCard & AppIconBox](#appcard--appiconbox)
2. [AppBadge & AppStatusDot](#appbadge--appstatusdot)
3. [AppSectionHeader & AppPageTitle](#appsectionheader--apppagetitle)
4. [AppEmptyState](#appemptystate)
5. [AppInlineNotice](#appinlinenotice)
6. [AppSkeleton](#appskeleton)
7. [appInputDecoration & AppFieldLabel](#appinputdecoration--appfieldlabel)
8. [AppAvatar](#appavatar)
9. [CustomBottomNavBar](#custombottomnavbar)
10. [AppLinearProgress](#applinearprogress)
11. [AppTimeline](#apptimeline)
12. [AttendanceSummaryPanel](#attendancesummarypanel)
13. [Sheet, dialog, snackbar](#sheet-dialog-snackbar)
14. [Komponen yang tidak dipakai lagi](#komponen-yang-tidak-dipakai-lagi)

---

## AppCard & AppIconBox

`lib/core/ui/components/app_card.dart` — permukaan dasar aplikasi. Dipakai di
seluruh fitur; bangun di atasnya alih-alih menyusun `Container` +
`BoxDecoration` sendiri.

### AppCard

| Properti | Tipe | Default | Keterangan |
|---|---|---|---|
| `child` | `Widget` | wajib | isi kartu |
| `padding` | `EdgeInsetsGeometry` | `EdgeInsets.all(AppSpacing.lg)` | isian dalam |
| `onTap` | `VoidCallback?` | `null` | membuat kartu dapat disentuh (ripple) |
| `borderRadius` | `BorderRadius` | `AppRadii.xlAll` (12) | jangan lebih besar |
| `color` | `Color?` | `surface` | isian |
| `borderColor` | `Color?` | `palette.borderSubtle` | garis 1px |
| `selected` | `bool` | `false` | garis brand untuk pilihan aktif |
| `clipBehavior` | `Clip` | `Clip.antiAlias` | |

```dart
AppCard(
  onTap: bukaRiwayatAbsensi,
  child: Text('Riwayat absensi', style: theme.textTheme.titleSmall),
)
```

Kartu tanpa isian sendiri (misalnya daftar bergaris di dalamnya) memakai
`padding: EdgeInsets.zero` dan menyisipkan `Divider(height: 1, color:
palette.borderSubtle)` antar baris.

### AppIconBox

Kotak ikon bertone: `icon` (wajib), `size` (default 36), `foreground`,
`background`, `borderColor`. Warna diambil dari `theme.palette`, bukan dari hex.

```dart
AppIconBox(
  icon: Icons.qr_code_scanner_rounded,
  size: 32,
  foreground: palette.success.foreground,
  background: palette.success.background,
)
```

---

## AppBadge & AppStatusDot

`lib/core/ui/components/app_badge.dart` — lencana status: isian sangat tipis,
garis 1px, teks berwarna penuh. **Ini komponen badge kanonik.**

| Properti | Tipe | Default | Keterangan |
|---|---|---|---|
| `label` | `String` | wajib | selalu kata Indonesia, bukan enum server |
| `tone` | `AppBadgeTone` | `neutral` | `neutral`, `brand`, `success`, `warning`, `danger`, `info` |
| `icon` | `IconData?` | `null` | opsional |
| `dense` | `bool` | `false` | varian rapat untuk baris daftar |

```dart
AppBadge(label: 'Tepat waktu', tone: AppBadgeTone.success, dense: true)
AppBadge(label: 'Menunggu', tone: AppBadgeTone.warning)
```

Lencana di aplikasi ini **tidak pernah** berupa blok warna pekat. Varian
`solid` sengaja tidak ada di sini; lihat [bagian terakhir](#komponen-yang-tidak-dipakai-lagi).

`AppStatusDot(color: ..., size: 6)` adalah titik bertone untuk baris yang sudah
terlalu padat untuk sebuah lencana — selalu didampingi kata statusnya di
dekatnya, karena warna tidak boleh menjadi satu-satunya pembawa makna.

---

## AppSectionHeader & AppPageTitle

`lib/core/ui/components/app_section_header.dart`.

`AppSectionHeader` menulis judulnya dalam **HURUF KAPITAL** tanpa syarat. Itu
suara panel instrumen yang dipakai arah desain ini, dan beberapa test widget
mencari string hasil kapitalisasinya (`PENYESUAIAN JAM`, `PENYESUAIAN SHIFT`).
Jangan mematikan `toUpperCase()`.

| Properti | Tipe | Default |
|---|---|---|
| `title` | `String` | wajib |
| `actionLabel` | `String?` | `null` |
| `onAction` | `VoidCallback?` | `null` |
| `trailing` | `Widget?` | `null` |
| `padding` | `EdgeInsetsGeometry` | lihat sumber |

```dart
AppSectionHeader(
  title: 'Absensi hari ini',
  actionLabel: 'Riwayat',
  onAction: bukaRiwayatAbsensi,
)
```

`AppPageTitle(title:, subtitle:, trailing:)` untuk judul halaman.

---

## AppEmptyState

`lib/core/ui/components/app_empty_state.dart`.

| Properti | Tipe | Default |
|---|---|---|
| `icon` | `IconData` | wajib |
| `title` | `String` | wajib |
| `message` | `String?` | `null` |
| `actionLabel` | `String?` | `null` |
| `onAction` | `VoidCallback?` | `null` |
| `compact` | `bool` | `false` (varian untuk di dalam kartu) |

```dart
AppEmptyState(
  icon: Icons.event_busy_rounded,
  title: 'Belum ada pengajuan',
  message: 'Pengajuan izin Anda akan muncul di sini.',
  actionLabel: 'Ajukan izin',
  onAction: bukaFormulirIzin,
)
```

**Keadaan kosong bukan keadaan error.** Periksa error lebih dulu, baru kosong;
kalau urutannya terbalik, karyawan yang koneksinya gagal akan diberi tahu bahwa
ia tidak pernah mengajukan cuti.

---

## AppInlineNotice

`lib/core/ui/components/app_inline_notice.dart`.

| Properti | Tipe | Default |
|---|---|---|
| `message` | `String` | wajib |
| `tone` | `AppNoticeTone` | `danger` |
| `icon` | `IconData?` | dipilih dari `tone` |
| `actionLabel` / `onAction` | `String?` / `VoidCallback?` | `null` |
| `secondaryActionLabel` / `onSecondaryAction` | `String?` / `VoidCallback?` | `null` |

```dart
AppInlineNotice(
  message: 'Absensi hari ini belum dapat dimuat.',
  tone: AppNoticeTone.warning,
  actionLabel: 'Coba lagi',
  onAction: controller.refreshDashboard,
)
```

**Pilih ini, bukan `AppErrorState`, ketika yang gagal adalah satu PANEL.**
`AppErrorState` adalah keadaan sebuah halaman: ia memusatkan diri, memasang chip
ikon 44–56px, dan memberi jarak `huge` di atas dan di bawah. Dipakai di dalam
kartu, ia menghasilkan blok setinggi ±200px — di Beranda itu mendorong akses
cepat, jadwal, dan pengumuman ke bawah lipatan, padahal ketiganya berhasil
dimuat dan tetap bisa dipakai.

Aksinya berada di baris tersendiri, bukan di samping teks: label bahasa
Indonesia pada skala teks 1,5 di layar 320dp tidak pernah muat berdampingan
dengan sebuah kalimat.

---

## AppSkeleton

`lib/core/ui/components/app_skeleton.dart`. Dipakai di hampir setiap daftar.

- `AppSkeleton(width:, height:, borderRadius:)` — satu blok berdenyut.
- `AppSkeletonRow(showLeading: true)` — satu baris daftar.
- `AppSkeletonList(count:, padding:)` — beberapa baris.

```dart
Obx(() => controller.isLoading.value
    ? const AppSkeletonList(count: 4)
    : _content())
```

Skeleton harus punya tinggi yang mendekati konten aslinya, supaya daftar tidak
melompat saat data mendarat.

---

## appInputDecoration & AppFieldLabel

`lib/core/ui/components/app_input_decoration.dart`.

```dart
TextFormField(
  decoration: appInputDecoration(
    theme,
    'Alasan izin',
    hintText: 'Tulis alasan singkat',
    helperText: 'Minimal 10 karakter',
  ),
)
```

Bentuk, radius, warna isian, dan warna garis sudah ditetapkan
`inputDecorationTheme` di `app_theme.dart` — jangan membangun ulang `border`,
`focusedBorder`, atau `fillColor` di layar.

---

## AppAvatar

`lib/core/ui/components/app_avatar.dart`.

| Properti | Tipe | Default |
|---|---|---|
| `userName` | `String` | wajib (dipakai untuk inisial saat gambar kosong) |
| `imageUrl` | `String?` | `null` — URL absolut; selesaikan path tersimpan dengan `assetUrl()` |
| `size` | `double` | 40 |
| `borderRadius` | `BorderRadius?` | mengikuti ukuran |

---

## CustomBottomNavBar

`lib/core/ui/components/custom_bottom_navbar.dart`, dipasang sebagai
`bottomNavigationBar` di Beranda, Absensi, Izin, dan Notifikasi. Ikon berganti
antara varian outline dan filled sehingga tab aktif terbaca dari bentuknya
sebelum warnanya — jangan mengganti mekanisme itu dengan perbedaan warna saja.
Indeks aktif dipegang `BottomNavController`.

---

## AppLinearProgress

`lib/core/ui/components/app_progress.dart`. Satu call site (`profile_view.dart`).

| Properti | Tipe | Default |
|---|---|---|
| `value` | `double` | wajib, 0.0–1.0 (di-clamp) |
| `label` | `String?` | `null` |
| `showPercentage` | `bool` | `true` |
| `height` | `double` | 6 |
| `borderRadius` | `BorderRadius` | pill |
| `accentColor` | `Color?` | `colorScheme.primary` |

```dart
AppLinearProgress(value: 0.82, label: 'Kehadiran bulan ini')
```

Bar berlabel adalah bentuk progres yang dipakai produk ini. Cincin progres
tidak: ia menghabiskan ruang delapan angka untuk satu skalar dan tidak bisa
menunjukkan tren.

---

## AppTimeline

`lib/core/ui/components/app_timeline.dart`. Satu call site.

`AppTimeline(items: List<TimelineItem>, compact: bool)`.

`TimelineItem`: `title`, `subtitle`, `timestamp` (semua `String`, wajib),
`icon`, `iconColor`, `status` (`TimelineStatus.neutral | success | warning |
error`), `trailing`.

```dart
AppTimeline(
  items: [
    TimelineItem(
      title: 'Absen masuk',
      subtitle: 'Pindai QR',
      timestamp: '08:11',
      status: TimelineStatus.success,
      icon: Icons.check_circle_rounded,
    ),
    TimelineItem(
      title: 'Absen keluar',
      subtitle: 'Manual',
      timestamp: '17:32',
      status: TimelineStatus.success,
      trailing: Text('8j 45m', style: AppTypography.mono(fontSize: 13)),
    ),
  ],
)
```

Jam ditulis 24 jam (`08:11`), durasi dalam bahasa Indonesia (`8j 45m`). Status
setiap langkah harus dihitung dari data, bukan dipatok `success` — timeline yang
semua langkahnya hijau tidak menyampaikan apa pun.

---

## AttendanceSummaryPanel

`lib/core/ui/components/app_attendance_summary.dart`. Dipakai di Beranda.

| Properti | Tipe | Default |
|---|---|---|
| `checkInTime` | `String` | wajib |
| `checkOutTime` | `String?` | `null` |
| `duration` | `String?` | `null` |
| `status` | `AttendanceStatus` | wajib — `checkedIn`, `checkedOut`, `absent`, `pending` |
| `onViewHistory` | `VoidCallback?` | `null` |

```dart
AttendanceSummaryPanel(
  checkInTime: '08:11',
  checkOutTime: '17:32',
  duration: '8j 45m',
  status: AttendanceStatus.checkedOut,
  onViewHistory: bukaRiwayatAbsensi,
)
```

Warna status panel ini datang dari `palette.success/info/danger/warning`.
Jangan mengganti nilainya dengan `Colors.green` dan kerabatnya: konstanta
Material tidak ikut berubah saat tema berganti dan gagal kontras di mode terang.

---

## Sheet, dialog, snackbar

`lib/core/ui/dialogs/`.

```dart
showAppBottomSheet<void>(
  context,
  title: 'Detail absensi',
  description: 'Rekaman dari perangkat Anda',
  child: AppDetailPanel(
    children: [
      AppDetailRow(label: 'Jam masuk', value: '08:11'),
      AppDetailRow(label: 'Jam keluar', value: '—'),
    ],
  ),
);

final bool ok = await showAppConfirmDialog(
  context,
  title: 'Batalkan pengajuan?',
  message: 'Pengajuan yang dibatalkan tidak bisa dikembalikan.',
  confirmLabel: 'Batalkan',
  destructive: true,
);

showSuccessSnackbar('Pengajuan terkirim');
showErrorSnackbar('Gagal memuat data');
```

`AppDetailRow(label:, value:, valueStyle:, trailing:)` menyejajarkan nilai pada
satu kolom. Nilai kosong ditulis em dash (`—`), bukan string kosong atau `-`.

---

## Komponen yang tidak dipakai lagi

Semuanya dihapus karena nol call site produksi. Jangan menghidupkannya kembali,
dan jangan menyalin polanya ke komponen baru.

| Item | Alasan |
|---|---|
| `AppStatCard` (`app_stat_card.dart`, dihapus) | hover di produk sentuh, aksen bebas per call site. Kartu metrik dibangun dari `AppCard` + `AppTypography.mono` + `AppBadge` |
| `modern_home_screen_example.dart` (dihapus) | tidak dirutekan tetapi ikut ter-compile, dan menjadi contoh yang menularkan pelanggaran palet |
| `AppCircularProgress` (`app_progress.dart`, dihapus) | nol call site, meluap pada ukuran defaultnya sendiri, dua node progress untuk satu nilai |
| `AppStatusBadge` (`app_status_badge.dart`, dihapus) | duplikat `AppBadge` dengan enum bernama sama. Pemanggil terakhirnya di Profil sudah pindah ke `AppBadge`, berkasnya dihapus, dan `AppBadgeTone` kini hanya punya satu definisi |
| `AppBadgeVariant.solid` (dihapus bersama `app_status_badge.dart`) | lencana status di aplikasi ini tidak pernah berupa blok warna pekat |
| `EnhancedQuickActionsGrid`, `EnhancedQuickAction` (`app_quick_actions.dart`, dihapus) | nol call site produksi setelah redesain Beranda. Petaknya adalah `AppCard` penuh — garis, radius, padding 16/20, kotak ikon 44px — sehingga tiga aksi memakan tinggi yang sama dengan panel absensi di atasnya dan halaman terbaca sebagai empat hal yang sama pentingnya. Digantikan `HomeQuickActions` di `features/home`: kotak ikon 52px tanpa kartu, empat kolom, umpan balik tekan berskala |
| `AppEnhancedSectionHeader`, `AppDividerSection` (`app_enhanced_section_header.dart`, dihapus) | header ganda. Ketujuh pemanggilnya memakai `AppSectionHeader` langsung, yang menuliskan judul dalam HURUF KAPITAL |

---

## Tips

1. Ambil setiap jarak dari `AppSpacing` dan setiap radius dari `AppRadii`.
2. Ambil setiap warna dari `theme.palette` atau `Theme.of(context)`; nol
   `Color(0x...)` di `lib/features`.
3. Uji setiap layar di mode terang dan gelap, dan pada skala teks 1.5.
4. Tulis jam sebagai `17:32` dan durasi sebagai `8j 45m`, selalu lewat
   `AppTypography.mono`.
5. Sediakan ketiga keadaan daftar — memuat, error, kosong — dalam urutan itu.
6. Umpan balik sentuh adalah ripple dan perubahan warna, bukan hover atau skala.
7. Komponen baru butuh call site nyata sebelum dianggap selesai.

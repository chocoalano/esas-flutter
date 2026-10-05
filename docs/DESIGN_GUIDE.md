# Panduan Desain ESAS — arah "Instrumen"

Dokumen ini menjelaskan aturan visual yang benar-benar berlaku di kode. Jika ada
pertentangan antara dokumen dan `lib/core/theme/`, **kode yang menang** dan
dokumen inilah yang harus diperbaiki. Versi dokumen sebelumnya meresepkan
gradient, hover shadow, dan palet status Tailwind yang tidak pernah ada di
`app_colors.dart`; resep itu terlanjur diimplementasikan di layar Beranda. Itu
sebabnya bagian "Aturan yang tidak bisa ditawar" ada di paling atas.

## Arah desain

Arahnya bernama **Instrumen**: layar ESAS bukan laporan, melainkan panel baca.
Angka tabular, garis 1px sebagai gridline, dan nada status yang sudah ada dipakai
untuk menjawab pertanyaan karyawan dalam satu tatapan. Kepadatan dibayar dengan
keterbacaan, bukan dengan efek.

Konsekuensinya:

- Setiap angka besar membawa pembanding — delta, target, atau bar. Tidak ada
  angka hero yang mengambang tanpa skala.
- Warna tidak pernah menjadi satu-satunya pembawa makna. Setiap status tetap
  membawa kata Indonesianya, setiap sel bertone tetap punya garis 1px.
- Mode terang adalah mode yang benar-benar dipakai orang di gerbang pabrik jam
  06:50. Setiap nilai warna dispesifikasikan di dua palet.

## Aturan yang tidak bisa ditawar

1. **Elevasi selalu 0.** Tidak ada `elevation`, tidak ada `BoxShadow`, tidak ada
   tier bayangan. Kedalaman dibawa dua hal: garis 1px (`palette.borderSubtle`)
   dan selisih permukaan (`surface` / `surfaceSubtle` / `surfaceRaised`).
2. **Tidak ada gradient — dengan satu pengecualian yang dinamai.** Tidak ada
   `LinearGradient`, `RadialGradient`, mesh, aurora, atau glow. Isian adalah
   satu warna solid dari palet.

   **Pengecualiannya: panel protagonis.** SATU kartu per layar, dan hanya pada
   layar yang memang punya satu hal terpenting, boleh memakai `palette.brandGlow`
   sebagai kilau radial ditambah rim `brandAccent` beralpha. Hari ini pemakainya
   tepat satu: `TodayWorkCard` di Beranda.

   Alasannya bukan selera. Hierarki yang dibawa semata-mata oleh ukuran huruf
   berhenti bekerja begitu sebuah halaman punya enam bagian — Beranda lama
   menggambar enam bagian berbobot nyaris sama dan mata tidak punya tempat
   mendarat. `brandGlow` sengaja dipilih 1.03:1 di atas putih dan 1.06:1 di atas
   kartu gelap: cukup untuk menyatakan urutan baca, terlalu lemah untuk
   mengubah kontras teks di atasnya.

   Dua syarat yang mengikat pemakaiannya: kilaunya memudar ke `brandGlow` pada
   **alpha nol**, tidak pernah ke `Colors.transparent` (yang memudar ke hitam
   transparan dan meninggalkan halo kotor di mode terang), dan tetap tidak ada
   `BoxShadow` — aturan 1 berlaku penuh.

   Menambah pemakai kedua adalah keputusan desain, bukan penerapan pola. Dua
   protagonis di satu layar berarti tidak ada protagonis.
3. **Radius maksimum 12** (`AppRadii.xl`) untuk kartu, tombol, input, dan badge.
   Pengecualiannya dua: sudut atas bottom sheet dan dialog yang memakai
   `AppRadii.xxl` (16) lewat `app_theme.dart`, dan panel protagonis pada aturan 2
   yang memakai radius yang sama. `AppRadii.pill` hanya untuk elemen yang memang
   bulat: badge kecil, dot, dan track progress.
4. **Warna status datang dari `AppTone` di `app_palette.dart`**, tidak pernah
   dari hex yang ditulis di layar. `palette.success`, `palette.warning`,
   `palette.danger`, `palette.info`, `palette.neutral` — masing-masing sepasang
   `foreground` / `background` / `border`. Tidak ada palet Tailwind di produk
   ini; angka seperti `#10B981` atau `#3B82F6` tidak ada di `app_colors.dart`
   dan tidak boleh muncul di mana pun.
5. **Tidak ada `Color(0x...)` mentah di dalam `lib/features`.** Warna diambil
   dari `Theme.of(context)` atau `theme.palette`. Satu-satunya lapisan yang
   boleh mengabaikan tema adalah lapisan di atas citra kamera, dan warnanya
   tetap datang dari token overlay, bukan dari hex lokal.
6. **Tidak ada state hover.** Ini produk sentuh: `MouseRegion` dan `_isHovered`
   menghasilkan afordans yang dikirim permanen dalam keadaan redup, menunggu
   penunjuk yang tidak akan pernah datang. Umpan balik sentuh adalah ripple
   (`InkWell`) dan perubahan warna saat ditekan.
7. **Target sentuh minimal 48dp** untuk setiap aksi, sekecil apa pun tampilan
   visualnya. Kepadatan tidak pernah dibayar oleh ibu jari.
8. **Teks tidak turun di bawah 12px**, dan skala teks pengguna dihormati sampai
   1.5. Tata letak yang tidak muat pada 1.5 adalah tata letak yang salah, bukan
   pengguna yang salah.
9. **Copy Indonesia tetap Indonesia**, termasuk saat memperbaiki bug. Enum
   server (`on_time`, `LATE`, `MANUAL`) diterjemahkan sebelum digambar.
10. **Format angka**: jam 24 jam (`17:32`), bukan `5:32 PM`; durasi `8j 45m`,
    bukan `8h 45m`; tanggal Indonesia (`2 Sep 2026`). Semua angka jam dan
    durasi memakai gaya monospace bertabular agar lebarnya tidak bergoyang.

## Token

Semua token ada di `lib/core/theme/`. Layar tidak pernah menyebut hex.

### Warna

`app_colors.dart` menyimpan nilai mentah: satu ramp netral panjang (`slate*`
untuk gelap, `gray*` untuk terang), satu hijau brand (`brand500` sebagai warna
tanda tangan, `brand700` untuk teks di mode terang), dan empat keluarga status.

`app_palette.dart` menetapkan perannya dan diambil lewat `theme.palette`:

| Peran | Token | Dipakai untuk |
|---|---|---|
| Garis pengelompokan | `borderSubtle` | tepi kartu, divider, garis app bar |
| Garis penegasan | `borderStrong` | elemen aktif atau sedang ditekan |
| Permukaan bawah | `surfaceSubtle` | dasar input, baris bergaris |
| Permukaan atas | `surfaceRaised` | kartu di dalam kartu, keadaan ditekan |
| Teks tersier | `textMuted` | keterangan waktu, satuan, teks bantuan |
| Aksen brand | `brandAccent`, `brandSubtle` | indikator dan isian, bukan huruf di mode terang |
| Nada status | `neutral`, `success`, `warning`, `danger`, `info` | `AppTone` (foreground/background/border) |

Aturan peran garis: garis **dekoratif** (pengelompokan) boleh di bawah 3:1
karena ditopang selisih permukaan; setiap garis yang menyatakan **keadaan**
(fokus, terpilih, error, outline input) wajib lolos 3:1 sendirian.

### Jarak

Skala 4pt di `AppSpacing`: `xxs` 2, `xs` 4, `sm` 8, `md` 12, `lg` 16 (standar),
`xl` 20, `xxl` 24, `xxxl` 32, `huge` 48. Margin halaman `page` 20, ruang aman di
atas bottom bar `bottomSafe` 32. Jangan menuliskan angka jarak langsung, dan
jangan menghitung setengah langkah sebagai `AppSpacing.sm - 2` — kalau sebuah
nilai dibutuhkan berulang kali, ia layak diberi nama di `app_dimens.dart`.

### Radius

`AppRadii`: `xs` 4, `sm` 6, `md` 8, `lg` 10, `xl` 12, `xxl` 16 (khusus sheet dan
dialog), `pill` 999. Kartu standar memakai `xlAll`.

### Tipografi

`AppTypography.textTheme()` memberi skala lengkap dari display sampai label.
Angka, jam, dan nomor dokumen memakai `AppTypography.mono(...)` supaya
`FontFeature.tabularFigures()` ikut terpasang. Flutter menerima **satu** nama
family, bukan tumpukan seperti CSS: menulis
`fontFamily: 'SF Mono, Menlo, monospace'` gagal secara senyap dan jatuh ke font
proporsional. Selalu lewat `AppTypography.mono`.

Jangan menambah `fontSize:` ad hoc di layar. Kalau sebuah ukuran dibutuhkan
berulang, tambahkan langkahnya ke skala.

### Gerak

`AppDurations`: `fast` 120ms (umpan balik sentuh), `normal` 200ms (transisi
standar), `slow` 320ms (count-up angka dan pengisian bar), `shimmer` 1400ms
(skeleton). Gerak di sini bertugas menjelaskan perubahan keadaan; tidak ada
gerak dekoratif, tidak ada stagger, tidak ada scale-on-press.

## Pola

### Kartu

`AppCard` sudah membawa isian, garis 1px, radius, dan ripple. Bangun di atasnya
alih-alih menyusun `Container` + `BoxDecoration` sendiri — itulah cara sebuah
layar diam-diam mendapatkan radius, warna garis, atau bayangan yang berbeda.

### Tiga keadaan setiap daftar

Setiap daftar wajib punya tiga cabang dan **urutannya penting**:

1. `isLoading` → skeleton (`AppSkeletonList`).
2. error → keadaan error dengan pesan server dan tombol coba lagi.
3. kosong → `AppEmptyState`.

Memeriksa kosong sebelum error adalah bug berkonsekuensi: karyawan yang
koneksinya gagal akan diberi tahu bahwa ia tidak pernah mengajukan cuti.

### Baris daftar

```dart
Container(
  decoration: BoxDecoration(
    border: Border(bottom: BorderSide(color: palette.borderSubtle)),
  ),
  padding: const EdgeInsets.symmetric(
    horizontal: AppSpacing.page,
    vertical: AppSpacing.lg,
  ),
  child: Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Judul', style: theme.textTheme.titleSmall),
            Text('08:11 → 17:32', style: AppTypography.mono(fontSize: 13)),
          ],
        ),
      ),
      AppBadge(label: 'Tepat waktu', tone: AppBadgeTone.success, dense: true),
    ],
  ),
)
```

### Panel data

Label kecil dulu, lalu nilai monospace, lalu nada status. Urutan itu yang
membuat mata menemukan angkanya, bukan kata "Absen Masuk".

## Daftar periksa sebelum mengirim layar

- [ ] Semua jarak dari `AppSpacing`, semua radius dari `AppRadii`.
- [ ] Semua warna dari `theme.palette` atau `Theme.of(context)`; nol `Color(0x...)`.
- [ ] Elevasi 0, tanpa shadow, tanpa gradient — kecuali satu panel protagonis
      per layar yang memakai `palette.brandGlow` sesuai aturan 2.
- [ ] Tiga keadaan daftar lengkap dan berurutan (skeleton, error, kosong).
- [ ] Jam dan durasi memakai `AppTypography.mono`, format 24 jam dan `8j 45m`.
- [ ] Status membawa kata Indonesianya, bukan hanya warna.
- [ ] Target sentuh ≥ 48dp.
- [ ] Diuji di mode terang **dan** gelap, pada 320/360/412dp, skala teks 1.0–1.5.
- [ ] `flutter analyze lib test` bersih tanpa `// ignore:` baru; `flutter test` lulus.

## Merawat komponen

Komponen baru dibuat di `lib/core/ui/components/` dengan nama
`app_[nama].dart`, memakai token dari `lib/core/theme/`, dan mendukung dua mode.
Komponen yang tidak punya call site bukan komponen yang sudah selesai — ia hanya
kode yang belum terbukti. Jangan mendokumentasikannya sebagai siap pakai sebelum
sebuah layar benar-benar memakainya, dan hapus komponen yang tidak pernah
dipakai daripada membiarkannya ikut ter-compile ke biner rilis.

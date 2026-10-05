import 'package:flutter/widgets.dart';

import 'app_breakpoints.dart';

/// Margin horizontal halaman, dipasang per bagian alih-alih per daftar.
///
/// Selama padding halaman tinggal di `ListView.padding`, tidak ada satu pun
/// bagian yang bisa menerobosnya: `ListView` menjepit setiap anaknya ke lebar
/// yang sudah dikurangi margin, dan sebuah kartu yang ingin menyentuh tepi
/// kaca tidak punya cara memintanya. Memindahkan margin ke sini membuat
/// "menerobos margin" menjadi pilihan satu widget, bukan pengecualian yang
/// harus ditulis ulang di setiap pemanggil.
///
/// Ada satu bahaya yang perlu dinyatakan di depan: probe overflow menangkap
/// luapan, bukan padding yang hilang. Sebuah bagian yang lupa dibungkus kelas
/// ini akan menempel di kaca dan tetap lulus semua tes. Karena itu daftar yang
/// memakainya sebaiknya bertipe daftar [AppPageInset], bukan daftar `Widget` —
/// biar kompilernya yang menegakkan, bukan pembaca diff.
class AppPageInset extends StatelessWidget {
  const AppPageInset({super.key, required this.child, this.bleed = false});

  final Widget child;

  /// Ketika benar, bagian ini tidak diberi margin sama sekali dan boleh
  /// menyentuh kedua tepi kaca.
  ///
  /// Ini hanya bermakna ketika tepi kolomnya memang tepi layar, jadi
  /// pemanggilnya biasanya menyalurkan `AppLayout.of(context).heroBleeds`
  /// alih-alih menuliskan `true` di tempat.
  final bool bleed;

  @override
  Widget build(BuildContext context) {
    if (bleed) return child;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppLayout.of(context).pagePadding,
      ),
      child: child,
    );
  }
}

/// Menjepit lebar isi ke ukuran yang masih nyaman dibaca, lalu memusatkannya.
///
/// Di atas [AppBreakpoints.readingMax] sisa lebar layar menjadi margin, bukan
/// kolom tambahan. Sebuah paragraf 13,5px yang membentang seribu piksel
/// menuntut mata melompat balik terlalu jauh di setiap akhir baris, dan
/// meregangkan dua kolom sampai 1366dp hanya memindahkan masalahnya.
///
/// Bentuk pohonnya sengaja sama pada setiap kelas ukuran — [Center] dan
/// [ConstrainedBox] tetap ada meski batasnya tak terbatas — supaya memutar
/// perangkat tidak mengganti bentuk pohon dan tidak menghapus state anaknya.
class AppContentClamp extends StatelessWidget {
  const AppContentClamp({super.key, required this.child, this.maxWidth});

  final Widget child;

  /// Batas lebar yang dipakai. Kalau dikosongkan, batasnya diambil dari kelas
  /// ukuran yang sedang berlaku.
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final double? limit = maxWidth ?? AppLayout.of(context).contentMaxWidth;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: limit ?? double.infinity),
        child: child,
      ),
    );
  }
}

/// Dua kolom pada layar yang cukup lebar, satu tumpukan pada yang tidak.
///
/// Mekanismenya sengaja yang paling bodoh yang masih benar: satu [Row] berisi
/// dua [Column] biasa di dalam [Expanded]. Tidak ada scrollable bersarang,
/// tidak ada [LayoutBuilder] bersarang, dan tidak ada fisika gulir yang
/// dimatikan lalu diam-diam memotong isi ketika skala teks 1,5 membuatnya lebih
/// tinggi daripada yang diduga. Pemanggilnya membungkus kelas ini dengan SATU
/// scrollable, dan seluruh halaman punya satu posisi gulir dan satu gestur
/// tarik-untuk-menyegarkan.
///
/// `CrossAxisAlignment.start` adalah seluruh mekanisme masonry-nya: kedua kolom
/// memang berbeda tinggi, dan itu disengaja.
///
/// Ketika kelas ukurannya satu kolom, [primary] dan [secondary] dituang
/// berurutan ke dalam satu [Column] — jadi urutan bacanya harus tetap masuk
/// akal kalau kedua daftar disambung.
class AppTwoColumn extends StatelessWidget {
  const AppTwoColumn({
    super.key,
    required this.primary,
    required this.secondary,
    this.gutter,
  });

  /// Kolom kiri: isi yang paling dicari orang saat membuka halaman.
  final List<Widget> primary;

  /// Kolom kanan: isi pendukung.
  final List<Widget> secondary;

  /// Jarak antar kolom. Kalau dikosongkan, dipakai margin halaman kelas ini,
  /// sehingga jarak antar kolom sama dengan jarak kolom ke tepi kaca.
  final double? gutter;

  @override
  Widget build(BuildContext context) {
    final AppLayoutMetrics layout = AppLayout.of(context);

    if (!layout.twoColumn) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[...primary, ...secondary],
      );
    }

    // Perbandingan lebar kolom. Ponsel lanskap dibagi rata karena kedua
    // kolomnya sama-sama sempit; begitu layar melebar, kolom kiri diberi
    // porsi lebih besar tetapi tidak pernah dua kali lipat — kolom kanan masih
    // memuat kalimat, bukan sekadar angka.
    final (int left, int right) = switch (layout.layoutClass) {
      AppLayoutClass.compactLandscape => (1, 1),
      AppLayoutClass.medium => (3, 2),
      _ => (5, 4),
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          flex: left,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: primary,
          ),
        ),
        SizedBox(width: gutter ?? layout.pagePadding),
        Expanded(
          flex: right,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: secondary,
          ),
        ),
      ],
    );
  }
}

import 'package:intl/intl.dart';

/// Truncate [text] to [maxLength] characters, ending in an ellipsis.
///
/// A null or empty value becomes `'N/A'` — the placeholder the list screens
/// already showed for a missing field.
String limitString(String? text, {int maxLength = 20}) {
  if (text == null || text.isEmpty) return 'N/A';
  if (text.length <= maxLength) return text;

  final effective = maxLength < 3 ? 3 : maxLength;
  return '${text.substring(0, effective - 3)}...';
}

/// Ubah cuplikan HTML menjadi satu paragraf teks biasa, atau null bila tidak
/// ada isinya.
///
/// Mengembalikan **null**, bukan kalimat pengganti, dan itu inti gunanya. Isi
/// pengumuman tidak dikirim oleh endpoint daftar — hanya oleh endpoint
/// rinciannya — jadi null di sana berarti "belum diminta", bukan "kosong".
/// Layar daftar yang mencetak "Tidak ada rincian." untuk setiap baris sedang
/// melaporkan sesuatu yang tidak benar, dan justru menutupi judul serta tanggal
/// yang sebenarnya ada.
///
/// Pemanggil yang memang punya isi memakai hasilnya; yang tidak, menampilkan
/// hal lain.
String? htmlToPlainText(String? html) {
  if (html == null) return null;

  final String named = html
      // Tag blok menjadi spasi, bukan hilang begitu saja: tanpa ini
      // "<p>Halo</p><p>Dunia</p>" terbaca "HaloDunia".
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'");

  // Entitas NUMERIK, desimal maupun heksadesimal. Editor rich-text yang dipakai
  // admin memancarkannya untuk hampir setiap tanda baca yang tidak ASCII —
  // `&#8220;` untuk tanda kutip kurva, `&#160;` untuk spasi mati — dan tanpa
  // baris ini semuanya tergambar apa adanya di kartu pengumuman.
  final String decoded = named.replaceAllMapped(
    RegExp(r'&#(x?)([0-9a-fA-F]+);'),
    (Match m) {
      final int? code = int.tryParse(
        m[2]!,
        radix: (m[1] ?? '').isEmpty ? 10 : 16,
      );

      // Rentang yang tidak sah dibiarkan apa adanya alih-alih melempar:
      // sebuah kartu yang menampilkan satu entitas mentah jauh lebih baik
      // daripada layar yang gagal dibangun.
      if (code == null || code < 0x20 || code > 0x10FFFF) return m[0]!;

      return String.fromCharCode(code);
    },
  );

  // Normalisasi spasi dilakukan PALING AKHIR, sesudah entitas menjadi karakter
  // sungguhan — kalau tidak, `&#160;` yang baru saja menjadi spasi mati akan
  // lolos sebagai spasi ganda.
  final String text = decoded
      .replaceAll('\u00a0', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  return text.isEmpty ? null : text;
}

/// Kembalikan judul yang DITULIS SELURUHNYA KAPITAL menjadi kalimat biasa.
///
/// Server mengirim judul pengumuman apa adanya dari formulir admin, dan
/// sebagian besar admin mengetiknya dengan tombol caps lock menyala:
/// "KEBIJAKAN JAM MASUK KERJA, IJIN TERLAMBAT, PULANG AWAL DAN ABSEN". Dirender
/// apa adanya pada ukuran judul, kalimat itu berteriak, jauh lebih lambat
/// dipindai daripada huruf campuran, dan elipsisnya jatuh di tengah frasa.
///
/// Normalisasi terjadi di lapisan RENDER dan bukan di model: data server tetap
/// utuh, dan layar daftar maupun rincian memakai fungsi yang sama sehingga satu
/// judul tidak pernah dirender dalam dua bentuk di dua layar.
///
/// Ambangnya sengaja tinggi — minimal delapan huruf DAN minimal 90% di
/// antaranya kapital — supaya judul yang memang ditulis campuran tidak pernah
/// disentuh. Dua hal dikecualikan dari penurunan huruf: token yang mengandung
/// angka (`K3`, `P2K3`, `07.30`, `2026`) dan akronim yang benar-benar dipakai
/// di lingkungan pabrik ([_acronyms]). Daftar itu sengaja pendek dan eksplisit:
/// aturan "pertahankan setiap token kapital pendek" terdengar lebih pintar
/// tetapi pada kalimat yang seluruhnya kapital ia mempertahankan "JAM", "DAN",
/// dan "IJIN" — yaitu kata biasa yang kebetulan pendek, bukan akronim.
String? sentenceFromShout(String? text) {
  if (text == null) return null;

  final String trimmed = text.trim();

  if (trimmed.isEmpty) return null;

  final String letters = trimmed.replaceAll(RegExp('[^A-Za-z]'), '');

  if (letters.length < 8) return trimmed;

  final int shouted = letters.replaceAll(RegExp('[^A-Z]'), '').length;

  if (shouted / letters.length < 0.9) return trimmed;

  final String lowered = trimmed.splitMapJoin(
    RegExp(r'\S+'),
    onMatch: (Match match) {
      final String token = match[0]!;

      // Angka membawa maknanya sendiri: menurunkan "K3" menjadi "k3" mengubah
      // nama sebuah komite menjadi sesuatu yang tidak ada.
      if (token.contains(RegExp('[0-9]'))) return token;

      final String bare = token
          .replaceAll(RegExp('[^A-Za-z]'), '')
          .toLowerCase();

      return _acronyms.contains(bare) ? token : token.toLowerCase();
    },
  );

  return toBeginningOfSentenceCase(lowered) ?? lowered;
}

/// Akronim yang tetap kapital ketika sebuah judul diturunkan hurufnya.
///
/// Sengaja daftar, bukan aturan: satu-satunya cara menahan "SOP" tanpa ikut
/// menahan "DAN" adalah menyebut namanya.
const Set<String> _acronyms = <String>{
  'apd',
  'bpjs',
  'cv',
  'hr',
  'hrd',
  'hse',
  'it',
  'nik',
  'npwp',
  'pt',
  'qc',
  'sdm',
  'sop',
  'spsi',
  'hris',
  'iso',
  'k3',
  'apar',
  'ojt',
  'pkwt',
  'pkwtt',
  'thr',
  'ptkp',
  'pph',
  'wib',
  'wit',
  'wita',
};

/// Nama orang, dengan kapitalisasi yang tidak membuatnya terlihat salah ketik.
///
/// Dua bentuk yang benar-benar dikirim server dan keduanya terlihat buruk di
/// layar: nama yang diketik dengan caps lock menyala ("TUBAGUS ANGGA
/// DHEVIESTS") dan nama yang seluruhnya huruf kecil. Yang pertama berteriak di
/// baris penerbit pengumuman; yang kedua terlihat seperti nama pengguna, bukan
/// nama orang.
///
/// Kepala Beranda sudah lama memakai `toBeginningOfSentenceCase` untuk ini, dan
/// itu jawaban yang salah untuk sebuah NAMA: ia menghasilkan "Alan gentina",
/// yaitu satu huruf kapital untuk dua kata yang dua-duanya nama diri.
///
/// Nama yang sudah bercampur huruf besar-kecil TIDAK disentuh sama sekali.
/// "McDonald", "de Vries", dan "bin Abdullah" semuanya ditulis begitu dengan
/// sengaja oleh seseorang, dan sebuah aturan yang lebih pintar daripada itu
/// akan merusaknya.
String? personName(String? raw) {
  final String? text = raw?.trim();

  if (text == null || text.isEmpty) return null;

  final String letters = text.replaceAll(RegExp('[^A-Za-z]'), '');

  if (letters.isEmpty) return text;

  final int capitals = letters.replaceAll(RegExp('[^A-Z]'), '').length;
  final bool shouted = capitals == letters.length;
  final bool whispered = capitals == 0;

  if (!shouted && !whispered) return text;

  return text
      .split(RegExp(r'\s+'))
      .map(
        (String word) => word.isEmpty
            ? word
            : word[0].toUpperCase() + word.substring(1).toLowerCase(),
      )
      .join(' ');
}

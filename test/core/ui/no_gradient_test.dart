import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Aturan yang tidak bisa di-grep akan longgar dalam dua sprint, apa pun yang
/// tertulis di dokumen desain.
///
/// Bahasa visual aplikasi ini menolak gradient, bayangan, glow dan blur —
/// bukan sebagai selera, melainkan karena ketiganya membeli nol rasio kontras
/// dan menagih biaya yang nyata: sebuah `saveLayer` per frame di perangkat yang
/// dua kali per shift juga memegang pemindai kamera, *banding* pada panel 6-bit
/// yang umum di Android murah, dan nol piksel yang berubah di bawah matahari
/// di gerbang pabrik. Kesepakatan tentang hal itu sudah pernah dibuat sekali
/// dan sudah pernah dilanggar sekali, oleh sebuah kilau radial di kartu
/// protagonis Beranda.
///
/// Berkas ini yang membuat "tidak ada" bisa dibaca mesin. Ia sengaja tes biasa,
/// bukan widget test: ia membaca sumbernya, bukan pohon rendernya.
void main() {
  /// Setiap berkas Dart di bawah `lib/`.
  List<File> libSources() {
    final Directory lib = Directory('lib');

    expect(
      lib.existsSync(),
      isTrue,
      reason: 'tes ini harus dijalankan dari akar proyek',
    );

    return lib
        .listSync(recursive: true)
        .whereType<File>()
        .where((File f) => f.path.endsWith('.dart'))
        .toList();
  }

  /// Baris yang bukan komentar. Sebuah aturan boleh DIJELASKAN dalam prosa —
  /// dan berkas yang menjelaskan mengapa gradient ditolak justru harus boleh
  /// menyebut katanya.
  bool isCode(String line) {
    final String t = line.trim();

    return !t.startsWith('//') && !t.startsWith('///') && !t.startsWith('*');
  }

  /// Berkas yang boleh menyebut sebuah pola, beserta alasannya. Daftar ini
  /// sengaja pendek, dan menambah satu baris ke dalamnya adalah keputusan
  /// desain yang harus dibela di review — itulah gunanya.
  const Map<String, Set<String>> allowed = <String, Set<String>>{
    // Definisi tema: di sinilah `elevation: 0` DITULIS, yaitu tempat bayangan
    // Material bawaan dimatikan untuk seluruh aplikasi. Melarangnya di sini
    // justru akan mengembalikan bayangannya.
    'lib/core/theme/app_theme.dart': <String>{'elevation:'},
  };

  for (final String pattern in <String>[
    'Gradient',
    'BoxShadow',
    'elevation:',
  ]) {
    test('nol "$pattern" di dalam lib/', () {
      final List<String> hits = <String>[];

      for (final File file in libSources()) {
        final String path = file.path;
        if (allowed[path]?.contains(pattern) ?? false) continue;

        final List<String> lines = file.readAsLinesSync();

        for (int i = 0; i < lines.length; i++) {
          if (!isCode(lines[i])) continue;
          if (!lines[i].contains(pattern)) continue;

          hits.add('$path:${i + 1}: ${lines[i].trim()}');
        }
      }

      expect(
        hits,
        isEmpty,
        reason:
            'Gradient, bayangan dan glow dilarang tanpa pengecualian. Kalau '
            'sebuah kasus benar-benar memerlukannya, yang berubah adalah '
            'daftar izin di berkas ini — dan perubahan itu terlihat di diff, '
            'yang memang seluruh maksudnya.\n${hits.join('\n')}',
      );
    });
  }

  test('aturan rotasi tidak bisa dipintas di lib/features/home/', () {
    // Orientasi hanya pernah berarti dua hal — cukup lebar untuk dua kolom,
    // dan cukup tinggi untuk memikulnya — dan keduanya sudah dijawab
    // `AppLayout`. `MediaQuery.orientationOf` berbohong pada split-screen, pada
    // foldable, dan pada jendela desktop yang diseret sempit.
    final List<String> hits = <String>[];

    for (final File file in libSources()) {
      if (!file.path.startsWith('lib/features/home/')) continue;

      final List<String> lines = file.readAsLinesSync();

      for (int i = 0; i < lines.length; i++) {
        if (!isCode(lines[i])) continue;
        if (!lines[i].contains('orientationOf') &&
            !lines[i].contains('OrientationBuilder')) {
          continue;
        }

        hits.add('${file.path}:${i + 1}: ${lines[i].trim()}');
      }
    }

    expect(hits, isEmpty, reason: hits.join('\n'));
  });
}

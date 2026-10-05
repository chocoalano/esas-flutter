import 'package:esas/core/utils/string_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('limitString', () {
    test('null and empty become the placeholder', () {
      expect(limitString(null), 'N/A');
      expect(limitString(''), 'N/A');
    });

    test('a short value is returned whole', () {
      expect(limitString('Cuti Tahunan'), 'Cuti Tahunan');
    });

    test('a long value is truncated to maxLength including the ellipsis', () {
      expect(limitString('Cuti Tahunan Bersama', maxLength: 10), 'Cuti Ta...');
      expect(limitString('Cuti Tahunan Bersama', maxLength: 10).length, 10);
    });

    test('a maxLength below the ellipsis itself floors at 3', () {
      // The floor is what stops `substring(0, maxLength - 3)` going negative.
      expect(limitString('Cuti', maxLength: 1), '...');
    });
  });

  group('htmlToPlainText', () {
    // Perbedaan yang menjadi inti bug: endpoint daftar pengumuman sengaja
    // tidak mengirim badan setiap pengumuman, jadi null di sana berarti
    // "belum diminta". Kartu carousel yang menerjemahkannya menjadi kalimat
    // "Tidak ada rincian." melaporkan sesuatu yang tidak benar, di setiap
    // baris, sambil memakan ruang milik judul dan tanggal.
    test('null tetap null, bukan kalimat pengganti', () {
      expect(htmlToPlainText(null), isNull);
    });

    test('isi yang efektif kosong juga null', () {
      expect(htmlToPlainText(''), isNull);
      expect(htmlToPlainText('   '), isNull);
      expect(htmlToPlainText('<p></p>'), isNull);
      expect(htmlToPlainText('<p>&nbsp;</p>'), isNull);
    });

    test('membuang tag dan merapikan spasi', () {
      expect(htmlToPlainText('<p>Rapat <b>umum</b></p>'), 'Rapat umum');
    });

    test('tag blok menjadi batas kata, bukan lenyap', () {
      // Tanpa ini "<p>Halo</p><p>Dunia</p>" terbaca "HaloDunia".
      expect(htmlToPlainText('<p>Halo</p><p>Dunia</p>'), 'Halo Dunia');
    });

    test('mengembalikan entitas HTML yang umum', () {
      expect(
        htmlToPlainText('PT A &amp; B &quot;Jaya&quot; &#39;25'),
        'PT A & B "Jaya" \'25',
      );
      expect(htmlToPlainText('5 &lt; 10 &gt; 3'), '5 < 10 > 3');
    });
  });

  group('sentenceFromShout', () {
    test('a shouted title becomes a sentence', () {
      expect(
        sentenceFromShout(
          'KEBIJAKAN JAM MASUK KERJA, IJIN TERLAMBAT, PULANG AWAL',
        ),
        'Kebijakan jam masuk kerja, ijin terlambat, pulang awal',
      );
    });

    test('a title written in mixed case is never touched', () {
      expect(
        sentenceFromShout('Kebijakan jam masuk kerja'),
        'Kebijakan jam masuk kerja',
      );
      expect(
        sentenceFromShout('Libur Bersama Idulfitri'),
        'Libur Bersama Idulfitri',
      );
    });

    test('an acronym survives the trip down', () {
      expect(
        sentenceFromShout('SOP PENGGUNAAN APD DI AREA PRODUKSI'),
        'SOP penggunaan APD di area produksi',
      );
      expect(
        sentenceFromShout('PENGUMUMAN DARI PT SUMBER MAKMUR'),
        'Pengumuman dari PT sumber makmur',
      );
    });

    test('a token carrying a digit keeps its shape', () {
      // "K3" diturunkan menjadi "k3" akan mengubah nama sebuah komite menjadi
      // sesuatu yang tidak ada, dan jam "07.30" tidak punya huruf kecil.
      expect(
        sentenceFromShout('RAPAT K3 PUKUL 07.30 DI RUANG A2'),
        'Rapat K3 pukul 07.30 di ruang A2',
      );
    });

    test('a short shout is left alone', () {
      // Di bawah delapan huruf tidak ada cukup bukti bahwa caps lock-nya
      // menyala; "HRD" dan "IZIN" adalah judul yang sah.
      expect(sentenceFromShout('IZIN HRD'), 'IZIN HRD');
    });

    test('a title with real lower-case words is left alone', () {
      expect(
        sentenceFromShout('PERUBAHAN JADWAL SHIFT bulan ini'),
        'PERUBAHAN JADWAL SHIFT bulan ini',
      );
    });

    test('null and blank stay absent instead of becoming a sentence', () {
      expect(sentenceFromShout(null), isNull);
      expect(sentenceFromShout('   '), isNull);
    });
  });

  group('personName', () {
    test(
      'nama yang berteriak dijadikan kapital per kata, bukan per kalimat',
      () {
        // `toBeginningOfSentenceCase` menghasilkan "Tubagus angga dheviests" —
        // satu huruf kapital untuk tiga kata yang semuanya nama diri.
        expect(
          personName('TUBAGUS ANGGA DHEVIESTS'),
          'Tubagus Angga Dheviests',
        );
        expect(personName('ALAN GENTINA'), 'Alan Gentina');
      },
    );

    test('nama yang seluruhnya huruf kecil ikut dirapikan', () {
      expect(personName('alan gentina'), 'Alan Gentina');
    });

    test('nama yang sudah bercampur TIDAK disentuh', () {
      // Seseorang menulisnya begitu dengan sengaja, dan aturan yang lebih
      // pintar daripada itu akan merusaknya.
      expect(personName('McDonald'), 'McDonald');
      expect(personName('de Vries'), 'de Vries');
      expect(personName('Alan Gentina'), 'Alan Gentina');
    });

    test('kosong dan null tetap kosong', () {
      expect(personName(null), isNull);
      expect(personName('   '), isNull);
    });
  });

  group('sentenceFromShout menjaga akronim', () {
    test('akronim yang dipakai di lingkungan pabrik tetap kapital', () {
      // Menurunkan hurufnya menghasilkan "Bpjs", "Sop", "Iso" — kata yang tidak
      // ada, dicetak di tempat kata yang ada.
      expect(
        sentenceFromShout('KEBIJAKAN BPJS DAN SOP KESELAMATAN KERJA'),
        'Kebijakan BPJS dan SOP keselamatan kerja',
      );
      expect(
        sentenceFromShout('SERTIFIKASI ISO UNTUK SELURUH DEPARTEMEN'),
        'Sertifikasi ISO untuk seluruh departemen',
      );
    });

    test('token berangka tidak pernah diturunkan', () {
      // "K3" menjadi "k3" mengubah nama sebuah komite menjadi sesuatu yang
      // tidak ada.
      expect(
        sentenceFromShout('PANITIA K3 DAN PPh21 TAHUN 2026'),
        'Panitia K3 dan PPh21 tahun 2026',
      );
    });

    test('judul yang sudah bercampur huruf tidak disentuh', () {
      const String mixed = 'Kebijakan BPJS untuk karyawan tetap';

      expect(sentenceFromShout(mixed), mixed);
    });
  });
}

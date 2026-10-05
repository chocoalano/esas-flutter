import 'package:esas/core/tenancy/workspace_clock.dart';
import 'package:esas/core/utils/date_formatter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id'));

  group('DateFormatter', () {
    test('formats an ISO timestamp in Indonesian', () {
      expect(
        DateFormatter.dayMonthYear('2025-07-09T02:43:31.000Z'),
        '09 Juli 2025',
      );
    });

    test('fullDate names the weekday', () {
      expect(
        DateFormatter.fullDate('2025-07-09T02:43:31.000Z'),
        'Rabu, 09 Juli 2025',
      );
    });

    test('returns the input unchanged when it will not parse', () {
      expect(DateFormatter.dayMonthYear('belum diisi'), 'belum diisi');
      expect(DateFormatter.fullDate(''), '');
    });
  });

  group('greeting', () {
    // Batasnya adalah konvensi yang sudah berjalan di produk ini: pagi sampai
    // 10:59, siang sampai 14:59, sore sampai 18:59. Diuji tepat di kedua sisi
    // setiap batas, karena satu jam meleset berarti seluruh shift pagi disapa
    // "selamat malam".
    test('pagi berakhir tepat sebelum jam sebelas', () {
      expect(DateFormatter.greetingForHour(0), 'Selamat pagi');
      expect(DateFormatter.greetingForHour(5), 'Selamat pagi');
      expect(DateFormatter.greetingForHour(10), 'Selamat pagi');
    });

    test('siang mulai jam sebelas dan berakhir sebelum jam tiga', () {
      expect(DateFormatter.greetingForHour(11), 'Selamat siang');
      expect(DateFormatter.greetingForHour(14), 'Selamat siang');
    });

    test('sore mulai jam tiga dan berakhir sebelum jam tujuh', () {
      expect(DateFormatter.greetingForHour(15), 'Selamat sore');
      expect(DateFormatter.greetingForHour(18), 'Selamat sore');
    });

    test('malam mulai jam tujuh sampai tengah malam', () {
      expect(DateFormatter.greetingForHour(19), 'Selamat malam');
      expect(DateFormatter.greetingForHour(23), 'Selamat malam');
    });

    test('jam di luar 0-23 tidak melempar di layar pertama aplikasi', () {
      expect(DateFormatter.greetingForHour(-1), 'Halo');
      expect(DateFormatter.greetingForHour(24), 'Halo');
    });

    test('sapaan berjalan memakai jam workspace, bukan jam ponsel', () {
      // WIT: tujuh jam di depan UTC + 2. Yang diuji di sini bukan kata mana
      // yang keluar, melainkan bahwa yang dibaca adalah jam kantor.
      WorkspaceClock.current = const WorkspaceClock(
        name: 'Asia/Jayapura',
        abbreviation: 'WIT',
        offsetMinutes: 540,
      );

      final int hour = WorkspaceClock.current.now().hour;

      expect(DateFormatter.greeting(), DateFormatter.greetingForHour(hour));

      WorkspaceClock.current = WorkspaceClock.fallback();
    });
  });
}

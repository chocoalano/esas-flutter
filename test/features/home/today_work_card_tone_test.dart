import 'package:esas/core/theme/app_palette.dart';
import 'package:esas/core/theme/app_theme.dart';
import 'package:esas/features/home/presentation/controllers/home_controller.dart';
import 'package:esas/features/home/presentation/widgets/today_work_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Panel protagonis harus membawa warna, bukan hanya garis.
///
/// Regresi yang dijaga di sini sudah pernah terjadi dua kali. Pertama sebuah
/// gelombang menukar seluruh panel dengan satu kalimat galat; lalu sebuah
/// gelombang berikutnya mengembalikan panelnya tetapi menggambarnya sebagai
/// kartu PUTIH dengan rim hijau 32% alpha — sebuah garis rambut yang hilang di
/// bawah matahari dan yang membuat benda terpenting di dasbor terlihat persis
/// seperti empat kartu lain di bawahnya. Keduanya lolos `flutter analyze`,
/// keduanya lolos seluruh suite, dan keduanya baru ketahuan setelah seseorang
/// membuka aplikasinya dan berkata layarnya monoton.
///
/// Karena itu warnanya diperiksa sebagai nilai, bukan dipercayakan pada mata.
void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  Future<void> pumpCard(
    WidgetTester tester, {
    required HomeTodayState state,
    required ThemeData theme,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: TodayWorkCard(
            state: state,
            shiftName: 'Pagi',
            scheduleIn: '08:00',
            scheduleOut: '17:00',
            timeIn: state == HomeTodayState.notClockedIn ? null : '08:11',
            timeOut: null,
            lateMinutes: null,
            nextPunch: null,
            canClock: true,
            dayContext: null,
            error: null,
            date: 'Kamis, 3 September 2026',
            onClock: () {},
            onSignIn: () {},
            onHistory: () {},
            onRetry: () {},
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// Kotak berhias terluar milik panel — latar bernada dan garisnya.
  BoxDecoration heroDecoration(WidgetTester tester) {
    final DecoratedBox box = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(TodayWorkCard),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );

    return box.decoration as BoxDecoration;
  }

  for (final (String name, ThemeData theme, AppPalette palette) in [
    ('terang', AppTheme.lightTheme, AppPalette.light),
    ('gelap', AppTheme.darkTheme, AppPalette.dark),
  ]) {
    group('mode $name', () {
      testWidgets('panel diisi warna nada, bukan permukaan putih', (
        tester,
      ) async {
        await pumpCard(tester, state: HomeTodayState.working, theme: theme);

        final BoxDecoration decoration = heroDecoration(tester);

        expect(decoration.color, palette.success.background);
        expect(decoration.color, isNot(theme.colorScheme.surface));
        expect((decoration.border as Border).top.color, palette.success.border);
      });

      testWidgets('nada mengikuti keadaan hari ini', (tester) async {
        await pumpCard(
          tester,
          state: HomeTodayState.notClockedIn,
          theme: theme,
        );

        // Belum absen setelah jadwalnya lewat adalah peringatan, bukan
        // keberhasilan — dan bukan pula bahaya: lihat aturan nada di
        // TodayWorkCard.
        expect(heroDecoration(tester).color, palette.warning.background);
      });

      testWidgets('rel setinggi penuh membawa warna pekatnya', (tester) async {
        await pumpCard(tester, state: HomeTodayState.working, theme: theme);

        final Finder rail = find.descendant(
          of: find.byType(TodayWorkCard),
          matching: find.byWidgetPredicate(
            (w) => w is ColoredBox && w.color == palette.success.foreground,
          ),
        );

        expect(rail, findsOneWidget);
        expect(tester.getSize(rail).width, 4);
        // Setinggi kartunya, bukan setinggi satu baris teks.
        expect(
          tester.getSize(rail).height,
          tester.getSize(find.byType(TodayWorkCard)).height,
        );
      });
    });
  }
}

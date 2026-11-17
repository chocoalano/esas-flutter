import 'dart:convert';

import 'package:esas/core/theme/app_theme.dart';
import 'package:esas/core/ui/components/app_button.dart';
import 'package:esas/core/ui/dialogs/app_dialog.dart';
import 'package:esas/core/ui/dialogs/app_dialogs.dart';
import 'package:esas/core/ui/dialogs/app_image_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Bentuk baku dialog aplikasi.
///
/// Dialog di aplikasi ini dulu ditulis lima kali, dan tiga bug-nya hanya
/// diperbaiki di sebagian salinan. Tes ini mematok bahwa bentuk bersama itu
/// benar, sehingga memperbaikinya sekali berarti memperbaikinya di semua
/// dialog.
void main() {
  /// 1x1 PNG transparan.
  final image = MemoryImage(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
    ),
  );

  Future<void> host(
    WidgetTester tester,
    Future<void> Function(BuildContext context) onOpen, {
    ThemeData? theme,
    double textScale = 1.0,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme ?? AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => onOpen(context),
                child: const Text('buka'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
  }

  /// Rasio kontras WCAG antara dua warna.
  double contrast(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    final hi = la > lb ? la : lb;
    final lo = la > lb ? lb : la;

    return (hi + 0.05) / (lo + 0.05);
  }

  group('konfirmasi', () {
    testWidgets('mengembalikan true untuk aksi utama, false untuk batal', (
      tester,
    ) async {
      bool? answer;

      await host(tester, (context) async {
        answer = await showAppConfirmDialog(
          context,
          title: 'Keluar aplikasi?',
          message: 'Anda akan menutup Absensas.',
          confirmLabel: 'Keluar',
          cancelLabel: 'Tetap di sini',
          icon: Icons.logout_rounded,
        );
      });

      expect(find.text('Keluar aplikasi?'), findsOneWidget);
      expect(find.text('Anda akan menutup Absensas.'), findsOneWidget);

      await tester.tap(find.text('Keluar'));
      await tester.pumpAndSettle();
      expect(answer, isTrue);

      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tetap di sini'));
      await tester.pumpAndSettle();
      expect(answer, isFalse);
    });

    testWidgets(
      'tetap sebuah AlertDialog, supaya semantik rute milik framework',
      (tester) async {
        await host(
          tester,
          (context) => showAppConfirmDialog(context, title: 'T', message: 'M'),
        );

        expect(find.byType(AlertDialog), findsOneWidget);
      },
    );
  });

  group('aksi destruktif', () {
    for (final entry in <String, ThemeData>{
      'terang': AppTheme.lightTheme,
      'gelap': AppTheme.darkTheme,
    }.entries) {
      testWidgets(
        'memakai warna error dengan kontras AA di mode ${entry.key}',
        (tester) async {
          await host(
            tester,
            (context) => showAppConfirmDialog(
              context,
              title: 'Hapus?',
              message: 'Tidak bisa dibatalkan.',
              confirmLabel: 'Hapus',
              destructive: true,
            ),
            theme: entry.value,
          );

          final button = tester.widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Hapus'),
          );
          final fill = button.style!.backgroundColor!.resolve(<WidgetState>{})!;
          final ink = button.style!.foregroundColor!.resolve(<WidgetState>{})!;

          expect(fill, entry.value.colorScheme.error);
          // Teks putih tetap di atas warna brand — yang dulu dipakai
          // `Get.defaultDialog` — hanya 1,9:1 di mode gelap.
          expect(contrast(fill, ink), greaterThanOrEqualTo(4.5));
        },
      );
    }
  });

  group('tata letak aksi', () {
    testWidgets('berdampingan pada skala teks normal', (tester) async {
      await host(
        tester,
        (context) => showAppConfirmDialog(
          context,
          title: 'T',
          message: 'M',
          confirmLabel: 'Ya',
          cancelLabel: 'Tidak',
        ),
      );

      final cancel = tester.getTopLeft(find.text('Tidak'));
      final confirm = tester.getTopLeft(find.text('Ya'));

      expect(confirm.dy, cancel.dy);
      expect(confirm.dx, greaterThan(cancel.dx));
    });

    testWidgets('menumpuk dengan aksi utama di atas pada skala teks 1,5', (
      tester,
    ) async {
      await host(
        tester,
        (context) => showAppConfirmDialog(
          context,
          title: 'T',
          message: 'M',
          confirmLabel: 'Ya',
          cancelLabel: 'Tidak',
        ),
        textScale: 1.5,
      );

      final cancel = tester.getTopLeft(find.text('Tidak'));
      final confirm = tester.getTopLeft(find.text('Ya'));

      expect(confirm.dy, lessThan(cancel.dy));
      expect(tester.takeException(), isNull);
    });
  });

  group('selama sibuk', () {
    testWidgets('tidak bisa ditutup dengan tombol kembali', (tester) async {
      await host(
        tester,
        (context) => showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => AppDialog(
            title: 'Mengirim',
            busy: true,
            actions: [AppDialog.button(label: 'Tutup', onPressed: null)],
          ),
        ),
      );

      final navigator = tester.state<NavigatorState>(find.byType(Navigator));

      // Nilai kembalian `maybePop` TIDAK dipakai: ia `true` juga ketika
      // `PopScope` yang menangani (dan menolak) penutupan. Yang dibuktikan
      // adalah dialognya masih ada.
      await navigator.maybePop();
      await tester.pumpAndSettle();
      expect(find.text('Mengirim'), findsOneWidget);
    });

    testWidgets('bisa ditutup bila tidak sibuk', (tester) async {
      await host(
        tester,
        (context) => showDialog<void>(
          context: context,
          builder: (_) => AppDialog(
            title: 'Diam',
            actions: [AppDialog.button(label: 'Tutup', onPressed: () {})],
          ),
        ),
      );

      final navigator = tester.state<NavigatorState>(find.byType(Navigator));

      await navigator.maybePop();
      await tester.pumpAndSettle();
      expect(find.text('Diam'), findsNothing);
    });
  });

  group('berformulir', () {
    testWidgets('tidak meluap di layar pendek dengan keyboard terbuka', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.reset);

      await host(
        tester,
        (context) => showDialog<void>(
          context: context,
          builder: (_) => AppDialog(
            icon: Icons.lock_outline_rounded,
            title: 'Buka data gaji',
            message:
                'Masukkan kembali kata sandi akun Anda. Data gaji terbuka '
                'selama beberapa menit di perangkat ini.',
            content: const TextField(autofocus: true),
            actions: [
              AppDialog.button(
                label: 'Batal',
                primary: false,
                onPressed: () {},
              ),
              AppDialog.button(label: 'Buka', onPressed: () {}),
            ],
          ),
        ),
        textScale: 1.3,
      );

      // `AlertDialog` tanpa `scrollable: true` meluap tepat di sini.
      expect(tester.takeException(), isNull);
      expect(find.byType(TextField), findsOneWidget);
    });
  });

  group('tombol', () {
    testWidgets('label terbungkus, tidak terpotong', (tester) async {
      await host(
        tester,
        (context) => showDialog<void>(
          context: context,
          builder: (_) => AppDialog(
            title: 'T',
            actions: [
              AppDialog.button(
                label: 'Catat pengembalian barang yang rusak',
                onPressed: () {},
              ),
            ],
          ),
        ),
      );

      final text = tester.widget<Text>(
        find.descendant(
          of: find.byType(AppButton),
          matching: find.text('Catat pengembalian barang yang rusak'),
        ),
      );

      expect(text.maxLines, isNull);
      expect(text.overflow, isNot(TextOverflow.ellipsis));
    });
  });

  group('penampil gambar', () {
    testWidgets('punya tombol tutup yang bekerja', (tester) async {
      await host(
        tester,
        (context) =>
            showAppImageViewer(context, image: image, title: 'Foto masuk'),
      );

      expect(find.text('Foto masuk'), findsOneWidget);
      expect(find.byTooltip('Tutup'), findsOneWidget);

      await tester.tap(find.byTooltip('Tutup'));
      await tester.pumpAndSettle();

      expect(find.text('Foto masuk'), findsNothing);
    });

    testWidgets('tombol tutup memenuhi target sentuh 48dp', (tester) async {
      await host(
        tester,
        (context) => showAppImageViewer(context, image: image),
      );

      final size = tester.getSize(find.byTooltip('Tutup'));

      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    });
  });
}

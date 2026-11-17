import 'package:esas/core/theme/app_theme.dart';
import 'package:esas/core/tenancy/workspace_clock.dart';
import 'package:esas/features/home/presentation/controllers/home_controller.dart';
import 'package:esas/features/home/presentation/widgets/home_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Kepala isi Beranda: tidak ada kalimat yang ditulis mati.
///
/// Versi sebelumnya menulis "Tersinkronisasi • Kantor Pusat (WFO)" dan
/// "Lead UI/UX Engineer • Tech Division" untuk setiap orang, dan menggambar
/// tanggal contoh bila tanggal asli belum ada. Tes ini mematok kebalikannya:
/// yang tergambar hanyalah yang datanya ada.
void main() {
  setUpAll(initializeDateFormatting);

  Future<void> pump(WidgetTester tester, HomeHeader header) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(body: SingleChildScrollView(child: header)),
      ),
    );
  }

  testWidgets('sapaan memuat nama yang diformat', (tester) async {
    await pump(tester, const HomeHeader(userName: 'DIMAS PRASETYO'));

    expect(find.textContaining('Dimas Prasetyo'), findsOneWidget);
  });

  testWidgets('tanpa data, tidak ada baris yang dikarang', (tester) async {
    await pump(tester, const HomeHeader(userName: 'Dimas'));

    // Tidak ada tanggal contoh, tidak ada lokasi kerja, tidak ada jabatan.
    expect(find.textContaining('24 Okt 2024'), findsNothing);
    expect(find.textContaining('Kantor Pusat'), findsNothing);
    expect(find.textContaining('WFO'), findsNothing);
    expect(find.textContaining('Lead UI/UX'), findsNothing);
    expect(find.textContaining('Tersinkronisasi'), findsNothing);
  });

  testWidgets('jabatan dan departemen datang dari data', (tester) async {
    await pump(
      tester,
      const HomeHeader(
        userName: 'Dimas',
        position: 'Staf Gudang',
        department: 'Logistik',
      ),
    );

    expect(
      find.textContaining('Staf Gudang', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('Logistik', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('hanya jabatan: tidak ada pemisah yatim', (tester) async {
    await pump(
      tester,
      const HomeHeader(userName: 'Dimas', position: 'Staf Gudang'),
    );

    expect(find.textContaining('•', findRichText: true), findsNothing);
  });

  testWidgets('tanggal digambar apa adanya, dan hilang bila tidak ada', (
    tester,
  ) async {
    await pump(
      tester,
      const HomeHeader(userName: 'Dimas', date: 'Rabu, 3 Sep 2026'),
    );
    expect(find.text('Rabu, 3 Sep 2026'), findsOneWidget);

    await pump(tester, const HomeHeader(userName: 'Dimas'));
    expect(find.text('Rabu, 3 Sep 2026'), findsNothing);
  });

  group('pil sinkron', () {
    final DateTime at = DateTime(2026, 9, 3, 8, 24);
    final String zone = WorkspaceClock.current.abbreviation;

    testWidgets('tersinkronisasi memuat jam dan zona workspace', (
      tester,
    ) async {
      await pump(
        tester,
        HomeHeader(
          userName: 'Dimas',
          syncStatus: HomeSyncStatus.synced,
          syncedAt: at,
        ),
      );

      expect(find.text('Tersinkronisasi • 08:24 $zone'), findsOneWidget);
    });

    testWidgets('luring tidak mengaku tersinkronisasi', (tester) async {
      await pump(
        tester,
        HomeHeader(
          userName: 'Dimas',
          syncStatus: HomeSyncStatus.offline,
          syncedAt: at,
        ),
      );

      expect(find.text('Luring • data 08:24 $zone'), findsOneWidget);
      expect(find.textContaining('Tersinkronisasi'), findsNothing);
    });

    testWidgets('memuat dan memperbarui tidak menyebut jam', (tester) async {
      await pump(
        tester,
        const HomeHeader(userName: 'Dimas', syncStatus: HomeSyncStatus.loading),
      );
      expect(find.text('Memuat data…'), findsOneWidget);

      await pump(
        tester,
        const HomeHeader(
          userName: 'Dimas',
          syncStatus: HomeSyncStatus.refreshing,
        ),
      );
      expect(find.text('Memperbarui…'), findsOneWidget);
    });

    testWidgets('tersinkronisasi tanpa jam tidak mengarang jam', (tester) async {
      await pump(
        tester,
        const HomeHeader(userName: 'Dimas', syncStatus: HomeSyncStatus.synced),
      );

      expect(find.text('Tersinkronisasi'), findsOneWidget);
    });
  });
}

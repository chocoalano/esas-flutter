import 'package:esas/core/theme/app_theme.dart';
import 'package:esas/core/ui/dialogs/app_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

/// Menjaga agar snackbar tidak pernah lagi menjatuhkan aplikasi.
///
/// `Get.snackbar` menyisipkan overlay lewat `Get.overlayContext`, yang memanggil
/// `visitChildElements()` — dan itu dilarang selama fase build. Karena GetX
/// menjalankan `onInit()` sebuah controller di tengah build widget-nya, sebuah
/// controller yang melaporkan kegagalan sebelum `await` pertamanya dulu
/// menjatuhkan seluruh layar dengan
/// `FlutterError (visitChildElements() called during build)`.
void main() {
  // Antrean snackbar GetX adalah keadaan statis dan bertahan antar tes; tanpa
  // ini, snackbar dari tes sebelumnya membuat tes berikutnya tak pernah tampil.
  tearDown(Get.reset);

  Widget host(VoidCallback duringBuild) {
    return GetMaterialApp(
      theme: AppTheme.lightTheme,
      home: Builder(
        builder: (context) {
          // Persis posisi `onInit` sebuah controller GetX: dijalankan sementara
          // pohon widget masih dibangun.
          duringBuild();
          return const Scaffold(body: SizedBox.shrink());
        },
      ),
    );
  }

  /// Menjalankan waktu sampai setiap snackbar selesai menutup dirinya.
  ///
  /// Snackbar memasang timer tiga detik untuk membubarkan diri, dan harness tes
  /// menganggap timer yang masih menggantung saat pohon widget dibuang sebagai
  /// kegagalan.
  Future<void> drain(WidgetTester tester, {int snackbars = 1}) async {
    for (var i = 0; i < snackbars * 5; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.pumpAndSettle();
  }

  testWidgets('dipanggil saat build, snackbar galat tidak melempar', (
    tester,
  ) async {
    await tester.pumpWidget(host(() => showErrorSnackbar('Gagal memuat data')));

    // Frame pertama selesai; callback pasca-frame menampilkan snackbar.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
    expect(find.text('Gagal memuat data'), findsOneWidget);

    await drain(tester);
  });

  testWidgets('keempat nada aman dipanggil saat build', (tester) async {
    await tester.pumpWidget(
      host(() {
        showSuccessSnackbar('sukses');
        showWarningSnackbar('peringatan');
        showInfoSnackbar('info');
        showErrorSnackbar('galat');
      }),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);

    await drain(tester, snackbars: 4);
  });

  testWidgets('di luar fase build, snackbar tetap tampil seketika', (
    tester,
  ) async {
    await tester.pumpWidget(host(() {}));

    showInfoSnackbar('Pesan biasa');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
    expect(find.text('Pesan biasa'), findsOneWidget);

    await drain(tester);
  });
}

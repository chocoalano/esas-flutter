import 'package:esas/app/routes/app_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:esas/app/widgets/views/custom_bottom_navbar.dart';
import '../controllers/attendance_controller.dart';

class AttendanceView extends StatelessWidget {
  final AttendanceController controller = Get.put(AttendanceController());

  AttendanceView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          return;
        }
        // Tampilkan dialog konfirmasi saat tombol kembali ditekan
        showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Keluar Aplikasi'),
            content: const Text(
              'Apakah Anda yakin ingin keluar dari aplikasi?',
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.of(context).pop(false), // Tutup dialog
                child: const Text('Tidak'),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.of(context).pop(true), // Keluar dari aplikasi
                child: const Text('Ya'),
              ),
            ],
          ),
        ).then((value) {
          if (value == true) {
            SystemNavigator.pop();
          }
        });
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Scan Absensi QR'),
          centerTitle: true,
          backgroundColor: colorScheme.surface,
          actions: [
            IconButton(
              onPressed: () => Get.offAllNamed(Routes.ATTENDANCE_LIST),
              icon: Icon(Icons.data_exploration_outlined),
            ),
          ],
        ),
        body: Stack(
          children: [
            // Kamera QR Scanner - Akan di-overlay jika lokasi tidak valid
            MobileScanner(
              controller: controller.mobileScannerController,
              // Only process QR codes if location is valid to prevent unnecessary calls
              onDetect: (barcodeCapture) {
                if (controller.isLocationValid.value) {
                  controller.onQRScanned(barcodeCapture);
                }
              },
            ),

            // --- Overlay untuk Status Lokasi ---
            Obx(() {
              if (controller.isLoadingLocation.value) {
                return Positioned.fill(
                  child: Container(
                    color: colorScheme.surface.withAlpha(29), // Semi-transparan
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: colorScheme.primary),
                          const SizedBox(height: 16),
                          Text(
                            'Memvalidasi lokasi Anda...',
                            style: textTheme.titleMedium?.copyWith(
                              color: colorScheme.onSurface,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Pastikan GPS aktif dan izin lokasi diberikan.',
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              } else if (!controller.isLocationValid.value) {
                // Jika lokasi tidak valid, tampilkan overlay penuh
                return Positioned.fill(
                  child: Container(
                    color: colorScheme
                        .surfaceContainerHigh, // Warna latar belakang yang lebih solid
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.location_off_rounded,
                          size: 80,
                          color: colorScheme.error,
                        ),
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Text(
                            'Anda tidak berada dalam jangkauan absensi atau lokasi palsu terdeteksi.',
                            textAlign: TextAlign.center,
                            style: textTheme.headlineSmall?.copyWith(
                              color: colorScheme.error,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Text(
                            'Pastikan GPS Anda aktif dan akurat, serta Anda berada di area kantor. Klik Coba Lagi untuk memperbarui lokasi.',
                            textAlign: TextAlign.center,
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                        ElevatedButton.icon(
                          onPressed: () => controller
                              .revalidateLocation(), // Panggil ulang validasi lokasi
                          icon: Icon(
                            Icons.refresh_rounded,
                            color: colorScheme.onPrimary,
                          ),
                          label: Text(
                            'Coba Lagi Lokasi',
                            style: textTheme.titleMedium?.copyWith(
                              color: colorScheme.onPrimary,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            elevation: 4,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: () =>
                              Geolocator.openLocationSettings(), // Buka pengaturan lokasi
                          child: Text(
                            'Buka Pengaturan Lokasi',
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return const SizedBox.shrink(); // Kosong jika lokasi valid
            }),

            // --- UI Scanner Utama (Hanya terlihat jika lokasi valid) ---
            Obx(() {
              if (controller.isLocationValid.value &&
                  !controller.isProcessing.value) {
                return Column(
                  children: [
                    // Overlay kotak scanner + animasi garis
                    Expanded(
                      child: Center(
                        child: Container(
                          width: MediaQuery.of(context).size.width * 0.7,
                          height: MediaQuery.of(context).size.width * 0.7,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: colorScheme.primary,
                              width: 4,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: TweenAnimationBuilder<double>(
                                tween: Tween<double>(begin: 0.0, end: 1.0),
                                duration: const Duration(seconds: 2),
                                curve: Curves
                                    .easeInOutSine, // Kurva animasi yang lebih halus
                                builder: (context, value, child) {
                                  return Transform.translate(
                                    offset: Offset(
                                      0,
                                      (MediaQuery.of(context).size.width * 0.7 -
                                              4) *
                                          value,
                                    ),
                                    child: Container(
                                      width: double.infinity,
                                      height: 4,
                                      color: colorScheme.secondary.withAlpha(
                                        28,
                                      ),
                                    ),
                                  );
                                },
                                onEnd: () {
                                  // Reset animasi setelah selesai untuk looping
                                  (context as Element).markNeedsBuild();
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Teks instruksi
                    Padding(
                      padding: const EdgeInsets.only(top: 24, bottom: 24),
                      child: Text(
                        'Arahkan kamera ke QR Code',
                        style: textTheme.titleMedium?.copyWith(
                          color: Colors
                              .white, // Teks putih pada latar belakang kamera
                          fontWeight: FontWeight.w600,
                          shadows: const [
                            Shadow(
                              blurRadius: 5,
                              color: Colors.black,
                              offset: Offset(1, 1),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    // Notifikasi kode QR yang terdeteksi (sementara) - dipindahkan ke bawah
                    Obx(() {
                      if (controller.scannedCode.value.isNotEmpty) {
                        // Remove !controller.isProcessing.value here, already handled by main check
                        return Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: colorScheme.outlineVariant,
                            ),
                          ),
                          child: Text(
                            'QR Terdeteksi: ${controller.scannedCode.value}',
                            style: textTheme.bodyLarge?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    }),

                    const SizedBox(height: 24), // Spasi di atas tombol
                  ],
                );
              }
              return const SizedBox.shrink(); // Kosong jika lokasi tidak valid
            }),

            // Overlay loading ketika processing absensi
            Obx(() {
              if (controller.isProcessing.value) {
                return Positioned.fill(
                  // Use Positioned.fill to cover the whole screen
                  child: Container(
                    color: colorScheme.scrim.withAlpha(
                      27,
                    ), // Lebih gelap dan dari tema
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            color: colorScheme.onPrimary,
                          ), // Warna progress indicator
                          const SizedBox(height: 16),
                          Text(
                            'Memproses Absensi...',
                            style: textTheme.titleMedium?.copyWith(
                              color: colorScheme.onPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            }),

            // Tombol flash & switch camera - Hanya terlihat jika lokasi valid
            Obx(() {
              if (controller.isLocationValid.value &&
                  !controller.isProcessing.value) {
                return Positioned(
                  bottom: 24,
                  left: 24,
                  right: 24,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Tombol flash
                      FloatingActionButton(
                        heroTag: 'flash',
                        mini: true,
                        backgroundColor: controller.isTorchOn.value
                            ? colorScheme
                                  .tertiaryContainer // Warna indikator aktif
                            : colorScheme
                                  .surfaceContainerHigh, // Warna background tombol non-aktif
                        foregroundColor: controller.isTorchOn.value
                            ? colorScheme.onTertiaryContainer
                            : colorScheme.onSurfaceVariant,
                        onPressed: controller.toggleFlash,
                        child: Icon(
                          controller.isTorchOn.value
                              ? Icons
                                    .flash_on_rounded // Rounded icon
                              : Icons.flash_off_rounded, // Rounded icon
                        ),
                      ),
                      // Switch camera button
                      FloatingActionButton(
                        heroTag: 'switchCam',
                        mini: true,
                        backgroundColor: colorScheme.surfaceContainerHigh,
                        foregroundColor: colorScheme.onSurfaceVariant,
                        onPressed: controller.flipCamera,
                        child: const Icon(
                          Icons.cameraswitch_rounded,
                        ), // Rounded icon
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            }),
          ],
        ),
        bottomNavigationBar: const CustomBottomNavBar(),
      ),
    );
  }
}

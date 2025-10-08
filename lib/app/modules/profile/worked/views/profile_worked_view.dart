import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:esas/app/modules/profile/profile_pages.dart'; // Pastikan ini mengarah ke ProfileRoutes
import '../controllers/profile_worked_controller.dart';

class ProfileWorkedView extends GetView<ProfileWorkedController> {
  const ProfileWorkedView({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          return;
        }
        Get.offAllNamed(ProfileRoutes.PROFILE);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Info Pekerjaan'),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: () => Get.offAllNamed(ProfileRoutes.PROFILE),
          ),
        ),
        body: Obx(() {
          if (controller.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }

          if (controller.errorMessage.isNotEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: colorScheme.error,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      controller.errorMessage.value,
                      style: textTheme.bodyLarge?.copyWith(
                        color: colorScheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => controller.setupProfile(),
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            );
          }

          // Using SingleChildScrollView and mainAxisSize.min to prevent RenderFlex issues
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min, // Crucial for scrollable columns
              children: [
                // --- Bagian Informasi Umum Perusahaan ---
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Informasi Perusahaan',
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _InfoTile(
                          title: 'Nama Perusahaan',
                          value: controller.companyName,
                        ),
                        const SizedBox(height: 12),
                        _InfoTile(
                          title: 'Departemen',
                          value: controller.departmentName,
                        ),
                        const SizedBox(height: 12),
                        _InfoTile(
                          title: 'Posisi Pekerjaan',
                          value: controller.jobPosition,
                        ),
                        const SizedBox(height: 12),
                        _InfoTile(
                          title: 'Level Pekerjaan',
                          value: controller.jobLevel,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // --- Bagian Detail Pekerjaan ---
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Detail Pekerjaan',
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _InfoTile(
                          title: 'Tanggal Bergabung',
                          value: controller.joinDate,
                        ),
                        const SizedBox(height: 12),
                        _InfoTile(
                          title: 'Tanggal Tanda Tangan',
                          value: controller.signDate,
                        ),
                        const SizedBox(height: 12),
                        _InfoTile(
                          title: 'Tanggal Resign',
                          value: controller.resignDate,
                        ),
                        const SizedBox(height: 12),
                        _InfoTile(
                          title: 'Saldo Cuti',
                          value: controller.saldoCuti,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // --- Bagian Informasi Bank & Gaji ---
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Informasi Bank & Gaji',
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _InfoTile(
                          title: 'Nama Bank',
                          value: controller.bankName,
                        ),
                        const SizedBox(height: 12),
                        _InfoTile(
                          title: 'Nomor Rekening',
                          value: controller.bankNumber,
                        ),
                        const SizedBox(height: 12),
                        _InfoTile(
                          title: 'Pemegang Rekening',
                          value: controller.bankHolder,
                        ),
                        const SizedBox(height: 12),
                        _InfoTile(
                          title: 'Gaji Pokok',
                          value: controller.basicSalary,
                        ),
                        const SizedBox(height: 12),
                        _InfoTile(
                          title: 'Tipe Pembayaran',
                          value: controller.paymentType,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // --- Bagian Informasi Approval ---
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Informasi Persetujuan',
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _InfoTile(
                          title: 'Persetujuan Line',
                          value: controller.approvalLine,
                        ),
                        const SizedBox(height: 12),
                        _InfoTile(
                          title: 'Persetujuan Manajer',
                          value: controller.approvalManager,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

// Reusable widget for displaying an info tile
class _InfoTile extends StatelessWidget {
  final String title;
  final String value;

  const _InfoTile({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: textTheme.bodySmall?.copyWith(color: Colors.grey)),
        const SizedBox(height: 4),
        Text(
          value,
          style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          maxLines: 2, // Allow value to wrap if long
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

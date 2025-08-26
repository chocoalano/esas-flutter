import 'package:esas/app/data/Permit/leave_type.m.dart';
import 'package:esas/app/widgets/views/custom_bottom_navbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../controllers/permit_controller.dart';
import 'widgets/type_card_item.dart';

class PermitView extends StatelessWidget {
  const PermitView({super.key});

  @override
  Widget build(BuildContext context) {
    final PermitController controller = Get.put(PermitController());
    final ThemeData theme = Theme.of(context);

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
          title: const Text(
            'Perizinan Karyawan',
          ), // Judul yang lebih deskriptif
          centerTitle: true,
        ),
        body: Obx(() {
          if (controller.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }

          final List<LeaveType> leaveTypes = controller.leaveTypes;

          if (leaveTypes.isEmpty) {
            return const Center(
              child: Text('Tidak ada data perizinan yang tersedia.'),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio:
                    0.8, // Menyesuaikan rasio aspek untuk tampilan yang lebih baik
              ),
              itemCount: leaveTypes.length,
              itemBuilder: (context, index) {
                final LeaveType item = leaveTypes[index];
                print(item.type);
                final IconData icon = _getIconForLeaveType(item.type);

                return TypeCardItem(
                  item: item,
                  icon: icon,
                  theme: theme,
                  onTap: () {
                    Get.toNamed('/permit/list', arguments: item);
                  },
                );
              },
            ),
          );
        }),
        bottomNavigationBar: const CustomBottomNavBar(),
      ),
    );
  }

  /// Helper function untuk mendapatkan ikon berdasarkan tipe cuti.
  /// Ditempatkan di luar widget build untuk menjaga kerapihan.
  static IconData _getIconForLeaveType(String type) {
    final String lowerType = type.toLowerCase();
    if (lowerType.contains('cuti') && !lowerType.contains('sakit')) {
      return Icons.beach_access;
    }
    if (lowerType.contains('nikah') || lowerType.contains('menikahkan')) {
      return Icons.favorite;
    }
    if (lowerType.contains('khitan') || lowerType.contains('baptis')) {
      return Icons.child_care;
    }
    if (lowerType.contains('melahirkan')) return Icons.pregnant_woman;
    if (lowerType.contains('sakit')) return Icons.medical_services;
    if (lowerType.contains('wisuda')) return Icons.school;
    if (lowerType.contains('ibadah')) return Icons.self_improvement;
    if (lowerType.contains('duka') || lowerType.contains('meninggal')) {
      return Icons.sick; // Ikon untuk duka/kematian
    }
    if (lowerType.contains('lain')) return Icons.more_horiz;
    return Icons.event; // Default icon
  }
}

import 'package:esas/core/ui/components/app_empty_state.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/profile_tab_controllers.dart';

/// Slip gaji — layar yang belum punya sumber data.
///
/// Sebelumnya halaman ini menggambar ikon 80px, judul 28px, dan sebuah tombol
/// pil berwarna penuh untuk mengumumkan bahwa tidak ada apa-apa di sini: satu
/// layar yang tidak membawa satu pun nilai, digambar lebih nyaring daripada
/// layar yang membawa gaji pokok. Sekarang ia memakai keadaan kosong yang sama
/// dengan seluruh aplikasi, dengan bobot yang sama.
class ProfilePayrollView extends GetView<ProfilePayrollController> {
  const ProfilePayrollView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Info Payroll'), centerTitle: true),
      body: AppEmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'Slip gaji belum tersedia',
        message:
            'Rincian payroll belum bisa dibuka dari aplikasi. Sementara ini '
            'gaji pokok dan rekening penerima ada di Info Pekerjaan.',
        actionLabel: 'Kembali',
        onAction: Get.back<void>,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/ui/components/app_empty_state.dart';
import '../../features/home/presentation/routes/home_routes.dart';

/// Where a route nobody registered lands (CORE-06).
///
/// Without it GetX 4.7.2 null-checks the missing page inside
/// `onGenerateRoute`: the tap throws and nothing happens — a dead tile, with
/// no way to tell the person why.
class NotFoundView extends StatelessWidget {
  const NotFoundView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tidak tersedia')),
      body: AppEmptyState(
        icon: Icons.construction_rounded,
        title: 'Halaman ini belum tersedia',
        message:
            'Fitur yang Anda buka belum ada di versi aplikasi ini. Kembali ke '
            'Beranda untuk melanjutkan.',
        actionLabel: 'Ke Beranda',
        onAction: () => Get.offAllNamed(HomeRoutes.home),
      ),
    );
  }
}

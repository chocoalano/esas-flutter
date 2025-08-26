import 'package:esas/app/modules/profile/profile_pages.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/profile_payroll_controller.dart';

class ProfilePayrollView extends GetView<ProfilePayrollController> {
  const ProfilePayrollView({super.key});

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
          title: const Text('Info Payroll'),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: () => Get.offAllNamed(ProfileRoutes.PROFILE),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(
            24.0,
          ), // Add some padding around the content
          child: Center(
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center, // Vertically center the content
              crossAxisAlignment:
                  CrossAxisAlignment.center, // Horizontally center the content
              children: [
                Icon(
                  Icons
                      .construction, // A relevant icon, like a construction sign
                  size: 80, // Make the icon larger
                  color: colorScheme
                      .primary, // Use theme's primary color for the icon
                ),
                const SizedBox(height: 24), // Spacing below the icon
                Text(
                  'Segera Hadir!', // More engaging "Coming Soon" phrase
                  style: textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12), // Spacing below the main text
                Text(
                  'Kami sedang bekerja keras untuk membawa fitur info payroll yang lengkap dan mudah digunakan kepada Anda. Nantikan pembaruan selanjutnya!',
                  style: textTheme.bodyLarge?.copyWith(
                    color: colorScheme
                        .onSurfaceVariant, // A slightly subdued color
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40), // More spacing
                // Optional: Add a button or placeholder
                ElevatedButton.icon(
                  onPressed: () => Get.offAllNamed(ProfileRoutes.PROFILE),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Kembali'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// lib/app/modules/login/views/login_view.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/login_controller.dart';

class LoginView extends GetView<LoginController> {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // final size = MediaQuery.of(context).size; // 'size' is not used, can remove

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            // ⭐ Wrap your form fields with a Form widget ⭐
            key: controller
                .loginFormKey, // ⭐ Assign the GlobalKey from the controller ⭐
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 50),

                // Judul halaman
                Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Masuk ke Akun Anda",
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Pastikan NIP dan kata sandi kamu benar ya!",
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 50),

                // Form NIP
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "NIP",
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: controller.nipController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: "1234567890",
                    prefixIcon: Icon(Icons.badge),
                  ),
                  validator: (value) {
                    // ⭐ Add validator ⭐
                    if (value == null || value.isEmpty) {
                      return 'NIP tidak boleh kosong';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Form Kata Sandi
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Kata Sandi",
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Obx(
                  () => TextFormField(
                    controller: controller.passwordController,
                    obscureText: controller.isPasswordHidden.value,
                    decoration: InputDecoration(
                      hintText: "********",
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          controller.isPasswordHidden.value
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: controller.togglePasswordVisibility,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Kata sandi tidak boleh kosong';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 30),

                // Tombol Login
                Obx(
                  () => SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      // Validate the form before calling loginUser
                      onPressed: controller.isLoading.value
                          ? null
                          : () {
                              if (controller.loginFormKey.currentState!
                                  .validate()) {
                                controller.loginUser();
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: controller.isLoading.value
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text("Masuk"),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Tautan Lupa Password
                // Align(
                //   alignment: Alignment.centerRight,
                //   child: TextButton(
                //     onPressed: () => Get.toNamed('/forgot-password'),
                //     child: Text(
                //       "Lupa kata sandi?",
                //       style: TextStyle(color: theme.colorScheme.primary),
                //     ),
                //   ),
                // ),

                // Navigasi ke halaman pendaftaran
                // Row(
                //   mainAxisAlignment: MainAxisAlignment.center,
                //   children: [
                //     Text(
                //       "Belum punya akun?",
                //       style: theme.textTheme.bodyMedium,
                //     ),
                //     TextButton(
                //       onPressed: () {},
                //       child: Text(
                //         "Daftar sekarang",
                //         style: TextStyle(
                //           color: theme.colorScheme.primary,
                //           fontWeight: FontWeight.bold,
                //         ),
                //       ),
                //     ),
                //   ],
                // ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

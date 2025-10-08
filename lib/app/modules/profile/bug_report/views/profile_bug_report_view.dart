import 'package:esas/app/modules/profile/profile_pages.dart';
import 'package:esas/utils/helper.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/profile_bug_report_controller.dart'; // Ensure this path is correct

class ProfileBugReportView extends GetView<ProfileBugReportController> {
  const ProfileBugReportView({super.key});

  @override
  Widget build(BuildContext context) {
    // Access Theme data for consistent styling
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
          title: const Text('Laporkan Bug'),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
            ), // Modern back icon
            onPressed: () => Get.offAllNamed(
              ProfileRoutes.PROFILE,
            ), // Prefer Get.back() for simple navigation
          ),
          backgroundColor: colorScheme
              .surfaceContainerHighest, // A slightly more prominent app bar
          elevation: 0, // Subtle shadow for depth
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: controller.bugReportFormKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // --- Engaging Introduction Text ---
                Text(
                  'Bantu kami meningkatkan aplikasi. Jelaskan bug atau masalah yang Anda temui secara detail, dan lampirkan screenshot jika ada!',
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500, // Slightly bolder for emphasis
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // --- Input Fields (Refined Design) ---
                _buildTextFormField(
                  context,
                  controller: controller.titleController,
                  labelText: 'Judul Laporan',
                  hintText: 'Cth: Aplikasi crash saat membuka profil',
                  validator: controller.validateTitle,
                  maxLength: 255,
                  icon: Icons.bug_report_outlined,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                _buildTextFormField(
                  context,
                  controller: controller.messageController,
                  labelText: 'Deskripsi Detail kronologi Bug',
                  hintText:
                      'Langkah-langkah reproduksi, pesan error, kapan terjadi, dll.',
                  validator: controller.validateMessage,
                  maxLines: null,
                  minLines: 3,
                  keyboardType: TextInputType.multiline,
                  icon: Icons.description_outlined,
                  alignLabelWithHint:
                      true, // For multiline text, label aligns with hint
                ),
                const SizedBox(height: 24), // Increased spacing
                // --- Platform Dropdown (Consistent Styling) ---
                _buildPlatformDropdown(context),
                const SizedBox(height: 24),

                // --- Image Picker Section (Enhanced UI) ---
                _buildImagePickerSection(context),
                const SizedBox(height: 24),

                // --- Status Checkbox (Improved Readability) ---
                _buildStatusCheckbox(context),
                const SizedBox(height: 32),

                // --- Submit Button (Interactive and Themed) ---
                _buildSubmitButton(context),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Helper method for consistent TextFormField styling
  Widget _buildTextFormField(
    BuildContext context, {
    required TextEditingController controller,
    required String labelText,
    String? hintText,
    String? Function(String?)? validator,
    int? maxLength,
    int? maxLines,
    int? minLines,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    required IconData icon,
    bool alignLabelWithHint = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return TextFormField(
      controller: controller,
      decoration: inputDecoration(
        Theme.of(context),
        labelText,
        hintText: hintText,
      ),
      validator: validator,
      maxLength: maxLength,
      maxLines: maxLines,
      minLines: minLines,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      cursorColor: colorScheme.primary, // Cursor color matches theme
    );
  }

  /// Helper method for Platform Dropdown
  Widget _buildPlatformDropdown(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Obx(
      () => DropdownButtonFormField<String>(
        initialValue: controller.selectedPlatform.value,
        decoration: inputDecoration(
          Theme.of(context),
          'Platform ditemukan',
          hintText: 'android',
        ),
        items: controller.platforms.map((String platform) {
          IconData icon;
          if (platform == 'web') {
            icon = Icons.web;
          } else if (platform == 'android') {
            icon = Icons.android;
          } else {
            icon = Icons.apple; // For iOS
          }
          return DropdownMenuItem<String>(
            value: platform,
            child: Row(
              children: [
                Icon(
                  icon,
                  color: colorScheme.onSurfaceVariant,
                ), // Adjusted icon color
                const SizedBox(width: 12),
                Text(platform.capitalizeFirst!, style: textTheme.bodyLarge),
              ],
            ),
          );
        }).toList(),
        onChanged: controller.onPlatformChanged,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Pilih platform di mana bug ditemukan.';
          }
          return null;
        },
        dropdownColor:
            colorScheme.surfaceContainer, // Background of the dropdown menu
      ),
    );
  }

  /// Helper method for Image Picker Section
  Widget _buildImagePickerSection(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Lampirkan Screenshot (Wajib)', // Explicitly state it's required
          style: textTheme.titleSmall?.copyWith(color: colorScheme.onSurface),
        ),
        const SizedBox(height: 8),
        Obx(() {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton.icon(
                onPressed: controller.pickImage,
                icon: const Icon(
                  Icons.add_photo_alternate_rounded,
                ), // Rounded icon
                label: Text(
                  controller.pickedImage.value == null
                      ? 'Pilih Gambar'
                      : 'Ganti Gambar',
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ), // Bolder text
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.primary,
                  side: BorderSide(color: colorScheme.primary, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle:
                      textTheme.bodyLarge, // Ensure text style is applied
                ),
              ),
              const SizedBox(height: 16),

              if (controller.pickedImage.value != null)
                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    Container(
                      height: 200, // Larger preview area
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(
                          16,
                        ), // More rounded corners
                        border: Border.all(
                          color: colorScheme.outlineVariant,
                          width: 1,
                        ),
                        image: DecorationImage(
                          image: FileImage(controller.pickedImage.value!),
                          fit: BoxFit.cover,
                        ),
                        boxShadow: [
                          // Subtle shadow for the image
                          BoxShadow(
                            color: colorScheme.shadow.withAlpha(20),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      clipBehavior:
                          Clip.antiAlias, // Clip image to border radius
                    ),
                    Positioned(
                      top: 10, // Adjusted position
                      right: 10, // Adjusted position
                      child: GestureDetector(
                        // Use GestureDetector for custom tap area
                        onTap: controller.removePickedImage,
                        child: CircleAvatar(
                          backgroundColor: colorScheme.error.withAlpha(20),
                          radius: 20, // Slightly larger
                          child: Icon(
                            Icons.close_rounded,
                            color: colorScheme.onError,
                            size: 24,
                          ), // Rounded close icon
                        ),
                      ),
                    ),
                  ],
                )
              else
                // Display validation message if no image picked
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    controller.validateImageRequired(
                          controller.pickedImage.value,
                        ) ??
                        '',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.error,
                    ),
                  ),
                ),
            ],
          );
        }),
      ],
    );
  }

  /// Helper method for Status Checkbox
  Widget _buildStatusCheckbox(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Obx(
      () => Card(
        // Wrap in Card for better visual separation
        margin: EdgeInsets.zero, // No external margin, padding inside
        elevation: 0, // Subtle elevation
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: colorScheme.primary.withAlpha(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
          child: CheckboxListTile(
            title: Text(
              'Bug Aktif',
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ), // Stronger title
            ),
            subtitle: Text(
              'Centang jika bug ini masih terjadi dan perlu penanganan segera.',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            value: controller.status.value,
            onChanged: controller.onStatusChanged,
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: colorScheme.primary,
            checkColor: colorScheme.onPrimary,
            // The shape property for CheckboxListTile mostly affects the splash effect,
            // not the container itself. Use Card for container styling.
          ),
        ),
      ),
    );
  }

  /// Helper method for Submit Button
  Widget _buildSubmitButton(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Obx(
      () => ElevatedButton.icon(
        onPressed: controller.isLoading.value
            ? null
            : () async {
                // Manual validation for the image field before overall form submission
                final String? imageError = controller.validateImageRequired(
                  controller.pickedImage.value,
                );
                if (imageError != null) {
                  // Trigger form validation to show other field errors if any
                  controller.bugReportFormKey.currentState?.validate();
                  return; // Stop if image is missing
                }
                await controller.submitBugReport();
              },
        icon: controller.isLoading.value
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: colorScheme.onPrimary,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.send_rounded), // Modern send icon
        label: Text(
          controller.isLoading.value
              ? 'Mengirim Laporan...'
              : 'Kirim Laporan Bug',
          style: textTheme.titleMedium?.copyWith(
            color: colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary, // Text and icon color
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 6, // More prominent shadow
          shadowColor: colorScheme.primary.withAlpha(20),
        ),
      ),
    );
  }
}

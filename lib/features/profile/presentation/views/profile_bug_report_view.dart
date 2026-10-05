import 'package:esas/core/theme/app_dimens.dart';
import 'package:esas/core/theme/app_palette.dart';
import 'package:esas/core/ui/components/app_button.dart';
import 'package:esas/core/ui/components/app_card.dart';
import 'package:esas/core/ui/components/app_input_decoration.dart';
import 'package:esas/core/ui/components/app_section_header.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/profile_bug_report_controller.dart';

/// Formulir laporan bug.
///
/// Tiga hal yang berubah di sini semuanya soal umpan balik, bukan hiasan:
/// tombol kirim memakai [AppButton] sehingga labelnya tetap terbaca selama
/// pengiriman alih-alih digantikan spinner; tombol hapus lampiran berhenti
/// menggambar ikon `onError` di atas isian `error` 8% — kombinasi yang nyaris
/// tak terlihat di kedua mode, pada satu-satunya kontrol yang bisa membatalkan
/// pilihan; dan bayangan di sekitar pratinjau serta elevasi 6 pada tombol
/// kirim dihapus, karena kedalaman di aplikasi ini dibawa garis 1px.
class ProfileBugReportView extends GetView<ProfileBugReportController> {
  const ProfileBugReportView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Laporkan Bug'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          AppSpacing.lg,
          AppSpacing.page,
          AppSpacing.bottomSafe,
        ),
        child: Form(
          key: controller.bugReportFormKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Bantu kami meningkatkan aplikasi. Jelaskan bug atau masalah '
                'yang Anda temui secara detail, dan lampirkan screenshot jika '
                'ada!',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.palette.textMuted,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              TextFormField(
                controller: controller.titleController,
                decoration: appInputDecoration(
                  theme,
                  'Judul Laporan',
                  hintText: 'Cth: Aplikasi crash saat membuka profil',
                ),
                validator: controller.validateTitle,
                maxLength: 255,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.lg),

              TextFormField(
                controller: controller.messageController,
                decoration: appInputDecoration(
                  theme,
                  'Deskripsi Detail kronologi Bug',
                  hintText:
                      'Langkah-langkah reproduksi, pesan error, kapan '
                      'terjadi, dll.',
                ),
                validator: controller.validateMessage,
                maxLines: null,
                minLines: 3,
                keyboardType: TextInputType.multiline,
              ),
              const SizedBox(height: AppSpacing.lg),

              _PlatformField(controller: controller),
              const SizedBox(height: AppSpacing.xl),

              const AppSectionHeader(
                title: 'Lampirkan screenshot (wajib)',
                dense: true,
              ),
              _AttachmentSection(controller: controller),
              const SizedBox(height: AppSpacing.xl),

              _StatusField(controller: controller),
              const SizedBox(height: AppSpacing.xl),

              Obx(
                () => AppButton(
                  label: 'Kirim Laporan Bug',
                  icon: Icons.send_rounded,
                  busy: controller.isLoading.value,
                  onPressed: () => _submit(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    // Validasi lampiran berjalan lebih dulu karena ia bukan bagian dari `Form`;
    // bila lampirannya belum ada, `validate()` tetap dipanggil supaya field
    // lain yang juga salah ikut menampilkan pesannya dalam satu ketukan.
    final String? imageError = controller.validateImageRequired(
      controller.pickedImage.value,
    );

    if (imageError != null) {
      controller.bugReportFormKey.currentState?.validate();
      return;
    }

    await controller.submitBugReport();
  }
}

class _PlatformField extends StatelessWidget {
  const _PlatformField({required this.controller});

  final ProfileBugReportController controller;

  static const Map<String, IconData> _icons = <String, IconData>{
    'web': Icons.language_rounded,
    'android': Icons.android_rounded,
    'ios': Icons.phone_iphone_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Obx(
      () => DropdownButtonFormField<String>(
        initialValue: controller.selectedPlatform.value,
        decoration: appInputDecoration(
          theme,
          'Platform ditemukan',
          hintText: 'android',
        ),
        items: controller.platforms.map((String platform) {
          return DropdownMenuItem<String>(
            value: platform,
            child: Row(
              children: [
                Icon(
                  _icons[platform] ?? Icons.devices_other_rounded,
                  size: AppIconSizes.xl,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.md),
                Text(
                  platform.capitalizeFirst!,
                  style: theme.textTheme.bodyLarge,
                ),
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
        dropdownColor: theme.colorScheme.surface,
      ),
    );
  }
}

class _AttachmentSection extends StatelessWidget {
  const _AttachmentSection({required this.controller});

  final ProfileBugReportController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;

    return Obx(() {
      final image = controller.pickedImage.value;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppButton(
            label: image == null ? 'Pilih Gambar' : 'Ganti Gambar',
            icon: Icons.add_photo_alternate_rounded,
            variant: AppButtonVariant.outlined,
            onPressed: controller.pickImage,
          ),
          const SizedBox(height: AppSpacing.md),
          if (image != null)
            Stack(
              alignment: Alignment.topRight,
              children: [
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: AppRadii.xlAll,
                    border: Border.all(color: palette.borderSubtle),
                    image: DecorationImage(
                      image: FileImage(image),
                      fit: BoxFit.cover,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  // Kontrol hapus berdiri di atas permukaan buram, bukan di
                  // atas isian error 8%: ia digambar di atas screenshot apa
                  // pun, jadi ia tidak boleh bergantung pada apa yang
                  // kebetulan ada di belakangnya.
                  child: IconButton(
                    onPressed: controller.removePickedImage,
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Hapus lampiran',
                    style: IconButton.styleFrom(
                      backgroundColor: theme.colorScheme.surface,
                      foregroundColor: palette.danger.foreground,
                      side: BorderSide(color: palette.danger.border),
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppRadii.mdAll,
                      ),
                    ),
                  ),
                ),
              ],
            )
          else
            Text(
              controller.validateImageRequired(image) ?? '',
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.danger.foreground,
              ),
            ),
        ],
      );
    });
  }
}

class _StatusField extends StatelessWidget {
  const _StatusField({required this.controller});

  final ProfileBugReportController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Obx(
      () => AppCard(
        padding: EdgeInsets.zero,
        child: Material(
          type: MaterialType.transparency,
          child: CheckboxListTile(
            title: Text('Bug Aktif', style: theme.textTheme.titleSmall),
            subtitle: Text(
              'Centang jika bug ini masih terjadi dan perlu penanganan segera.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.palette.textMuted,
              ),
            ),
            value: controller.status.value,
            onChanged: controller.onStatusChanged,
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
          ),
        ),
      ),
    );
  }
}

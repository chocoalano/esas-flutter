import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/ui/components/app_button.dart';
import '../../../../core/ui/components/app_empty_state.dart';
import '../../../../core/ui/components/app_error_state.dart';
import '../../../../core/ui/components/app_inline_notice.dart';
import '../../../../core/ui/components/app_input_decoration.dart';
import '../../data/models/enrollment_code.dart';
import '../controllers/device_enrollment_controller.dart';
import '../routes/auth_routes.dart';
import '../widgets/device_session_notice.dart';

/// Enrol this phone for attendance with the code HR showed the employee.
///
/// One field, one button, and a state for every way it can end. Nothing on it
/// is technical: the key, the challenge and the signature happen behind
/// "Daftarkan Perangkat".
class DeviceEnrollmentView extends GetView<DeviceEnrollmentController> {
  const DeviceEnrollmentView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perangkat Absensi'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          tooltip: 'Kembali',
          onPressed: controller.finish,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xxl,
            AppSpacing.xxl,
            AppSpacing.xxl,
            AppSpacing.bottomSafe,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Obx(() => _body(context)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    switch (controller.stage.value) {
      case EnrollmentStage.success:
        return _Success(
          shortId: controller.enrolled.value?.shortId,
          onDone: controller.finish,
        );
      case EnrollmentStage.keyUnavailable:
        return AppErrorState(
          icon: Icons.no_encryption_gmailerrorred_outlined,
          title: 'Ponsel Belum Dapat Dipakai untuk Absensi',
          message:
              'Ponsel ini belum dapat menyiapkan pengaman absensi. Coba lagi. '
              'Bila tetap gagal, hubungi HR.',
          actionLabel: 'Coba Lagi',
          onRetry: controller.submit,
        );
      case EnrollmentStage.recovery:
        return AppErrorState(
          icon: Icons.phonelink_erase_rounded,
          title: 'Hubungi HR untuk Mengganti Perangkat',
          message:
              'Ponsel ini belum dapat dipastikan sebagai perangkat absensi '
              'Anda. Minta HR menerbitkan kode aktivasi baru, lalu coba lagi.',
          actionLabel: 'Masukkan Kode Lain',
          onRetry: controller.startOver,
        );
      case EnrollmentStage.sessionEnded:
        return AppEmptyState(
          icon: Icons.login_rounded,
          title: deviceSessionEndedTitle,
          message: deviceSessionEndedMessage,
          actionLabel: 'Masuk Kembali',
          onAction: () => Get.offAllNamed(AuthRoutes.login),
        );
      case EnrollmentStage.input ||
          EnrollmentStage.submitting ||
          EnrollmentStage.invalidCode ||
          EnrollmentStage.offline ||
          EnrollmentStage.failed:
        return _CodeForm(controller: controller);
    }
  }
}

class _CodeForm extends StatelessWidget {
  const _CodeForm({required this.controller});

  final DeviceEnrollmentController controller;

  @override
  Widget build(BuildContext context) => Obx(() => _form(context));

  Widget _form(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;
    final stage = controller.stage.value;
    final busy = controller.busy;
    final retry =
        stage == EnrollmentStage.offline || stage == EnrollmentStage.failed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Masukkan Kode Aktivasi', style: theme.textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Daftarkan ponsel ini sekali agar bisa dipakai untuk absensi. Kode '
          'aktivasi berisi 10 karakter, contoh ABCDE-12345.',
          style: theme.textTheme.bodyMedium?.copyWith(color: palette.textMuted),
        ),
        const SizedBox(height: AppSpacing.lg),
        const AppInlineNotice(
          tone: AppNoticeTone.info,
          icon: Icons.badge_outlined,
          message:
              'Belum punya kode? Minta Kode dari HR. Kode berlaku '
              '${EnrollmentCode.validityMinutes} menit sejak diterbitkan dan '
              'hanya bisa dipakai sekali.',
        ),
        if (stage == EnrollmentStage.invalidCode) ...[
          const SizedBox(height: AppSpacing.lg),
          const _Refusal(
            title: 'Kode Tidak Berlaku',
            message:
                'Kode tidak dapat dipakai: mungkin salah ketik, sudah lewat '
                '${EnrollmentCode.validityMinutes} menit, atau sudah terpakai. '
                'Periksa lagi kodenya. Bila sudah benar, minta kode baru ke '
                'HR, lalu masukkan di sini.',
            tone: AppNoticeTone.danger,
          ),
        ],
        if (stage == EnrollmentStage.offline) ...[
          const SizedBox(height: AppSpacing.lg),
          const _Refusal(
            title: 'Tidak Ada Koneksi',
            message:
                'Perangkat belum didaftarkan. Periksa koneksi internet, lalu '
                'coba lagi.',
            tone: AppNoticeTone.warning,
          ),
        ],
        if (stage == EnrollmentStage.failed) ...[
          const SizedBox(height: AppSpacing.lg),
          _Refusal(
            title: 'Belum Berhasil',
            message:
                controller.failureMessage.value ??
                'Perangkat belum dapat didaftarkan. Coba lagi.',
            tone: AppNoticeTone.danger,
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        TextField(
          key: const ValueKey('enrollment-code-field'),
          controller: controller.codeController,
          enabled: !busy,
          autocorrect: false,
          enableSuggestions: false,
          keyboardType: TextInputType.visiblePassword,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.done,
          inputFormatters: const [EnrollmentCodeInputFormatter()],
          style: AppTypography.mono(
            color: theme.colorScheme.onSurface,
            fontSize: 22,
            letterSpacing: 2,
          ),
          onChanged: controller.onCodeChanged,
          onSubmitted: (_) => controller.submit(),
          decoration: appInputDecoration(
            theme,
            'Kode Aktivasi',
            hintText: 'XXXXX-XXXXX',
            prefixIcon: const Icon(Icons.pin_outlined, size: AppIconSizes.lg),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        AppButton(
          wrapLabel: true,
          label: retry ? 'Coba Lagi' : 'Daftarkan Perangkat',
          icon: retry ? Icons.refresh_rounded : Icons.verified_user_outlined,
          busy: busy,
          onPressed: controller.canSubmit ? controller.submit : null,
        ),
        if (busy) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            'Mendaftarkan perangkat…',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: palette.textMuted,
            ),
          ),
        ],
      ],
    );
  }
}

class _Refusal extends StatelessWidget {
  const _Refusal({
    required this.title,
    required this.message,
    required this.tone,
  });

  final String title;
  final String message;
  final AppNoticeTone tone;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppSpacing.xs),
        AppInlineNotice(tone: tone, message: message),
      ],
    );
  }
}

class _Success extends StatelessWidget {
  const _Success({required this.shortId, required this.onDone});

  final String? shortId;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppEmptyState(
          icon: Icons.verified_rounded,
          title: 'Perangkat Berhasil Didaftarkan',
          message: 'Ponsel ini sekarang dapat dipakai untuk absensi.',
        ),
        if (shortId != null)
          Text(
            'ID perangkat: $shortId',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.palette.textMuted,
            ),
          ),
        const SizedBox(height: AppSpacing.xl),
        AppButton(
          wrapLabel: true,
          label: 'Lanjut ke Absensi',
          icon: Icons.arrow_forward_rounded,
          onPressed: onDone,
        ),
      ],
    );
  }
}

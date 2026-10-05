import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/ui/components/app_button.dart';
import '../../../../core/ui/dialogs/app_bottom_sheet.dart';

/// What is shown before a camera is ever pointed at somebody's face.
///
/// **This sheet is a notice. It is not the consent record, and tapping through
/// it does not create one.** The consent that governs biometric processing is
/// HR's: it is recorded against the enrolment as
/// `hrms_user_face_references.consent_recorded_at`, and the server refuses to
/// treat an enrolment as usable without it — so an employee who reaches this
/// screen at all already has a consent on file. What this adds is the thing a
/// recorded consent cannot: telling the person, at the moment their camera is
/// about to open, what is about to happen.
///
/// A face used for attendance is *data pribadi spesifik* under **UU PDP
/// 27/2022**. Dismissing this sheet is acknowledged locally, per employee, per
/// workspace and per version of the wording, only so the same four paragraphs
/// are not shown before every clock-in.
///
/// ## What it deliberately does not say
///
/// No similarity score, no threshold, no model name, no mention of ML Kit or of
/// the scoring service. An employee does not need to understand the technology
/// to be informed by this, and a sheet that explained embeddings would be harder
/// to read, not easier.
Future<bool> showFaceNotice(BuildContext context) async {
  final read = await showAppBottomSheet<bool>(
    context,
    title: 'Verifikasi wajah',
    description:
        'Sebelum kamera dibuka, berikut yang perlu Anda ketahui tentang '
        'verifikasi wajah untuk absensi.',
    child: const _FaceNoticeBody(),
  );

  return read ?? false;
}

class _FaceNoticeBody extends StatelessWidget {
  const _FaceNoticeBody();

  static const List<(IconData, String, String)> _points = [
    (
      Icons.badge_outlined,
      'Untuk apa',
      'Memastikan yang melakukan absensi adalah Anda sendiri, bukan orang '
          'lain yang memakai perangkat Anda.',
    ),
    (
      Icons.photo_camera_outlined,
      'Apa yang diproses',
      'Satu foto wajah Anda saat verifikasi, dibandingkan dengan foto '
          'referensi yang didaftarkan HR.',
    ),
    (
      Icons.schedule_outlined,
      'Berapa lama disimpan',
      'Foto verifikasi disimpan bersama catatan kehadiran sesuai kebijakan '
          'retensi perusahaan, lalu dihapus.',
    ),
    (
      Icons.groups_outlined,
      'Siapa yang dapat melihat',
      'Anda dan bagian HR yang berwenang meninjau kehadiran.',
    ),
    (
      Icons.assignment_turned_in_outlined,
      'Persetujuan Anda',
      'Persetujuan penggunaan data wajah dicatat HR saat pendaftaran wajah, '
          'bukan pada layar ini.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (icon, title, body) in _points) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: palette.brandSubtle,
                    borderRadius: AppRadii.lgAll,
                  ),
                  child: Icon(
                    icon,
                    size: AppIconSizes.md,
                    color: palette.brandAccent,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        body,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: palette.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: palette.surfaceSubtle,
              borderRadius: AppRadii.lgAll,
              border: Border.all(color: palette.borderSubtle),
            ),
            // Only what actually exists is promised. Withdrawal is real: HR
            // deletes the face enrolment in the panel, which removes the
            // reference photographs and the consent document with it, and the
            // wajah method then disappears from this screen because the server
            // stops reporting `face_enrolled`. There is no in-app button for it,
            // so this does not imply one.
            child: Text(
              'Untuk menarik persetujuan, hubungi HR agar pendaftaran wajah '
              'Anda dihapus. Setelah dihapus, verifikasi wajah tidak lagi '
              'tersedia dan Anda tetap dapat absen dengan memindai QR.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.textMuted,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: 'Saya sudah membaca, lanjutkan',
            icon: Icons.check_rounded,
            onPressed: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Nanti saja',
            variant: AppButtonVariant.text,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }
}

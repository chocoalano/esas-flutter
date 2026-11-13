import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/ui/components/app_badge.dart';
import '../../../../core/ui/components/app_button.dart';
import '../../../../core/ui/components/app_card.dart';
import '../../../../core/ui/components/app_inline_notice.dart';
import '../../data/models/device_status.dart';
import '../../data/repositories/device_proof_gate.dart';
import '../../data/repositories/device_proof_repository.dart';
import 'device_session_notice.dart';

/// Whether attendance is ready on this phone, and what to do if it is not.
///
/// Driven by the gate's decision, which is driven by `device.attendance_block`.
/// Every sentence is for an employee: no codes, no fingerprints — at most the
/// short "ID perangkat" HR can match against.
class DeviceStatusCard extends StatelessWidget {
  const DeviceStatusCard({
    super.key,
    required this.status,
    this.device,
    this.failure,
    this.busy = false,
    this.onEnterCode,
    this.onRetry,
    this.onContinue,
  });

  final DeviceGateStatus status;
  final DeviceStatus? device;
  final DeviceProofFailure? failure;

  /// A check or proof is running.
  final bool busy;

  /// Opens the activation-code screen. Hidden while enrolment is not open.
  final VoidCallback? onEnterCode;

  final VoidCallback? onRetry;

  /// "Lanjut ke Absensi" — only where attendance is not yet gated.
  final VoidCallback? onContinue;

  bool get _canEnroll => device?.enrollmentAvailable ?? false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;
    final content = _contentFor(status);
    final tone = content.tone(palette);
    final shortId = status == DeviceGateStatus.ready ? device?.shortId : null;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppIconBox(
                icon: content.icon,
                size: 40,
                foreground: tone.foreground,
                background: tone.background,
                borderColor: tone.border,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(content.title, style: theme.textTheme.titleMedium),
                    if (content.badge != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      AppBadge(
                        label: content.badge!,
                        tone: content.badgeTone,
                        dense: true,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            content.message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: palette.textMuted,
            ),
          ),
          if (content.showSteps) ...[
            const SizedBox(height: AppSpacing.lg),
            const _Step(
              number: 1,
              title: 'Minta Kode dari HR',
              detail: 'Datangi HR dan minta kode aktivasi untuk ponsel ini.',
            ),
            const SizedBox(height: AppSpacing.sm),
            const _Step(
              number: 2,
              title: 'Masukkan Kode Aktivasi',
              detail: 'Ketik kode 10 karakter dari HR di aplikasi ini.',
            ),
          ],
          if (content.offersCode && !_canEnroll) ...[
            const SizedBox(height: AppSpacing.lg),
            const AppInlineNotice(
              tone: AppNoticeTone.info,
              message:
                  'Pendaftaran perangkat belum dibuka di aplikasi. Hubungi HR.',
            ),
          ],
          if (shortId != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'ID perangkat: $shortId',
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.textMuted,
              ),
            ),
          ],
          if (busy) ...[
            const SizedBox(height: AppSpacing.lg),
            const LinearProgressIndicator(
              semanticsLabel: 'Memeriksa perangkat absensi',
            ),
          ],
          ..._actions(content),
        ],
      ),
    );
  }

  List<Widget> _actions(_CardContent content) {
    if (busy) return const [];

    final buttons = <Widget>[
      if (content.offersCode && _canEnroll && onEnterCode != null)
        AppButton(
          wrapLabel: true,
          label: 'Masukkan Kode Aktivasi',
          icon: Icons.pin_outlined,
          onPressed: onEnterCode,
        ),
      if (content.retryLabel != null && onRetry != null)
        AppButton(
          wrapLabel: true,
          label: content.retryLabel!,
          icon: Icons.refresh_rounded,
          variant: content.offersCode
              ? AppButtonVariant.outlined
              : AppButtonVariant.filled,
          onPressed: onRetry,
        ),
      if (status == DeviceGateStatus.offerEnrollment && onContinue != null)
        AppButton(
          wrapLabel: true,
          label: 'Lanjut ke Absensi',
          variant: AppButtonVariant.text,
          onPressed: onContinue,
        ),
    ];

    return [
      for (final button in buttons) ...[
        const SizedBox(height: AppSpacing.md),
        button,
      ],
    ];
  }

  _CardContent _contentFor(DeviceGateStatus status) => switch (status) {
    DeviceGateStatus.ready => const _CardContent(
      icon: Icons.verified_user_outlined,
      title: 'Absensi Siap di Perangkat Ini',
      message: 'Perangkat ini sudah terverifikasi untuk absensi.',
      badge: 'Siap',
      badgeTone: AppBadgeTone.success,
      toneOf: _success,
    ),
    DeviceGateStatus.needsProof => const _CardContent(
      icon: Icons.shield_outlined,
      title: 'Memeriksa Perangkat',
      message:
          'Memastikan ponsel ini terdaftar untuk absensi. Tunggu sebentar.',
      toneOf: _info,
    ),
    DeviceGateStatus.offerEnrollment => const _CardContent(
      icon: Icons.phonelink_lock_outlined,
      title: 'Perangkat Absensi Belum Terdaftar',
      message:
          'Daftarkan ponsel ini sekali untuk absensi. Untuk sementara absensi '
          'tetap bisa dipakai.',
      badge: 'Belum terdaftar',
      badgeTone: AppBadgeTone.warning,
      showSteps: true,
      offersCode: true,
      toneOf: _warning,
    ),
    DeviceGateStatus.notEnrolled => const _CardContent(
      icon: Icons.phonelink_lock_outlined,
      title: 'Perangkat Absensi Belum Terdaftar',
      // Per account, said out loud: on a phone another account already
      // uses for attendance, "ponsel ini belum terdaftar" alone reads as a
      // contradiction (Putaran 8, J7/J8).
      message:
          'Akun ini belum didaftarkan untuk absensi di ponsel ini. '
          'Pendaftaran berlaku per akun, jadi setiap akun memakai kodenya '
          'sendiri. Fitur lain di aplikasi tetap bisa digunakan.',
      badge: 'Belum terdaftar',
      badgeTone: AppBadgeTone.warning,
      showSteps: true,
      offersCode: true,
      retryLabel: 'Periksa Lagi',
      toneOf: _warning,
    ),
    DeviceGateStatus.recovery => const _CardContent(
      icon: Icons.phonelink_erase_rounded,
      title: 'Hubungi HR untuk Mengganti Perangkat',
      message:
          'Ponsel ini tidak lagi dikenali untuk absensi Anda, misalnya setelah '
          'aplikasi dipasang ulang atau ponsel diganti. Minta HR menerbitkan '
          'kode aktivasi baru, lalu masukkan di sini.',
      badge: 'Perlu bantuan HR',
      badgeTone: AppBadgeTone.danger,
      offersCode: true,
      retryLabel: 'Periksa Lagi',
      toneOf: _danger,
    ),
    // This phone cannot hold the key at all: no code will change that, and
    // "Coba Lagi" would only repeat the refusal. Says what to do instead.
    DeviceGateStatus.keyUnavailable
        when failure == DeviceProofFailure.keyUnsupported =>
      const _CardContent(
        icon: Icons.no_encryption_gmailerrorred_outlined,
        title: 'Ponsel Belum Dapat Dipakai untuk Absensi',
        message:
            'Ponsel ini tidak dapat menyimpan pengaman absensi, jadi absensi '
            'belum bisa dilakukan dari ponsel ini. Hubungi HR untuk cara '
            'absensi lain. Fitur lain di aplikasi tetap bisa digunakan.',
        retryLabel: 'Periksa Lagi',
        toneOf: _danger,
      ),
    DeviceGateStatus.keyUnavailable => const _CardContent(
      icon: Icons.no_encryption_gmailerrorred_outlined,
      title: 'Ponsel Belum Dapat Dipakai untuk Absensi',
      message:
          'Ponsel ini belum dapat menyiapkan pengaman absensi. Coba lagi. '
          'Bila tetap gagal, hubungi HR.',
      retryLabel: 'Coba Lagi',
      toneOf: _danger,
    ),
    DeviceGateStatus.offline => const _CardContent(
      icon: Icons.cloud_off_rounded,
      title: 'Tidak Ada Koneksi',
      message:
          'Perangkat belum dapat diverifikasi untuk absensi. Periksa koneksi '
          'internet, lalu coba lagi.',
      retryLabel: 'Coba Lagi',
      toneOf: _warning,
    ),
    DeviceGateStatus.sessionEnded => const _CardContent(
      icon: Icons.login_rounded,
      title: deviceSessionEndedTitle,
      message: deviceSessionEndedMessage,
      toneOf: _info,
    ),
    DeviceGateStatus.failed => _CardContent(
      icon: Icons.error_outline_rounded,
      title: 'Perangkat Belum Dapat Diverifikasi',
      message: failure == DeviceProofFailure.rateLimited
          ? 'Terlalu banyak percobaan. Tunggu sebentar, lalu coba lagi.'
          : 'Terjadi kendala saat memeriksa perangkat absensi. Coba lagi '
                'beberapa saat lagi. Bila berulang, hubungi HR.',
      retryLabel: 'Coba Lagi',
      toneOf: _danger,
    ),
  };

  static AppTone _success(AppPalette palette) => palette.success;
  static AppTone _info(AppPalette palette) => palette.info;
  static AppTone _warning(AppPalette palette) => palette.warning;
  static AppTone _danger(AppPalette palette) => palette.danger;
}

class _CardContent {
  const _CardContent({
    required this.icon,
    required this.title,
    required this.message,
    required this.toneOf,
    this.badge,
    this.badgeTone = AppBadgeTone.neutral,
    this.showSteps = false,
    this.offersCode = false,
    this.retryLabel,
  });

  final IconData icon;
  final String title;
  final String message;
  final AppTone Function(AppPalette palette) toneOf;
  final String? badge;
  final AppBadgeTone badgeTone;
  final bool showSteps;
  final bool offersCode;
  final String? retryLabel;

  AppTone tone(AppPalette palette) => toneOf(palette);
}

class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.title,
    required this.detail,
  });

  final int number;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;

    // One announcement per step ("1, Minta Kode dari HR, ...") rather than
    // three separate stops for a screen reader.
    return MergeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: palette.brandSubtle,
              borderRadius: AppRadii.pillAll,
            ),
            child: Text(
              '$number',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                Text(
                  detail,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: palette.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

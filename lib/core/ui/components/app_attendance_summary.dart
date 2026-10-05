import 'package:flutter/material.dart';

import '../../theme/app_dimens.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_typography.dart';
import 'app_card.dart';

/// Panel status kehadiran hari ini: satu keadaan, dua jam, dan durasinya.
///
/// Ini blok pertama yang dilihat karyawan setiap pagi, jadi tiga hal di sini
/// bukan soal selera:
///
/// * Warnanya datang dari [AppTone], bukan dari `Colors.green`/`blue`/`red`/
///   `orange`. Judul "Sudah Absen Keluar" sebelumnya dirender `Colors.blue` di
///   atas kartu putih — sekitar 3.12:1, kalimat paling sulit dibaca di layar
///   pertama aplikasi — dan keempat warna itu juga tidak pernah ikut berubah
///   saat tema berganti.
/// * Lambang keadaan adalah [IconData], bukan huruf. Glif '⧗' (U+29D7) tidak
///   punya cakupan di Roboto, jadi keadaan menunggu — persis keadaan yang
///   dipelototi orang sambil menanti hasil pindai — tampil sebagai kotak tofu.
/// * Jamnya memakai [AppTypography.dataMedium]. Sebelumnya `fontFamily` diisi
///   daftar bergaya CSS; Flutter hanya menerima SATU nama keluarga, jadi jam di
///   Beranda diam-diam kehilangan angka tabularnya dan jatuh ke font
///   proporsional — bypass yang gagal tanpa suara, dan karena itu tidak pernah
///   dilaporkan siapa pun.
class AttendanceSummaryPanel extends StatelessWidget {
  const AttendanceSummaryPanel({
    super.key,
    required this.checkInTime,
    required this.checkOutTime,
    required this.duration,
    required this.status,
    this.onViewHistory,
  });

  final String checkInTime;
  final String? checkOutTime;
  final String? duration;
  final AttendanceStatus status;
  final VoidCallback? onViewHistory;

  AppTone _tone(AppPalette palette) {
    return switch (status) {
      AttendanceStatus.checkedIn => palette.success,
      AttendanceStatus.checkedOut => palette.info,
      AttendanceStatus.absent => palette.danger,
      AttendanceStatus.pending => palette.warning,
    };
  }

  String _statusLabel() {
    return switch (status) {
      AttendanceStatus.checkedIn => 'Sudah Absen Masuk',
      AttendanceStatus.checkedOut => 'Sudah Absen Keluar',
      AttendanceStatus.absent => 'Belum Absen',
      AttendanceStatus.pending => 'Menunggu Konfirmasi',
    };
  }

  IconData _statusIcon() {
    return switch (status) {
      AttendanceStatus.checkedIn => Icons.check_rounded,
      AttendanceStatus.checkedOut => Icons.done_all_rounded,
      AttendanceStatus.absent => Icons.radio_button_unchecked_rounded,
      AttendanceStatus.pending => Icons.hourglass_top_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;
    final AppTone tone = _tone(palette);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadii.xlAll,
        border: Border.all(color: palette.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Kepala panel: keadaan hari ini, dinyatakan bentuk lebih dulu lalu
          // warna. Ikonnya sendiri sudah membedakan keempat keadaan tanpa satu
          // pun warna terbaca, yang penting di bawah matahari gerbang pabrik.
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: tone.background,
              border: Border(bottom: BorderSide(color: palette.borderSubtle)),
            ),
            child: Row(
              children: [
                AppIconBox(
                  icon: _statusIcon(),
                  size: 48,
                  foreground: tone.foreground,
                  background: theme.colorScheme.surface,
                  borderColor: tone.border,
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Status Hari Ini',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: palette.textMuted,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        _statusLabel(),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: tone.foreground,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                _TimeRow(
                  label: 'Waktu Masuk',
                  time: checkInTime,
                  icon: Icons.login_rounded,
                ),
                if (checkOutTime != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  _TimeRow(
                    label: 'Waktu Keluar',
                    time: checkOutTime!,
                    icon: Icons.logout_rounded,
                  ),
                ],
                if (duration != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: tone.background,
                      borderRadius: AppRadii.mdAll,
                      border: Border.all(color: tone.border),
                    ),
                    // Label boleh menyusut, angkanya tidak. Pada 320dp di
                    // skala teks 1.3 kedua teks ini tidak muat berdampingan;
                    // yang mengalah harus selalu kata pengantarnya, karena
                    // durasi yang terpotong menjadi "8j 4…" adalah angka yang
                    // salah, bukan angka yang sempit.
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            'Total Durasi',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: palette.textMuted,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          duration!,
                          style: AppTypography.dataSmall(
                            color: tone.foreground,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          if (onViewHistory != null)
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: palette.borderSubtle)),
              ),
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: onViewHistory,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            'Lihat Riwayat Lengkap',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: AppIconSizes.md,
                          color: theme.colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({required this.label, required this.time, required this.icon});

  final String label;
  final String time;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: palette.brandSubtle,
            borderRadius: AppRadii.smAll,
          ),
          child: Icon(
            icon,
            size: AppIconSizes.md,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: palette.textMuted,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(time, style: AppTypography.dataMedium()),
            ],
          ),
        ),
      ],
    );
  }
}

enum AttendanceStatus { checkedIn, checkedOut, absent, pending }

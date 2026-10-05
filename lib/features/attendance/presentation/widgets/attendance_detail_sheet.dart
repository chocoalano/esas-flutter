import 'package:esas/core/config/asset_url.dart';
import 'package:esas/core/theme/app_dimens.dart';
import 'package:esas/core/theme/app_palette.dart';
import 'package:esas/core/theme/app_typography.dart';
import 'package:esas/core/ui/components/app_avatar.dart';
import 'package:esas/core/ui/components/app_badge.dart';
import 'package:esas/core/ui/components/app_data_row.dart';
import 'package:esas/core/ui/components/app_section_header.dart';
import 'package:esas/core/ui/dialogs/app_bottom_sheet.dart';
import 'package:esas/features/attendance/data/models/attendance.dart';
import 'package:esas/features/attendance/presentation/attendance_labels.dart';
import 'package:flutter/material.dart';

/// Rincian satu hari kehadiran.
///
/// Parameternya kini bertipe [Attendance], bukan `dynamic`, dan pembacaan
/// defensif `_tryGet` yang menelan setiap kesalahan ikut hilang bersamanya.
/// Penangkapan kosong itu bukan pengamanan melainkan penyembunyian: sheet ini
/// membaca `attendance.locationIn`, `attendance.locationOut`, dan
/// `attendance.user.avatarUrl` — tiga properti yang tidak ada pada model
/// (namanya `latIn`/`longIn`, `latOut`/`longOut`, dan `avatar`), jadi ketiganya
/// selalu bernilai null dan tiga baris rincian tidak pernah sekali pun
/// tergambar. Koordinat geofence yang aplikasi paksa dipenuhi setiap karyawan
/// direkam, lalu tidak pernah ditunjukkan kembali kepada pemiliknya.
///
/// Metode capture juga turun ke sini dari baris ledger. Ia jarang menjadi
/// alasan orang membuka riwayat, tetapi ketika sebuah punch dipersoalkan,
/// "Input manual" adalah jawaban pertama yang dicari.
void showAttendanceDetailSheet(BuildContext context, Attendance attendance) {
  final String imageIn = attendance.imageIn ?? '';
  final String imageOut = attendance.imageOut ?? '';

  final String userName = attendance.user?.name ?? 'Karyawan';
  final String userNip = attendance.user?.nip ?? attendanceEmptyValue;
  final String avatar = attendance.user?.avatar ?? '';

  final AttendanceGap? gap = attendanceGapOf(
    timeIn: attendance.timeIn,
    timeOut: attendance.timeOut,
    datePresence: attendance.datePresence,
  );

  final bool hasSchedule = attendance.hasSchedule;
  final String? shiftLine = attendanceShiftLine(
    shift: attendance.shift,
    shiftIn: attendance.shiftIn,
    shiftOut: attendance.shiftOut,
  );
  final String? dayTypeLabel = attendanceDayTypeLabel(attendance.dayType);

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => DraggableScrollableSheet(
      initialChildSize: 0.62,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        final theme = Theme.of(context);
        final palette = theme.palette;

        return SafeArea(
          top: false,
          child: ListView(
            controller: scrollController,
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              0,
              AppSpacing.xl,
              AppSpacing.xl,
            ),
            children: [
              // Identitas
              Row(
                children: [
                  AppAvatar(
                    userName: userName,
                    imageUrl: avatar.isEmpty ? null : assetUrl(avatar),
                    size: 40,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(userName, style: theme.textTheme.titleMedium),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          'NIP $userNip',
                          style: AppTypography.dataSmall(
                            color: palette.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Tutup',
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      size: AppIconSizes.xl,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              Text(
                attendanceFullDateLabel(attendance.datePresence),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: palette.textMuted,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Jadwal hari itu, di atas jam-jamnya, karena ia yang membuat
              // "Tepat waktu" berarti sesuatu. Tanpa baris ini, dua lencana di
              // bawah adalah penilaian tanpa pembanding yang terlihat.
              if (shiftLine != null || dayTypeLabel != null) ...[
                Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: AppIconSizes.sm,
                      color: palette.textMuted,
                    ),
                    const SizedBox(width: AppSpacing.tight),
                    Expanded(
                      child: Text(
                        [
                          if (dayTypeLabel != null) dayTypeLabel,
                          if (shiftLine != null) shiftLine,
                        ].join(' · '),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
              ],

              // Dua jam berdampingan.
              AppDetailPanel(
                children: [
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _TimeBlock(
                            label: 'Masuk',
                            time: attendance.timeIn,
                            status: attendance.statusIn,
                            hasSchedule: hasSchedule,
                            gap: attendanceHasClock(attendance.timeIn)
                                ? null
                                : gap,
                          ),
                        ),
                        VerticalDivider(width: 1, color: palette.borderSubtle),
                        Expanded(
                          child: _TimeBlock(
                            label: 'Pulang',
                            time: attendance.timeOut,
                            status: attendance.statusOut,
                            hasSchedule: hasSchedule,
                            isOut: true,
                            gap: attendanceHasClock(attendance.timeOut)
                                ? null
                                : gap,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.xxl),
              const AppSectionHeader(title: 'Rincian'),
              AppDetailPanel(
                children: [
                  AppDataRow(
                    // "Durasi tercatat", bukan "Lama kerja": yang diketahui
                    // adalah jarak antara dua punch. Istirahat tidak ada dalam
                    // payload mana pun, jadi menyebutnya jam kerja berarti
                    // menghitungkan waktu makan siang sebagai kerja.
                    label: 'Durasi tercatat',
                    value: attendanceDuration(
                      attendance.timeIn,
                      attendance.timeOut,
                      overnight: attendance.crossesMidnight,
                    ),
                  ),
                  if (shiftLine != null)
                    AppDataRow(label: 'Jadwal', value: shiftLine),
                  AppDataRow(
                    label: 'Metode masuk',
                    value: attendanceMethodLabel(attendance.typeIn),
                    valueStyle: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  AppDataRow(
                    label: 'Metode pulang',
                    value: attendanceMethodLabel(attendance.typeOut),
                    valueStyle: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  AppDataRow(
                    label: 'Titik masuk',
                    value: _coordinate(attendance.latIn, attendance.longIn),
                  ),
                  AppDataRow(
                    label: 'Titik pulang',
                    value: _coordinate(attendance.latOut, attendance.longOut),
                  ),
                ],
              ),

              if (imageIn.isNotEmpty || imageOut.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xxl),
                const AppSectionHeader(title: 'Foto absensi'),
                Row(
                  children: [
                    if (imageIn.isNotEmpty)
                      Expanded(
                        child: _PhotoTile(
                          title: 'Masuk',
                          url: assetUrl('esas-assets/deployment/$imageIn'),
                        ),
                      ),
                    if (imageIn.isNotEmpty && imageOut.isNotEmpty)
                      const SizedBox(width: AppSpacing.md),
                    if (imageOut.isNotEmpty)
                      Expanded(
                        child: _PhotoTile(
                          title: 'Pulang',
                          url: assetUrl('esas-assets/deployment/$imageOut'),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    ),
  );
}

/// Sepasang koordinat sebagaimana direkam, atau em dash bila tidak ada.
String _coordinate(String? latitude, String? longitude) {
  final lat = latitude?.trim() ?? '';
  final long = longitude?.trim() ?? '';
  if (lat.isEmpty || long.isEmpty) return attendanceEmptyValue;

  return '$lat, $long';
}

class _TimeBlock extends StatelessWidget {
  const _TimeBlock({
    required this.label,
    required this.time,
    required this.status,
    required this.hasSchedule,
    this.isOut = false,
    this.gap,
  });

  final String label;
  final String? time;
  final String? status;

  /// Apakah hari itu punya shift terjadwal.
  ///
  /// `RecordAttendance::status()` mengembalikan `Normal` tanpa syarat ketika
  /// hari itu tidak punya shift, jadi tanpa ini lencananya berbunyi "Tepat
  /// waktu" untuk sebuah punch yang tidak pernah diukur terhadap apa pun.
  final bool hasSchedule;

  /// Punch pulang memakai kosakata sendiri: server menandai pulang terlalu awal
  /// dengan `AttendanceStatus::Late`, nilai enum yang sama dengan datang
  /// terlambat.
  final bool isOut;

  /// Diisi hanya bila jamnya kosong: ia yang membedakan punch hari ini yang
  /// masih terbuka dari tanggal lampau yang tidak pernah ditutup.
  final AttendanceGap? gap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;
    final bool recorded = attendanceHasClock(time);

    final String badgeLabel = recorded
        ? (isOut
              ? attendanceOutStatusLabelFor(status, hasSchedule: hasSchedule)
              : attendanceStatusLabelFor(status, hasSchedule: hasSchedule))
        : (gap?.label ?? attendanceEmptyValue);
    final AppBadgeTone badgeTone = recorded
        ? attendanceStatusToneFor(status, hasSchedule: hasSchedule)
        : (gap?.tone ?? AppBadgeTone.neutral);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: palette.textMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.snug),
          Text(
            attendanceClock(time),
            style: AppTypography.dataLarge(
              color: recorded ? theme.colorScheme.onSurface : palette.textMuted,
            ),
          ),
          if (badgeLabel != attendanceEmptyValue) ...[
            const SizedBox(height: AppSpacing.snug),
            AppBadge(label: badgeLabel, tone: badgeTone, dense: true),
          ],
        ],
      ),
    );
  }
}

/// Foto absensi, bisa diperbesar dengan sekali ketuk.
class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.title, required this.url});

  final String title;
  final String url;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;

    return InkWell(
      borderRadius: AppRadii.xlAll,
      onTap: () => showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          insetPadding: const EdgeInsets.all(AppSpacing.lg),
          // Kerudung yang sama dengan lapisan di atas kamera, bukan ejaan
          // keempat dari hitam transparan.
          backgroundColor: palette.overlayScrim,
          child: ClipRRect(
            borderRadius: AppRadii.xlAll,
            child: InteractiveViewer(
              child: Image.network(url, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: palette.surfaceSubtle,
          borderRadius: AppRadii.xlAll,
          border: Border.all(color: palette.borderSubtle),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Center(
                child: Icon(
                  Icons.image_not_supported_outlined,
                  size: AppIconSizes.xl,
                  color: palette.textMuted,
                ),
              ),
            ),
            Positioned(
              left: AppSpacing.sm,
              top: AppSpacing.sm,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: palette.overlayScrim,
                  borderRadius: AppRadii.smAll,
                ),
                child: Text(
                  title.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: palette.onOverlay,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:math' as math;

import 'package:esas/core/theme/app_dimens.dart';
import 'package:esas/core/theme/app_palette.dart';
import 'package:esas/core/theme/app_typography.dart';
import 'package:esas/core/ui/components/app_card.dart';
import 'package:esas/core/ui/components/app_skeleton.dart';
import 'package:esas/features/home/data/repositories/home_repository.dart';
import 'package:esas/features/home/presentation/widgets/home_metric.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Sisa cuti, sebagai saldo yang bisa dilihat sekilas.
///
/// ## Berapa yang boleh digambar, dan kapan
///
/// Bentuknya mengikuti BANYAKNYA jenis izin yang punya saldo, bukan sebuah
/// petak tetap:
///
/// | Jenis | Bentuk |
/// |---|---|
/// | 0 | permukaan lembut satu baris — kosong, bukan galat |
/// | 1 | satu saldo besar, dengan bar bila jatahnya diketahui |
/// | 2 | dua kolom |
/// | 3+ | dua kolom + "Lihat semua" ke layar izin |
///
/// Tidak pernah tiga kolom atau lebih. Pada 320dp sebuah kolom ketiga menyisakan
/// ~85dp per ubin, dan angka besar di dalamnya berhenti terbaca sebagai angka
/// besar — yaitu satu-satunya alasan ubin ini ada.
///
/// ## Bar hanya ketika jatahnya nyata
///
/// `quota` datang dari server dan boleh kosong. Ketika ia ada, `terpakai =
/// quota - remaining` adalah aritmetika atas dua angka kanonis, dan barnya sah.
/// Ketika ia tidak ada, tidak ada bar — sebuah lintasan yang panjangnya
/// dikarang membuat sisa 8 hari terlihat seperti "hampir habis" atau "masih
/// banyak" tergantung angka yang tidak pernah dikirim siapa pun.
class HomeLeaveBalance extends StatelessWidget {
  const HomeLeaveBalance({
    super.key,
    required this.balances,
    required this.loading,
    required this.error,
    required this.onOpen,
    required this.onRequests,
  });

  final List<LeaveBalance> balances;
  final bool loading;

  /// Gagal dimuat. Bagian sekunder yang gagal menghilang, tidak berteriak —
  /// kegagalannya sudah tercatat di log oleh `HomeController._load`.
  final bool error;

  final VoidCallback onOpen;

  /// Daftar pengajuan. Dipakai keadaan kosong, yang tidak punya saldo untuk
  /// dibuka tetapi tetap punya sesuatu yang berguna untuk ditawarkan.
  final VoidCallback onRequests;

  /// Berapa saldo yang muat berdampingan tanpa membunuh ukuran angkanya.
  static const int _maxTiles = 2;

  bool get hasContent => loading || !error;

  /// Apakah judul bagiannya layak membawa chevron.
  ///
  /// Hanya ketika ada yang benar-benar bisa dibuka. Chevron adalah janji
  /// navigasi, bukan hiasan.
  bool get isNavigable => !loading && !error && balances.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    if (loading) return const _BalanceSkeleton();
    if (error) return const SizedBox.shrink();
    if (balances.isEmpty) return _EmptyBalance(onOpenRequests: onRequests);

    final List<LeaveBalance> shown = balances.take(_maxTiles).toList();
    final int hidden = balances.length - shown.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (shown.length == 1)
          _BalanceTile(
            balance: shown.first,
            onTap: onOpen,
            wide: true,
            accent: true,
          )
        else
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (int i = 0; i < shown.length; i++) ...<Widget>[
                  if (i > 0) const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _BalanceTile(
                      balance: shown[i],
                      onTap: onOpen,
                      // Hanya saldo PERTAMA yang bertinta hijau. Dua angka
                      // besar hijau berdampingan, ditambah bar hijau di
                      // ringkasan tepat di atasnya dan petak "Absen" yang juga
                      // hijau, mengubah aksen tunggal produk ini menjadi warna
                      // latar — dan begitu semuanya hijau, tidak ada lagi yang
                      // berarti "ini yang penting".
                      accent: i == 0,
                    ),
                  ),
                ],
              ],
            ),
          ),
        if (hidden > 0) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              // The balances themselves, not the permit tab (HOME-14): that
              // screen shows no balance, so the ones promised here were not
              // anywhere to be seen.
              onPressed: () => _showAll(context),
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              ),
              child: Text('Lihat $hidden jenis izin lainnya'),
            ),
          ),
        ],
      ],
    );
  }
}

extension on HomeLeaveBalance {
  Future<void> _showAll(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);

        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.7,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            children: <Widget>[
              Text('Sisa cuti', style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              for (final LeaveBalance balance in balances)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(leaveTypeLabel(balance)),
                  subtitle: balance.quota == null
                      ? null
                      : Text('dari ${leaveDaysLabel(balance.quota!)} hari'),
                  trailing: Text(
                    '${leaveDaysLabel(balance.remaining)} hari',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              const SizedBox(height: AppSpacing.sm),
              FilledButton(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  onOpen();
                },
                child: const Text('Ajukan izin'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BalanceTile extends StatelessWidget {
  const _BalanceTile({
    required this.balance,
    required this.onTap,
    this.wide = false,
    this.accent = false,
  });

  final LeaveBalance balance;
  final VoidCallback onTap;

  /// Satu-satunya saldo di barisnya: boleh membentang penuh, dan barnya punya
  /// ruang untuk terbaca.
  final bool wide;

  /// Saldo utama baris ini — satu-satunya yang angkanya bertinta hijau.
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppPalette palette = theme.palette;
    final bool isDark = theme.brightness == Brightness.dark;

    final num? quota = balance.quota;
    final bool hasQuota = quota != null && quota > 0;
    final num used = hasQuota ? (quota - balance.remaining).clamp(0, quota) : 0;

    if (wide && hasQuota) {
      return AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // 1. Header Baris Atas: Ikon Cuti, Nama Jenis Izin, dan Status Aktif
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF064E3B)
                            : const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.beach_access_rounded,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      leaveTypeLabel(balance),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        letterSpacing: -0.2,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF064E3B)
                        : const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF059669)
                          : const Color(0xFFA7F3D0),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF34D399)
                              : const Color(0xFF059669),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Tersedia',
                        style: TextStyle(
                          color: isDark
                              ? const Color(0xFF34D399)
                              : const Color(0xFF059669),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Divider(height: 1, color: palette.borderSubtle),
            const SizedBox(height: AppSpacing.md),
            // 2. Baris Konten: Angka Utama & Bar Kiri + Donut Chart Kanan
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: <Widget>[
                            Text(
                              leaveDaysLabel(balance.remaining),
                              style: AppTypography.dataDisplay(
                                color: theme.colorScheme.primary,
                                fontSize: 34,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              'hari',
                              style: AppTypography.dataSmall(
                                color: palette.textMuted,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: palette.brandSubtle,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Sisa Kuota',
                                style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      HomeSplitBar(
                        primary: (used * 2).round(),
                        secondary: (balance.remaining * 2).round(),
                        primaryTone: palette.neutral,
                        secondaryTone: palette.success,
                        semanticsLabel:
                            '${leaveDaysLabel(used)} dari ${leaveDaysLabel(quota)} hari '
                            'terpakai, ${leaveDaysLabel(balance.remaining)} hari tersisa',
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '$used dari $quota hari terpakai',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: palette.textMuted,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: palette.surfaceSubtle,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: palette.borderSubtle,
                      width: 1.0,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      LeaveDonutChart(
                        used: used,
                        remaining: balance.remaining,
                        total: quota,
                        size: 68,
                        strokeWidth: 7.5,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'Sisa',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: palette.textMuted,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFFF59E0B)
                                  : const Color(0xFFD97706),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'Pakai',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: palette.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            // 3. Mini Info Chips Footer: Informatif (Total Jatah, Telah Diambil, Dapat Diajukan)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              decoration: BoxDecoration(
                color: palette.surfaceSubtle,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: _MiniStat(
                        label: 'Total Jatah',
                        value: '$quota Hari',
                        color: palette.textMuted,
                      ),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 18,
                    color: palette.borderSubtle,
                  ),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: _MiniStat(
                        label: 'Telah Diambil',
                        value: '$used Hari',
                        color: isDark
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFFD97706),
                      ),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 18,
                    color: palette.borderSubtle,
                  ),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: _MiniStat(
                        label: 'Dapat Diajukan',
                        value: '${balance.remaining} Hari',
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isDark
                      ? (accent ? const Color(0xFF064E3B) : const Color(0xFF1E293B))
                      : (accent ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9)),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.beach_access_rounded,
                  size: 17,
                  color: accent
                      ? theme.colorScheme.primary
                      : palette.textMuted,
                ),
              ),
              if (hasQuota)
                LeaveDonutChart(
                  used: used,
                  remaining: balance.remaining,
                  total: quota,
                  size: 42,
                  strokeWidth: 4.5,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: <Widget>[
                Text(
                  leaveDaysLabel(balance.remaining),
                  style: AppTypography.dataDisplay(
                    color: accent && balance.remaining > 0
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
                    fontSize: 28,
                  ),
                ),
                const SizedBox(width: AppSpacing.xxs),
                Text(
                  'hari',
                  style: AppTypography.dataSmall(
                    color: palette.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            leaveTypeLabel(balance),
            style: theme.textTheme.bodySmall?.copyWith(
              color: palette.textMuted,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (hasQuota) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            HomeSplitBar(
              primary: (used * 2).round(),
              secondary: (balance.remaining * 2).round(),
              primaryTone: palette.neutral,
              secondaryTone: palette.success,
              semanticsLabel:
                  '${leaveDaysLabel(used)} dari ${leaveDaysLabel(quota)} hari '
                  'terpakai, ${leaveDaysLabel(balance.remaining)} hari tersisa',
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '$used dari $quota hari terpakai',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.textMuted,
                fontSize: 10.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: palette.textMuted,
            fontSize: 9.5,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// Grafik donat ringkas untuk visualisasi perbandingan kuota cuti terpakai vs tersisa.
class LeaveDonutChart extends StatelessWidget {
  const LeaveDonutChart({
    super.key,
    required this.used,
    required this.remaining,
    required this.total,
    this.size = 64.0,
    this.strokeWidth = 7.0,
  });

  final num used;
  final num remaining;
  final num total;
  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;
    final bool isDark = theme.brightness == Brightness.dark;

    final double validTotal = total > 0 ? total.toDouble() : 1.0;
    final double usedFraction = (used / validTotal).clamp(0.0, 1.0);
    final int percentUsed = (usedFraction * 100).round();

    final Color trackColor = isDark
        ? const Color(0xFF1E293B)
        : const Color(0xFFE2E8F0);

    final Color usedColor = isDark
        ? const Color(0xFFF59E0B)
        : const Color(0xFFD97706);

    final Color remainingColor = theme.colorScheme.primary;

    return Semantics(
      label: '$percentUsed% kuota cuti terpakai',
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            CustomPaint(
              size: Size(size, size),
              painter: _DonutChartPainter(
                usedFraction: usedFraction,
                trackColor: trackColor,
                usedColor: usedColor,
                remainingColor: remainingColor,
                strokeWidth: strokeWidth,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  '$percentUsed%',
                  style: TextStyle(
                    fontSize: size * 0.22,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                    letterSpacing: -0.5,
                    height: 1.0,
                  ),
                ),
                if (size >= 50) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    'pakai',
                    style: TextStyle(
                      fontSize: size * 0.13,
                      fontWeight: FontWeight.w600,
                      color: palette.textMuted,
                      height: 1.0,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  const _DonutChartPainter({
    required this.usedFraction,
    required this.trackColor,
    required this.usedColor,
    required this.remainingColor,
    required this.strokeWidth,
  });

  final double usedFraction;
  final Color trackColor;
  final Color usedColor;
  final Color remainingColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = (size.width - strokeWidth) / 2;

    final Paint trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    if (usedFraction <= 0.0) {
      final Paint remPaint = Paint()
        ..color = remainingColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawCircle(center, radius, remPaint);
      return;
    }

    if (usedFraction >= 1.0) {
      final Paint usedPaint = Paint()
        ..color = usedColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawCircle(center, radius, usedPaint);
      return;
    }

    final Rect rect = Rect.fromCircle(center: center, radius: radius);
    const double startAngle = -math.pi / 2;
    const double gapAngle = 0.08;
    final double remainingFraction = 1.0 - usedFraction;

    if (remainingFraction > 0.0) {
      final Paint remPaint = Paint()
        ..color = remainingColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      final double sweepRem = (2 * math.pi * remainingFraction) - gapAngle;
      if (sweepRem > 0) {
        canvas.drawArc(rect, startAngle + (gapAngle / 2), sweepRem, false, remPaint);
      }
    }

    if (usedFraction > 0.0) {
      final Paint usedPaint = Paint()
        ..color = usedColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      final double startUsed = startAngle + (2 * math.pi * remainingFraction) + (gapAngle / 2);
      final double sweepUsed = (2 * math.pi * usedFraction) - gapAngle;
      if (sweepUsed > 0) {
        canvas.drawArc(rect, startUsed, sweepUsed, false, usedPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.usedFraction != usedFraction ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.usedColor != usedColor ||
        oldDelegate.remainingColor != remainingColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

/// Tidak ada satu pun saldo, dan permintaannya BERHASIL.
///
/// Kalimatnya hanya sah setelah 200. Permintaan yang gagal tidak pernah sampai
/// ke sini — pemanggil menyembunyikan seluruh bagiannya — karena "belum ada
/// saldo cuti" adalah klaim tentang hak orangnya, dan sebuah penolakan jaringan
/// tidak memberi kita hak untuk mengucapkannya.
///
/// Bentuknya kartu bergaris dengan aksi, berbeda dari keadaan kosong ringkasan
/// bulanan di atasnya yang berupa permukaan terisi tanpa garis. Dua bagian yang
/// kebetulan kosong bersamaan tidak boleh terbaca sebagai satu blok berulang.
class _EmptyBalance extends StatelessWidget {
  const _EmptyBalance({required this.onOpenRequests});

  /// Menuju daftar pengajuan — BUKAN formulir pengajuan. Akses cepat di atas
  /// sudah menawarkan "Ajukan izin", dan dua tombol yang mengerjakan hal yang
  /// sama pada satu layar adalah satu tombol yang terlalu banyak.
  final VoidCallback onOpenRequests;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppPalette palette = theme.palette;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              AppIconBox(
                icon: Icons.beach_access_outlined,
                size: 40,
                foreground: palette.textMuted,
                background: palette.surfaceSubtle,
                borderColor: palette.borderSubtle,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      'Belum ada saldo cuti',
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      'Saldo tampil setelah hak cuti tersedia.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: palette.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onOpenRequests,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              ),
              icon: const Icon(
                Icons.arrow_forward_rounded,
                size: AppIconSizes.md,
              ),
              iconAlignment: IconAlignment.end,
              label: const Text('Lihat pengajuan'),
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceSkeleton extends StatelessWidget {
  const _BalanceSkeleton();

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = Theme.of(context).palette;

    Widget tile() => Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: AppRadii.xlAll,
          border: Border.all(color: palette.borderSubtle),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            AppSkeleton(width: 48, height: 30),
            SizedBox(height: AppSpacing.sm),
            AppSkeleton(width: 76, height: 11),
          ],
        ),
      ),
    );

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          tile(),
          const SizedBox(width: AppSpacing.md),
          tile(),
        ],
      ),
    );
  }
}

/// Nama jenis cuti dalam bahasa Indonesia.
///
/// Server mengirim kode (`ANNUAL`, `SICK`) pada sebagian instalasi dan nama pada
/// sebagian lain. Kode tidak pernah ditampilkan apa adanya kepada staf pabrik;
/// yang tidak ada di daftar diturunkan menjadi kalimat biasa daripada dicetak
/// sebagai konstanta huruf besar.
String leaveTypeLabel(LeaveBalance balance) {
  const Map<String, String> names = <String, String>{
    'annual': 'Cuti tahunan',
    'annualleave': 'Cuti tahunan',
    'cutitahunan': 'Cuti tahunan',
    'big': 'Cuti besar',
    'sick': 'Sakit',
    'sickleave': 'Sakit',
    'unpaid': 'Tanpa upah',
    'unpaidleave': 'Tanpa upah',
    'maternity': 'Cuti melahirkan',
    'paternity': 'Cuti ayah',
    'marriage': 'Cuti menikah',
    'special': 'Cuti khusus',
    'leave': 'Cuti',
    'permit': 'Izin',
  };

  final String key = balance.code.toLowerCase().replaceAll(
    RegExp(r'[^a-z]'),
    '',
  );
  final String? known = names[key];

  if (known != null) return known;

  final String raw = balance.label.trim();

  if (RegExp(r'^[A-Z0-9_\- ]+$').hasMatch(raw)) {
    final String spaced = raw.replaceAll(RegExp(r'[_\-]+'), ' ').toLowerCase();

    return toBeginningOfSentenceCase(spaced) ?? raw;
  }

  return raw;
}

/// A number of leave days the Indonesian way: `8`, `2,5` (HOME-08).
String leaveDaysLabel(num days) {
  if (days == days.roundToDouble()) return '${days.toInt()}';

  return days.toString().replaceAll('.', ',');
}

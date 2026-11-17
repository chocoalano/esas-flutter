import 'package:flutter/material.dart';

import '../../../../core/registry/module_registry.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_palette.dart';

/// Grid layanan modular enterprise 2x2 berkonsep carousel horizontal.
///
/// Setiap halaman carousel menampung maksimal 4 layanan (2 baris x 2 kolom).
/// Bila terdapat lebih dari 4 layanan, pengguna dapat menggeser (swipe)
/// antar-halaman dengan indikator titik/pill yang responsif di bagian bawah.
class EnterpriseServicesGrid extends StatefulWidget {
  const EnterpriseServicesGrid({
    super.key,
    required this.services,
    required this.onTapService,
  });

  final List<EnterpriseServiceItem> services;
  final void Function(EnterpriseServiceItem service) onTapService;

  @override
  State<EnterpriseServicesGrid> createState() => _EnterpriseServicesGridState();
}

class _EnterpriseServicesGridState extends State<EnterpriseServicesGrid> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.services.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final palette = theme.palette;
    final int total = widget.services.length;
    final int pageCount = (total / 4).ceil();

    final double textScale = (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(1.0, 1.5);
    final double carouselHeight = (144 * textScale).roundToDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          height: carouselHeight,
          child: PageView.builder(
            controller: _pageController,
            physics: const BouncingScrollPhysics(),
            itemCount: pageCount,
            onPageChanged: (int page) {
              if (_currentPage != page) {
                setState(() => _currentPage = page);
              }
            },
            itemBuilder: (BuildContext context, int pageIndex) {
              final int startIndex = pageIndex * 4;

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  // Baris 1 (Item 0 dan Item 1)
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Expanded(
                          child: _buildTileOrEmpty(startIndex),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _buildTileOrEmpty(startIndex + 1),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // Baris 2 (Item 2 dan Item 3)
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Expanded(
                          child: _buildTileOrEmpty(startIndex + 2),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _buildTileOrEmpty(startIndex + 3),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        if (pageCount > 1) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List<Widget>.generate(pageCount, (int index) {
              final bool isActive = index == _currentPage;

              return AnimatedContainer(
                duration: AppDurations.fast,
                curve: AppMotion.standard,
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                width: isActive ? 18 : 5,
                height: 4,
                decoration: BoxDecoration(
                  color: isActive
                      ? theme.colorScheme.primary
                      : palette.borderSubtle,
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }

  Widget _buildTileOrEmpty(int index) {
    if (index >= widget.services.length) {
      return const SizedBox.shrink();
    }

    final item = widget.services[index];

    return _EnterpriseServiceTile(
      service: item,
      onTap: () => widget.onTapService(item),
    );
  }
}

/// Representasi visual dan token tema per layanan enterprise.
///
/// Menyediakan warna ikon, latar belakang, border lembut, tag indikator,
/// dan micro-copy subtitle yang proporsional serta anti-overflow di semua ukuran layar.
class EnterpriseServiceVisual {
  const EnterpriseServiceVisual({
    required this.icon,
    required this.iconFg,
    required this.iconBg,
    required this.cardBorder,
    required this.tag,
    required this.tagFg,
    required this.tagBg,
    required this.compactSubtitle,
  });

  final IconData icon;
  final Color iconFg;
  final Color iconBg;
  final Color cardBorder;
  final String tag;
  final Color tagFg;
  final Color tagBg;
  final String compactSubtitle;

  static EnterpriseServiceVisual resolve(
    EnterpriseServiceItem item, {
    required bool isDark,
    required Color primaryColor,
  }) {
    final String id = item.id.toLowerCase();

    // 1. Jadwal Shift
    if (id.contains('schedule')) {
      return EnterpriseServiceVisual(
        icon: Icons.calendar_month_outlined,
        iconFg: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
        iconBg: isDark ? const Color(0xFF0C243B) : const Color(0xFFF0F9FF),
        cardBorder: isDark ? const Color(0xFF0369A1) : const Color(0xFFBAE6FD),
        tag: 'Shift',
        tagFg: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
        tagBg: isDark ? const Color(0xFF0C243B) : const Color(0xFFE0F2FE),
        compactSubtitle: 'Jadwal kerja & shift',
      );
    }

    // 2. Lembur / Overtime
    if (id.contains('overtime')) {
      return EnterpriseServiceVisual(
        icon: Icons.more_time_rounded,
        iconFg: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
        iconBg: isDark ? const Color(0xFF382305) : const Color(0xFFFFFBEB),
        cardBorder: isDark ? const Color(0xFFB45309) : const Color(0xFFFDE68A),
        tag: 'SPKL',
        tagFg: isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309),
        tagBg: isDark ? const Color(0xFF382305) : const Color(0xFFFEF3C7),
        compactSubtitle: 'Surat tugas lembur',
      );
    }

    // 3. Pinjaman / Kasbon / Financial
    if (id.contains('financial') || id.contains('loan') || id.contains('kasbon')) {
      return EnterpriseServiceVisual(
        icon: Icons.account_balance_wallet_outlined,
        iconFg: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
        iconBg: isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5),
        cardBorder: isDark ? const Color(0xFF047857) : const Color(0xFFA7F3D0),
        tag: 'Kasbon',
        tagFg: isDark ? const Color(0xFF34D399) : const Color(0xFF047857),
        tagBg: isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5),
        compactSubtitle: 'Sisa kasbon & pinjaman',
      );
    }

    // 4. AI Copilot / Assistant
    if (id.contains('ai') || id.contains('assistant') || id.contains('chat')) {
      return EnterpriseServiceVisual(
        icon: Icons.auto_awesome_rounded,
        iconFg: isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED),
        iconBg: isDark ? const Color(0xFF2E1065) : const Color(0xFFF5F3FF),
        cardBorder: isDark ? const Color(0xFF6D28D9) : const Color(0xFFDDD6FE),
        tag: 'AI',
        tagFg: isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED),
        tagBg: isDark ? const Color(0xFF2E1065) : const Color(0xFFEDE9FE),
        compactSubtitle: 'Asisten cerdas tanya jawab',
      );
    }

    // 5. GAMS: Ruang Rapat
    if (id.contains('space') || id.contains('room')) {
      return EnterpriseServiceVisual(
        icon: Icons.meeting_room_outlined,
        iconFg: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
        iconBg: isDark ? const Color(0xFF1E1B4B) : const Color(0xFFEEF2FF),
        cardBorder: isDark ? const Color(0xFF4338CA) : const Color(0xFFC7D2FE),
        tag: 'Ruangan',
        tagFg: isDark ? const Color(0xFF818CF8) : const Color(0xFF4338CA),
        tagBg: isDark ? const Color(0xFF1E1B4B) : const Color(0xFFE0E7FF),
        compactSubtitle: 'Reservasi ruang rapat',
      );
    }

    // 6. GAMS: Kendaraan
    if (id.contains('vehicle') || id.contains('car')) {
      return EnterpriseServiceVisual(
        icon: Icons.directions_car_outlined,
        iconFg: isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0D9488),
        iconBg: isDark ? const Color(0xFF134E4A) : const Color(0xFFF0FDFA),
        cardBorder: isDark ? const Color(0xFF0F766E) : const Color(0xFF99F6E4),
        tag: 'Armada',
        tagFg: isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0F766E),
        tagBg: isDark ? const Color(0xFF134E4A) : const Color(0xFFCCFBF1),
        compactSubtitle: 'Peminjaman kendaraan',
      );
    }

    // 7. GAMS: Tamu / Visitor
    if (id.contains('visitor') || id.contains('guest')) {
      return EnterpriseServiceVisual(
        icon: Icons.badge_outlined,
        iconFg: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
        iconBg: isDark ? const Color(0xFF0C243B) : const Color(0xFFF0F9FF),
        cardBorder: isDark ? const Color(0xFF0369A1) : const Color(0xFFBAE6FD),
        tag: 'Tamu',
        tagFg: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
        tagBg: isDark ? const Color(0xFF0C243B) : const Color(0xFFE0F2FE),
        compactSubtitle: 'Buku tamu & QR pass',
      );
    }

    // 8. ATK
    if (id.contains('atk')) {
      return EnterpriseServiceVisual(
        icon: Icons.inventory_2_outlined,
        iconFg: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
        iconBg: isDark ? const Color(0xFF382305) : const Color(0xFFFFFBEB),
        cardBorder: isDark ? const Color(0xFFB45309) : const Color(0xFFFDE68A),
        tag: 'ATK',
        tagFg: isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309),
        tagBg: isDark ? const Color(0xFF382305) : const Color(0xFFFEF3C7),
        compactSubtitle: 'Permintaan alat tulis',
      );
    }

    // 9. ITMS: Tiket IT
    if (id.contains('ticket') || id.contains('kendala')) {
      return EnterpriseServiceVisual(
        icon: Icons.confirmation_number_outlined,
        iconFg: isDark ? const Color(0xFFFB7185) : const Color(0xFFE11D48),
        iconBg: isDark ? const Color(0xFF4C0519) : const Color(0xFFFFF1F2),
        cardBorder: isDark ? const Color(0xFF9F1239) : const Color(0xFFFECDD3),
        tag: 'Tiket',
        tagFg: isDark ? const Color(0xFFFB7185) : const Color(0xFF9F1239),
        tagBg: isDark ? const Color(0xFF4C0519) : const Color(0xFFFFE4E6),
        compactSubtitle: 'Lapor kendala teknis & IT',
      );
    }

    // 10. ITMS: Katalog IT
    if (id.contains('catalog') || id.contains('katalog')) {
      return EnterpriseServiceVisual(
        icon: Icons.inventory_2_outlined,
        iconFg: isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED),
        iconBg: isDark ? const Color(0xFF2E1065) : const Color(0xFFF5F3FF),
        cardBorder: isDark ? const Color(0xFF6D28D9) : const Color(0xFFDDD6FE),
        tag: 'Katalog',
        tagFg: isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED),
        tagBg: isDark ? const Color(0xFF2E1065) : const Color(0xFFEDE9FE),
        compactSubtitle: 'Lisensi & aset perangkat',
      );
    }

    // 11. MTMS: Lapor Kerusakan / Maintenance
    if (id.contains('mtms') || id.contains('maintenance') || id.contains('rusak')) {
      return EnterpriseServiceVisual(
        icon: Icons.build_outlined,
        iconFg: isDark ? const Color(0xFFFB923C) : const Color(0xFFEA580C),
        iconBg: isDark ? const Color(0xFF431407) : const Color(0xFFFFF7ED),
        cardBorder: isDark ? const Color(0xFFC2410C) : const Color(0xFFFED7AA),
        tag: 'Perbaikan',
        tagFg: isDark ? const Color(0xFFFB923C) : const Color(0xFFC2410C),
        tagBg: isDark ? const Color(0xFF431407) : const Color(0xFFFFEDD5),
        compactSubtitle: 'Lapor kerusakan mesin',
      );
    }

    // 12. Payroll / Slip Gaji
    if (id.contains('salary') || id.contains('payroll')) {
      return EnterpriseServiceVisual(
        icon: Icons.payments_outlined,
        iconFg: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
        iconBg: isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5),
        cardBorder: isDark ? const Color(0xFF047857) : const Color(0xFFA7F3D0),
        tag: 'Baru',
        tagFg: isDark ? const Color(0xFF34D399) : const Color(0xFF047857),
        tagBg: isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5),
        compactSubtitle: 'Slip gaji & tunjangan',
      );
    }

    // 13. Persetujuan / Inbox
    if (id.contains('inbox') || id.contains('approval')) {
      return EnterpriseServiceVisual(
        icon: Icons.approval_rounded,
        iconFg: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
        iconBg: isDark ? const Color(0xFF0C243B) : const Color(0xFFF0F9FF),
        cardBorder: isDark ? const Color(0xFF0369A1) : const Color(0xFFBAE6FD),
        tag: 'Approval',
        tagFg: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
        tagBg: isDark ? const Color(0xFF0C243B) : const Color(0xFFE0F2FE),
        compactSubtitle: 'Approval lintas divisi',
      );
    }

    // Default Fallback
    return EnterpriseServiceVisual(
      icon: item.icon,
      iconFg: isDark ? primaryColor : const Color(0xFF059669),
      iconBg: isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5),
      cardBorder: isDark ? const Color(0xFF047857) : const Color(0xFFA7F3D0),
      tag: item.module.toUpperCase(),
      tagFg: isDark ? primaryColor : const Color(0xFF059669),
      tagBg: isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5),
      compactSubtitle: item.description,
    );
  }
}

class _EnterpriseServiceTile extends StatefulWidget {
  const _EnterpriseServiceTile({required this.service, required this.onTap});

  final EnterpriseServiceItem service;
  final VoidCallback onTap;

  @override
  State<_EnterpriseServiceTile> createState() => _EnterpriseServiceTileState();
}

class _EnterpriseServiceTileState extends State<_EnterpriseServiceTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;
    final bool isDark = theme.brightness == Brightness.dark;
    final EnterpriseServiceItem item = widget.service;

    final visual = EnterpriseServiceVisual.resolve(
      item,
      isDark: isDark,
      primaryColor: theme.colorScheme.primary,
    );

    final double textScale = (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(1.0, 1.5);

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isCompact = constraints.maxWidth < 140 || textScale > 1.15;
        final bool showTag = !isCompact;

        return Semantics(
          button: true,
          label: item.title,
          excludeSemantics: true,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(14),
              onHighlightChanged: (bool val) {
                if (_pressed != val) {
                  setState(() => _pressed = val);
                }
              },
              child: AnimatedScale(
                scale: _pressed ? 0.97 : 1.0,
                duration: AppDurations.fast,
                curve: AppMotion.standard,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? visual.cardBorder.withValues(alpha: 0.35)
                          : visual.cardBorder.withValues(alpha: 0.5),
                      width: 1.0,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: visual.iconBg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            visual.icon,
                            size: 19,
                            color: visual.iconFg,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Text(
                                      item.title,
                                      style: theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12.5,
                                        letterSpacing: -0.2,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (showTag) ...<Widget>[
                                    const SizedBox(width: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4.5,
                                        vertical: 1.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: visual.tagBg,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        visual.tag,
                                        style: TextStyle(
                                          color: visual.tagFg,
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: -0.1,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2.5),
                              Text(
                                visual.compactSubtitle,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: palette.textMuted,
                                  fontSize: 10.5,
                                  height: 1.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/ui/components/app_badge.dart';
import '../../../../core/ui/components/app_button.dart';
import '../controllers/splash_controller.dart';

/// Data representasi satu slide onboarding.
class _OnboardingSlide {
  const _OnboardingSlide({
    required this.badge,
    required this.badgeTone,
    required this.badgeIcon,
    required this.title,
    required this.description,
    required this.svgAsset,
    required this.highlights,
  });

  final String badge;
  final AppBadgeTone badgeTone;
  final IconData badgeIcon;
  final String title;
  final String description;
  final String svgAsset;
  final List<_SlideHighlight> highlights;
}

class _SlideHighlight {
  const _SlideHighlight({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// Frame pertama yang dilihat setiap karyawan saat membuka aplikasi.
///
/// Tampilan onboarding dirancang dengan pendekatan enterprise modern:
/// * **Hierarki Visual Jelas**: Dilengkapi identitas brand ("ABSENSAS") di bagian
///   header atas, badge kategori semantik, serta micro-chips fitur unggulan.
/// * **Hero Illustration Card**: Menggunakan bingkai kartu berkedalaman halus
///   ([AppPalette.surfaceSubtle] & hairline border) dengan ambient glow lembut di
///   belakang SVG, menghindari kesan gambar mengambang tanpa konteks.
/// * **Aksi Terpadu & Bebas Tabrakan**: Navigasi slide (dots indikator + tombol
///   "Lanjutkan"/"Mulai Sekarang") disatukan secara elegan tanpa duplikasi tombol.
/// * **Umpan Balik Sesi Responsif**: Status pemeriksaan sesi terintegrasi rapi
///   tanpa memicu layout shift atau balapan navigasi.
class SplashView extends GetView<SplashController> {
  const SplashView({super.key});

  static const List<_OnboardingSlide> _slides = [
    _OnboardingSlide(
      badge: 'PRESENSI CEPAT',
      badgeTone: AppBadgeTone.brand,
      badgeIcon: Icons.location_on_outlined,
      title: 'Presensi Akurat & Terverifikasi',
      description:
          'Catat kehadiran masuk dan pulang secara instan dengan verifikasi geofencing GPS presisi dan deteksi wajah biometrik.',
      svgAsset: 'assets/svg/onboarding_1.svg',
      highlights: [
        _SlideHighlight(icon: Icons.pin_drop_outlined, label: 'Geofencing GPS'),
        _SlideHighlight(icon: Icons.face_outlined, label: 'Biometrik Wajah'),
        _SlideHighlight(
          icon: Icons.verified_user_outlined,
          label: 'Validasi Lokasi',
        ),
      ],
    ),
    _OnboardingSlide(
      badge: 'SELF-SERVICE HR',
      badgeTone: AppBadgeTone.info,
      badgeIcon: Icons.assignment_outlined,
      title: 'Pengajuan Izin & Cuti Mudah',
      description:
          'Ajukan permohonan cuti, izin sakit, dan lembur langsung dari genggaman. Pantau status persetujuan atasan secara real-time.',
      svgAsset: 'assets/svg/onboarding_2.svg',
      highlights: [
        _SlideHighlight(
          icon: Icons.event_available_outlined,
          label: 'Cuti & Lembur',
        ),
        _SlideHighlight(icon: Icons.flash_on_outlined, label: 'Approval Cepat'),
        _SlideHighlight(
          icon: Icons.notifications_active_outlined,
          label: 'Notifikasi Otomatis',
        ),
      ],
    ),
    _OnboardingSlide(
      badge: 'KOLABORASI TIM',
      badgeTone: AppBadgeTone.success,
      badgeIcon: Icons.groups_outlined,
      title: 'Akses Fleksibel Kapan Saja',
      description:
          'Lihat jadwal shift kerja, rekapitulasi jam hadir, dan informasi perusahaan dengan sinkronisasi data yang aman dan terenkripsi.',
      svgAsset: 'assets/svg/onboarding_3.svg',
      highlights: [
        _SlideHighlight(
          icon: Icons.calendar_today_outlined,
          label: 'Jadwal Shift',
        ),
        _SlideHighlight(icon: Icons.timer_outlined, label: 'Rekap Jam Kerja'),
        _SlideHighlight(
          icon: Icons.lock_outline_rounded,
          label: 'Aman & Terenkripsi',
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
    );

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: _SplashCarousel(slides: _slides, controller: controller),
          ),
        ),
      ),
    );
  }
}

class _SplashCarousel extends StatefulWidget {
  const _SplashCarousel({required this.slides, required this.controller});

  final List<_OnboardingSlide> slides;
  final SplashController controller;

  @override
  State<_SplashCarousel> createState() => _SplashCarouselState();
}

class _SplashCarouselState extends State<_SplashCarousel> {
  late final PageController _pageController;
  int _currentPage = 0;
  bool _hasStarted = false;

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

  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
    });
  }

  void _handlePrimaryAction() {
    final isLastPage = _currentPage == widget.slides.length - 1;
    if (isLastPage) {
      setState(() {
        _hasStarted = true;
      });
      widget.controller.onIntroEnd();
    } else {
      _pageController.nextPage(
        duration: AppDurations.slow,
        curve: AppMotion.standard,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;
    final isLastPage = _currentPage == widget.slides.length - 1;

    return Column(
      children: [
        // Top Header: Brand Identity & Skip Action
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.md,
            AppSpacing.page,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                padding: const EdgeInsets.all(AppSpacing.xs + 1),
                decoration: BoxDecoration(
                  color: palette.surfaceRaised,
                  borderRadius: AppRadii.lgAll,
                  border: Border.all(color: palette.borderSubtle),
                ),
                child: Image.asset(
                  'assets/images/logo-square.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Icon(
                    Icons.badge_outlined,
                    size: AppIconSizes.md,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'ABSENSAS',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    'Employee Self-Service',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: palette.textMuted,
                      fontWeight: FontWeight.w500,
                      fontSize: 10.5,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: AppRadii.pillAll,
                  onTap: () {
                    setState(() {
                      _hasStarted = true;
                    });
                    widget.controller.onIntroEnd();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm + 2,
                      vertical: AppSpacing.xs + 2,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Lewati',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: palette.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xxs),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: AppIconSizes.md,
                          color: palette.textMuted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.xs),

        // Carousel Slider
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            itemCount: widget.slides.length,
            itemBuilder: (context, index) {
              final slide = widget.slides[index];

              return LayoutBuilder(
                builder: (context, constraints) {
                  final h = constraints.maxHeight;
                  final isCompact = h < 450;
                  final illustrationHeight = isCompact
                      ? 130.0
                      : (h < 550 ? 170.0 : 210.0);

                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.page,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: AppSpacing.xs),

                        // Hero Illustration Showcase
                        Container(
                          height: illustrationHeight,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: palette.surfaceSubtle,
                            borderRadius: AppRadii.xxlAll,
                            border: Border.all(color: palette.borderSubtle),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Soft ambient radial glow
                              Container(
                                width: illustrationHeight * 0.75,
                                height: illustrationHeight * 0.75,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: palette.brandGlow.withValues(
                                    alpha: 0.25,
                                  ),
                                ),
                              ),
                              // Illustration
                              Padding(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                child: SvgPicture.asset(
                                  slide.svgAsset,
                                  fit: BoxFit.contain,
                                  placeholderBuilder: (_) => Center(
                                    child: SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: palette.brandAccent,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: AppSpacing.md),

                        // Semantic Category Badge
                        AppBadge(
                          label: slide.badge,
                          tone: slide.badgeTone,
                          icon: slide.badgeIcon,
                          size: AppBadgeSize.small,
                        ),

                        const SizedBox(height: AppSpacing.sm),

                        // Title
                        Text(
                          slide.title,
                          textAlign: TextAlign.center,
                          style:
                              (isCompact
                                      ? theme.textTheme.titleMedium
                                      : theme.textTheme.headlineSmall)
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.3,
                                    color: theme.colorScheme.onSurface,
                                  ),
                        ),

                        const SizedBox(height: AppSpacing.xs),

                        // Description
                        Text(
                          slide.description,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: palette.textMuted,
                            height: 1.4,
                          ),
                        ),

                        const SizedBox(height: AppSpacing.md),

                        // Feature Highlight Micro-Pills
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: AppSpacing.xs + 2,
                          runSpacing: AppSpacing.xs + 2,
                          children: slide.highlights
                              .map(
                                (h) => _HighlightPill(
                                  highlight: h,
                                  palette: palette,
                                  theme: theme,
                                ),
                              )
                              .toList(),
                        ),

                        const SizedBox(height: AppSpacing.md),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),

        // Bottom Controls: Page Indicator + Action Button + Session Status
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.xs,
            AppSpacing.page,
            AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated Page Indicator Dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.slides.length, (index) {
                  final isActive = index == _currentPage;
                  return AnimatedContainer(
                    duration: AppDurations.normal,
                    curve: AppMotion.standard,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: isActive ? 22 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isActive
                          ? theme.colorScheme.primary
                          : palette.borderStrong,
                      borderRadius: AppRadii.pillAll,
                    ),
                  );
                }),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Primary Action Button
              Obx(() {
                final isLoading = widget.controller.isLoading.value;
                final isProbing = _hasStarted && isLoading;

                return AppButton(
                  label: isLastPage ? 'Mulai Sekarang' : 'Lanjutkan',
                  icon: isLastPage
                      ? Icons.arrow_forward_rounded
                      : Icons.arrow_forward_rounded,
                  busy: isProbing,
                  onPressed: _handlePrimaryAction,
                );
              }),

              const SizedBox(height: AppSpacing.sm),

              // Session Status Live Indicator
              SizedBox(
                height: 20,
                child: Obx(() {
                  if (widget.controller.isLoading.value) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: AppIconSizes.xs,
                          height: AppIconSizes.xs,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: palette.brandAccent,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          'Memeriksa sesi Anda…',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: palette.textMuted,
                          ),
                        ),
                      ],
                    );
                  }
                  return const SizedBox.shrink();
                }),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HighlightPill extends StatelessWidget {
  const _HighlightPill({
    required this.highlight,
    required this.palette,
    required this.theme,
  });

  final _SlideHighlight highlight;
  final AppPalette palette;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 2,
        vertical: AppSpacing.xs + 1,
      ),
      decoration: BoxDecoration(
        color: palette.surfaceSubtle,
        borderRadius: AppRadii.pillAll,
        border: Border.all(color: palette.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            highlight.icon,
            size: AppIconSizes.sm,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: AppSpacing.xs + 1),
          Text(
            highlight.label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

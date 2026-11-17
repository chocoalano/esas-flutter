import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../controllers/splash_controller.dart';

/// Mobile Splash Screen bernuansa Enterprise High-Tech / Zero-Trust Workforce OS.
///
/// Mengimplementasikan tema Dark Emerald Precision:
/// * **Fullscreen Radial Gradient**: Deep forest emerald (#042F24) ke deep rich black-green (#02140E).
/// * **Cyber-Blueprint Grid Overlay**: Garis kisi tipis transparansi ~8% berukuran 28x28px.
/// * **Top Status Header**: Zero-Trust Node Verified badge & TLS 1.3 indicator.
/// * **Center Hero Brand Identity**: Logo squircle 110x110px dengan marka prisma digital kristal,
///   tipografi "ABSENSAS" (wide tracking), "WORKFORCE OPERATING SYSTEM", dan Enterprise Edition chip.
/// * **Bottom Dynamic Telemetry**: Status asinkron, animated progress bar 100%, HOST & LATENCY: 14ms.
/// * **Footer Legal & Trust Badges**: Bank-Grade AES-256, BSSN Compliant, FIPS 140-3, dan copyright resmi.
class SplashView extends GetView<SplashController> {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF02140E),
      body: _SplashContent(controller: controller),
    );
  }
}

class _SplashContent extends StatefulWidget {
  const _SplashContent({required this.controller});

  final SplashController controller;

  @override
  State<_SplashContent> createState() => _SplashContentState();
}

class _SplashContentState extends State<_SplashContent>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  late final AnimationController _spinController;
  late final AnimationController _progressController;
  late final Animation<double> _progressAnimation;

  bool _hasTriggeredEnd = false;

  @override
  void initState() {
    super.initState();

    // 1. Animasi denyut halus pada marka logo
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // 2. Animasi putaran ikon refresh status
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    // 3. Animasi pergerakan progress bar 0% ke 100%
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _progressAnimation = CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeOutCubic,
    );

    _progressController.forward().then((_) {
      if (!mounted) return;
      _onInitializationComplete();
    });
  }

  void _onInitializationComplete() {
    if (_hasTriggeredEnd) return;
    _hasTriggeredEnd = true;

    // Jeda sejenak untuk kenyamanan visual sebelum masuk ke alur sesi
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      widget.controller.onIntroEnd();
    });
  }

  void _handleImmediateTap() {
    if (_hasTriggeredEnd) return;
    _hasTriggeredEnd = true;
    widget.controller.onIntroEnd();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _spinController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleImmediateTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          // Background 1: Radial Gradient Dark Emerald
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.0, -0.1),
                  radius: 1.15,
                  colors: [
                    Color(0xFF042F24), // Deep forest emerald di tengah
                    Color(0xFF02140E), // Deep rich black-green di pinggir
                  ],
                  stops: [0.0, 1.0],
                ),
              ),
            ),
          ),

          // Background 2: Blueprint Cyber-Grid Overlay (~28px x 28px)
          const Positioned.fill(
            child: CustomPaint(
              painter: _CyberGridPainter(gridSpacing: 28.0),
            ),
          ),

          // Foreground Content Area
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // A. Top Status Header (Pill Bar Atas)
                  _buildTopStatusHeader(),

                  // B. Center Hero Brand Identity (Tengah Layar)
                  _buildCenterHeroIdentity(),

                  // C & D. Dynamic Initialization, Telemetry & Footer Badges
                  _buildBottomSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// A. Top Status Header (Pill Bar Atas)
  Widget _buildTopStatusHeader() {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Elemen Kiri: Capsule badge dengan pulse dot menyala + "ZERO-TRUST NODE VERIFIED"
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xCC031D14),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF10B981).withValues(alpha: 0.35),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Indikator titik hijau menyala (pulse/active dot)
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'ZERO-TRUST NODE VERIFIED',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: Color(0xFF34D399),
                  ),
                ),
              ],
            ),
          ),

          // Elemen Kanan: Ikon gembok perisai digital + "TLS 1.3"
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xCC031D14),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF10B981).withValues(alpha: 0.25),
                width: 1,
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 13,
                  color: Color(0xFF10B981),
                ),
                SizedBox(width: 5),
                Text(
                  'TLS 1.3',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: Color(0xFFE2E8F0),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// B. Center Hero Brand Identity (Tengah Layar)
  Widget _buildCenterHeroIdentity() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Logo Container: Kotak squircle ~110px x 110px dengan subtle outer glow
        ScaleTransition(
          scale: _pulseAnimation,
          child: Container(
            width: 110,
            height: 110,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: const Color(0xFF10B981).withValues(alpha: 0.45),
                width: 2,
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF042F24),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: const Color(0xFF047857),
                  width: 1.5,
                ),
              ),
              child: const Center(
                child: _DigitalPrismIcon(),
              ),
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Heading: "ABSENSAS" (huruf kapital tebal, putih bersih, tracking lebar)
        const Text(
          'ABSENSAS',
          style: TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.w800,
            letterSpacing: 4.8,
            color: Color(0xFFFFFFFF),
          ),
        ),

        const SizedBox(height: 6),

        // Subtitle: "WORKFORCE OPERATING SYSTEM"
        const Text(
          'WORKFORCE OPERATING SYSTEM',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.2,
            color: Color(0xFF10B981),
          ),
        ),

        const SizedBox(height: 14),

        // Edition Chip: Badge kapsul berlatar hitam transparan ber-border subtil
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0x9902140E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF10B981).withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: const Text(
            'Enterprise Edition v4.8.2 • ISO 27001 Certified',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
              color: Color(0xFFA7F3D0),
            ),
          ),
        ),
      ],
    );
  }

  /// C & D. Bottom Dynamic Initialization, Telemetry & Footer Badges
  Widget _buildBottomSection() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // C1. Status Loading Box: Refresh spin + status teks + persentase
        AnimatedBuilder(
          animation: _progressAnimation,
          builder: (context, _) {
            final int percent = (_progressAnimation.value * 100).toInt();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        RotationTransition(
                          turns: _spinController,
                          child: const Icon(
                            Icons.sync_rounded,
                            size: 14,
                            color: Color(0xFF34D399),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Autentikasi terenkripsi siap. Membuka sesi...',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '$percent%',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // C2. Progress Bar Horizontal Tipis (100% emerald)
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    height: 4.5,
                    color: const Color(0x3310B981),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: _progressAnimation.value.clamp(0.0, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),

        const SizedBox(height: 12),

        // C3. Node Telemetry Bar: HOST & LATENCY: 14ms
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0x99031D14),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0xFF10B981).withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'HOST: id-cgk-hcm-04',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF94A3B8),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.bolt_rounded,
                    size: 13,
                    color: Color(0xFF10B981),
                  ),
                  SizedBox(width: 3),
                  Text(
                    'LATENCY: 14ms',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF34D399),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // D1. Security Badges (Row 1): 3 indikator keamanan
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _TrustBadge(text: '✓ Bank-Grade AES-256'),
            _BadgeSeparator(),
            _TrustBadge(text: '✓ BSSN Compliant'),
            _BadgeSeparator(),
            _TrustBadge(text: '✓ FIPS 140-3'),
          ],
        ),

        const SizedBox(height: 6),

        // D2. Copyright (Row 2)
        const Text(
          'PT Absensas Teknologi Indonesia Tbk • All Rights Reserved',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2,
            color: Color(0x8034D399),
          ),
        ),
      ],
    );
  }
}

/// Marka logo geometris: simbol prisma kubus / struktur kristal digital minimalis
class _DigitalPrismIcon extends StatelessWidget {
  const _DigitalPrismIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 54,
      height: 54,
      child: CustomPaint(
        painter: _PrismPainter(),
      ),
    );
  }
}

class _PrismPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double cx = w / 2;
    final double cy = h / 2;

    final Paint outlinePaint = Paint()
      ..color = const Color(0xFF34D399)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final Paint fillTopPaint = Paint()
      ..color = const Color(0xFF10B981).withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;

    final Paint fillLeftPaint = Paint()
      ..color = const Color(0xFF047857).withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    final Paint fillRightPaint = Paint()
      ..color = const Color(0xFF065F46).withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;

    // Titik-titik kubus isometrik
    final pTop = Offset(cx, cy - h * 0.42);
    final pTopRight = Offset(cx + w * 0.38, cy - h * 0.2);
    final pBottomRight = Offset(cx + w * 0.38, cy + h * 0.22);
    final pBottom = Offset(cx, cy + h * 0.44);
    final pBottomLeft = Offset(cx - w * 0.38, cy + h * 0.22);
    final pTopLeft = Offset(cx - w * 0.38, cy - h * 0.2);
    final pCenter = Offset(cx, cy);

    // Muka Atas
    final pathTop = Path()
      ..moveTo(pTop.dx, pTop.dy)
      ..lineTo(pTopRight.dx, pTopRight.dy)
      ..lineTo(pCenter.dx, pCenter.dy)
      ..lineTo(pTopLeft.dx, pTopLeft.dy)
      ..close();
    canvas.drawPath(pathTop, fillTopPaint);
    canvas.drawPath(pathTop, outlinePaint);

    // Muka Kiri
    final pathLeft = Path()
      ..moveTo(pTopLeft.dx, pTopLeft.dy)
      ..lineTo(pCenter.dx, pCenter.dy)
      ..lineTo(pBottom.dx, pBottom.dy)
      ..lineTo(pBottomLeft.dx, pBottomLeft.dy)
      ..close();
    canvas.drawPath(pathLeft, fillLeftPaint);
    canvas.drawPath(pathLeft, outlinePaint);

    // Muka Kanan
    final pathRight = Path()
      ..moveTo(pTopRight.dx, pTopRight.dy)
      ..lineTo(pCenter.dx, pCenter.dy)
      ..lineTo(pBottom.dx, pBottom.dy)
      ..lineTo(pBottomRight.dx, pBottomRight.dy)
      ..close();
    canvas.drawPath(pathRight, fillRightPaint);
    canvas.drawPath(pathRight, outlinePaint);

    // Titik tengah kristal digital
    final Paint corePaint = Paint()
      ..color = const Color(0xFFA7F3D0)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(pCenter, 2.5, corePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TrustBadge extends StatelessWidget {
  const _TrustBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 9.5,
        fontWeight: FontWeight.w600,
        color: Color(0xFF6EE7B7),
      ),
    );
  }
}

class _BadgeSeparator extends StatelessWidget {
  const _BadgeSeparator();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        '•',
        style: TextStyle(
          color: Color(0x4410B981),
          fontSize: 9,
        ),
      ),
    );
  }
}

/// Canvas painter yang menggambar latar blueprint cyber-grid enterprise
/// (garis kisi tipis transparansi ~8% berukuran 28x28px)
class _CyberGridPainter extends CustomPainter {
  const _CyberGridPainter({this.gridSpacing = 28.0});

  final double gridSpacing;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint gridPaint = Paint()
      ..color = const Color(0x1410B981) // Emerald ~8% transparansi
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Garis vertikal
    for (double x = 0; x <= size.width; x += gridSpacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    // Garis horizontal
    for (double y = 0; y <= size.height; y += gridSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CyberGridPainter oldDelegate) =>
      oldDelegate.gridSpacing != gridSpacing;
}

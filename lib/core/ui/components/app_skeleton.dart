import 'package:flutter/material.dart';

import '../../theme/app_dimens.dart';
import '../../theme/app_palette.dart';

/// Denyut bersama untuk seluruh kerangka di bawahnya.
///
/// Sebelumnya setiap blok kerangka membangun [AnimationController]-nya sendiri,
/// sehingga satu `AppSkeletonList(count: 5)` menyalakan sekitar dua puluh
/// controller yang berdetak berbarengan tanpa pernah sinkron. Satu controller
/// per daftar memberi hasil visual yang justru lebih benar — seluruh blok
/// bernapas serempak — sekaligus menghapus sembilan belas ticker dari perangkat
/// Android kelas bawah yang sedang menunggu jaringan.
///
/// Widget ini boleh dipakai langsung untuk membungkus susunan kerangka buatan
/// sendiri. Ketiga baris siap pakai di bawah memasangnya otomatis lewat
/// [ensure] kalau belum ada denyut di atasnya, jadi sebuah [AppSkeletonRow]
/// lepas tetap berdenyut.
class AppSkeletonPulse extends StatefulWidget {
  const AppSkeletonPulse({super.key, required this.child});

  final Widget child;

  /// Membungkus [child] hanya bila belum ada denyut di atas [context].
  static Widget ensure(BuildContext context, Widget child) {
    return _SkeletonPulseScope.maybeOf(context) == null
        ? AppSkeletonPulse(child: child)
        : child;
  }

  @override
  State<AppSkeletonPulse> createState() => _AppSkeletonPulseState();
}

class _AppSkeletonPulseState extends State<AppSkeletonPulse>
    with SingleTickerProviderStateMixin {
  // `repeat(reverse: true)` dipertahankan apa adanya. Ini denyut, bukan kilau
  // yang menyapu: kilau menarik mata ke tempat yang justru belum berisi apa-apa.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppDurations.shimmer,
  )..repeat(reverse: true);

  // Lantai denyut 0.62, bukan 0.45. Isian kerangka sendiri hanya beberapa
  // langkah di atas kartu; menurunkannya sampai 0.45 membuat separuh siklus
  // hampir lenyap, dan daftar yang sedang memuat terbaca sebagai daftar kosong.
  late final Animation<double> _pulse = Tween<double>(
    begin: 0.62,
    end: 1.0,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SkeletonPulseScope(animation: _pulse, child: widget.child);
  }
}

class _SkeletonPulseScope extends InheritedWidget {
  const _SkeletonPulseScope({required this.animation, required super.child});

  final Animation<double> animation;

  static Animation<double>? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_SkeletonPulseScope>()
        ?.animation;
  }

  @override
  bool updateShouldNotify(_SkeletonPulseScope oldWidget) {
    return animation != oldWidget.animation;
  }
}

/// Placeholder berdenyut untuk data yang sedang dimuat.
///
/// Menggantikan `CircularProgressIndicator` di tengah layar. Spinner tidak
/// memberi tahu apa pun tentang apa yang sedang datang; kerangka konten
/// menahan tata letak tetap di tempatnya, jadi layar tidak melompat ketika data
/// akhirnya tiba.
class AppSkeleton extends StatelessWidget {
  const AppSkeleton({
    super.key,
    this.width,
    this.height = 12,
    this.borderRadius = AppRadii.smAll,
  });

  final double? width;
  final double height;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final Widget block = _SkeletonBlock(
      width: width,
      height: height,
      borderRadius: borderRadius,
    );

    return AppSkeletonPulse.ensure(context, block);
  }
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({
    required this.width,
    required this.height,
    required this.borderRadius,
  });

  final double? width;
  final double height;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).palette;
    final Animation<double>? pulse = _SkeletonPulseScope.maybeOf(context);

    final Widget box = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        // Isian khusus kerangka, bukan `surfaceRaised`. Permukaan itu hanya
        // sekitar 1.10:1 di atas kartu gelap — cukup untuk menyatakan "kartu di
        // dalam kartu", tidak cukup untuk menyatakan "ada sesuatu di sini".
        color: palette.skeletonFill,
        borderRadius: borderRadius,
      ),
    );

    if (pulse == null) return box;
    return FadeTransition(opacity: pulse, child: box);
  }
}

/// Bentuk baris kerangka. Bentuk yang dipilih harus menyerupai tinggi baris
/// yang akan menggantikannya; kalau tidak, daftar melompat justru pada saat
/// datanya mendarat, dan lompatan itu terjadi persis ketika mata sedang
/// membaca.
enum AppSkeletonShape {
  /// Baris ringkas: kotak ikon, dua baris teks, satu nilai (~68px).
  row,

  /// Baris pengajuan izin (~150px).
  permit,

  /// Baris ledger absensi (~140px).
  attendance,
}

/// Kerangka satu baris daftar: kotak ikon, dua baris teks, satu nilai.
class AppSkeletonRow extends StatelessWidget {
  const AppSkeletonRow({super.key, this.showLeading = true});

  final bool showLeading;

  @override
  Widget build(BuildContext context) {
    return AppSkeletonPulse.ensure(
      context,
      _SkeletonSurface(
        child: Row(
          children: [
            if (showLeading) ...[
              const AppSkeleton(
                width: 36,
                height: 36,
                borderRadius: AppRadii.lgAll,
              ),
              const SizedBox(width: AppSpacing.md),
            ],
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppSkeleton(width: 140, height: 11),
                  SizedBox(height: AppSpacing.sm),
                  AppSkeleton(width: 90, height: 9),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            const AppSkeleton(
              width: 48,
              height: 20,
              borderRadius: AppRadii.smAll,
            ),
          ],
        ),
      ),
    );
  }
}

/// Kerangka satu baris pengajuan izin: judul dan lencana status, dua baris
/// meta, bar persetujuan, lalu baris kaki.
class PermitSkeletonRow extends StatelessWidget {
  const PermitSkeletonRow({super.key});

  @override
  Widget build(BuildContext context) {
    return AppSkeletonPulse.ensure(
      context,
      const _SkeletonSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppSkeleton(width: 140, height: 13),
                Spacer(),
                AppSkeleton(width: 64, height: 20),
              ],
            ),
            SizedBox(height: AppSpacing.lg),
            AppSkeleton(width: 180, height: 13),
            SizedBox(height: AppSpacing.snug),
            AppSkeleton(width: 120, height: 11),
            SizedBox(height: AppSpacing.lg),
            AppSkeleton(height: 8),
            SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                AppSkeleton(width: 90, height: 11),
                Spacer(),
                AppSkeleton(width: 48, height: 11),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Kerangka satu baris ledger absensi: tanggal dan lencana, pasangan jam masuk
/// dan jam pulang, lalu baris meta.
class AttendanceSkeletonRow extends StatelessWidget {
  const AttendanceSkeletonRow({super.key});

  @override
  Widget build(BuildContext context) {
    return AppSkeletonPulse.ensure(
      context,
      const _SkeletonSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppSkeleton(width: 110, height: 12),
                Spacer(),
                AppSkeleton(width: 56, height: 18),
              ],
            ),
            SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                AppSkeleton(width: 72, height: 22),
                SizedBox(width: AppSpacing.md),
                AppSkeleton(width: 16, height: 8),
                SizedBox(width: AppSpacing.md),
                AppSkeleton(width: 72, height: 22),
              ],
            ),
            SizedBox(height: AppSpacing.lg),
            AppSkeleton(width: 150, height: 11),
            SizedBox(height: AppSpacing.md),
            Row(
              children: [
                AppSkeleton(
                  width: 6,
                  height: 6,
                  borderRadius: AppRadii.pillAll,
                ),
                SizedBox(width: AppSpacing.sm),
                AppSkeleton(width: 96, height: 11),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Kartu tempat sebuah baris kerangka duduk: sama persis dengan permukaan baris
/// aslinya, supaya yang berubah saat data mendarat hanya isinya.
class _SkeletonSurface extends StatelessWidget {
  const _SkeletonSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadii.xlAll,
        border: Border.all(color: theme.palette.borderSubtle),
      ),
      child: child,
    );
  }
}

/// Beberapa baris kerangka bertumpuk, untuk memuat sebuah daftar.
///
/// Seluruh daftar berbagi satu denyut, dan bentuk barisnya dipilih lewat
/// [shape] supaya tinggi kerangka mendekati tinggi baris yang akan menggantikan
/// tempatnya.
class AppSkeletonList extends StatelessWidget {
  const AppSkeletonList({
    super.key,
    this.count = 4,
    this.padding = const EdgeInsets.symmetric(horizontal: AppSpacing.page),
    this.shape = AppSkeletonShape.row,
  });

  final int count;
  final EdgeInsetsGeometry padding;
  final AppSkeletonShape shape;

  @override
  Widget build(BuildContext context) {
    return AppSkeletonPulse(
      child: ListView.separated(
        padding: padding,
        itemCount: count,
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (_, _) => switch (shape) {
          AppSkeletonShape.row => const AppSkeletonRow(),
          AppSkeletonShape.permit => const PermitSkeletonRow(),
          AppSkeletonShape.attendance => const AttendanceSkeletonRow(),
        },
      ),
    );
  }
}

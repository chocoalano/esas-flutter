import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:introduction_screen/introduction_screen.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/ui/components/app_button.dart';
import '../controllers/splash_controller.dart';

/// Frame pertama yang dilihat setiap karyawan.
///
/// Onboarding empat halaman ini dipertahankan sebagai keputusan produk, tetapi
/// dua hal yang membuatnya terasa seperti kecelakaan sudah tidak ada:
///
/// * **Tombolnya tidak lagi berlomba dengan pemeriksaan sesi.** Menekan "Mulai
///   Sekarang!" dulu mengirim siapa pun ke layar masuk, termasuk orang yang
///   sesinya masih sah dan sedang diperiksa saat itu juga — jadi ketukan yang
///   sedikit terlalu cepat berarti mengetik ulang NIP di gerbang pabrik.
///   Sekarang ketukan itu menyerahkan tujuannya kepada pemeriksaan yang sedang
///   berjalan, dan layar mengatakan bahwa pemeriksaan itu ada.
/// * **Warnanya berasal dari tema.** Judul memakai warna teks utama, bukan
///   hijau brand — hijau brand di atas putih adalah kombinasi paling tidak
///   terbaca yang dipunyai palet ini, dan ia dipakai untuk seluruh judul
///   onboarding.
class SplashView extends GetView<SplashController> {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;

    // Bilah status mengikuti tema, bukan dipaksa terang. Memaksanya ke
    // `SystemUiOverlayStyle.light` membuat ikon sistem berwarna terang di atas
    // latar onboarding yang putih pada mode terang.
    final bool isDark = theme.brightness == Brightness.dark;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: theme.scaffoldBackgroundColor,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
    );

    // SVG or PNG image builder
    Widget buildImage(String assetPath, [double width = 300]) {
      if (assetPath.endsWith('.svg')) {
        return SvgPicture.asset(assetPath, width: width, fit: BoxFit.contain);
      } else {
        return Image.asset(assetPath, width: width, fit: BoxFit.contain);
      }
    }

    final titleStyle = theme.textTheme.headlineSmall;

    // `withAlpha(20)` — 8% opasitas — membuat seluruh teks penjelas onboarding
    // praktis tak terbaca. Yang dimaksud jelas warna teks sekunder, jadi itulah
    // yang dipakai sekarang.
    final bodyStyle = theme.textTheme.bodyMedium?.copyWith(
      color: palette.textMuted,
    );

    final pageDecoration = PageDecoration(
      titleTextStyle: titleStyle ?? const TextStyle(),
      bodyTextStyle: bodyStyle ?? const TextStyle(),
      bodyPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      pageColor: theme.scaffoldBackgroundColor,
      imagePadding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
      contentMargin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      titlePadding: const EdgeInsets.only(
        bottom: AppSpacing.sm,
        top: AppSpacing.lg,
      ),
    );

    return IntroductionScreen(
      key: controller.introKey,
      globalBackgroundColor: theme.scaffoldBackgroundColor,
      allowImplicitScrolling: true,
      autoScrollDuration: 3000,
      infiniteAutoScroll: true,
      globalFooter: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xxl,
          AppSpacing.lg,
          AppSpacing.xxl,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppButton(
              label: 'Mulai Sekarang!',
              onPressed: controller.onIntroEnd,
            ),
            const SizedBox(height: AppSpacing.sm),
            // Barisnya selalu memesan tingginya, jadi tombol di atasnya tidak
            // melompat saat kalimatnya muncul dan hilang.
            SizedBox(
              height: 20,
              child: Obx(() {
                if (!controller.isLoading.value) {
                  return const SizedBox.shrink();
                }

                return Text(
                  'Memeriksa sesi Anda…',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: palette.textMuted,
                  ),
                );
              }),
            ),
          ],
        ),
      ),

      pages: [
        PageViewModel(
          title: "Kelola Perizinan dan Absensi Anda dengan Mudah",
          body:
              "Pantau progres, alokasikan sumber daya, dan capai target pekerjaan Anda dengan efisien.",
          image: buildImage('assets/svg/onboarding_1.svg'),
          decoration: pageDecoration,
        ),
        PageViewModel(
          title: "Integrasi Tim yang Mulus",
          body:
              "Kolaborasi dengan rekan kerja Anda secara real-time, tingkatkan komunikasi, dan selesaikan tugas bersama.",
          image: buildImage('assets/svg/onboarding_2.svg'),
          decoration: pageDecoration,
        ),
        PageViewModel(
          title: "Akses Kapan Saja, Di Mana Saja",
          body:
              "Aplikasi kami dirancang untuk membantu Anda bekerja secara fleksibel, dari perangkat apa pun.",
          image: buildImage('assets/svg/onboarding_3.svg'),
          decoration: pageDecoration,
        ),
        PageViewModel(
          title: "Siap untuk Memulai?",
          bodyWidget: Column(
            children: [
              Text(
                "Rasakan kemudahan mengelola bisnis Anda dalam satu genggaman.",
                style: bodyStyle,
                textAlign: TextAlign.center,
              ),
            ],
          ),
          image: buildImage('assets/svg/onboarding_1.svg', 250),
          decoration: pageDecoration.copyWith(
            bodyFlex: 2,
            imageFlex: 3,
            bodyAlignment: Alignment.center,
            imageAlignment: Alignment.center,
            contentMargin: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xxl,
            ),
          ),
        ),
      ],

      onDone: controller.onIntroEnd,
      onSkip: controller.onIntroEnd,
      showSkipButton: true,
      showBackButton: false,
      back: Icon(
        Icons.arrow_back_ios_new_rounded,
        size: AppIconSizes.lg,
        color: theme.colorScheme.onSurface,
      ),
      skip: Text(
        'Lewati',
        style: theme.textTheme.labelLarge?.copyWith(color: palette.textMuted),
      ),
      next: Icon(
        Icons.arrow_forward_ios_rounded,
        size: AppIconSizes.lg,
        color: theme.colorScheme.onSurface,
      ),
      done: Text(
        'Selesai',
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
      curve: AppMotion.standard,
      controlsMargin: const EdgeInsets.all(AppSpacing.lg),
      controlsPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),

      dotsDecorator: DotsDecorator(
        size: const Size(AppSpacing.tight, AppSpacing.tight),
        color: palette.borderStrong,
        activeSize: const Size(AppSpacing.lg + 2, AppSpacing.tight),
        activeColor: theme.colorScheme.primary,
        activeShape: const RoundedRectangleBorder(
          borderRadius: AppRadii.pillAll,
        ),
      ),
      dotsContainerDecorator: const ShapeDecoration(
        shape: RoundedRectangleBorder(),
      ),
    );
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:introduction_screen/introduction_screen.dart';

import '../controllers/splash_controller.dart';

class SplashView extends GetView<SplashController> {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    // Set status bar transparent
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
    );

    // SVG or PNG image builder
    Widget buildImage(String assetPath, [double width = 300]) {
      if (assetPath.endsWith('.svg')) {
        return SvgPicture.asset(assetPath, width: width, fit: BoxFit.contain);
      } else {
        return Image.asset(assetPath, width: width, fit: BoxFit.contain);
      }
    }

    final titleStyle = Get.textTheme.headlineSmall!.copyWith(
      fontWeight: FontWeight.bold,
      color: Get.theme.colorScheme.primary,
    );

    final bodyStyle = Get.textTheme.bodyLarge!.copyWith(
      color: Get.theme.colorScheme.onSurface.withAlpha(20),
    );

    final pageDecoration = PageDecoration(
      titleTextStyle: titleStyle,
      bodyTextStyle: bodyStyle,
      bodyPadding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 16.0),
      pageColor: Get.theme.scaffoldBackgroundColor,
      imagePadding: const EdgeInsets.symmetric(vertical: 24.0),
      contentMargin: const EdgeInsets.symmetric(horizontal: 16),
      titlePadding: const EdgeInsets.only(bottom: 8.0, top: 16.0),
    );

    return IntroductionScreen(
      key: controller.introKey,
      globalBackgroundColor: Get.theme.scaffoldBackgroundColor,
      allowImplicitScrolling: true,
      autoScrollDuration: 3000,
      infiniteAutoScroll: true,
      globalFooter: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Get.theme.colorScheme.primary,
              foregroundColor: Get.theme.colorScheme.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              elevation: 5,
            ),
            onPressed: controller.onIntroEnd,
            child: Text(
              'Mulai Sekarang!',
              style: Get.textTheme.titleMedium!.copyWith(
                color: Get.theme.colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
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
            contentMargin: const EdgeInsets.symmetric(horizontal: 24),
          ),
        ),
      ],

      onDone: controller.onIntroEnd,
      onSkip: controller.onIntroEnd,
      showSkipButton: true,
      showBackButton: false,
      back: Icon(Icons.arrow_back_ios, color: Get.theme.colorScheme.onSurface),
      skip: Text(
        'Lewati',
        style: Get.textTheme.labelLarge!.copyWith(
          color: Get.theme.colorScheme.onSurface,
        ),
      ),
      next: Icon(
        Icons.arrow_forward_ios,
        color: Get.theme.colorScheme.onSurface,
      ),
      done: Text(
        'Selesai',
        style: Get.textTheme.labelLarge!.copyWith(
          color: Get.theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
      curve: Curves.easeOutCubic,
      controlsMargin: const EdgeInsets.all(16),
      controlsPadding: kIsWeb
          ? const EdgeInsets.all(12.0)
          : const EdgeInsets.fromLTRB(8.0, 4.0, 8.0, 4.0),

      dotsDecorator: DotsDecorator(
        size: const Size(10.0, 10.0),
        color: Get.theme.colorScheme.onSurface.withAlpha(20),
        activeSize: const Size(22.0, 10.0),
        activeColor: Get.theme.colorScheme.primary,
        activeShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25.0),
        ),
      ),
      dotsContainerDecorator: ShapeDecoration(
        color: Get.theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      ),
    );
  }
}

import 'package:esas/core/theme/app_dimens.dart';
import 'package:esas/core/theme/app_palette.dart';
import 'package:esas/core/ui/components/app_skeleton.dart';
import 'package:esas/core/ui/layout/app_breakpoints.dart';
import 'package:flutter/material.dart';

/// Rangka panel protagonis, dibentuk menyerupai panel yang akan menggantikannya.
///
/// Kemiripan itu bukan kerapian melainkan syarat: sebuah rangka yang tingginya
/// meleset jauh dari isi aslinya membuat halaman melompat persis pada saat
/// datanya mendarat — dan lompatan itu terjadi tepat ketika mata sedang membaca
/// baris pertama.
class HomeHeroSkeleton extends StatelessWidget {
  const HomeHeroSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadii.xxlAll,
        border: Border.all(color: palette.borderSubtle),
      ),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              AppSkeleton(width: 64, height: 11),
              Spacer(),
              AppSkeleton(
                width: 96,
                height: 22,
                borderRadius: AppRadii.pillAll,
              ),
            ],
          ),
          SizedBox(height: AppSpacing.lg),
          AppSkeleton(width: 120, height: 16),
          SizedBox(height: AppSpacing.lg),
          AppSkeleton(width: 168, height: 40),
          SizedBox(height: AppSpacing.md),
          AppSkeleton(width: 128, height: 11),
          SizedBox(height: AppSpacing.xl),
          AppSkeleton(
            width: double.infinity,
            height: 6,
            borderRadius: AppRadii.pillAll,
          ),
          SizedBox(height: AppSpacing.xl),
          Row(
            children: <Widget>[
              Expanded(child: AppSkeleton(width: double.infinity, height: 36)),
              SizedBox(width: AppSpacing.md),
              Expanded(child: AppSkeleton(width: double.infinity, height: 36)),
            ],
          ),
          SizedBox(height: AppSpacing.xl),
          AppSkeleton(
            width: double.infinity,
            height: 52,
            borderRadius: AppRadii.lgAll,
          ),
        ],
      ),
    );
  }
}

/// Rangka petak akses cepat: satu kotak ikon dan satu label per kolom.
class HomeQuickActionsSkeleton extends StatelessWidget {
  const HomeQuickActionsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final int columns = AppLayout.of(context).quickActionColumns.clamp(1, 6);

    return Row(
      children: <Widget>[
        for (int i = 0; i < columns; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: AppSpacing.sm),
          const Expanded(
            child: Column(
              children: <Widget>[
                AppSkeleton(
                  width: 52,
                  height: 52,
                  borderRadius: AppRadii.xlAll,
                ),
                SizedBox(height: AppSpacing.sm),
                AppSkeleton(width: 44, height: 10),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

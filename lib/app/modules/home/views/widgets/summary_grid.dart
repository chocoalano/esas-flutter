import 'package:esas/app/modules/home/controllers/home_controller.dart';
import 'package:esas/app/modules/home/views/widgets/summary_card.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SummaryGrid extends StatelessWidget {
  final HomeController controller;
  const SummaryGrid({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final summary = controller.summaryCards; // Reactive RxList
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: summary.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.8,
        ),
        itemBuilder: (context, index) {
          final item = summary[index];
          return SummaryCard(
            title: item.title,
            time: item.time,
            status: item.status,
            icon: item.icon,
          );
        },
      );
    });
  }
}

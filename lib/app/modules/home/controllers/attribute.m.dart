import 'package:flutter/material.dart';

/// Model for summary cards
class SummaryCard {
  final String title;
  final String time;
  final String status;
  final IconData icon;

  SummaryCard({
    required this.title,
    required this.time,
    required this.status,
    required this.icon,
  });

  SummaryCard copyWith({
    String? title,
    String? time,
    String? status,
    IconData? icon,
  }) {
    return SummaryCard(
      title: title ?? this.title,
      time: time ?? this.time,
      status: status ?? this.status,
      icon: icon ?? this.icon,
    );
  }
}

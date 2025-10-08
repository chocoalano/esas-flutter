import 'package:intl/intl.dart'; // Import ini untuk DateFormat
import 'package:flutter/foundation.dart'; // Untuk kDebugMode, jika diperlukan di model

class Schedule {
  final int id;
  final int userId;
  final int timeWorkId;
  final DateTime workDay; // Tetap sebagai DateTime

  Schedule({
    required this.id,
    required this.userId,
    required this.timeWorkId,
    required this.workDay,
  });

  /// Factory constructor to create a Schedule from a JSON map.
  factory Schedule.fromJson(Map<String, dynamic> json) {
    // Helper function to safely parse various date formats
    // This logic is adapted from the previous robust parsing attempts.
    DateTime parseRobustDateTime(String? dateString, String fieldName) {
      if (dateString == null || dateString.isEmpty) {
        if (kDebugMode) {
          print('Warning: $fieldName date string is null or empty.');
        }
        // Return a default/invalid DateTime or throw an error based on your app's needs
        return DateTime(0); // Example: Return epoch if null/empty
      }

      // Try ISO 8601 first (default for DateTime.parse)
      try {
        return DateTime.parse(dateString);
      } on FormatException catch (_) {
        // If default parse fails, try custom formatters
        final List<DateFormat> formatters = [
          // Format: "28 June 25 13:56:36" (full month name)
          DateFormat("dd MMMM yy HH:mm:ss", 'id'), // 'id' for Indonesian locale
          // Format: "28 Jun 25 13:56:36" (abbreviated month name)
          DateFormat("dd MMM yy HH:mm:ss", 'id'), // 'id' for Indonesian locale
          // Add any other specific formats your API might return, e.g.:
          // DateFormat("yyyy-MM-dd HH:mm:ss"),
          // DateFormat("dd-MM-yyyy"),
        ];

        for (var formatter in formatters) {
          try {
            return formatter.parse(dateString);
          } on FormatException catch (_) {
            // Continue to next formatter if this one fails
          }
        }
      }

      // If all attempts fail, log and throw an error
      if (kDebugMode) {
        print(
          'Error: Could not parse "$dateString" for field "$fieldName" with any known format.',
        );
      }
      throw FormatException(
        'Invalid date format for $fieldName: "$dateString"',
      );
    }

    return Schedule(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      timeWorkId: json['time_work_id'] as int,
      // Gunakan helper function untuk parsing workDay
      workDay: parseRobustDateTime(json['work_day'] as String?, 'work_day'),
    );
  }

  /// Getter untuk mengembalikan workDay dalam format tanggal Indonesia.
  /// Contoh: "Kamis, 10 Juli 2025"
  String get formattedWorkDay {
    // 'EEEE' untuk nama hari penuh (e.g., "Kamis")
    // 'dd' untuk tanggal (e.g., "10")
    // 'MMMM' untuk nama bulan penuh (e.g., "Juli")
    // 'yyyy' untuk tahun penuh (e.g., "2025")
    final DateFormat formatter = DateFormat('EEEE, dd MMMM yyyy', 'id_ID');
    return formatter.format(workDay);
  }

  /// Convert a Schedule object to a JSON map.
  /// Biasanya, saat mengirim tanggal kembali ke API, format ISO 8601 lebih disukai.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'time_work_id': timeWorkId,
      'work_day': workDay
          .toIso8601String(), // Tetap kirim sebagai ISO 8601 ke API
    };
  }

  @override
  String toString() {
    // Menggunakan formattedWorkDay untuk representasi string yang lebih mudah dibaca
    return 'Schedule(id: $id, userId: $userId, timeWorkId: $timeWorkId, workDay: $formattedWorkDay)';
  }
}

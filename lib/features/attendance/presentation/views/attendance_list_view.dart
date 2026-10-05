import 'package:esas/app/modules/attendance/list/views/bottomsheet_detail_view.dart';
import 'package:esas/app/routes/app_pages.dart';
import 'package:esas/utils/helper.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/attendance_list_controller.dart'; // Sesuaikan path jika berbeda

class AttendanceListView extends GetView<AttendanceListController> {
  const AttendanceListView({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    Get.put(AttendanceListController());

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) =>
          Get.offAllNamed(Routes.ATTENDANCE),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Daftar Absensi'),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: () => Get.offAllNamed(Routes.ATTENDANCE),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.date_range),
              tooltip: 'Filter Tanggal',
              onPressed: () async {
                final now = DateTime.now();
                final today = DateTime(
                  now.year,
                  now.month,
                  now.day,
                ); // Hilangkan jam

                final initialStart =
                    controller.startDate.value ??
                    today.subtract(const Duration(days: 30));
                final initialEnd = controller.endDate.value ?? today;

                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2023, 1, 1),
                  lastDate: today,
                  initialDateRange: DateTimeRange(
                    start: DateTime(
                      initialStart.year,
                      initialStart.month,
                      initialStart.day,
                    ),
                    end: DateTime(
                      initialEnd.year,
                      initialEnd.month,
                      initialEnd.day,
                    ),
                  ),
                  builder: (context, child) {
                    final theme = Theme.of(context);
                    final colorScheme = theme.colorScheme;

                    return Theme(
                      data: theme.copyWith(
                        colorScheme: colorScheme.copyWith(
                          primary: colorScheme.primary,
                          onPrimary: colorScheme.onPrimary,
                          surface: colorScheme.surface,
                          onSurface: colorScheme.onSurface,
                        ),
                      ),
                      child: child!,
                    );
                  },
                );

                if (picked != null) {
                  controller.startDate.value = picked.start;
                  controller.endDate.value = picked.end;
                  controller.refreshAttendance();
                }
              },
            ),
          ],
        ),
        body: Obx(() {
          // Tampilkan indikator loading awal jika data sedang dimuat pertama kali
          if (controller.isLoading.value && controller.attendanceList.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          // Tampilkan pesan jika tidak ada data sama sekali setelah loading
          if (!controller.isLoading.value &&
              controller.attendanceList.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Tidak ada data absensi.'),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () => controller.refreshAttendance(),
                    child: const Text('Refresh Data'),
                  ),
                ],
              ),
            );
          }

          // Tampilan utama dengan RefreshIndicator dan ListView.builder
          return RefreshIndicator(
            onRefresh: () => controller.refreshAttendance(),
            child: ListView.builder(
              controller: controller.scrollController, // Ikat scroll controller
              itemCount:
                  controller.attendanceList.length +
                  (controller.isLoadMore.value
                      ? 1
                      : 0), // Tambah 1 untuk loading indikator
              itemBuilder: (context, index) {
                // Jika ini adalah item terakhir dan sedang memuat lebih banyak data
                if (index == controller.attendanceList.length) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10.0),
                    child: Center(
                      child: controller.hasMore.value
                          ? const CircularProgressIndicator()
                          : const Text('Tidak ada lagi data.'),
                    ),
                  );
                }

                // Tampilkan item absensi
                final attendance = controller.attendanceList[index];
                return InkWell(
                  onTap: () => showAttendanceDetailSheet(context, attendance),
                  borderRadius: BorderRadius.circular(10),
                  child: Card(
                    elevation: 0,
                    color: colorScheme.surface,
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                limitString(
                                  attendance.user?.name ?? 'Karyawan',
                                  maxLength: 15,
                                ), // Display name
                                style: theme.textTheme.bodyMedium,
                              ),
                              Text(
                                'NIP: ${attendance.user?.nip ?? 'N/A'}',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Tanggal: ${attendance.datePresence ?? 'N/A'}',
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              // Time In Section
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.arrow_forward_ios,
                                          size: 16,
                                          color: colorScheme.primary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Masuk: ${attendance.timeIn ?? 'N/A'}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Metode: ${attendance.typeIn ?? 'N/A'}',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                    Text(
                                      'Status: ${attendance.statusIn ?? 'N/A'}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: attendance.statusIn == 'LATE'
                                            ? colorScheme.error
                                            : colorScheme.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Time Out Section
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.arrow_back_ios,
                                          size: 16,
                                          color: colorScheme.error,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Keluar: ${attendance.timeOut ?? 'N/A'}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Metode: ${attendance.typeOut ?? 'N/A'}',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                    Text(
                                      'Status: ${attendance.statusOut ?? 'N/A'}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: attendance.statusOut == 'LATE'
                                            ? colorScheme.error
                                            : colorScheme.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        }),
      ),
    );
  }
}

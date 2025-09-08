// ignore_for_file: unnecessary_to_list_in_spreads

import 'package:esas/app/routes/app_pages.dart';
import 'package:esas/utils/api_constants.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart'; // Untuk memformat tanggal
import 'package:url_launcher/url_launcher.dart'; // Untuk membuka URL (misal: file)
import '../controllers/permit_show_controller.dart'; // Sesuaikan jalur import controller
import 'package:esas/app/data/Permit/leave_list.m.dart'; // Import model Permit
import 'package:esas/app/widgets/views/snackbar.dart'; // Pastikan ini diimpor jika digunakan di controller

class PermitShowView extends GetView<PermitShowController> {
  const PermitShowView({super.key});

  @override
  Widget build(BuildContext context) {
    // Memastikan controller diinisialisasi.
    // Jika Anda menggunakan GetX bindings di app_pages.dart, baris ini tidak wajib.
    Get.put(PermitShowController());

    final ThemeData theme = Theme.of(context);
    final DateFormat formatter = DateFormat(
      'dd MMMM yyyy',
    ); // Contoh format tanggal

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          return;
        }
        // print(controller.permitType.value);
        Get.offAllNamed(
          Routes.PERMIT_LIST,
          arguments: controller.permitType.value,
        );
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Detail Pengajuan'),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: () => Get.offAllNamed(
              Routes.PERMIT_LIST,
              arguments: controller.permitType,
            ),
          ),
        ),
        body: Obx(() {
          if (controller.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }

          // Tampilkan pesan error jika permit null setelah loading selesai
          if (controller.permit.value == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.sentiment_dissatisfied_rounded,
                    size: 80,
                    color: theme.colorScheme.onSurface.withAlpha(29),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Gagal memuat detail perizinan.\nMohon coba lagi.',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(29),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: controller.permitId != 0
                        ? controller
                              .loadPermitDetails // Panggil ulang fetch jika ID valid
                        : null, // Nonaktifkan tombol jika ID tidak valid
                    icon: const Icon(Icons.refresh),
                    label: const Text('Coba Lagi'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          final Permit permit =
              controller.permit.value!; // Data perizinan yang berhasil dimuat

          return SingleChildScrollView(
            padding: const EdgeInsets.all(8), // Padding keseluruhan lebih baik
            child: Card(
              color: theme.colorScheme.surface,
              elevation: 0, // Sedikit lebih tinggi
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow(
                      context,
                      'Nomor:',
                      permit.permitNumbers,
                      isTitle: true,
                    ),
                    const Divider(height: 24),
                    _buildDetailRow(
                      context,
                      'Tipe Perizinan:',
                      permit.permitType!.type,
                    ),
                    _buildDetailRow(
                      context,
                      'Periode:',
                      '${formatter.format(permit.startDate!)} - ${formatter.format(permit.endDate!)}',
                    ),
                    _buildDetailRow(
                      context,
                      'Durasi:',
                      '${permit.durationInDays} hari',
                    ),
                    _buildDetailRow(
                      context,
                      'Waktu:',
                      '${permit.startTime} - ${permit.endTime}',
                    ),
                    _buildDetailRow(
                      context,
                      'Yang mengajukan:',
                      permit.user!.name,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Status Persetujuan:',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 5),
                    // Menampilkan daftar persetujuan
                    ...permit.approvals
                        .map(
                          (approval) => Padding(
                            padding: const EdgeInsets.only(
                              left: 8.0,
                              bottom: 4.0,
                            ),
                            child: InkWell(
                              // Make approval status clickable for notes
                              onTap: () {
                                if (approval.userApprove!.toLowerCase() ==
                                        'n' &&
                                    approval.notes != null &&
                                    approval.notes!.isNotEmpty) {
                                  _showApprovalReasonBottomSheet(
                                    context,
                                    approval.userType!,
                                    approval.notes!,
                                  );
                                }
                              },
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    _getApprovalStatusIcon(
                                      approval.userApprove,
                                    ),
                                    size: 18,
                                    color: _getApprovalStatusColor(
                                      approval.userApprove,
                                      theme,
                                    ), // Warna ikon sesuai status
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      // Menampilkan UserType dan Status
                                      '${approval.userType}: ${_getApprovalStatusText(approval.userApprove)}',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: _getApprovalStatusColor(
                                              approval.userApprove,
                                              theme,
                                            ),
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                  ),
                                  if (approval.userApprove!.toLowerCase() ==
                                          'n' &&
                                      approval.notes != null &&
                                      approval.notes!.isNotEmpty)
                                    Icon(
                                      Icons.info_outline,
                                      size: 18,
                                      color: theme.colorScheme.primary,
                                    ), // Add info icon for rejected reasons
                                ],
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    const Divider(height: 24),
                    Text(
                      'Catatan Pengajuan:', // Perjelas ini catatan dari pengaju
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      permit.notes ?? 'Tidak ada catatan.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                      softWrap: true,
                      overflow: TextOverflow.visible,
                    ),
                    const SizedBox(height: 16),
                    // Tampilkan tombol lihat dokumen jika ada file
                    if ((permit.file ?? '').isNotEmpty)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: ElevatedButton.icon(
                          onPressed: () => _showDocumentPreviewBottomSheet(
                            context,
                            permit.file!,
                          ),
                          icon: const Icon(Icons.attach_file),
                          label: const Text('Lihat Dokumen Terlampir'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: theme
                                .colorScheme
                                .onPrimary, // Ubah ke onPrimary agar konsisten
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    // --- Bagian Tombol Persetujuan/Penolakan ---
                    Obx(() {
                      if (controller.canApprove.value) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 24.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () =>
                                      controller.submitApproval(approve: true),
                                  icon: const Icon(Icons.check_circle_outline),
                                  label: const Text('Setujui'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green.shade600,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _showRejectReasonBottomSheet(
                                    context,
                                    controller,
                                  ),
                                  icon: const Icon(Icons.cancel_outlined),
                                  label: const Text('Tolak'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red.shade600,
                                    side: BorderSide(
                                      color: Colors.red.shade600,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      } else {
                        // Jika tidak bisa approve, tampilkan status approval user ini jika sudah ada
                        if (controller.myApproval.value != null &&
                            controller.myApproval.value!.userApprove!
                                    .toLowerCase() !=
                                'w') {
                          final approvalStatusText = _getApprovalStatusText(
                            controller.myApproval.value!.userApprove,
                          );
                          return Padding(
                            padding: const EdgeInsets.only(top: 24.0),
                            child: Center(
                              child: Chip(
                                label: Text(
                                  'Anda Telah: $approvalStatusText',
                                  style: TextStyle(
                                    color: _getApprovalStatusColor(
                                      controller.myApproval.value!.userApprove,
                                      theme,
                                    ),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                backgroundColor: _getApprovalStatusColor(
                                  controller.myApproval.value!.userApprove,
                                  theme,
                                ).withAlpha(29),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  side: BorderSide(
                                    color: _getApprovalStatusColor(
                                      controller.myApproval.value!.userApprove,
                                      theme,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink(); // Sembunyikan jika tidak ada tombol dan tidak ada status
                      }
                    }),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  /// Helper widget untuk membuat baris detail.
  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value, {
    bool isTitle = false,
  }) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130, // Lebar tetap untuk label agar sejajar
            child: Text(
              label,
              style: isTitle
                  ? theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    )
                  : theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: isTitle
                  ? theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.onSurface,
                    )
                  : theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  /// Membantu menentukan warna teks status persetujuan.
  Color _getApprovalStatusColor(String? userApproveStatus, ThemeData theme) {
    switch (userApproveStatus?.toLowerCase()) {
      case 'w': // Waiting / Pending
        return Colors.orange.shade700;
      case 'y': // Yes / Approved
        return Colors.green;
      case 'n': // No / Rejected
        return Colors.red.shade700;
      default:
        return theme.colorScheme.onSurface;
    }
  }

  /// Membantu menentukan ikon berdasarkan status persetujuan.
  IconData _getApprovalStatusIcon(String? userApproveStatus) {
    switch (userApproveStatus?.toLowerCase()) {
      case 'w': // Waiting / Pending
        return Icons.hourglass_empty;
      case 'y': // Yes / Approved
        return Icons.check_circle;
      case 'n': // No / Rejected
        return Icons.cancel;
      default:
        return Icons.info_outline;
    }
  }

  /// Membantu menentukan teks status persetujuan.
  String _getApprovalStatusText(String? userApproveStatus) {
    switch (userApproveStatus?.toLowerCase()) {
      case 'w':
        return 'Menunggu Persetujuan';
      case 'y':
        return 'Disetujui';
      case 'n':
        return 'Ditolak';
      default:
        return 'Tidak Diketahui';
    }
  }

  /// --- BOTTOM SHEET UNTUK PREVIEW DOKUMEN ---
  void _showDocumentPreviewBottomSheet(BuildContext context, String fileUrl) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.center,
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(29),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Lihat Dokumen',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Anda dapat melihat atau mengunduh dokumen terlampir:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(
                Icons.file_present,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(
                'File: ${fileUrl.split('/').last}', // Ambil nama file dari URL
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              trailing: Icon(
                Icons.open_in_new,
                color: Theme.of(context).colorScheme.primary,
              ),
              onTap: () async {
                final Uri uri = Uri.parse("$baseImageUrl/$fileUrl");
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                } else {
                  showErrorSnackbar(
                    'Tidak dapat membuka dokumen. URL tidak valid atau aplikasi tidak ditemukan.',
                  );
                }
                Get.back(); // Tutup bottom sheet
              },
            ),
            const SizedBox(height: 16),
            Center(
              child: ElevatedButton(
                onPressed: () => Get.back(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context)
                      .colorScheme
                      .onPrimary, // Changed to onPrimary for better contrast with primary background
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical:
                        16, // Increased vertical padding for a more substantial button
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  minimumSize: const Size(
                    double.infinity,
                    0,
                  ), // Makes the button take full width
                ),
                child: const Text('Tutup'),
              ),
            ),
          ],
        ),
      ),
      isScrollControlled:
          true, // Izinkan bottom sheet mengambil tinggi yang dibutuhkan
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      backgroundColor: Colors.transparent, // Untuk sudut melengkung
    );
  }

  /// --- BOTTOM SHEET UNTUK REJECT REASON ---
  void _showRejectReasonBottomSheet(
    BuildContext context,
    PermitShowController controller,
  ) {
    final TextEditingController notesController = TextEditingController();
    final RxBool isNotesValid =
        false.obs; // Menggunakan RxBool untuk validasi reaktif

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize:
              MainAxisSize.min, // Penting agar tidak memenuhi seluruh layar
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.center,
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(29),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Tolak Perizinan',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Mohon berikan alasan penolakan:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Obx(
              () => TextField(
                controller: notesController,
                maxLines: 4,
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(
                  hintText: 'Masukkan catatan penolakan...',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: isNotesValid.value
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  errorText: notesController.text.isEmpty && !isNotesValid.value
                      ? 'Catatan tidak boleh kosong.'
                      : null,
                ),
                onChanged: (text) {
                  isNotesValid.value = text.trim().isNotEmpty;
                },
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Get.back(), // Tutup bottom sheet
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.error,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Obx(
                    () => ElevatedButton(
                      onPressed: isNotesValid.value
                          ? () {
                              Get.back(); // Tutup bottom sheet sebelum submit
                              controller.submitApproval(
                                approve: false,
                                notes: notesController.text.trim(),
                              );
                            }
                          : null, // Tombol nonaktif jika catatan tidak valid
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Tolak'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      isScrollControlled: true, // Penting agar keyboard tidak menutupi input
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      backgroundColor: Colors.transparent, // Untuk efek sudut melengkung
    );
  }

  /// --- BOTTOM SHEET UNTUK MENAMPILKAN ALASAN PENOLAKAN YANG SUDAH ADA ---
  void _showApprovalReasonBottomSheet(
    BuildContext context,
    String approverType,
    String reason,
  ) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.center,
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(29),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Alasan Penolakan dari $approverType',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              reason,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: ElevatedButton(
                onPressed: () => Get.back(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Tutup'),
              ),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      backgroundColor: Colors.transparent,
    );
  }
}

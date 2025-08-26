import 'package:esas/app/data/Permit/leave_list.m.dart';
import 'package:esas/app/routes/app_pages.dart';
import 'package:esas/utils/helper.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class PermitListItem extends StatelessWidget {
  final Permit permit;
  final ThemeData theme;

  const PermitListItem({
    required this.permit,
    required this.theme,
    super.key, // Menggunakan super.key untuk konstruktor konstan
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        onTap: () => Get.toNamed(
          Routes.PERMIT_SHOW,
          arguments: {'permit': permit, 'id': permit.id},
        ),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'No. Pengajuan: ${permit.permitNumbers}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface, // Gunakan warna dari tema
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tipe: ${permit.permitType!.type}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme
                      .colorScheme
                      .onSurfaceVariant, // Gunakan warna dari tema
                ),
              ),
              const SizedBox(height: 4),
              // Memanggil _getOverallPermitStatusText untuk status keseluruhan
              Text(
                'Status: ${_getOverallPermitStatusText(permit)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: _getOverallPermitStatusColor(permit, theme),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              // Menggunakan helper formatDateIndo (asumsi ada)
              Text(
                'Tanggal: ${formatDateIndo(permit.startDate.toString())} - ${formatDateIndo(permit.endDate.toString())}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Durasi: ${permit.durationInDays} hari',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Membantu menentukan teks status persetujuan keseluruhan dari suatu perizinan.
  /// Logika:
  /// - Jika ada penolakan, statusnya 'Ditolak'.
  /// - Jika semua disetujui, statusnya 'Disetujui'.
  /// - Jika ada yang masih 'w', statusnya 'Dalam Proses'.
  /// - Default 'N/A'.
  String _getOverallPermitStatusText(Permit permit) {
    if (permit.approvals.isEmpty) {
      return 'Menunggu Proses'; // Atau 'Belum Diproses'
    }

    bool hasRejected = false;
    bool hasPending = false;
    bool allApproved = true;

    for (var approval in permit.approvals) {
      final status = approval.userApprove!.toLowerCase();
      if (status == 'n' || status == 'rejected') {
        hasRejected = true;
        break; // Jika ada yang ditolak, langsung 'Ditolak'
      }
      if (status == 'w' || status == 'waiting' || status == 'pending') {
        hasPending = true;
      }
      if (status != 'y' && status != 'approved') {
        allApproved = false;
      }
    }

    if (hasRejected) {
      return 'Ditolak';
    } else if (allApproved) {
      return 'Disetujui';
    } else if (hasPending) {
      return 'Dalam Proses';
    }
    return 'N/A'; // Kasus lain yang tidak terdefinisi
  }

  /// Membantu menentukan warna teks status berdasarkan status perizinan secara keseluruhan.
  Color _getOverallPermitStatusColor(Permit permit, ThemeData theme) {
    String status = _getOverallPermitStatusText(
      permit,
    ); // Gunakan fungsi status keseluruhan

    switch (status.toLowerCase()) {
      case 'dalam proses':
        return Colors.orange.shade700;
      case 'disetujui':
        return Colors.green.shade700;
      case 'ditolak':
        return Colors.red.shade700;
      case 'menunggu proses': // Warna untuk status awal
        return Colors.blueGrey.shade600;
      default:
        return theme.colorScheme.onSurface;
    }
  }
}

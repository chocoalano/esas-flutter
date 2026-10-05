import 'package:esas/core/theme/app_palette.dart';
import 'package:esas/core/ui/components/app_badge.dart';
import 'package:esas/features/permit/data/models/leave_list.dart';
import 'package:flutter/material.dart';

/// Status persetujuan sebuah pengajuan, sebagai label dan nada warna.
///
/// Logika ini sebelumnya hidup sebagai dua metode privat di dalam widget baris
/// daftar, dan disalin ulang dengan pemetaan warna yang sedikit berbeda di
/// layar rincian. Menaruhnya di satu tempat berarti sebuah pengajuan tidak bisa
/// lagi tampak "Dalam Proses" berwarna oranye di satu layar dan biru di layar
/// lain.
class PermitStatus {
  const PermitStatus(this.label, this.tone, this.icon);

  final String label;
  final AppBadgeTone tone;
  final IconData icon;

  static const PermitStatus pending = PermitStatus(
    'Menunggu',
    AppBadgeTone.neutral,
    Icons.schedule_rounded,
  );
  static const PermitStatus inProgress = PermitStatus(
    'Diproses',
    AppBadgeTone.warning,
    Icons.hourglass_bottom_rounded,
  );
  static const PermitStatus approved = PermitStatus(
    'Disetujui',
    AppBadgeTone.success,
    Icons.check_circle_outline_rounded,
  );
  static const PermitStatus rejected = PermitStatus(
    'Ditolak',
    AppBadgeTone.danger,
    Icons.cancel_outlined,
  );

  /// Keadaan yang tidak dikenali kamus ini. Ditulis apa adanya alih-alih
  /// ditebak menjadi "Menunggu": sebuah kolom yang berubah arti di server
  /// harus terlihat, bukan diam-diam dibaca sebagai antrean yang normal.
  static const PermitStatus unknown = PermitStatus(
    'Tidak diketahui',
    AppBadgeTone.neutral,
    Icons.help_outline_rounded,
  );
}

/// Menyimpulkan satu status dari seluruh baris persetujuan.
///
/// Satu penolakan mengalahkan segalanya; selain itu, semua setuju berarti
/// disetujui, dan sisanya masih berjalan. Urutan itu penting: pengajuan yang
/// sudah ditolak oleh manajer tidak boleh tampil "Diproses" hanya karena HR
/// belum menyentuhnya.
PermitStatus resolvePermitStatus(Permit permit) {
  if (permit.approvals.isEmpty) return PermitStatus.pending;

  bool allApproved = true;
  for (final approval in permit.approvals) {
    final String status = (approval.userApprove ?? '').toLowerCase();
    if (status == 'n' || status == 'rejected') return PermitStatus.rejected;
    if (status != 'y' && status != 'approved') allApproved = false;
  }

  return allApproved ? PermitStatus.approved : PermitStatus.inProgress;
}

/// Berapa banyak persetujuan yang sudah masuk, untuk ditampilkan sebagai
/// "2 dari 3 disetujui". Angka ini menjawab pertanyaan yang selalu menyusul
/// status "Diproses": diproses sampai sejauh mana?
({int approved, int total}) permitApprovalProgress(Permit permit) {
  final int total = permit.approvals.length;
  final int approved = permit.approvals.where((a) {
    final String status = (a.userApprove ?? '').toLowerCase();
    return status == 'y' || status == 'approved';
  }).length;
  return (approved: approved, total: total);
}

/// Status satu langkah persetujuan, dibaca dari `user_approve`.
///
/// Ini yang membuat layar rincian berhenti punya dua kamus: sebelumnya sebuah
/// `_lookFor` privat di dalam `permit_show_view.dart` memetakan keadaan yang
/// sama ke nada yang berbeda, sehingga "Menunggu" tampil kelabu netral pada
/// lencana kepala dan kuning pada langkah di lini masa — pada satu layar yang
/// sama, untuk satu pengajuan yang sama.
PermitStatus resolveApprovalStatus(Approval approval) {
  switch ((approval.userApprove ?? '').toLowerCase()) {
    case 'y':
    case 'approved':
      return PermitStatus.approved;
    case 'n':
    case 'rejected':
      return PermitStatus.rejected;
    case 'w':
    case 'waiting':
    case 'pending':
    case '':
      return PermitStatus.pending;
    default:
      return PermitStatus.unknown;
  }
}

/// Indeks langkah terakhir yang sudah benar-benar diputuskan, atau -1 bila
/// belum ada satu pun. Rel lini masa memakai ini untuk menghentikan warna
/// tepat di titik pengajuan berhenti bergerak.
int lastDecidedApprovalIndex(Permit permit) {
  int last = -1;
  for (var i = 0; i < permit.approvals.length; i++) {
    final PermitStatus status = resolveApprovalStatus(permit.approvals[i]);
    if (status == PermitStatus.approved || status == PermitStatus.rejected) {
      last = i;
    }
  }
  return last;
}

/// Warna nada penuh untuk sebuah status, diambil dari palet tema.
///
/// [PermitStatus.tone] menyebut nadanya; ini yang menerjemahkannya menjadi
/// tiga warna, supaya titik pada lini masa dan lencana pada kartu tidak pernah
/// bisa menyimpang satu sama lain.
extension PermitStatusColors on PermitStatus {
  AppTone colors(AppPalette palette) => switch (tone) {
    AppBadgeTone.neutral => palette.neutral,
    AppBadgeTone.success => palette.success,
    AppBadgeTone.warning => palette.warning,
    AppBadgeTone.danger => palette.danger,
    AppBadgeTone.info => palette.info,
    AppBadgeTone.brand => AppTone(
      foreground: palette.brandAccent,
      background: palette.brandSubtle,
      border: palette.brandAccent,
    ),
  };
}

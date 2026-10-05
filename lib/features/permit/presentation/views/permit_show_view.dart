import 'package:esas/core/config/env.dart';
import 'package:esas/core/theme/app_dimens.dart';
import 'package:esas/core/theme/app_palette.dart';
import 'package:esas/core/theme/app_typography.dart';
import 'package:esas/core/ui/components/app_badge.dart';
import 'package:esas/core/ui/components/app_card.dart';
import 'package:esas/core/ui/components/app_empty_state.dart';
import 'package:esas/core/ui/components/app_section_header.dart';
import 'package:esas/core/ui/components/app_skeleton.dart';
import 'package:esas/core/ui/dialogs/app_bottom_sheet.dart';
import 'package:esas/core/ui/dialogs/app_snackbar.dart';
import 'package:esas/features/permit/data/models/leave_list.dart';
import 'package:esas/features/permit/data/models/permit_variant.dart';
import 'package:esas/features/permit/presentation/routes/permit_routes.dart';
import 'package:esas/features/permit/presentation/widgets/permit_status.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../controllers/permit_show_controller.dart';

/// Rincian satu pengajuan izin.
///
/// Perubahan terbesar ada pada dua hal.
///
/// Pertama, alur persetujuan. Sebelumnya ia berupa daftar baris berbunyi
/// "line: Menunggu Persetujuan", "manager: Disetujui" — rata kiri, tanpa
/// hubungan visual antar baris, sehingga urutan siapa menyetujui setelah siapa
/// harus disimpulkan sendiri. Sekarang ia digambar sebagai lini masa dengan
/// garis penghubung: satu tatapan cukup untuk melihat pengajuan ini berhenti di
/// mana.
///
/// Kedua, tombol Setujui dan Tolak pindah dari ujung bawah halaman yang harus
/// digulir ke sebuah bilah tetap di kaki layar. Seorang atasan yang membuka
/// layar ini datang untuk memutuskan; keputusannya tidak seharusnya bersembunyi
/// di bawah lampiran.
class PermitShowView extends GetView<PermitShowController> {
  const PermitShowView({super.key});

  @override
  Widget build(BuildContext context) {
    void back() => Get.offAllNamed(
      PermitRoutes.list,
      arguments: controller.permitType.value,
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        back();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Kembali',
            onPressed: back,
          ),
          title: const Text('Detail pengajuan'),
          titleSpacing: 0,
        ),
        body: Obx(() {
          if (controller.isLoading.value) {
            return const Padding(
              padding: EdgeInsets.only(top: AppSpacing.lg),
              child: AppSkeletonList(count: 3),
            );
          }

          final Permit? permit = controller.permit.value;
          if (permit == null) {
            return AppEmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Gagal memuat detail',
              message:
                  'Rincian pengajuan ini tidak bisa diambil. Periksa koneksi '
                  'Anda lalu coba lagi.',
              actionLabel: 'Coba lagi',
              onAction: controller.permitId.value != 0
                  ? controller.loadPermitDetails
                  : null,
            );
          }

          return _PermitDetail(permit: permit);
        }),
        bottomNavigationBar: Obx(() {
          if (controller.permit.value == null) return const SizedBox.shrink();

          if (controller.canApprove.value) {
            return _ApprovalBar(controller: controller);
          }

          final Approval? mine = controller.myApproval.value;
          final String state = (mine?.userApprove ?? '').toLowerCase();
          if (mine == null || state.isEmpty || state == 'w') {
            return const SizedBox.shrink();
          }
          return _MyDecisionBar(state: state);
        }),
      ),
    );
  }
}

class _PermitDetail extends StatelessWidget {
  const _PermitDetail({required this.permit});

  final Permit permit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;
    final PermitStatus status = resolvePermitStatus(permit);
    final DateFormat dateFormat = DateFormat('d MMMM yyyy', 'id');

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.lg,
        AppSpacing.page,
        AppSpacing.bottomSafe,
      ),
      children: [
        // Ringkasan
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      permit.permitType?.type ?? 'Perizinan',
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  AppBadge(
                    label: status.label,
                    tone: status.tone,
                    icon: status.icon,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                permit.permitNumbers,
                style: AppTypography.dataSmall(color: palette.textMuted),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.xxl),
        const AppSectionHeader(title: 'Rincian'),
        AppDetailPanel(
          children: [
            AppDetailRow(label: 'Periode', value: _period(permit, dateFormat)),
            AppDetailRow(
              label: 'Durasi',
              value: '${permit.durationInDays} hari',
            ),
            if ((permit.startTime ?? '').isNotEmpty ||
                (permit.endTime ?? '').isNotEmpty)
              AppDetailRow(
                label: 'Jam',
                value:
                    '${permit.startTime ?? '--:--'} – '
                    '${permit.endTime ?? '--:--'}',
              ),
            AppDetailRow(
              label: 'Pengaju',
              value: permit.user?.name ?? '—',
              trailing: permit.user == null
                  ? null
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          permit.user!.name,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'NIP ${permit.user!.nip}',
                          style: AppTypography.dataSmall(
                            color: palette.textMuted,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),

        ..._adjustment(permit),

        const SizedBox(height: AppSpacing.xxl),
        const AppSectionHeader(title: 'Alur persetujuan'),
        if (permit.approvals.isEmpty)
          AppCard(
            padding: EdgeInsets.zero,
            child: const AppEmptyState(
              icon: Icons.how_to_reg_outlined,
              title: 'Belum masuk antrean persetujuan',
              compact: true,
            ),
          )
        else
          AppCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.lg,
            ),
            child: Builder(
              builder: (context) {
                // Sampai di mana rel ini sudah benar-benar dilewati. Konektor
                // di bawah langkah yang sudah diputuskan ikut bernada; sisanya
                // kembali menjadi hairline netral, jadi bentuk relnya sendiri
                // sudah menjawab "berhenti di mana".
                final int decidedUpTo = lastDecidedApprovalIndex(permit);

                return Column(
                  children: [
                    for (var i = 0; i < permit.approvals.length; i++)
                      _ApprovalStep(
                        approval: permit.approvals[i],
                        isLast: i == permit.approvals.length - 1,
                        traversed: i <= decidedUpTo,
                      ),
                  ],
                );
              },
            ),
          ),

        const SizedBox(height: AppSpacing.xxl),
        const AppSectionHeader(title: 'Catatan pengajuan'),
        AppCard(
          child: Text(
            (permit.notes ?? '').trim().isEmpty
                ? 'Tidak ada catatan.'
                : permit.notes!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: (permit.notes ?? '').trim().isEmpty
                  ? palette.textMuted
                  : theme.colorScheme.onSurface,
            ),
          ),
        ),

        if ((permit.file ?? '').isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xxl),
          const AppSectionHeader(title: 'Lampiran'),
          _AttachmentCard(file: permit.file!),
        ],
      ],
    );
  }

  /// Apa yang sebenarnya diminta, pada dua jenis izin yang meminta lebih dari
  /// sekadar tanggal.
  ///
  /// Layar ini dulu menampilkan periode, durasi, jam dan catatan untuk semua
  /// jenis izin tanpa kecuali — jadi seorang atasan yang membuka permintaan
  /// tukar shift menyetujui sesuatu yang tidak pernah ditampilkan kepadanya.
  /// Keempat kolomnya ada di dalam jawaban server sejak dulu.
  ///
  /// Ditampilkan bila variannya mengatakan begitu **atau** bila datanya
  /// memang ada: pengajuan lama dibuat sebelum jenis izin punya kode, dan
  /// menyembunyikan isinya karena alasan itu sama saja dengan kehilangannya.
  static List<Widget> _adjustment(Permit permit) {
    final PermitVariant variant =
        permit.permitType?.variant ?? PermitVariant.general;

    final String? timeIn = _hourMinute(permit.timeinAdjust);
    final String? timeOut = _hourMinute(permit.timeoutAdjust);
    final PermitShift? from = permit.shiftFrom;
    final PermitShift? to = permit.shiftTo;

    final bool showTime =
        variant.isTimeAdjustment || timeIn != null || timeOut != null;
    final bool showShift =
        variant.isShiftAdjustment || from != null || to != null;

    return [
      if (showTime) ...[
        const SizedBox(height: AppSpacing.xxl),
        const AppSectionHeader(title: 'Penyesuaian jam'),
        AppDetailPanel(
          children: [
            // Hanya jam yang diminta. Jam absensi yang berlaku sekarang tidak
            // ada di dalam jawaban endpoint ini, dan menampilkan tebakan
            // sebagai "jam semula" akan membuat penyetuju membandingkan
            // permintaan dengan angka yang tidak pernah dicatat.
            AppDetailRow(label: 'Jam masuk diminta', value: timeIn ?? '—'),
            AppDetailRow(label: 'Jam pulang diminta', value: timeOut ?? '—'),
          ],
        ),
      ],
      if (showShift) ...[
        const SizedBox(height: AppSpacing.xxl),
        const AppSectionHeader(title: 'Penyesuaian shift'),
        _ShiftChange(from: from, to: to),
      ],
    ];
  }

  /// `08:00:00` menjadi `08:00`; kolom jam membawa detik yang tidak pernah
  /// berarti apa pun di layar.
  static String? _hourMinute(String? raw) {
    final value = raw?.trim();

    if (value == null || value.isEmpty) return null;

    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(value);

    if (match == null) return value;

    return '${match.group(1)!.padLeft(2, '0')}:${match.group(2)}';
  }

  static String _period(Permit permit, DateFormat format) {
    final start = permit.startDate;
    final end = permit.endDate;
    if (start == null && end == null) return 'Belum ditentukan';
    if (start != null && end != null) {
      return start == end
          ? format.format(start)
          : '${format.format(start)} – ${format.format(end)}';
    }
    return format.format((start ?? end)!);
  }
}

/// Satu langkah pada lini masa persetujuan.
///
/// Label dan nadanya datang dari `permit_status.dart`, kamus yang sama yang
/// dipakai lencana di kepala layar ini dan setiap baris di daftar riwayat.
/// Sebelumnya file ini memelihara pemetaannya sendiri, dan pemetaan itu tidak
/// sepakat dengan yang di sebelahnya.
class _ApprovalStep extends StatelessWidget {
  const _ApprovalStep({
    required this.approval,
    required this.isLast,
    required this.traversed,
  });

  final Approval approval;
  final bool isLast;

  /// Apakah rel sudah lewat titik ini — yakni langkah ini berada pada atau
  /// sebelum keputusan terakhir yang sudah diambil.
  final bool traversed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;
    final PermitStatus status = resolveApprovalStatus(approval);
    final AppTone tone = status.colors(palette);
    final bool hasReason =
        status == PermitStatus.rejected &&
        (approval.notes ?? '').trim().isNotEmpty;
    // Stempel waktu hanya untuk langkah yang sudah diputuskan. Pada langkah
    // yang masih menunggu, `updated_at` adalah waktu baris itu dibuat — angka
    // yang akan dibaca sebagai waktu keputusan yang belum pernah terjadi.
    final String? stamp = traversed ? _stamp(approval.updatedAt) : null;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Rel lini masa: bulatan status, lalu garis menuju langkah berikutnya.
          Column(
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tone.background,
                  shape: BoxShape.circle,
                  border: Border.all(color: tone.border),
                ),
                child: Icon(
                  status.icon,
                  size: AppIconSizes.xs,
                  color: tone.foreground,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 1.5,
                    margin: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xxs,
                    ),
                    color: traversed ? tone.border : palette.borderSubtle,
                  ),
                ),
            ],
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _roleLabel(approval.userType),
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  // Kata statusnya tetap ditulis — titik bernada saja adalah
                  // warna sebagai pembawa makna tunggal — tetapi bukan lagi
                  // sebagai lencana berbingkai: satu rel dengan tiga lencana
                  // membaca lebih ramai daripada keadaan yang diwakilinya.
                  Row(
                    children: [
                      Text(
                        status.label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: tone.foreground,
                        ),
                      ),
                      if (stamp != null) ...[
                        Text(
                          '  ·  ',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: palette.borderStrong,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            stamp,
                            style: AppTypography.dataSmall(
                              color: palette.textMuted,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (hasReason) ...[
                    const SizedBox(height: AppSpacing.sm),
                    // Alasan penolakan ditampilkan langsung, bukan disembunyikan
                    // di balik ikon info yang harus ditekan. Ini justru
                    // informasi yang paling dicari orang saat pengajuannya
                    // ditolak.
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: palette.danger.background,
                        borderRadius: AppRadii.mdAll,
                        border: Border.all(color: palette.danger.border),
                      ),
                      child: Text(
                        approval.notes!.trim(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: palette.danger.foreground,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// `userType` datang sebagai slug bahasa Inggris (`line`, `manager`, `hr`).
  static String _roleLabel(String? type) {
    switch ((type ?? '').toLowerCase()) {
      case 'line':
        return 'Atasan langsung';
      case 'manager':
        return 'Manajer';
      case 'hr':
        return 'HR';
      default:
        return (type ?? 'Penyetuju').toUpperCase();
    }
  }

  /// Kapan keputusan itu diambil. Kolom ini sudah diurai model sejak dulu dan
  /// tidak pernah sekali pun digambar, sehingga "sudah berapa lama pengajuan
  /// ini mengendap" adalah pertanyaan yang layar rincian tidak bisa jawab.
  static String? _stamp(DateTime? at) {
    if (at == null) return null;
    return DateFormat('d MMM yyyy · HH:mm', 'id').format(at);
  }
}

/// Kartu lampiran: nama berkas dan satu tindakan.
class _AttachmentCard extends StatelessWidget {
  const _AttachmentCard({required this.file});

  final String file;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;

    return AppCard(
      onTap: () => _open(),
      child: Row(
        children: [
          const AppIconBox(icon: Icons.description_outlined, size: 36),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  file.split('/').last,
                  style: theme.textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Ketuk untuk membuka di aplikasi lain',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: palette.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.open_in_new_rounded,
            size: AppIconSizes.md,
            color: palette.textMuted,
          ),
        ],
      ),
    );
  }

  Future<void> _open() async {
    final Uri uri = Uri.parse('${Env.assetBaseUrl}/$file');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      showErrorSnackbar(
        'Tidak dapat membuka dokumen. Tautan tidak valid atau tidak ada '
        'aplikasi yang bisa membukanya.',
      );
    }
  }
}

/// Bilah keputusan di kaki layar, untuk penyetuju.
class _ApprovalBar extends StatelessWidget {
  const _ApprovalBar({required this.controller});

  final PermitShowController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: palette.borderSubtle)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: OutlinedButton.icon(
                    onPressed: () => _askReason(context),
                    icon: const Icon(
                      Icons.close_rounded,
                      size: AppIconSizes.lg,
                    ),
                    label: const Text('Tolak'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: palette.danger.foreground,
                      side: BorderSide(color: palette.danger.border),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 46,
                  child: FilledButton.icon(
                    onPressed: () => controller.submitApproval(approve: true),
                    icon: const Icon(
                      Icons.check_rounded,
                      size: AppIconSizes.lg,
                    ),
                    label: const Text('Setujui'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _askReason(BuildContext context) {
    showAppBottomSheet<void>(
      context,
      title: 'Tolak pengajuan',
      description:
          'Alasan ini akan dibaca oleh karyawan yang mengajukan, jadi tulis '
          'sejelas mungkin.',
      child: _RejectForm(
        onSubmit: (notes) =>
            controller.submitApproval(approve: false, notes: notes),
      ),
    );
  }
}

/// Formulir alasan penolakan.
///
/// Sebuah [StatefulWidget] agar [TextEditingController]-nya punya pemilik yang
/// membuangnya. Versi sebelumnya membuat controller di dalam sebuah fungsi dan
/// tidak pernah memanggil `dispose()`, jadi setiap kali sheet dibuka satu
/// controller tertinggal.
class _RejectForm extends StatefulWidget {
  const _RejectForm({required this.onSubmit});

  final void Function(String notes) onSubmit;

  @override
  State<_RejectForm> createState() => _RejectFormState();
}

class _RejectFormState extends State<_RejectForm> {
  final TextEditingController _notes = TextEditingController();
  bool _valid = false;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _notes,
          maxLines: 4,
          autofocus: true,
          keyboardType: TextInputType.multiline,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Contoh: kuota cuti tahun ini sudah habis.',
            alignLabelWithHint: true,
          ),
          // Galat baru muncul setelah pengguna sempat mengetik. Versi lama
          // menandai kolom sebagai salah sejak sheet terbuka, sebelum ada
          // kesempatan mengisinya.
          onChanged: (text) => setState(() => _valid = text.trim().isNotEmpty),
        ),
        const SizedBox(height: AppSpacing.xl),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 46,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Batal'),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: SizedBox(
                height: 46,
                child: FilledButton(
                  onPressed: _valid
                      ? () {
                          Navigator.of(context).pop();
                          widget.onSubmit(_notes.text.trim());
                        }
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.error,
                    foregroundColor: theme.colorScheme.onError,
                    disabledBackgroundColor: palette.surfaceRaised,
                    disabledForegroundColor: palette.textMuted,
                  ),
                  child: const Text('Tolak'),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Bilah yang menyebutkan keputusan yang sudah pernah diambil pengguna ini.
class _MyDecisionBar extends StatelessWidget {
  const _MyDecisionBar({required this.state});

  final String state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;
    final bool approved = state == 'y' || state == 'approved';
    final AppTone tone = approved ? palette.success : palette.danger;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: palette.borderSubtle)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                approved ? Icons.check_circle_outline : Icons.cancel_outlined,
                size: AppIconSizes.md,
                color: tone.foreground,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                approved
                    ? 'Anda sudah menyetujui pengajuan ini'
                    : 'Anda sudah menolak pengajuan ini',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: tone.foreground,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Perpindahan shift, dibaca dalam satu tarikan: dari apa, menjadi apa.
///
/// Bukan "current_shift_id 12 → adjust_shift_id 15". Sebuah id bukan kalimat
/// yang bisa disetujui siapa pun, dan `Pagi (07:00–15:00) → Malam
/// (23:00–07:00)` adalah keputusan yang berbeda dari `Pagi → Siang` meskipun
/// keduanya sama-sama "tukar shift".
class _ShiftChange extends StatelessWidget {
  const _ShiftChange({required this.from, required this.to});

  final PermitShift? from;
  final PermitShift? to;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;

    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: _side(theme, palette, 'Shift saat ini', from)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Icon(
              Icons.arrow_forward_rounded,
              size: AppIconSizes.lg,
              color: palette.textMuted,
            ),
          ),
          Expanded(child: _side(theme, palette, 'Diminta', to)),
        ],
      ),
    );
  }

  Widget _side(
    ThemeData theme,
    AppPalette palette,
    String label,
    PermitShift? shift,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(color: palette.textMuted),
        ),
        const SizedBox(height: 2),
        Text(
          shift?.name ?? 'Tidak disebutkan',
          style: theme.textTheme.titleSmall?.copyWith(
            color: shift == null
                ? palette.textMuted
                : theme.colorScheme.onSurface,
          ),
        ),
        if (shift?.start != null && shift?.end != null) ...[
          const SizedBox(height: 2),
          Text(
            '${shift!.start} – ${shift.end}',
            style: AppTypography.dataSmall(color: palette.textMuted),
          ),
        ],
      ],
    );
  }
}

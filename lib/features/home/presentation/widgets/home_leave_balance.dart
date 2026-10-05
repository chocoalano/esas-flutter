import 'package:esas/core/theme/app_dimens.dart';
import 'package:esas/core/theme/app_palette.dart';
import 'package:esas/core/ui/components/app_card.dart';
import 'package:esas/core/ui/components/app_skeleton.dart';
import 'package:esas/features/home/data/repositories/home_repository.dart';
import 'package:esas/features/home/presentation/widgets/home_metric.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Sisa cuti, sebagai saldo yang bisa dilihat sekilas.
///
/// ## Berapa yang boleh digambar, dan kapan
///
/// Bentuknya mengikuti BANYAKNYA jenis izin yang punya saldo, bukan sebuah
/// petak tetap:
///
/// | Jenis | Bentuk |
/// |---|---|
/// | 0 | permukaan lembut satu baris — kosong, bukan galat |
/// | 1 | satu saldo besar, dengan bar bila jatahnya diketahui |
/// | 2 | dua kolom |
/// | 3+ | dua kolom + "Lihat semua" ke layar izin |
///
/// Tidak pernah tiga kolom atau lebih. Pada 320dp sebuah kolom ketiga menyisakan
/// ~85dp per ubin, dan angka besar di dalamnya berhenti terbaca sebagai angka
/// besar — yaitu satu-satunya alasan ubin ini ada.
///
/// ## Bar hanya ketika jatahnya nyata
///
/// `quota` datang dari server dan boleh kosong. Ketika ia ada, `terpakai =
/// quota - remaining` adalah aritmetika atas dua angka kanonis, dan barnya sah.
/// Ketika ia tidak ada, tidak ada bar — sebuah lintasan yang panjangnya
/// dikarang membuat sisa 8 hari terlihat seperti "hampir habis" atau "masih
/// banyak" tergantung angka yang tidak pernah dikirim siapa pun.
class HomeLeaveBalance extends StatelessWidget {
  const HomeLeaveBalance({
    super.key,
    required this.balances,
    required this.loading,
    required this.error,
    required this.onOpen,
    required this.onRequests,
  });

  final List<LeaveBalance> balances;
  final bool loading;

  /// Gagal dimuat. Bagian sekunder yang gagal menghilang, tidak berteriak —
  /// kegagalannya sudah tercatat di log oleh `HomeController._load`.
  final bool error;

  final VoidCallback onOpen;

  /// Daftar pengajuan. Dipakai keadaan kosong, yang tidak punya saldo untuk
  /// dibuka tetapi tetap punya sesuatu yang berguna untuk ditawarkan.
  final VoidCallback onRequests;

  /// Berapa saldo yang muat berdampingan tanpa membunuh ukuran angkanya.
  static const int _maxTiles = 2;

  bool get hasContent => loading || !error;

  /// Apakah judul bagiannya layak membawa chevron.
  ///
  /// Hanya ketika ada yang benar-benar bisa dibuka. Chevron adalah janji
  /// navigasi, bukan hiasan.
  bool get isNavigable => !loading && !error && balances.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    if (loading) return const _BalanceSkeleton();
    if (error) return const SizedBox.shrink();
    if (balances.isEmpty) return _EmptyBalance(onOpenRequests: onRequests);

    final List<LeaveBalance> shown = balances.take(_maxTiles).toList();
    final int hidden = balances.length - shown.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (shown.length == 1)
          _BalanceTile(
            balance: shown.first,
            onTap: onOpen,
            wide: true,
            accent: true,
          )
        else
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (int i = 0; i < shown.length; i++) ...<Widget>[
                  if (i > 0) const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _BalanceTile(
                      balance: shown[i],
                      onTap: onOpen,
                      // Hanya saldo PERTAMA yang bertinta hijau. Dua angka
                      // besar hijau berdampingan, ditambah bar hijau di
                      // ringkasan tepat di atasnya dan petak "Absen" yang juga
                      // hijau, mengubah aksen tunggal produk ini menjadi warna
                      // latar — dan begitu semuanya hijau, tidak ada lagi yang
                      // berarti "ini yang penting".
                      accent: i == 0,
                    ),
                  ),
                ],
              ],
            ),
          ),
        if (hidden > 0) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: onOpen,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              ),
              child: Text('Lihat $hidden jenis izin lainnya'),
            ),
          ),
        ],
      ],
    );
  }
}

class _BalanceTile extends StatelessWidget {
  const _BalanceTile({
    required this.balance,
    required this.onTap,
    this.wide = false,
    this.accent = false,
  });

  final LeaveBalance balance;
  final VoidCallback onTap;

  /// Satu-satunya saldo di barisnya: boleh membentang penuh, dan barnya punya
  /// ruang untuk terbaca.
  final bool wide;

  /// Saldo utama baris ini — satu-satunya yang angkanya bertinta hijau.
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppPalette palette = theme.palette;

    final int? quota = balance.quota;
    final bool hasQuota = quota != null && quota > 0;
    final int used = hasQuota ? (quota - balance.remaining).clamp(0, quota) : 0;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          HomeMetric(
            value: '${balance.remaining}',
            unit: 'hari',
            label: leaveTypeLabel(balance),
            // Saldo yang tersisa adalah kabar baik selama masih ada; nol
            // diwarnai netral, bukan merah — habisnya jatah cuti bukan
            // kesalahan orangnya.
            tone: accent && balance.remaining > 0 ? palette.success : null,
          ),
          if (hasQuota) ...<Widget>[
            SizedBox(height: wide ? AppSpacing.lg : AppSpacing.md),
            HomeSplitBar(
              primary: used,
              secondary: balance.remaining,
              primaryTone: palette.neutral,
              secondaryTone: palette.success,
              semanticsLabel:
                  '$used dari $quota hari terpakai, '
                  '${balance.remaining} hari tersisa',
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '$used dari $quota hari terpakai',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Tidak ada satu pun saldo, dan permintaannya BERHASIL.
///
/// Kalimatnya hanya sah setelah 200. Permintaan yang gagal tidak pernah sampai
/// ke sini — pemanggil menyembunyikan seluruh bagiannya — karena "belum ada
/// saldo cuti" adalah klaim tentang hak orangnya, dan sebuah penolakan jaringan
/// tidak memberi kita hak untuk mengucapkannya.
///
/// Bentuknya kartu bergaris dengan aksi, berbeda dari keadaan kosong ringkasan
/// bulanan di atasnya yang berupa permukaan terisi tanpa garis. Dua bagian yang
/// kebetulan kosong bersamaan tidak boleh terbaca sebagai satu blok berulang.
class _EmptyBalance extends StatelessWidget {
  const _EmptyBalance({required this.onOpenRequests});

  /// Menuju daftar pengajuan — BUKAN formulir pengajuan. Akses cepat di atas
  /// sudah menawarkan "Ajukan izin", dan dua tombol yang mengerjakan hal yang
  /// sama pada satu layar adalah satu tombol yang terlalu banyak.
  final VoidCallback onOpenRequests;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppPalette palette = theme.palette;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              AppIconBox(
                icon: Icons.beach_access_outlined,
                size: 40,
                foreground: palette.textMuted,
                background: palette.surfaceSubtle,
                borderColor: palette.borderSubtle,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      'Belum ada saldo cuti',
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      'Saldo tampil setelah hak cuti tersedia.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: palette.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onOpenRequests,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              ),
              icon: const Icon(
                Icons.arrow_forward_rounded,
                size: AppIconSizes.md,
              ),
              iconAlignment: IconAlignment.end,
              label: const Text('Lihat pengajuan'),
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceSkeleton extends StatelessWidget {
  const _BalanceSkeleton();

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = Theme.of(context).palette;

    Widget tile() => Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: AppRadii.xlAll,
          border: Border.all(color: palette.borderSubtle),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            AppSkeleton(width: 48, height: 30),
            SizedBox(height: AppSpacing.sm),
            AppSkeleton(width: 76, height: 11),
          ],
        ),
      ),
    );

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          tile(),
          const SizedBox(width: AppSpacing.md),
          tile(),
        ],
      ),
    );
  }
}

/// Nama jenis cuti dalam bahasa Indonesia.
///
/// Server mengirim kode (`ANNUAL`, `SICK`) pada sebagian instalasi dan nama pada
/// sebagian lain. Kode tidak pernah ditampilkan apa adanya kepada staf pabrik;
/// yang tidak ada di daftar diturunkan menjadi kalimat biasa daripada dicetak
/// sebagai konstanta huruf besar.
String leaveTypeLabel(LeaveBalance balance) {
  const Map<String, String> names = <String, String>{
    'annual': 'Cuti tahunan',
    'annualleave': 'Cuti tahunan',
    'cutitahunan': 'Cuti tahunan',
    'big': 'Cuti besar',
    'sick': 'Sakit',
    'sickleave': 'Sakit',
    'unpaid': 'Tanpa upah',
    'unpaidleave': 'Tanpa upah',
    'maternity': 'Cuti melahirkan',
    'paternity': 'Cuti ayah',
    'marriage': 'Cuti menikah',
    'special': 'Cuti khusus',
    'leave': 'Cuti',
    'permit': 'Izin',
  };

  final String key = balance.code.toLowerCase().replaceAll(
    RegExp(r'[^a-z]'),
    '',
  );
  final String? known = names[key];

  if (known != null) return known;

  final String raw = balance.label.trim();

  if (RegExp(r'^[A-Z0-9_\- ]+$').hasMatch(raw)) {
    final String spaced = raw.replaceAll(RegExp(r'[_\-]+'), ' ').toLowerCase();

    return toBeginningOfSentenceCase(spaced) ?? raw;
  }

  return raw;
}

import 'dart:async';

import 'package:esas/core/network/api_exception.dart';
import 'package:esas/core/theme/app_dimens.dart';
import 'package:esas/core/theme/app_palette.dart';
import 'package:esas/core/theme/app_typography.dart';
import 'package:esas/core/ui/components/app_badge.dart';
import 'package:esas/core/ui/layout/app_breakpoints.dart';
import 'package:esas/features/home/data/repositories/home_repository.dart';
import 'package:esas/features/home/presentation/controllers/home_controller.dart';
import 'package:esas/features/home/presentation/widgets/home_failure.dart';
import 'package:esas/features/home/presentation/widgets/shift_track.dart';
import 'package:flutter/material.dart';

/// Panel protagonis Beranda: hari kerja hari ini, dan satu tindakan.
///
/// Ia TIDAK punya kedalaman apa pun selain garis 1px. Larangan gradient,
/// bayangan dan glow berlaku penuh di sini juga — kartu ini sempat memegang
/// satu pengecualian berupa kilau radial `brandGlow` 1,03:1, dan pengecualian
/// itu dicabut: sebuah kilau yang kontrasnya 1,03:1 membeli nol rasio kontras
/// (teks di atasnya tetap harus lolos AA pada stop terburuknya), hilang sama
/// sekali di bawah matahari di gerbang pabrik, dan pada panel 6-bit yang umum
/// di Android murah satu-satunya penampakan yang bisa dijaminnya adalah
/// *banding*-nya.
///
/// Yang membuat kartu ini terbaca lebih dulu diukur, bukan dirasakan: angka
/// 44px lawan body 13,5px (3,26:1), rim brand yang menjadi satu-satunya garis
/// berwarna di seluruh halaman, dan posisinya sebagai blok pertama yang tidak
/// diperkenalkan judul bagian apa pun. Ketiganya geometri dan skala, jadi
/// ketiganya bertahan di bawah matahari, identik di kedua mode, dan berbiaya
/// nol per frame.
///
/// Yang membedakannya dari panel yang ia gantikan adalah tombolnya. Panel lama menggambar status, dua jam, dan sebuah tautan ke
/// riwayat — jadi layar pertama aplikasi absensi tidak punya satu pun cara untuk
/// mengabsen, dan setiap pagi dimulai dengan satu ketukan ke tab lain.
class TodayWorkCard extends StatefulWidget {
  const TodayWorkCard({
    super.key,
    required this.state,
    required this.shiftName,
    required this.scheduleIn,
    required this.scheduleOut,
    required this.timeIn,
    required this.timeOut,
    required this.lateMinutes,
    required this.nextPunch,
    required this.canClock,
    required this.dayContext,
    required this.error,
    required this.date,
    required this.onClock,
    required this.onSignIn,
    required this.onHistory,
    required this.onRetry,
  });

  final HomeTodayState state;
  final String? shiftName;
  final String? scheduleIn;
  final String? scheduleOut;
  final String? timeIn;
  final String? timeOut;

  /// Keterlambatan hari ini, sudah dihitung controller. `null` berarti tidak
  /// terlambat ATAU tidak bisa dihitung — dua hal yang di layar ini sama-sama
  /// berarti "tidak ada yang perlu dikatakan".
  final int? lateMinutes;

  /// Ketukan berikutnya, atau `null` bila tidak ada lagi yang diharapkan.
  final AttendancePunch? nextPunch;

  /// Apakah akun ini boleh mengabsen sama sekali. Keduanya milik server.
  final bool canClock;

  /// Konteks hari ini, bila server mengirimkannya. Dipakai HANYA untuk kalimat
  /// pada hari tanpa jadwal — izin mengabsen tidak pernah disimpulkan darinya.
  final DayContext? dayContext;

  /// Kegagalan yang tercatat pada panel absensi, bila ada.
  ///
  /// Dibawa MASUK ke dalam kartu alih-alih menggantikannya. Versi sebelumnya
  /// menukar seluruh panel dengan satu `AppInlineNotice` begitu keadaannya
  /// [HomeTodayState.unavailable], dan hasilnya adalah Beranda yang kehilangan
  /// jangkar visualnya persis pada saat sesuatu sedang salah: setelah kepala
  /// halaman langsung akses cepat, tanpa satu pun konteks tentang hari ini.
  final ApiException? error;

  /// Tanggal hari ini pada jam workspace, sudah diformat.
  ///
  /// Satu-satunya isi kartu yang tidak bergantung pada jaringan sama sekali,
  /// dan karena itu justru yang paling penting ketika jaringannya gagal: ia
  /// yang menjaga panel ini tetap menjawab "hari apa ini" walaupun tidak ada
  /// satu pun jam yang bisa digambar.
  final String? date;

  final VoidCallback onClock;

  /// Akhiri sesi dan bawa orangnya ke layar masuk. Satu-satunya jalan keluar
  /// dari sebuah kredensial yang sudah tidak berlaku.
  final VoidCallback onSignIn;
  final VoidCallback onHistory;
  final VoidCallback onRetry;

  @override
  State<TodayWorkCard> createState() => _TodayWorkCardState();
}

class _TodayWorkCardState extends State<TodayWorkCard> {
  Timer? _timer;

  /// Menit yang sedang tergambar. Detiknya berdenyut, menitnya tidak, jadi
  /// kartu hanya dibangun ulang ketika angkanya benar-benar berubah.
  int? _shownMinutes;

  bool get _isRunning => widget.state == HomeTodayState.working;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTimer();
  }

  @override
  void didUpdateWidget(covariant TodayWorkCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }

  /// Nyalakan pencacah hanya selama jam kerja berjalan DAN rute ini terlihat.
  ///
  /// `TickerMode` dimatikan Navigator untuk halaman yang tertutup halaman lain,
  /// jadi tidak ada `Timer` yang menyala di belakang pemindai QR.
  void _syncTimer() {
    final bool shouldRun = _isRunning && TickerMode.of(context);

    if (shouldRun && _timer == null) {
      _timer = Timer.periodic(AppDurations.tick, (_) {
        if (!mounted) return;

        if (_workedMinutes() != _shownMinutes) {
          setState(() {});
        }
      });
    } else if (!shouldRun && _timer != null) {
      _timer!.cancel();
      _timer = null;
    }
  }

  /// Menit kerja hari ini: sampai absen pulang, atau sampai sekarang.
  ///
  /// Penjumlahan hari lewat [HomeController.wrapMinutes] adalah shift malam:
  /// 22:00 sampai 06:00 menghasilkan -16 jam kalau kedua jam dianggap milik hari
  /// yang sama, dan itulah yang pernah tergambar di layar ini.
  int? _workedMinutes() {
    final int? start = HomeController.minutesOfDay(widget.timeIn);

    if (start == null) return null;

    final int? end = widget.timeOut == null
        ? HomeController.nowMinutes()
        : HomeController.minutesOfDay(widget.timeOut);

    if (end == null) return null;

    return HomeController.wrapMinutes(end - start);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;

    _shownMinutes = _workedMinutes();

    return _HeroSurface(
      tone: _status().$2.resolve(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _headline(theme, palette),
          ?_dateLine(theme, palette),
          ..._body(theme, palette),
        ],
      ),
    );
  }

  /// Baris pertama: penanda bagian, dan lencana keadaan di sisi kanan.
  ///
  /// Keadaan dibawa BENTUK lebih dulu (ikon di dalam lencana) baru warna, supaya
  /// ia tetap terbaca di bawah matahari gerbang pabrik dan oleh mata yang tidak
  /// membedakan merah dari hijau.
  Widget _headline(ThemeData theme, AppPalette palette) {
    final (String label, AppBadgeTone badgeTone, IconData icon) = _status();
    final AppTone tone = badgeTone.resolve(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: Text(
            'HARI INI',
            style: theme.textTheme.labelSmall?.copyWith(
              color: palette.textMuted,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        // Ikon dan teks bernada, BUKAN `AppBadge`. Sejak seluruh panel ini
        // memakai `tone.background` sebagai latarnya, sebuah lencana dengan
        // latar yang sama persis akan lenyap ke dalamnya dan hanya menyisakan
        // garis tepinya — dan sebuah lencana di atas bidang senada adalah
        // tautologi: bidangnya sudah menyatakan keadaannya.
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: AppIconSizes.sm, color: tone.foreground),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: tone.foreground,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Tanggal hari ini, di bawah penanda bagian.
  ///
  /// Satu-satunya baris di kartu ini yang tidak bergantung pada jaringan, dan
  /// karena itu justru yang paling berguna ketika jaringannya gagal: ia menjaga
  /// panel tetap menjawab "hari apa ini" walaupun tidak ada satu pun jam yang
  /// bisa digambar. Pada hari kerja normal ia dilewati — di sana jadwal dan jam
  /// sudah menjawab pertanyaan yang sama dengan lebih tepat, dan tanggalnya
  /// sudah ada di kepala halaman.
  Widget? _dateLine(ThemeData theme, AppPalette palette) {
    if (_isWorkingDay || widget.date == null) return null;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Text(
        widget.date!,
        style: theme.textTheme.bodySmall?.copyWith(color: palette.textMuted),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  /// Lencana keadaan: BENTUK lebih dulu, baru warna.
  ///
  /// Ikonnya sendiri sudah membedakan keempat keluarga keadaan tanpa satu pun
  /// warna terbaca — yang penting di bawah matahari gerbang pabrik dan bagi
  /// mata yang tidak membedakan merah dari hijau.
  (String, AppBadgeTone, IconData) _status() {
    if (widget.state == HomeTodayState.unavailable) {
      // Nadanya netral, bukan merah: sebuah panel yang belum bisa dimuat tidak
      // menuntut tindakan darurat dari karyawan, dan merah disimpan untuk hal
      // yang benar-benar rusak.
      return switch (homeFailureKindOf(widget.error)) {
        HomeFailureKind.notPermitted => (
          'Belum tersedia',
          AppBadgeTone.neutral,
          Icons.hourglass_empty_rounded,
        ),
        HomeFailureKind.sessionExpired => (
          'Perlu masuk ulang',
          AppBadgeTone.neutral,
          Icons.lock_outline_rounded,
        ),
        HomeFailureKind.network => (
          'Luring',
          AppBadgeTone.warning,
          Icons.wifi_off_rounded,
        ),
        HomeFailureKind.server => (
          'Gangguan server',
          AppBadgeTone.warning,
          Icons.cloud_off_rounded,
        ),
        HomeFailureKind.unknown => (
          'Belum tersedia',
          AppBadgeTone.neutral,
          Icons.hourglass_empty_rounded,
        ),
      };
    }

    return switch (widget.state) {
      HomeTodayState.loading => (
        'Memuat',
        AppBadgeTone.neutral,
        Icons.hourglass_top_rounded,
      ),
      HomeTodayState.unavailable => (
        'Belum tersedia',
        AppBadgeTone.neutral,
        Icons.hourglass_empty_rounded,
      ),
      HomeTodayState.attendanceDisabled => (
        'Tidak tersedia',
        AppBadgeTone.neutral,
        Icons.do_not_disturb_on_outlined,
      ),
      HomeTodayState.noSchedule => (
        'Tidak ada jadwal',
        AppBadgeTone.neutral,
        Icons.event_busy_rounded,
      ),
      HomeTodayState.dayOff => (
        'Hari libur',
        AppBadgeTone.neutral,
        Icons.weekend_outlined,
      ),
      HomeTodayState.holiday => (
        'Libur nasional',
        AppBadgeTone.info,
        Icons.flag_outlined,
      ),
      HomeTodayState.onLeave => (
        'Cuti disetujui',
        AppBadgeTone.info,
        Icons.beach_access_outlined,
      ),
      HomeTodayState.notClockedIn => (
        'Belum absen',
        AppBadgeTone.warning,
        Icons.radio_button_unchecked_rounded,
      ),
      HomeTodayState.working => (
        'Sedang bekerja',
        AppBadgeTone.success,
        Icons.play_arrow_rounded,
      ),
      HomeTodayState.done => (
        'Shift selesai',
        AppBadgeTone.info,
        Icons.done_all_rounded,
      ),
    };
  }

  List<Widget> _body(ThemeData theme, AppPalette palette) {
    // Hari kerja yang punya jam untuk digambar: angka protagonis, rel jadwal,
    // dua fakta jam, lalu ajakan. Ini bentuk TERKAYA kartu ini.
    if (_isWorkingDay) {
      return <Widget>[
        if (widget.shiftName != null) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          Text(
            widget.shiftName!,
            style: theme.textTheme.titleLarge,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        _protagonist(theme, palette),
        if (widget.scheduleIn != null &&
            widget.scheduleOut != null) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          ShiftTrack(
            scheduleIn: widget.scheduleIn!,
            scheduleOut: widget.scheduleOut!,
            timeIn: widget.timeIn,
            timeOut: widget.timeOut,
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        _facts(theme, palette),
        ..._action(theme),
      ];
    }

    // Setiap keadaan lain memakai anatomi yang SAMA — judul, kalimat penjelas,
    // aksi opsional — dan hanya isinya yang berganti. Itu yang membuat panel
    // ini tetap terbaca sebagai benda yang sama pada hari libur, pada akun yang
    // tidak boleh mengabsen, dan pada jaringan yang putus.
    final (String headline, String? detail) = _quietDay();

    return <Widget>[
      const SizedBox(height: AppSpacing.md),
      Text(headline, style: theme.textTheme.titleLarge),
      if (detail != null) ...<Widget>[
        const SizedBox(height: AppSpacing.xs),
        Text(
          detail,
          style: theme.textTheme.bodyMedium?.copyWith(color: palette.textMuted),
        ),
      ],
      // Kalau server ternyata TETAP mengharapkan sebuah ketukan hari ini —
      // misalnya seseorang yang dirosterkan pada hari raya — tombolnya tetap
      // muncul, karena izin mengabsen adalah aturan bisnis dan bukan kesimpulan
      // dari kalimat di atas.
      if (widget.canClock && widget.nextPunch != null)
        ..._action(theme)
      else ...<Widget>[
        const SizedBox(height: AppSpacing.md),
        ..._quietAction(),
      ],
    ];
  }

  /// Apakah hari ini punya cukup data untuk digambar sebagai hari kerja.
  bool get _isWorkingDay => switch (widget.state) {
    HomeTodayState.notClockedIn ||
    HomeTodayState.working ||
    HomeTodayState.done => true,
    _ => false,
  };

  /// Jalan keluar untuk keadaan yang tidak punya ajakan absen.
  ///
  /// Sebuah kapabilitas yang tidak diberikan tidak menawarkan apa pun: mencoba
  /// lagi akan ditolak lagi, dan masuk kembali tidak menambah izin. Tombol yang
  /// hanya bisa gagal lebih buruk daripada tidak ada tombol.
  List<Widget> _quietAction() {
    if (widget.state == HomeTodayState.unavailable) {
      return switch (homeErrorRemedyFor(widget.error)) {
        HomeErrorRemedy.signIn => <Widget>[
          _SecondaryAction(label: 'Masuk kembali', onTap: widget.onSignIn),
        ],
        HomeErrorRemedy.retry => <Widget>[
          _SecondaryAction(label: 'Coba lagi', onTap: widget.onRetry),
        ],
        HomeErrorRemedy.none => const <Widget>[],
      };
    }

    if (widget.state == HomeTodayState.attendanceDisabled) {
      return const <Widget>[];
    }

    return <Widget>[
      _SecondaryAction(label: 'Lihat riwayat absensi', onTap: widget.onHistory),
    ];
  }

  /// Judul dan kalimat penjelas untuk setiap keadaan yang bukan hari kerja.
  ///
  /// Bahasanya sengaja bukan bahasa sistem. "Fitur ini tidak tersedia untuk
  /// akun Anda" adalah kalimat yang ditulis dari sudut pandang server; Beranda
  /// sudah menyebut nama orangnya di kepala halaman dan tidak perlu menunjuknya
  /// lagi di setiap kalimat.
  (String, String?) _quietDay() {
    final DayContext? day = widget.dayContext;

    if (widget.state == HomeTodayState.attendanceDisabled) {
      return (
        'Absensi belum tersedia',
        'Fitur absensi belum aktif untuk akun ini.',
      );
    }

    if (widget.state == HomeTodayState.unavailable) {
      return switch (homeFailureKindOf(widget.error)) {
        // Tidak mengklaim apa pun tentang akun orangnya. Yang benar-benar
        // diketahui hanyalah bahwa permintaannya ditolak, dan penyebabnya ada
        // di sisi server — lihat [HomeFailureKind.notPermitted].
        HomeFailureKind.notPermitted => (
          'Absensi belum dapat dimuat',
          'Data absensi sedang tidak dapat diakses. Coba lagi sebentar lagi.',
        ),
        HomeFailureKind.sessionExpired => (
          'Sesi perlu diperbarui',
          'Masuk kembali untuk melanjutkan.',
        ),
        HomeFailureKind.network => (
          'Absensi belum dapat dimuat',
          'Periksa koneksi, lalu coba lagi.',
        ),
        HomeFailureKind.server => (
          'Absensi belum dapat dimuat',
          'Server sedang bermasalah. Coba lagi sebentar lagi.',
        ),
        HomeFailureKind.unknown => (
          'Absensi belum dapat dimuat',
          'Coba lagi sebentar lagi.',
        ),
      };
    }

    return switch (widget.state) {
      HomeTodayState.holiday => (
        day?.holidayName ?? day?.label ?? 'Hari libur nasional',
        'Tidak ada jadwal kerja hari ini.',
      ),
      HomeTodayState.dayOff => (
        day?.label ?? 'Hari libur',
        'Tidak ada jadwal kerja hari ini.',
      ),
      HomeTodayState.onLeave => (
        day?.label ?? 'Sedang cuti',
        'Cuti untuk hari ini sudah disetujui.',
      ),
      // Termasuk `loading`, yang tidak pernah sampai ke sini karena pemanggil
      // menggambar rangka — tetapi sebuah cabang yang jujur lebih baik daripada
      // sebuah `!` yang menunggu giliran.
      _ => (
        'Tidak ada jadwal kerja hari ini.',
        'Jadwal berikutnya akan muncul di sini.',
      ),
    };
  }

  /// Satu angka yang menjawab "saya ada di mana dalam hari kerja saya".
  ///
  /// Angka itu berbeda per keadaan, dan itulah gunanya: sebelum absen yang
  /// dicari adalah jam mulai, selama bekerja yang dicari adalah sudah berapa
  /// lama, sesudahnya yang dicari adalah totalnya.
  Widget _protagonist(ThemeData theme, AppPalette palette) {
    final double size = AppLayout.of(context).displaySize;
    final int? worked = _shownMinutes;

    final (String value, String caption) = switch (widget.state) {
      HomeTodayState.working => (
        worked == null ? '—' : HomeController.spanLabel(worked),
        'Durasi kerja berjalan',
      ),
      HomeTodayState.done => (
        worked == null ? '—' : HomeController.spanLabel(worked),
        'Total kerja hari ini',
      ),
      _ => (widget.scheduleIn ?? '—', 'Jam mulai kerja'),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // `scaleDown` dan bukan ukuran tetap: pada skala teks 1,5 di layar
        // 320dp sebuah angka 44px menjadi 66px dan tidak muat. Ia tetap
        // membesar mengikuti setelan pengguna sampai menyentuh lebar kolom,
        // lalu berhenti — mengecil lebih baik daripada terpotong.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: AppTypography.dataDisplay(
              color: theme.colorScheme.onSurface,
              fontSize: size,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          caption,
          style: theme.textTheme.bodySmall?.copyWith(color: palette.textMuted),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  /// Jam masuk dan jam pulang, dengan selisihnya terhadap jadwal.
  Widget _facts(ThemeData theme, AppPalette palette) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: _Fact(
            label: 'Masuk',
            value: widget.timeIn,
            note: widget.lateMinutes == null
                ? null
                : 'telat ${HomeController.spanLabel(widget.lateMinutes!)}',
            noteTone: palette.warning,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _Fact(
            label: 'Pulang',
            value: widget.timeOut,
            note: widget.timeOut == null && widget.scheduleOut != null
                ? 'jadwal ${widget.scheduleOut}'
                : null,
            noteTone: palette.neutral,
          ),
        ),
      ],
    );
  }

  /// Ajakan utama, yang berubah mengikuti ketukan berikutnya.
  ///
  /// Ia hilang seluruhnya ketika server mengatakan akun ini tidak boleh
  /// mengabsen, atau ketika tidak ada ketukan lagi yang diharapkan. Aturan UI
  /// README: sebuah tombol yang hanya bisa gagal lebih buruk daripada tidak ada
  /// tombol.
  List<Widget> _action(ThemeData theme) {
    final AttendancePunch? punch = widget.nextPunch;

    if (!widget.canClock) {
      return <Widget>[
        const SizedBox(height: AppSpacing.lg),
        _SecondaryAction(
          label: 'Lihat riwayat absensi',
          onTap: widget.onHistory,
        ),
      ];
    }

    if (punch == null) {
      return <Widget>[
        const SizedBox(height: AppSpacing.lg),
        _SecondaryAction(
          label: 'Lihat detail hari ini',
          onTap: widget.onHistory,
        ),
      ];
    }

    return <Widget>[
      const SizedBox(height: AppSpacing.xl),
      FilledButton.icon(
        onPressed: widget.onClock,
        icon: Icon(
          punch == AttendancePunch.clockIn
              ? Icons.login_rounded
              : Icons.logout_rounded,
          size: AppIconSizes.xl,
        ),
        label: Text(
          punch == AttendancePunch.clockIn ? 'Absen masuk' : 'Absen pulang',
        ),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
      ),
    ];
  }
}

/// Permukaan kartu protagonis: satu garis brand tembus pandang, dan tidak ada
/// yang lain.
///
/// Di sini pernah ada kilau radial 300dp di sudut kanan atas. Ia dibuang, dan
/// alasannya sama dengan alasan seluruh aplikasi ini menolak gradient, bayangan
/// dan glow tanpa pengecualian. Sebuah gradient yang memudar ke alpha nol
/// membeli NOL rasio kontras — setiap teks di atasnya tetap harus lolos AA pada
/// stop terburuknya, jadi kita tetap mendesain ke stop terburuk — sementara ia
/// menagih delta luminansi yang, pada panel 6-bit yang umum di Android murah,
/// satu-satunya penampakan yang bisa dijaminnya adalah *banding*-nya. Di mode
/// gelap ia nyaris nol piksel yang berubah, dan di bawah matahari di gerbang
/// pabrik ia benar-benar nol.
///
/// Yang memikul daya tarik kartu ini bukan luminansi melainkan geometri dan
/// skala: angka 44px lawan body 13,5px, rim brand yang menjadi satu-satunya
/// garis berwarna di halaman, dan posisinya sebagai blok pertama tanpa judul
/// bagian. Semuanya bertahan di bawah matahari, identik di kedua mode, dan
/// berbiaya nol per frame. Aturan ini ditegakkan mesin, bukan kesepakatan:
/// lihat `test/core/ui/no_gradient_test.dart`.
class _HeroSurface extends StatelessWidget {
  const _HeroSurface({required this.tone, required this.child});

  /// Nada keadaan absensi hari ini. Ia yang mewarnai seluruh bidang, bukan
  /// hanya lencana kecil di pojok.
  final AppTone tone;

  final Widget child;

  /// Lebar rel di tepi kiri.
  ///
  /// Empat piksel, dan itu satu-satunya tempat di aplikasi ini yang memakai
  /// warna nada pada saturasi penuh sebagai bidang. Pada tinggi kartu sekitar
  /// 240dp ia menghasilkan ~960 dp² warna pekat — lima belas kali luas titik
  /// status 8dp yang sebelumnya menjadi satu-satunya isyarat nada di layar —
  /// dan karena ia dibaca sebagai luminansi, ia tetap bekerja di greyscale dan
  /// bagi mata yang tidak membedakan merah dari hijau.
  static const double railWidth = 4;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        // Bidang bernada, bukan permukaan putih dengan garis hijau tipis.
        // Versi sebelumnya menaruh rim brand 32% alpha di sekeliling kartu
        // putih: sebuah garis rambut yang hilang di bawah matahari dan yang
        // membuat panel terpenting di layar terlihat persis seperti empat
        // kartu lain di bawahnya. Latar nada memberi panel ini luas warna
        // yang sepadan dengan kepentingannya, dan setiap nada sudah dirancang
        // untuk menyangga teks pada kontras AA — itulah gunanya AppTone punya
        // tiga warna dan bukan satu.
        color: tone.background,
        borderRadius: AppRadii.xxlAll,
        border: Border.all(color: tone.border),
      ),
      child: ClipRRect(
        borderRadius: AppRadii.xxlAll,
        child: Stack(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl + railWidth,
                AppSpacing.xl,
                AppSpacing.xl,
                AppSpacing.xl,
              ),
              child: child,
            ),
            // `Positioned` setinggi penuh, bukan `IntrinsicHeight` + `Row`:
            // relnya hanya perlu setinggi apa pun yang sudah diukur, dan
            // sebuah lintasan intrinsik untuk itu adalah ongkos yang dibayar
            // setiap frame demi hasil yang sama.
            Positioned(
              top: 0,
              bottom: 0,
              left: 0,
              width: railWidth,
              child: ColoredBox(color: tone.foreground),
            ),
          ],
        ),
      ),
    );
  }
}

/// Satu fakta jam: label kecil, jam tabular, dan catatan opsional.
class _Fact extends StatelessWidget {
  const _Fact({
    required this.label,
    required this.value,
    required this.note,
    required this.noteTone,
  });

  final String label;

  /// `null` digambar sebagai em dash. Ia berarti "belum", dan itu memang yang
  /// ingin diketahui orang.
  final String? value;

  final String? note;
  final AppTone noteTone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(color: palette.textMuted),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          value ?? '—',
          style: AppTypography.dataMedium(
            color: value == null
                ? palette.textMuted
                : theme.colorScheme.onSurface,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (note != null) ...<Widget>[
          const SizedBox(height: AppSpacing.xxs),
          Text(
            note!,
            style: theme.textTheme.labelMedium?.copyWith(
              color: noteTone.foreground,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}

/// Ajakan tingkat kedua: sebuah tautan, bukan sebuah tombol terisi.
class _SecondaryAction extends StatelessWidget {
  const _SecondaryAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: onTap,
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        ),
        icon: const Icon(Icons.arrow_forward_rounded, size: AppIconSizes.md),
        iconAlignment: IconAlignment.end,
        label: Text(label),
      ),
    );
  }
}

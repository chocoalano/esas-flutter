import 'package:esas/core/tenancy/workspace_clock.dart';
import 'package:esas/core/theme/app_dimens.dart';
import 'package:esas/core/theme/app_palette.dart';
import 'package:esas/core/theme/app_typography.dart';
import 'package:esas/core/ui/components/app_card.dart';
import 'package:esas/core/ui/components/app_empty_state.dart';
import 'package:esas/core/ui/components/app_badge.dart';
import 'package:esas/core/ui/components/app_day_strip.dart';
import 'package:esas/core/ui/components/app_error_state.dart';
import 'package:esas/core/ui/components/app_skeleton.dart';
import 'package:esas/core/ui/components/app_sparkline.dart';
import 'package:esas/features/attendance/data/models/attendance.dart';
import 'package:esas/features/attendance/data/models/attendance_month_totals.dart';
import 'package:esas/features/attendance/presentation/attendance_labels.dart';
import 'package:esas/features/attendance/presentation/routes/attendance_routes.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../controllers/attendance_list_controller.dart';
import '../widgets/attendance_detail_sheet.dart';
import '../widgets/attendance_list_item.dart';

/// Riwayat kehadiran sebagai ledger.
///
/// Tiga hal yang membedakannya dari daftar sebelumnya. Barisnya menyusut dari
/// 176dp menjadi sekitar 88dp, jadi satu layar memuat sekitar tujuh hari alih
/// alih empat. Setiap bulan mendapat header lengket berisi sparkline jam masuk
/// beserta ringkasan kalimatnya, sehingga pola "saya selalu telat hari Senin"
/// terbaca sebagai bentuk sebelum dibaca sebagai angka. Dan penyaring rentang
/// berhenti menjadi ikon di app bar saja: tiga preset satu ketukan duduk di
/// bawah kalimat rentang yang sedang berlaku.
///
/// Penyaring yang tidak terlihat adalah penyebab paling umum dari keluhan
/// "data saya hilang": daftar memang kosong, tetapi tidak ada yang memberi tahu
/// bahwa ia sedang disaring.
class AttendanceListView extends GetView<AttendanceListController> {
  const AttendanceListView({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Get.offAllNamed(AttendanceRoutes.attendance);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Kembali',
            onPressed: () => Get.offAllNamed(AttendanceRoutes.attendance),
          ),
          title: const Text('Riwayat absensi'),
          titleSpacing: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.tune_rounded),
              tooltip: 'Saring tanggal',
              onPressed: () => _pickRange(context),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
        ),
        body: Column(
          children: [
            _RangeStrip(onPickRange: () => _pickRange(context)),
            // `toList()`, bukan daftarnya langsung: menyerahkan `RxList` apa
            // adanya sebagai argumen tidak membaca observable apa pun, jadi
            // `Obx` melempar "improper use of a GetX" dan menggambar widget
            // galat di tempatnya. Menyalinnya membaca `length` dan `[]`, dan
            // keduanya melapor ke `Obx` seperti yang diharapkan.
            Obx(
              () => _SevenDayStrip(
                rows: controller.attendanceList.toList(),
                loading: controller.isLoading.value,
                range: controller.effectiveRange,
              ),
            ),
            Expanded(
              child: Obx(() {
                if (controller.isLoading.value &&
                    controller.attendanceList.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.only(top: AppSpacing.lg),
                    child: AppSkeletonList(count: 6),
                  );
                }

                // Cabang error mendahului cabang kosong. Kalau urutannya
                // terbalik, halaman pertama yang gagal dibaca sebagai riwayat
                // absensi yang tidak pernah ada.
                final String? error = controller.errorMessage.value;
                if (error != null && controller.attendanceList.isEmpty) {
                  return AppErrorState(
                    message: error,
                    onRetry: controller.refreshAttendance,
                  );
                }

                if (controller.attendanceList.isEmpty) {
                  // Dua kekosongan yang berbeda, dan hanya satu di antaranya
                  // punya jalan keluar. Kalimat lama menyebut "rentang tanggal
                  // ini" bahkan ketika tidak ada penyaring sama sekali, lalu
                  // menawarkan mengubah rentang yang tidak pernah dipasang —
                  // sebuah layar yang menyalahkan penyaring atas riwayat yang
                  // memang masih kosong.
                  final bool filtered =
                      controller.startDate.value != null &&
                      controller.endDate.value != null;

                  return AppEmptyState(
                    icon: filtered
                        ? Icons.filter_alt_off_outlined
                        : Icons.event_busy_outlined,
                    title: filtered
                        ? 'Tidak ada absensi pada periode ini'
                        : 'Belum ada absensi tercatat',
                    message: filtered
                        ? 'Coba periode lain, atau tampilkan seluruh riwayat.'
                        : 'Absensi Anda akan muncul di sini setelah tercatat '
                              'pertama kali.',
                    actionLabel: filtered ? 'Tampilkan semua tanggal' : null,
                    onAction: filtered
                        ? () => controller.applyDateRange(null, null)
                        : null,
                  );
                }

                return RefreshIndicator(
                  onRefresh: () => controller.refreshAttendance(),
                  child: _Ledger(
                    groups: _groupByMonth(controller.attendanceList),
                    totals: Map<DateTime, AttendanceMonthTotals>.of(
                      controller.monthTotals,
                    ),
                    scrollController: controller.scrollController,
                    footer: _Footer(
                      loadingMore: controller.isLoadMore.value,
                      error: controller.errorMessage.value,
                      exhausted: !controller.hasMore.value,
                      onRetry: controller.retryLoadMore,
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickRange(BuildContext context) async {
    // The workspace's today. Near midnight the handset's would offer a range
    // ending on a day the office has not reached, or refuse one it is already on.
    final now = WorkspaceClock.current.now();
    final today = DateTime(now.year, now.month, now.day);
    final initialStart =
        controller.startDate.value ?? today.subtract(const Duration(days: 30));
    final initialEnd = controller.endDate.value ?? today;

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023, 1, 1),
      lastDate: today,
      helpText: 'Pilih rentang tanggal',
      saveText: 'Terapkan',
      initialDateRange: DateTimeRange(
        start: DateTime(
          initialStart.year,
          initialStart.month,
          initialStart.day,
        ),
        end: DateTime(initialEnd.year, initialEnd.month, initialEnd.day),
      ),
    );

    if (picked != null) {
      await controller.applyDateRange(picked.start, picked.end);
    }
  }
}

/// Baris-baris satu bulan, beserta bulannya.
class _MonthGroup {
  _MonthGroup(this.month);

  /// Null untuk baris yang tanggalnya tidak terbaca.
  final DateTime? month;
  final List<Attendance> rows = <Attendance>[];
}

/// Mengelompokkan baris menurut bulan, mempertahankan urutan yang dikirim
/// server. Tidak menyortir ulang: urutan itu keputusan server, dan menyusunnya
/// ulang di klien akan menyembunyikan ketidakurutan yang justru perlu terlihat.
List<_MonthGroup> _groupByMonth(List<Attendance> rows) {
  final groups = <_MonthGroup>[];

  for (final row in rows) {
    final date = attendanceDate(row.datePresence);
    final DateTime? month = date == null
        ? null
        : DateTime(date.year, date.month);

    if (groups.isEmpty || groups.last.month != month) {
      groups.add(_MonthGroup(month));
    }

    groups.last.rows.add(row);
  }

  return groups;
}

/// Daftar bergulir dengan header bulan yang menempel di puncaknya.
class _Ledger extends StatelessWidget {
  const _Ledger({
    required this.groups,
    required this.totals,
    required this.scrollController,
    required this.footer,
  });

  final List<_MonthGroup> groups;

  /// What the server says each month adds up to, keyed by its first day.
  final Map<DateTime, AttendanceMonthTotals> totals;
  final ScrollController scrollController;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    final TextScaler scaler = MediaQuery.textScalerOf(context);

    // The pinned bar carries the month name and nothing else.
    //
    // It used to carry the month's figures too, and that is why it kept
    // overflowing: a `SliverPersistentHeader` reserves its height in advance,
    // so anything inside it that can wrap — and a row of metrics wraps as soon
    // as the screen narrows or the type grows — is a clipped header waiting to
    // happen. The figures now live in an ordinary sliver directly below, free
    // to take the height they need.
    //
    // What is left is one line, so its height follows the text scale exactly.
    final double headerExtent =
        AppSpacing.snug * 2 + scaler.scale(14) * 1.35 + 1;

    return CustomScrollView(
      controller: scrollController,
      slivers: [
        for (final group in groups)
          SliverMainAxisGroup(
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: _MonthHeaderDelegate(
                  extent: headerExtent,
                  title: group.month == null
                      ? 'Tanggal tidak tercatat'
                      : attendanceMonthLabel(group.month!),
                ),
              ),
              SliverToBoxAdapter(
                child: _MonthSummary(
                  metrics: _metrics(totals[group.month]),
                  summary: _summarise(totals[group.month]),
                  values: _clockInSeries(group.rows),
                  // The line is drawn from the rows in hand. It may only be
                  // shown once those rows ARE the month — see [_isComplete].
                  complete: _isComplete(group, totals[group.month]),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  AppSpacing.md,
                  AppSpacing.page,
                  0,
                ),
                sliver: SliverList.separated(
                  itemCount: group.rows.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, index) {
                    final attendance = group.rows[index];
                    return AttendanceListItem(
                      attendance: attendance,
                      onTap: () =>
                          showAttendanceDetailSheet(context, attendance),
                    );
                  },
                ),
              ),
            ],
          ),
        SliverToBoxAdapter(child: footer),
      ],
    );
  }

  /// Deret jam masuk sebulan, dari yang paling lama ke yang paling baru.
  /// `null` berarti hari itu tidak punya punch masuk, dan null MEMUTUS garis.
  static List<double?> _clockInSeries(List<Attendance> rows) {
    return <double?>[
      for (final row in rows.reversed)
        attendanceMinuteOfDay(row.timeIn)?.toDouble(),
    ];
  }

  /// Whether every row of this month is already loaded.
  ///
  /// The trend line is drawn from the rows the phone is holding, and the header
  /// above it names a month — so a line through the ten rows of page one under
  /// the words "September 2026" is a shape describing something else. The
  /// server's own count of the month is what makes the question answerable.
  static bool _isComplete(_MonthGroup group, AttendanceMonthTotals? totals) {
    if (totals == null) return false;

    return group.rows.length >= totals.recordedDays;
  }

  /// The month as figures — the server's, for the whole window it was asked
  /// about.
  ///
  /// Empty when the server sent nothing for this month, and empty means the
  /// panel does not draw. Counting the loaded rows instead is how a month of
  /// twenty-two attendances came to announce "10 hari tercatat": a heading that
  /// names a period above a number that describes a page.
  ///
  /// There is no attendance *rate* here and there will not be one on this
  /// screen. A percentage needs the days somebody was expected — the roster
  /// knows them and `GET /attendance/summary` now answers them — and what to do
  /// with that number is a product decision, not a layout one.
  static List<_Metric> _metrics(AttendanceMonthTotals? totals) {
    if (totals == null) return const <_Metric>[];

    return <_Metric>[
      _Metric(value: '${totals.recordedDays}', label: 'Hari tercatat'),
      if (totals.averageClockIn case final average?)
        _Metric(value: average, label: 'Rata-rata masuk'),
      if (totals.lateDays > 0)
        _Metric(value: '${totals.lateDays}', label: 'Terlambat'),
    ];
  }

  /// The sentence a screen reader hears in place of the trend line. A polyline
  /// must never be the only carrier of meaning.
  static String _summarise(AttendanceMonthTotals? totals) {
    if (totals == null) return '';

    final parts = <String>['${totals.recordedDays} hari tercatat'];

    if (totals.averageClockIn case final average?) {
      parts.add('rata-rata masuk $average');
    }

    if (totals.lateDays > 0) {
      parts.add('${totals.lateDays} terlambat');
    }

    return parts.join(' · ');
  }
}

class _MonthHeaderDelegate extends SliverPersistentHeaderDelegate {
  _MonthHeaderDelegate({required this.extent, required this.title});

  final double extent;
  final String title;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    final theme = Theme.of(context);
    final palette = theme.palette;

    // `SizedBox.expand`: sebuah header tersemat melaporkan `layoutExtent`
    // sebesar `maxExtent` tetapi `paintExtent` sebesar tinggi anaknya, dan
    // rangka kerja menegaskan bahwa yang pertama tidak boleh melebihi yang
    // kedua. Isinya setinggi teksnya — beberapa piksel lebih pendek daripada
    // `extent` yang sengaja dihitung longgar — jadi tanpa ini setiap pembukaan
    // riwayat absensi melempar galat rendering.
    return SizedBox.expand(
      child: Container(
        // Permukaan pekat, bukan tembus pandang: bar ini melintas di atas
        // baris-baris yang sedang bergulir di bawahnya.
        decoration: BoxDecoration(
          color: palette.surfaceSubtle,
          border: Border(bottom: BorderSide(color: palette.borderSubtle)),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.page,
          vertical: AppSpacing.snug,
        ),
        alignment: Alignment.centerLeft,
        child: Text(
          // Sentence case. A month is a label, not an announcement.
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onSurface,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _MonthHeaderDelegate oldDelegate) {
    return extent != oldDelegate.extent || title != oldDelegate.title;
  }
}

/// One month, as two or three numbers and — only when they mean something — a
/// shape.
///
/// ## What changed and why
///
/// It used to read `SEPTEMBER 2026` in caps above one grey sentence, with a
/// 96×24 sparkline pinned beside it. Three problems, all of them about claiming
/// more than the data supports:
///
/// * the caps eyebrow shouted a month name that nobody needs shouted;
/// * the sentence carried every fact at the same weight, so "2 hari" and
///   "rata-rata masuk 12:36" competed rather than one leading;
/// * the sparkline drew a line through two points, which is not a trend — it is
///   a line segment wearing a trend's clothes.
///
/// Now the numbers lead at display weight and the line appears only once there
/// are enough points for its shape to mean anything. The month name stays
/// pinned above; this panel scrolls, which is what lets it wrap freely at large
/// text scales instead of being clipped by a reserved height.
class _MonthSummary extends StatelessWidget {
  const _MonthSummary({
    required this.metrics,
    required this.summary,
    required this.values,
    required this.complete,
  });

  static const double sparklineHeight = 32;

  /// Below this a polyline is not a trend. Two points are a segment; three are
  /// the fewest that can change direction.
  static const int minimumTrendPoints = 4;

  final List<_Metric> metrics;

  /// The spoken summary — still the sparkline's accessible equivalent.
  final String summary;

  final List<double?> values;

  /// Whether the rows behind [values] are the whole month.
  final bool complete;

  bool get _showTrend =>
      complete && values.whereType<double>().length >= minimumTrendPoints;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;

    // Nothing the server vouched for, so nothing said. A deployment that does
    // not answer `summary` gets a bare month heading rather than three figures
    // counted off page one — a summary drawn from a fraction of the period it
    // names is worse than no summary at all.
    if (metrics.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.md,
        AppSpacing.page,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // `Row` berisi `Expanded`, bukan `Wrap`: sebuah `Wrap` memecah tiga
          // metrik menjadi satu, dua, atau tiga baris tergantung lebar
          // glifnya, jadi tinggi panel ini berubah-ubah tanpa alasan yang bisa
          // dilihat pembacanya. Kolom yang membagi rata selalu tiga kolom.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final metric in metrics)
                Expanded(child: _MetricTile(metric: metric)),
            ],
          ),
          if (_showTrend) ...[
            const SizedBox(height: AppSpacing.lg),
            // Diberi judul. Sebuah garis tanpa nama adalah dekorasi, dan
            // dekorasi berbentuk grafik adalah cara termudah sebuah layar
            // terlihat lebih tahu daripada yang sebenarnya.
            Text(
              'Pola jam masuk',
              style: theme.textTheme.labelSmall?.copyWith(
                color: palette.textMuted,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            // Selebar panelnya, bukan 88px di samping metrik: satu bulan yang
            // dimampatkan ke selebar ibu jari adalah bentuk yang tidak bisa
            // dibaca, dan bentuk yang tidak bisa dibaca tidak menjawab apa pun.
            AppSparkline(
              values: values,
              summary: summary,
              height: sparklineHeight,
            ),
          ],
        ],
      ),
    );
  }
}

/// One figure and the word for it.
class _Metric {
  const _Metric({required this.value, required this.label});

  final String value;
  final String label;
}

/// A number people can read across a room, and a label they read once.
///
/// The number carries the weight because it is the answer; the label only says
/// which question it answers.
class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.metric});

  final _Metric metric;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;

    return Semantics(
      label: '${metric.value} ${metric.label}',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              metric.value,
              style: AppTypography.dataLarge(
                color: theme.colorScheme.onSurface,
              ),
              maxLines: 1,
            ),
            const SizedBox(height: AppSpacing.xxs),
            // Dua baris, karena "Rata-rata masuk" pada 320dp dengan skala teks
            // 1,5 tidak muat dalam sepertiga lebar layar — dan sebuah label
            // yang dipotong menjadi "Rata-rata…" adalah angka tanpa
            // pertanyaannya.
            Text(
              metric.label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.textMuted,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Kaki daftar: kerangka saat memuat halaman berikutnya, tawaran coba lagi bila
/// halaman itu gagal, dan kalimat penutup bila memang sudah habis.
///
/// Yang digantikannya menghitung `itemCount` sebagai panjang daftar ditambah
/// satu HANYA saat `isLoadMore` bernilai true, lalu di dalam pembangunnya
/// memilih antara kerangka dan kalimat penutup berdasarkan `hasMore` — sehingga
/// cabang penutupnya tidak pernah bisa dijangkau sama sekali.
class _Footer extends StatelessWidget {
  const _Footer({
    required this.loadingMore,
    required this.error,
    required this.exhausted,
    required this.onRetry,
  });

  final bool loadingMore;
  final String? error;
  final bool exhausted;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;

    final Widget child;

    if (loadingMore) {
      child = const AppSkeletonRow(showLeading: false);
    } else if (error != null) {
      child = AppErrorState(
        title: 'Halaman berikutnya gagal dimuat',
        message: error!,
        onRetry: onRetry,
        compact: true,
      );
    } else if (exhausted) {
      child = Center(
        child: Text(
          'Semua data sudah ditampilkan',
          style: theme.textTheme.bodySmall?.copyWith(color: palette.textMuted),
        ),
      );
    } else {
      child = const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.lg,
        AppSpacing.page,
        AppSpacing.bottomSafe,
      ),
      child: child,
    );
  }
}

/// The recent days, as a row of cells and one sentence.
///
/// The first question somebody brings to an attendance history is not "what
/// happened on the 14th" but "how has this week gone". Answering it from the
/// ledger means reading seven cards and drawing the conclusion yourself; one
/// row answers it before they scroll.
///
/// ## What a cell is allowed to claim
///
/// The sentence under the strip is the whole of its accessible content —
/// `AppDayStrip` labels itself with it — so whatever it says is what a screen
/// reader user is told happened. That makes accuracy the entire design problem
/// here, and earlier versions got it wrong in five ways:
///
/// 1. **It spoke before it knew.** The strip sits above the branch that handles
///    loading, so a cold open rendered seven blank cells and the words "7 tanpa
///    catatan" while the list underneath was still a skeleton. It stated an
///    absence it had no evidence for.
/// 2. **It described a window it was not looking at.** The rows come from a
///    paginated, filterable list; the strip promised "seven days" while reading
///    whatever page one happened to hold. Filtering to last month emptied every
///    cell.
/// 3. **It counted leave as attendance.** `PERMIT`, `SICK` and `HOLIDAY` map to
///    the info tone, and the old tally sent every tone that was not late or
///    absent into "hadir" — so a week of sick leave read as a week present.
/// 4. **It used the handset's clock.** `attendanceIsToday`, two functions away,
///    uses `WorkspaceClock` precisely because the phone crosses midnight at a
///    different moment than the office that recorded the row.
/// 5. **It drew days the request never asked about.** It anchored on the
///    filter's end and then counted seven days back regardless of where the
///    filter *started* — and the unfiltered case sent no window at all, which
///    the endpoint answers with the current month. Both painted days that had
///    rows as days with none.
///
/// A blank cell now means one thing: a day inside the requested window with no
/// attendance row. Not loading, not outside the filter, not a different
/// timezone's idea of today.
///
/// The window is short enough that one page of the list always contains it:
/// `ux_user_attendances_user_day` allows one row per person per day, so seven
/// days is at most seven rows and a page is ten.
class _SevenDayStrip extends StatelessWidget {
  const _SevenDayStrip({
    required this.rows,
    required this.loading,
    required this.range,
  });

  final List<Attendance> rows;

  /// Whether the first page is still on its way.
  final bool loading;

  /// The window the request actually asked the server about.
  ///
  /// The strip follows it in **both** directions, and the second one was a bug.
  /// It anchored on the filter's end but always drew seven days back from
  /// there — so filtering to "Bulan ini" on the 3rd drew four days of the
  /// previous month, days the request had never asked for, as days with no
  /// attendance. They had rows. The screen simply had not been sent them.
  ///
  /// A day outside the window is not a day without a record, and the strip is
  /// now shorter rather than wrong.
  final ({DateTime start, DateTime end}) range;

  static const int _days = 7;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).palette;

    // Nothing is known yet. A skeleton holds the space without asserting
    // anything about it — the one thing the old version would not do.
    if (loading && rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.page,
          0,
          AppSpacing.page,
          AppSpacing.md,
        ),
        child: _StripSkeleton(),
      );
    }

    // Genuinely nothing to describe. The empty state below already says so, and
    // seven blank cells above it are noise that looks like data.
    if (rows.isEmpty) return const SizedBox.shrink();

    final DateTime today = _startOfDay(WorkspaceClock.current.now());
    // Never past today: a filter that runs to the end of the month should not
    // draw days that have not happened.
    final DateTime windowEnd = _startOfDay(range.end);
    final DateTime anchor = windowEnd.isAfter(today) ? today : windowEnd;

    // Never before the window's own start either.
    final DateTime windowStart = _startOfDay(range.start);
    final int span = anchor.difference(windowStart).inDays + 1;
    final int days = span < _days ? span : _days;

    if (days < 1) return const SizedBox.shrink();

    // Satu lintasan atas daftar, bukan tujuh pencarian: daftarnya bisa
    // sepanjang beberapa bulan setelah beberapa kali muat-lagi.
    final Map<String, Attendance> byDate = {};
    for (final row in rows) {
      final DateTime? date = attendanceDate(row.datePresence);
      if (date == null) continue;
      byDate.putIfAbsent(DateFormat('yyyy-MM-dd').format(date), () => row);
    }

    final DateFormat weekday = DateFormat('EEE', 'id');
    final DateFormat spoken = DateFormat('EEEE d MMMM', 'id');

    final List<AppTone> tones = [];
    final List<String> captions = [];
    final List<String> labels = [];
    final Map<AppBadgeTone, int> counted = {};
    int blank = 0;

    for (int offset = days - 1; offset >= 0; offset--) {
      final DateTime day = anchor.subtract(Duration(days: offset));
      final Attendance? row = byDate[DateFormat('yyyy-MM-dd').format(day)];

      captions.add(weekday.format(day));

      if (row == null) {
        tones.add(_blankTone(palette));
        labels.add('${spoken.format(day)}, ${_words[null]}');
        blank++;
        continue;
      }

      final AppBadgeTone tone = attendanceDayToneFor(
        statusIn: row.statusIn,
        statusOut: row.statusOut,
        hasSchedule: row.hasSchedule,
      );

      tones.add(tone.resolve(context));
      labels.add('${spoken.format(day)}, ${_words[tone] ?? 'tercatat'}');
      counted[tone] = (counted[tone] ?? 0) + 1;
    }

    final String summary = _summary(counted, blank, anchor, today, days);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        0,
        AppSpacing.page,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AppDayStrip(
            days: tones,
            summary: summary,
            dayCaptions: captions,
            dayLabels: labels,
            // The sentence is replaced below by the same counts carrying their
            // own swatch. It stays the strip's accessible label.
            showSummary: false,
          ),
          const SizedBox(height: AppSpacing.snug),
          _StripLegend(counted: counted, blank: blank),
        ],
      ),
    );
  }

  /// A day with no row: an empty outline, not a filled grey cell.
  ///
  /// The two used to look identical, and they are not the same claim. A filled
  /// cell says "something was recorded here and there is nothing to judge it
  /// against"; an empty one says "nothing was recorded". Drawn as presence and
  /// absence of fill rather than as two greys, so it survives a monochrome
  /// screen and a colour-blind reader.
  static AppTone _blankTone(AppPalette palette) => AppTone(
    foreground: palette.textMuted,
    background: Colors.transparent,
    border: palette.borderSubtle,
  );

  /// The word for each tone, used by both the legend and the spoken per-day
  /// label so the two can never drift apart.
  static const Map<AppBadgeTone?, String> _words = <AppBadgeTone?, String>{
    AppBadgeTone.success: 'hadir',
    AppBadgeTone.warning: 'terlambat',
    AppBadgeTone.info: 'izin',
    AppBadgeTone.danger: 'tidak hadir',
    // Recorded, on a day the roster expected nothing of. Not "hadir", because
    // nothing said they had to be.
    AppBadgeTone.neutral: 'tercatat',
    // "No record", not "absent". The two are different claims and only the
    // server knows which applies — a day off and a no-show look identical from
    // here until a row exists for it.
    null: 'tanpa catatan',
  };

  /// One sentence, and every word in it earned.
  ///
  /// Each kind of day is counted separately. Lumping them was how a week of
  /// sick leave came to read as a week present, and how one real absence plus
  /// two days the page had not loaded became "3 tanpa catatan".
  ///
  /// A tone this build cannot name is counted as nothing at all rather than
  /// guessed into the nearest bucket. The parts do not have to add up to seven —
  /// this is a description, not a ledger, and a wrong total is worse than a
  /// short one.
  static String _summary(
    Map<AppBadgeTone, int> counted,
    int blank,
    DateTime anchor,
    DateTime today,
    int days,
  ) {
    final List<String> parts = [
      for (final tone in const [
        AppBadgeTone.success,
        AppBadgeTone.warning,
        AppBadgeTone.info,
        AppBadgeTone.danger,
        AppBadgeTone.neutral,
      ])
        if ((counted[tone] ?? 0) > 0) '${counted[tone]} ${_words[tone]}',
      if (blank > 0) '$blank ${_words[null]}',
    ];

    // The window names its own length. A strip cut short by a narrow filter
    // that still called itself seven days would be describing days it never
    // drew.
    final String length = days == _days ? 'Tujuh' : '$days';

    final String window = anchor == today
        ? '$length hari terakhir'
        : '$length hari sampai ${DateFormat('d MMM', 'id').format(anchor)}';

    return parts.isEmpty ? window : '$window · ${parts.join(' · ')}';
  }

  static DateTime _startOfDay(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}

/// The counts, each wearing the colour it stands for.
///
/// This replaces the plain grey sentence that used to sit under the strip. The
/// sentence said "5 hadir · 1 terlambat" without ever saying *which* cell was
/// which, so the seven coloured blocks above it stayed a code the reader had to
/// break. A legend that is also the tally costs one row and closes that gap —
/// and it only lists what actually happened this week, so it can never claim a
/// category the data does not contain.
class _StripLegend extends StatelessWidget {
  const _StripLegend({required this.counted, required this.blank});

  final Map<AppBadgeTone, int> counted;
  final int blank;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;

    final List<Widget> entries = [
      for (final tone in const [
        AppBadgeTone.success,
        AppBadgeTone.warning,
        AppBadgeTone.info,
        AppBadgeTone.danger,
        AppBadgeTone.neutral,
      ])
        if ((counted[tone] ?? 0) > 0)
          _LegendEntry(
            tone: tone.resolve(context),
            text: '${counted[tone]} ${_SevenDayStrip._words[tone]}',
          ),
      if (blank > 0)
        _LegendEntry(
          tone: _SevenDayStrip._blankTone(palette),
          text: '$blank ${_SevenDayStrip._words[null]}',
        ),
    ];

    if (entries.isEmpty) return const SizedBox.shrink();

    // Sudah dibacakan sebagai label strip di atas; membacanya dua kali membuat
    // pembaca layar bertele-tele tanpa menambah satu fakta pun.
    return ExcludeSemantics(
      child: Wrap(
        spacing: AppSpacing.lg,
        runSpacing: AppSpacing.tight,
        children: entries,
      ),
    );
  }
}

class _LegendEntry extends StatelessWidget {
  const _LegendEntry({required this.tone, required this.text});

  final AppTone tone;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Bentuk kotak yang sama persis dengan sel di atasnya, isian dan garis
        // ikut — itulah yang membuatnya sebuah legenda dan bukan sekadar titik
        // berwarna di sebelah kata.
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: tone.background,
            borderRadius: AppRadii.smAll,
            border: Border.all(color: tone.border),
          ),
        ),
        const SizedBox(width: AppSpacing.tight),
        // `Flexible`: pada 320dp dengan skala teks 1,5 sebuah entri seperti
        // "1 tanpa catatan" melampaui lebar barisnya, dan sebuah `Text` yang
        // membungkus ke baris kedua mengambil seluruh lebar yang tersedia —
        // termasuk yang sudah dipakai kotak di sebelahnya.
        Flexible(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: palette.textMuted,
            ),
          ),
        ),
      ],
    );
  }
}

/// The strip's own loading state.
///
/// Seven blocks and a bar where the sentence goes. It holds exactly the height
/// the real strip will take, so nothing below it jumps when the data lands —
/// and it says nothing, which is the point.
class _StripSkeleton extends StatelessWidget {
  const _StripSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            const int count = _SevenDayStrip._days;
            const double gap = 3;
            final double cellWidth =
                (constraints.maxWidth - gap * (count - 1)) / count;

            return Row(
              children: [
                for (var index = 0; index < count; index++) ...[
                  if (index > 0) const SizedBox(width: gap),
                  AppSkeleton(width: cellWidth, height: 20),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        const AppSkeleton(width: 160, height: 12),
      ],
    );
  }
}

/// Periode yang sedang berlaku, dan cara-cara cepat menggantinya.
///
/// ## Dua cacat yang diperbaiki di sini
///
/// **Baris "Semua tanggal" adalah tawaran palsu.** Ia berisi ikon kalender dan
/// sebuah teks di atas latar bernada — bentuk yang persis sama dengan sebuah
/// tombol — dan tidak melakukan apa pun saat disentuh. Sekarang ia jelas-jelas
/// sebuah keterangan (label kecil di atas nilainya), dan pekerjaan yang dulu
/// seolah-olah ditawarkannya diberikan kepada chip "Semua" yang benar-benar
/// mengosongkan penyaring.
///
/// **Chip "Pilih tanggal" tidak pernah menyebut tanggal yang dipilih.** Ia
/// menyala saat sebuah rentang khusus aktif tetapi tetap berbunyi "Pilih
/// tanggal", sehingga satu-satunya tempat rentang itu tertulis adalah baris di
/// atas — dan chip yang menyala tanpa menyebut nilainya membuat orang mengetuk
/// ulang untuk memastikan. Kini ia menyebutkan rentangnya.
class _RangeStrip extends StatelessWidget {
  const _RangeStrip({required this.onPickRange});

  final VoidCallback onPickRange;

  static final DateFormat _long = DateFormat('d MMM yyyy', 'id');
  static final DateFormat _short = DateFormat('d MMM', 'id');

  /// "1 – 30 Sep 2026", dan "1 Sep – 3 Okt 2026" ketika rentangnya menyeberangi
  /// bulan. Tahun disebut sekali: dua kali adalah dua kali membaca angka yang
  /// sama.
  static String _rangeLabel(DateTime start, DateTime end) {
    if (start.year == end.year && start.month == end.month) {
      return '${start.day} – ${_long.format(end)}';
    }

    if (start.year == end.year) {
      return '${_short.format(start)} – ${_long.format(end)}';
    }

    return '${_long.format(start)} – ${_long.format(end)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;
    final controller = Get.find<AttendanceListController>();

    return Obx(() {
      final start = controller.startDate.value;
      final end = controller.endDate.value;
      final bool filtered = start != null && end != null;
      final AttendanceRangePreset? active = controller.activePreset;

      // The window the request actually carries, never a word standing in for
      // one. "Semua tanggal tercatat" was the caption while the endpoint was
      // answering with the current month, so on the 3rd of a month the screen
      // claimed everything and held three days.
      final range = controller.effectiveRange;
      final String value = _rangeLabel(range.start, range.end);

      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: palette.surfaceSubtle,
          border: Border(bottom: BorderSide(color: palette.borderSubtle)),
        ),
        padding: const EdgeInsets.only(
          top: AppSpacing.md,
          bottom: AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              child: Semantics(
                container: true,
                label: 'Periode $value',
                child: ExcludeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Periode',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: palette.textMuted,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        value,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.page,
                ),
                children: [
                  // Yang dulu hanya sebuah kalimat yang tampak bisa diketuk.
                  _PresetChip(
                    // Named for what it does: the endpoint caps a range at a
                    // year, so this is as far back as the screen can see.
                    label: '12 bulan',
                    selected: !filtered,
                    onTap: filtered
                        ? () => controller.applyDateRange(null, null)
                        : () {},
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  for (final preset in AttendanceRangePreset.values) ...[
                    _PresetChip(
                      label: preset.label,
                      selected: active == preset,
                      onTap: () => controller.togglePreset(preset),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  _PresetChip(
                    // Menyebut rentangnya sendiri saat ia yang sedang berlaku.
                    label: filtered && active == null
                        ? _rangeLabel(start, end)
                        : 'Pilih tanggal',
                    icon: Icons.edit_calendar_outlined,
                    selected: filtered && active == null,
                    onTap: onPickRange,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}

/// Satu preset rentang. Target sentuhnya 48dp penuh; sebuah chip penyaring yang
/// meleset adalah penyaring yang salah diterapkan.
class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: ExcludeSemantics(
        child: SizedBox(
          height: 48,
          child: AppCard(
            onTap: onTap,
            selected: selected,
            borderRadius: AppRadii.mdAll,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Center(
              widthFactor: 1,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(
                      icon,
                      size: AppIconSizes.sm,
                      color: selected
                          ? theme.colorScheme.primary
                          : palette.textMuted,
                    ),
                    const SizedBox(width: AppSpacing.tight),
                  ],
                  Text(
                    label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: selected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

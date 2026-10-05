import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../../core/tenancy/workspace_clock.dart';
import '../../../../core/ui/dialogs/app_snackbar.dart';
import '../../../../core/network/api_exception.dart';
import '../../data/models/attendance.dart';
import '../../data/models/attendance_month_totals.dart';
import '../../data/repositories/attendance_repository.dart';

/// Rentang tanggal siap pakai untuk ledger.
///
/// Ketiganya menutup hampir seluruh alasan orang membuka penyaring — dan
/// masing-masing satu ketukan, bukan sebuah dialog kalender dua langkah.
enum AttendanceRangePreset { thisMonth, last30Days, lastMonth }

extension AttendanceRangePresetLabel on AttendanceRangePreset {
  String get label => switch (this) {
    AttendanceRangePreset.thisMonth => 'Bulan ini',
    AttendanceRangePreset.last30Days => '30 hari terakhir',
    AttendanceRangePreset.lastMonth => 'Bulan lalu',
  };
}

class AttendanceListController extends GetxController {
  AttendanceListController({required AttendanceRepository repository})
    : _repository = repository;

  final AttendanceRepository _repository;

  static final _dateFormat = DateFormat('yyyy-MM-dd');

  final attendanceList = <Attendance>[].obs;
  final isLoading = false.obs;
  final isLoadMore = false.obs;
  final hasMore = true.obs;

  /// Kalimat kesalahan terakhir dari server.
  ///
  /// Sebelumnya kegagalan jaringan hanya menjadi toast tiga detik dan daftar
  /// kosong, jadi karyawan yang koneksinya putus diberi tahu bahwa ia tidak
  /// pernah absen. Di sebuah HRMS itu kebohongan yang bersinggungan dengan
  /// payroll, bukan kekurangan poles.
  final errorMessage = RxnString();

  final Rx<DateTime?> startDate = Rx<DateTime?>(null);
  final Rx<DateTime?> endDate = Rx<DateTime?>(null);

  /// What the server says each month in the window adds up to.
  ///
  /// Keyed by the month's first day. Empty until a first page answers, and
  /// empty forever against a deployment that does not send it — which is why
  /// every reader treats a missing month as "do not claim a figure" rather than
  /// as zero.
  final RxMap<DateTime, AttendanceMonthTotals> monthTotals =
      <DateTime, AttendanceMonthTotals>{}.obs;

  /// How far back the screen looks when nobody has chosen a range.
  ///
  /// Not "everything", and the word was the bug. The client sent no `from`/`to`
  /// at all, and the endpoint's default window is **the current month** — so on
  /// the 3rd of a month a screen captioned "Semua tanggal tercatat" held three
  /// days, and the seven-day strip drew the four days before the 1st as days
  /// with no attendance. They had rows; they were simply outside a window
  /// nobody had been told about. Saying "tanpa catatan" about them is exactly
  /// the claim this screen must never make.
  ///
  /// A year is the most the endpoint will answer — it caps an explicit range at
  /// `from.addYear()` — so this asks for precisely as much as can be had.
  static const int defaultWindowDays = 365;

  late final ScrollController scrollController;

  int _page = 1;
  static const int _perPage = 10;
  Timer? _debounce;

  @override
  void onInit() {
    super.onInit();
    scrollController = ScrollController()..addListener(_onScroll);
    refreshAttendance();
  }

  @override
  void onClose() {
    // Both were leaked by the previous controller: the listener was attached
    // and the debounce timer started, and neither was ever cancelled.
    _debounce?.cancel();
    scrollController.removeListener(_onScroll);
    scrollController.dispose();
    super.onClose();
  }

  void _onScroll() {
    if (!scrollController.hasClients || isLoadMore.value || !hasMore.value) {
      return;
    }

    final position = scrollController.position;

    if (position.pixels < position.maxScrollExtent * 0.9) {
      return;
    }

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), _loadMore);
  }

  Future<void> refreshAttendance() async {
    _page = 1;
    hasMore.value = true;
    isLoading.value = true;
    errorMessage.value = null;

    try {
      // Halaman pertama melaporkan kegagalannya di dalam halaman, bukan lewat
      // toast: layarnya kosong dan justru layar itu yang harus menjelaskan
      // dirinya sendiri.
      final rows = await _fetch(announce: false);
      attendanceList.assignAll(rows);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _loadMore() async {
    if (isLoadMore.value || !hasMore.value) {
      return;
    }

    isLoadMore.value = true;

    try {
      _page += 1;
      final rows = await _fetch(announce: true);
      attendanceList.addAll(rows);
    } finally {
      isLoadMore.value = false;
    }
  }

  Future<List<Attendance>> _fetch({required bool announce}) async {
    final range = effectiveRange;

    try {
      final page = await _repository.history(
        page: _page,
        perPage: _perPage,
        startDate: _dateFormat.format(range.start),
        endDate: _dateFormat.format(range.end),
      );

      // Only when the server actually sent them. Null means "later page" or
      // "older deployment", and both mean keep what is already held rather than
      // wipe the figures the header is drawn from.
      if (page.monthTotals case final totals?) {
        monthTotals
          ..clear()
          ..addEntries(
            totals.map(
              (entry) => MapEntry(
                DateTime(entry.month.year, entry.month.month),
                entry,
              ),
            ),
          );
      }

      hasMore.value = page.rows.length == _perPage;
      errorMessage.value = null;

      return page.rows;
    } on ApiException catch (error) {
      // `hasMore` sengaja tidak disetel false: halaman berikutnya belum tentu
      // tidak ada, ia hanya belum sampai. Yang berhenti adalah pemuatan
      // otomatis, karena kaki daftar kini menawarkan tombol coba lagi.
      errorMessage.value = error.message;

      if (announce) {
        showErrorSnackbar('Gagal memuat data absensi: ${error.message}');
      }

      return const [];
    }
  }

  /// Mengulang halaman yang barusan gagal.
  Future<void> retryLoadMore() async {
    if (isLoadMore.value) return;

    errorMessage.value = null;
    isLoadMore.value = true;

    try {
      final rows = await _fetch(announce: false);
      attendanceList.addAll(rows);
    } finally {
      isLoadMore.value = false;
    }
  }

  /// The window every request actually asks about.
  ///
  /// The chosen range when there is one, and otherwise the last
  /// [defaultWindowDays] days ending today — never "unspecified", because the
  /// endpoint answers an unspecified window with the current month and nothing
  /// on the screen said so.
  ///
  /// Both ends or neither, always: a half-open range would silently widen the
  /// query into whatever the server decided to default to.
  ({DateTime start, DateTime end}) get effectiveRange {
    final start = startDate.value;
    final end = endDate.value;

    if (start != null && end != null) {
      return (start: start, end: end);
    }

    final now = WorkspaceClock.current.now();
    final today = DateTime(now.year, now.month, now.day);

    return (
      start: today.subtract(const Duration(days: defaultWindowDays - 1)),
      end: today,
    );
  }

  /// Apply a range, or clear it when either end is missing.
  ///
  /// A reversed pair is swapped rather than sent. The picker cannot produce
  /// one, but nothing else stops a caller from passing one — and the endpoint
  /// answers a reversed range by clamping `to` up to `from`, which silently
  /// turns "3 to 21 August" into a single day. Swapping here means the caption
  /// above the list, the seven-day strip's anchor and the request all describe
  /// the same window.
  Future<void> applyDateRange(DateTime? start, DateTime? end) async {
    if (start != null && end != null && end.isBefore(start)) {
      startDate.value = end;
      endDate.value = start;
    } else {
      startDate.value = start;
      endDate.value = end;
    }

    await refreshAttendance();
  }

  /// Rentang yang diwakili sebuah preset, dihitung dari jam workspace.
  ({DateTime start, DateTime end}) rangeOf(AttendanceRangePreset preset) {
    final now = WorkspaceClock.current.now();
    final today = DateTime(now.year, now.month, now.day);

    return switch (preset) {
      AttendanceRangePreset.thisMonth => (
        start: DateTime(today.year, today.month, 1),
        end: today,
      ),
      AttendanceRangePreset.last30Days => (
        start: today.subtract(const Duration(days: 29)),
        end: today,
      ),
      AttendanceRangePreset.lastMonth => (
        start: DateTime(today.year, today.month - 1, 1),
        // Hari ke-0 bulan ini adalah hari terakhir bulan lalu, termasuk pada
        // Februari dan pada pergantian tahun.
        end: DateTime(today.year, today.month, 0),
      ),
    };
  }

  /// Preset yang sedang berlaku, bila rentang aktif kebetulan sama persis
  /// dengan salah satunya.
  AttendanceRangePreset? get activePreset {
    final start = startDate.value;
    final end = endDate.value;
    if (start == null || end == null) return null;

    for (final preset in AttendanceRangePreset.values) {
      final range = rangeOf(preset);
      if (_sameDay(range.start, start) && _sameDay(range.end, end)) {
        return preset;
      }
    }

    return null;
  }

  /// Menerapkan preset, atau melepasnya kembali ke seluruh tanggal bila preset
  /// yang sama diketuk dua kali.
  Future<void> togglePreset(AttendanceRangePreset preset) async {
    if (activePreset == preset) {
      return applyDateRange(null, null);
    }

    final range = rangeOf(preset);

    return applyDateRange(range.start, range.end);
  }

  static bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

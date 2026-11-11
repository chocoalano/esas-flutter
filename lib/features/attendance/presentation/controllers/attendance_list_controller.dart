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
    // An error stops the automatic loading (ATTP-03); the footer's retry is
    // the way on. Scrolling past a failure used to ask for the page after it.
    if (!scrollController.hasClients ||
        isLoadMore.value ||
        !hasMore.value ||
        errorMessage.value != null) {
      return;
    }

    final position = scrollController.position;

    if (position.pixels < position.maxScrollExtent * 0.9) {
      return;
    }

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), loadMore);
  }

  /// Bumped by every refresh, so an answer to an older filter is recognised
  /// and dropped without touching anything (ATTP-10).
  int _generation = 0;

  /// The range the list on screen belongs to.
  String? _loadedRange;

  String get _rangeKey {
    final range = effectiveRange;

    return '${_dateFormat.format(range.start)}..${_dateFormat.format(range.end)}';
  }

  Future<void> refreshAttendance() async {
    final generation = ++_generation;

    // A page queued for the old filter must not fire into the new one.
    _debounce?.cancel();

    // The page counter is wound back only when page 1 has arrived (UAT review
    // A4): a refresh that fails keeps the rows on screen, and those rows are
    // still the pages they were.
    hasMore.value = true;
    isLoading.value = true;
    errorMessage.value = null;

    try {
      // Halaman pertama melaporkan kegagalannya di dalam halaman, bukan lewat
      // toast: layarnya kosong dan justru layar itu yang harus menjelaskan
      // dirinya sendiri.
      final key = _rangeKey;
      final rows = await _fetch(
        page: 1,
        announce: false,
        generation: generation,
      );

      if (generation != _generation) return;

      if (rows == null) {
        // Rows of another range are not this range's history.
        if (_loadedRange != key) {
          attendanceList.clear();
          _page = 1;
        }
        return;
      }

      _loadedRange = key;
      _page = 1;
      attendanceList.assignAll(rows);
    } finally {
      if (generation == _generation) isLoading.value = false;
    }
  }

  Future<void> loadMore() async {
    if (isLoadMore.value ||
        !hasMore.value ||
        isLoading.value ||
        errorMessage.value != null) {
      return;
    }

    await _loadNextPage(announce: true);
  }

  /// The page after the last one that arrived. The counter moves only once
  /// it has (ATTP-03).
  Future<void> _loadNextPage({required bool announce}) async {
    final generation = _generation;

    isLoadMore.value = true;

    try {
      final rows = await _fetch(
        page: _page + 1,
        announce: announce,
        generation: generation,
      );

      if (generation != _generation || rows == null) return;

      _page += 1;
      attendanceList.addAll(rows);
    } finally {
      isLoadMore.value = false;
    }
  }

  /// One page, or null when it failed or belongs to a superseded filter.
  Future<List<Attendance>?> _fetch({
    required int page,
    required bool announce,
    required int generation,
  }) async {
    final range = effectiveRange;

    try {
      final result = await _repository.history(
        page: page,
        perPage: _perPage,
        startDate: _dateFormat.format(range.start),
        endDate: _dateFormat.format(range.end),
      );

      // Superseded while on its way: nothing of it is this filter's.
      if (generation != _generation) return null;

      // Only when the server actually sent them. Null means "later page" or
      // "older deployment", and both mean keep what is already held rather than
      // wipe the figures the header is drawn from.
      if (result.monthTotals case final totals?) {
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

      hasMore.value = result.rows.length == _perPage;
      errorMessage.value = null;

      return result.rows;
    } on ApiException catch (error) {
      if (generation != _generation) return null;

      // `hasMore` sengaja tidak disetel false: halaman berikutnya belum tentu
      // tidak ada, ia hanya belum sampai. Yang berhenti adalah pemuatan
      // otomatis, karena kaki daftar kini menawarkan tombol coba lagi.
      errorMessage.value = error.message;

      if (announce) {
        showErrorSnackbar('Gagal memuat data absensi: ${error.message}');
      }

      return null;
    }
  }

  Future<void> retryLoadMore() async {
    if (isLoadMore.value) return;

    errorMessage.value = null;
    await _loadNextPage(announce: false);
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
  Future<void> applyDateRange(DateTime? start, DateTime? end) =>
      _applyRange(start, end, preset: null);

  Future<void> _applyRange(
    DateTime? start,
    DateTime? end, {
    required AttendanceRangePreset? preset,
  }) async {
    _preset.value = start == null || end == null ? null : preset;

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

  /// Preset yang dipilih, persis seperti dipilih (ATTP-18).
  ///
  /// Bukan diturunkan dari tanggal: pada tanggal 30 "Bulan ini" dan "30 hari
  /// terakhir" adalah dua tanggal yang sama, sehingga chip yang menyala salah
  /// dan ketukan kedua tidak bisa melepasnya. Rentang kustom mengosongkannya.
  final Rxn<AttendanceRangePreset> _preset = Rxn<AttendanceRangePreset>();

  AttendanceRangePreset? get activePreset => _preset.value;

  /// Menerapkan preset, atau melepasnya kembali ke seluruh tanggal bila preset
  /// yang sama diketuk dua kali.
  Future<void> togglePreset(AttendanceRangePreset preset) async {
    if (activePreset == preset) {
      return applyDateRange(null, null);
    }

    final range = rangeOf(preset);

    return _applyRange(range.start, range.end, preset: preset);
  }
}

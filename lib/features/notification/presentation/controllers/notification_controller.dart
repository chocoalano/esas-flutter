import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../../core/ui/dialogs/app_snackbar.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/utils/app_logger.dart';
import '../../data/models/notification.dart';
import '../../../auth/data/repositories/session_repository.dart';
import '../../data/repositories/notification_repository.dart';

class NotificationController extends GetxController {
  NotificationController({
    required NotificationRepository repository,
    SessionRepository? session,
  }) : _repository = repository,
       _session = session;

  final NotificationRepository _repository;

  /// Tempat hitungan belum-dibaca diterbitkan supaya layar lain ikut tahu.
  ///
  /// Opsional karena harness uji membangun controller ini tanpa sesi. Ketika ia
  /// ada, setiap halaman yang sudah dibayar ikut memperbarui lencana di Beranda
  /// dan di bilah navigasi — tanpa satu pun permintaan tambahan.
  final SessionRepository? _session;

  final notifications = <NotificationModel>[].obs;
  final isLoading = false.obs;
  final isMoreLoading = false.obs;
  final hasMore = true.obs;

  /// Kalimat kegagalan halaman pertama, kosong bila tidak ada.
  ///
  /// Sebelumnya `_fetch` menangkap [ApiException] dan mengembalikan daftar
  /// kosong, jadi permintaan yang gagal disajikan kepada karyawan sebagai fakta
  /// bahwa ia tidak punya notifikasi. Kegagalan dan kekosongan adalah dua
  /// keadaan, dan layar hanya bisa membedakannya kalau controller-nya
  /// membedakannya lebih dulu.
  final RxnString errorMessage = RxnString();

  /// Hanya yang belum dibaca. Bendera ini sudah diterima api service sejak awal
  /// dan tidak pernah ada pemanggil yang mengirimnya.
  final RxBool unreadOnly = false.obs;

  /// Jumlah belum dibaca menurut server, `null` selama belum pernah dikirim.
  final RxnInt _serverUnread = RxnInt();

  late final ScrollController scrollController;

  int _page = 1;
  static const int _perPage = 10;

  /// Angka yang digambar lencana.
  ///
  /// Hitungan server dipakai bila ada, karena ia melihat seluruh kotak masuk;
  /// hitungan lokal hanya melihat halaman yang kebetulan sudah termuat, jadi ia
  /// selalu terlalu kecil dan tidak pernah terlalu besar.
  int get unreadCount => _serverUnread.value ?? _localUnread;

  /// Terbitkan hitungan yang baru diketahui ke sesi, supaya Beranda dan bilah
  /// navigasi memakainya tanpa memintanya sendiri.
  void _publishUnread(int? count) {
    _session?.noteUnreadNotifications(count);
  }

  int get _localUnread => notifications.where((n) => !n.isRead).length;

  @override
  void onInit() {
    super.onInit();
    scrollController = ScrollController()..addListener(_onScroll);
    refreshNotifications();
  }

  @override
  void onClose() {
    // The previous controller attached this listener and never removed it, and
    // never disposed the controller either.
    scrollController.removeListener(_onScroll);
    scrollController.dispose();
    super.onClose();
  }

  void _onScroll() {
    if (!scrollController.hasClients || isMoreLoading.value || !hasMore.value) {
      return;
    }

    final position = scrollController.position;

    if (position.pixels >= position.maxScrollExtent * 0.9) {
      _loadMore();
    }
  }

  Future<void> refreshNotifications() async {
    isLoading.value = true;
    errorMessage.value = null;
    _page = 1;
    hasMore.value = true;

    try {
      final page = await _fetch();

      if (page != null) {
        notifications.assignAll(page.rows);
      }
    } finally {
      isLoading.value = false;
    }
  }

  /// Menyaring ke yang belum dibaca, atau kembali ke seluruhnya.
  ///
  /// Selalu memuat ulang dari halaman pertama: menyaring di sisi klien hanya
  /// akan menyembunyikan baris yang sudah termuat dan berbohong tentang sisanya.
  Future<void> setUnreadOnly(bool value) async {
    if (unreadOnly.value == value) {
      return;
    }

    unreadOnly.value = value;
    await refreshNotifications();
  }

  Future<void> _loadMore() async {
    if (isMoreLoading.value || !hasMore.value) {
      return;
    }

    isMoreLoading.value = true;
    _page += 1;

    try {
      final page = await _fetch();

      if (page == null || page.rows.isEmpty) {
        // Do not strand the pager on a page that produced nothing.
        _page -= 1;
      } else {
        notifications.addAll(page.rows);
      }
    } finally {
      isMoreLoading.value = false;
    }
  }

  /// Satu halaman, atau `null` bila permintaannya ditolak.
  ///
  /// Halaman pertama yang gagal melaporkan dirinya lewat [errorMessage] dan
  /// layarnya menggambar keadaan gagal; halaman berikutnya yang gagal memakai
  /// snackbar, karena daftarnya sudah terlihat dan mengganti seluruh layar
  /// dengan pesan kesalahan akan membuang apa yang sedang dibaca orang.
  Future<NotificationPage?> _fetch() async {
    try {
      final page = await _repository.page(
        page: _page,
        perPage: _perPage,
        unreadOnly: unreadOnly.value,
      );

      hasMore.value = page.rows.length == _perPage;
      _serverUnread.value = page.unreadCount;
      _publishUnread(page.unreadCount);
      errorMessage.value = null;

      return page;
    } on ApiException catch (error) {
      hasMore.value = false;

      if (_page <= 1) {
        errorMessage.value = error.message;
      } else {
        showErrorSnackbar('Gagal memuat notifikasi: ${error.message}');
      }

      return null;
    }
  }

  /// Mark one as read, optimistically.
  ///
  /// The optimistic update rebuilt the whole model field by field at the call
  /// site; it is a `copyWith` now, so adding a field to the model can no longer
  /// silently drop it here.
  Future<void> markAsRead(String notificationId) async {
    final index = notifications.indexWhere((n) => n.id == notificationId);

    if (index == -1 || notifications[index].isRead) {
      return;
    }

    final original = notifications[index];
    final now = DateTime.now();
    final int? countBefore = _serverUnread.value;

    notifications[index] = original.copyWith(readAt: now, updatedAt: now);
    notifications.refresh();
    // Lencana ikut turun seketika. Angka server baru datang lagi pada
    // penyegaran berikutnya, dan sampai saat itu lencana yang tidak bergerak
    // setelah sebuah baris dibuka terbaca sebagai ketukan yang tidak terdaftar.
    if (countBefore != null) {
      _serverUnread.value = countBefore > 0 ? countBefore - 1 : 0;
      _publishUnread(_serverUnread.value);
    }

    try {
      await _repository.markAsRead(notificationId);
    } on ApiException catch (error) {
      notifications[index] = original;
      notifications.refresh();
      _serverUnread.value = countBefore;
      _publishUnread(countBefore);

      AppLogger.warning('Could not mark notification as read: ${error.status}');
      showErrorSnackbar(
        'Gagal menandai notifikasi sebagai sudah dibaca.',
        title: 'Gagal',
      );
    }
  }
}

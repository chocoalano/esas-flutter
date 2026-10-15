import 'package:esas/core/network/api_exception.dart';
import 'package:esas/features/home/data/repositories/home_repository.dart';
import 'package:esas/features/home/presentation/widgets/home_failure.dart';
import 'package:flutter_test/flutter_test.dart';

/// Bagaimana sebuah panel Beranda yang gagal memilih kalimat dan tombolnya.
///
/// Berkas ini menggantikan versi yang menguji pencocokan SUBSTRING bahasa
/// Indonesia. Pendekatan itu memang pernah menjadi satu-satunya bukti yang ada
/// — slot galat bertipe `String` dan statusnya dibuang sebelum sampai ke layar
/// — dan ia pecah pada tiga hal yang semuanya wajar terjadi: seseorang
/// memperbaiki tata bahasa sebuah pesan server, sebuah instalasi menjawab dalam
/// bahasa lain, dan sebuah backend menjawab 401 tanpa menyebut kata "sesi".
///
/// Sekarang yang dibaca adalah status HTTP, dan `401` adalah `401` di mana pun.
void main() {
  group('klasifikasi', () {
    test('permintaan yang tidak pernah sampai adalah kegagalan jaringan', () {
      // `status: null` adalah tanda transport gagal — tidak ada jawaban sama
      // sekali, bukan jawaban yang menolak.
      const error = ApiException(
        'Tidak ada koneksi internet.',
        code: 'network_unreachable',
      );

      expect(homeFailureKindOf(error), HomeFailureKind.network);
      expect(homeErrorRemedyFor(error), HomeErrorRemedy.retry);
    });

    test('401 adalah sesi berakhir, dan hanya masuk kembali menolongnya', () {
      const error = ApiException('apa pun kalimatnya', status: 401);

      expect(homeFailureKindOf(error), HomeFailureKind.sessionExpired);
      expect(homeErrorRemedyFor(error), HomeErrorRemedy.signIn);
    });

    test('401 dikenali walau kalimatnya tidak menyebut kata "sesi"', () {
      // Inilah kasus yang membuat pencocokan substring salah: kalimat server
      // yang benar-benar terkirim berbunyi "Sesi ini dibuat sebelum fitur
      // tersebut ada", dan tidak ada jaminan kalimat berikutnya menyebut apa
      // pun yang bisa dicocokkan.
      const error = ApiException('Token tidak dikenali.', status: 401);

      expect(homeErrorRemedyFor(error), HomeErrorRemedy.signIn);
    });

    test('403 menawarkan coba lagi, dan tidak pernah keluar dari sesi', () {
      // Sebabnya ada di server dan bisa berubah tanpa aplikasi dipasang ulang —
      // jadi jalan buntu adalah jawaban yang salah. Yang TIDAK ditawarkan
      // adalah "masuk kembali": mengeluarkan orang dari aplikasi untuk menebak
      // sebuah penolakan yang tidak dimengerti adalah kerusakan yang pasti demi
      // perbaikan yang belum tentu.
      const error = ApiException('Tidak diizinkan.', status: 403);

      expect(homeFailureKindOf(error), HomeFailureKind.notPermitted);
      expect(homeErrorRemedyFor(error), HomeErrorRemedy.retry);
    });

    test('perangkat yang diketahui belum terdaftar tidak diberi retry', () {
      const error = AttendanceAccessException(isRegisteredDevice: false);

      expect(homeFailureKindOf(error), HomeFailureKind.deviceNotRegistered);
      expect(homeErrorRemedyFor(error), HomeErrorRemedy.none);
    });

    test('izin sesi terbatas tidak disimpulkan sebagai perangkat salah', () {
      for (final registered in <bool?>[true, null]) {
        final error = AttendanceAccessException(isRegisteredDevice: registered);

        expect(
          homeFailureKindOf(error),
          HomeFailureKind.attendanceAccessRestricted,
        );
        expect(homeErrorRemedyFor(error), HomeErrorRemedy.none);
      }
    });

    test('5xx adalah kegagalan server dan boleh dicoba lagi', () {
      const error = ApiException('Kesalahan server.', status: 503);

      expect(homeFailureKindOf(error), HomeFailureKind.server);
      expect(homeErrorRemedyFor(error), HomeErrorRemedy.retry);
    });

    test('status lain jatuh ke tidak dikenal, bukan ke sesi berakhir', () {
      // Salah menebak "sesi berakhir" akan mengeluarkan orang dari aplikasi
      // karena sebuah 404.
      const error = ApiException('Tidak ditemukan.', status: 404);

      expect(homeFailureKindOf(error), HomeFailureKind.unknown);
      expect(homeErrorRemedyFor(error), HomeErrorRemedy.retry);
    });

    test('423 adalah workspace tidak aktif: tidak pernah keluar dari sesi', () {
      // Belum aktif, langganan berakhir, atau ditangguhkan: tokennya tetap
      // sah dan berlaku lagi begitu workspace aktif. Mengeluarkan orang dari
      // aplikasi karena keputusan komersial adalah kerusakan yang pasti.
      for (final (code, kind) in [
        (
          'tenant_activation_pending',
          WorkspaceUnavailability.activationPending,
        ),
        (
          'tenant_subscription_cancelled',
          WorkspaceUnavailability.subscriptionCancelled,
        ),
        ('tenant_suspended', WorkspaceUnavailability.suspended),
      ]) {
        final error = ApiException('Kalimat server.', status: 423, code: code);

        expect(homeFailureKindOf(error), HomeFailureKind.workspaceUnavailable);
        expect(error.workspaceUnavailability, kind);
        expect(error.isUnauthenticated, isFalse);
        expect(homeErrorRemedyFor(error), HomeErrorRemedy.retry);
      }
    });

    test('423 tanpa kode yang dikenal dibaca sebagai penangguhan', () {
      // Sebelum dua keadaan lainnya ada, penangguhan adalah satu-satunya
      // alasan sebuah workspace menjawab 423.
      const error = ApiException('Workspace ditangguhkan.', status: 423);

      expect(error.workspaceUnavailability, WorkspaceUnavailability.suspended);
    });

    test('bukan 423 tidak membawa keadaan workspace', () {
      const error = ApiException(
        'Tidak diizinkan.',
        status: 403,
        code: 'tenant_suspended',
      );

      expect(error.isWorkspaceUnavailable, isFalse);
      expect(error.workspaceUnavailability, isNull);
    });

    test('tanpa galat sama sekali tidak ada yang perlu diklasifikasikan', () {
      expect(homeFailureKindOf(null), HomeFailureKind.unknown);
      expect(homeErrorRemedyFor(null), HomeErrorRemedy.retry);
    });
  });
}

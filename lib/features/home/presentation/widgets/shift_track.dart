import 'package:esas/core/theme/app_dimens.dart';
import 'package:esas/core/theme/app_palette.dart';
import 'package:esas/core/theme/app_typography.dart';
import 'package:esas/features/home/presentation/controllers/home_controller.dart';
import 'package:flutter/material.dart';

/// Posisi hari kerja pada jadwalnya: `08:00 ─────●───── 17:00`.
///
/// Satu baris yang menjawab pertanyaan yang tidak dijawab dua jam berdampingan:
/// *seberapa jauh saya sudah berjalan*. Jam masuk dan jam pulang mengatakan
/// dua titik; yang dicari orang jam 13:00 adalah jarak di antaranya.
///
/// Ia menggambar dirinya HANYA dari jadwal yang benar-benar diketahui. Tanpa
/// `scheduleIn` dan `scheduleOut` tidak ada skala, dan sebuah bar tanpa skala
/// adalah dekorasi yang menyamar sebagai data — jadi pemanggilnya tidak
/// membangunnya sama sekali.
class ShiftTrack extends StatelessWidget {
  const ShiftTrack({
    super.key,
    required this.scheduleIn,
    required this.scheduleOut,
    required this.timeIn,
    required this.timeOut,
  });

  final String scheduleIn;
  final String scheduleOut;
  final String? timeIn;
  final String? timeOut;

  static const double _trackHeight = 6;
  static const double _markerSize = 14;

  /// Sejauh mana hari kerja sudah berjalan, 0 sampai 1.
  ///
  /// Titik acuannya adalah jam pulang bila sudah ada, dan "sekarang" bila belum.
  /// Keduanya dibawa [HomeController.wrapMinutes] supaya shift yang melewati
  /// tengah malam tidak menghasilkan panjang negatif.
  double? get _progress {
    final int? start = HomeController.minutesOfDay(scheduleIn);
    final int? end = HomeController.minutesOfDay(scheduleOut);

    if (start == null || end == null) return null;

    final int span = HomeController.wrapMinutes(end - start);

    // Jadwal yang mulai dan selesai pada menit yang sama tidak punya panjang,
    // dan pembagian dengan nol di sini akan menghasilkan NaN yang diam-diam
    // merusak `Align`.
    if (span == 0) return null;

    final int? nowRef = timeOut == null
        ? HomeController.nowMinutes()
        : HomeController.minutesOfDay(timeOut);

    if (nowRef == null) return null;

    final int elapsed = HomeController.wrapMinutes(nowRef - start);

    return (elapsed / span).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;
    final double? progress = _progress;

    final TextStyle capStyle = AppTypography.dataSmall(
      color: palette.textMuted,
    );

    return Semantics(
      // Bar ini tidak boleh menjadi satu-satunya pembawa informasinya: pembaca
      // layar mendapat kalimat, bukan sebuah persentase tanpa konteks.
      label: progress == null
          ? 'Jadwal $scheduleIn sampai $scheduleOut'
          : 'Jadwal $scheduleIn sampai $scheduleOut, '
                'berjalan ${(progress * 100).round()} persen',
      excludeSemantics: true,
      child: Row(
        children: <Widget>[
          Text(scheduleIn, style: capStyle, maxLines: 1),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: SizedBox(
              height: _markerSize,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final double width = constraints.maxWidth;

                  return Stack(
                    alignment: Alignment.centerLeft,
                    children: <Widget>[
                      // Palung. Selalu punya bentuk, juga ketika kosong.
                      Container(
                        height: _trackHeight,
                        decoration: BoxDecoration(
                          color: palette.trackSubtle,
                          borderRadius: AppRadii.pillAll,
                          border: Border.all(color: palette.borderSubtle),
                        ),
                      ),
                      if (progress != null) ...<Widget>[
                        Container(
                          height: _trackHeight,
                          width: width * progress,
                          decoration: BoxDecoration(
                            color: palette.brandAccent,
                            borderRadius: AppRadii.pillAll,
                          ),
                        ),
                        // Penanda dijepit ke dalam lebar palung supaya ia tidak
                        // menggantung setengah badan di luar tepi pada 0% dan
                        // 100%.
                        Positioned(
                          left: (width * progress - _markerSize / 2).clamp(
                            0.0,
                            width - _markerSize,
                          ),
                          child: Container(
                            width: _markerSize,
                            height: _markerSize,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: palette.brandAccent,
                                width: 3,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(scheduleOut, style: capStyle, maxLines: 1),
        ],
      ),
    );
  }
}

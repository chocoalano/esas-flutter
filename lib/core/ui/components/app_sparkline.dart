import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../theme/app_palette.dart';

/// Garis tren mini: sederet nilai yang dibaca sebagai bentuk, bukan sebagai
/// angka satu per satu.
///
/// Dilukis sendiri dengan [CustomPainter] dan tanpa pustaka grafik. Menarik
/// paket chart penuh — beberapa ratus kilobyte beserta pohon dependensinya —
/// untuk menggambar satu garis setinggi 26px pada ponsel kelas bawah adalah
/// kebalikan dari yang diinginkan bahasa visual ini.
///
/// Nilai `null` MEMUTUS garis, tidak diinterpolasi. Hari tanpa absen bukan hari
/// dengan jam masuk nol; menyambungkan garis melewatinya akan menggambar
/// penurunan tajam yang tidak pernah terjadi.
///
/// Grafik ini selalu [ExcludeSemantics] dan selalu membawa [summary]. Sebuah
/// polyline tidak bisa dibacakan, jadi ringkasan kalimatnyalah yang menjadi
/// simpul semantik — dan karena parameternya wajib, ia tidak bisa lupa ditulis.
/// Pemanggil tetap dianjurkan merender ringkasan yang sama sebagai teks yang
/// terlihat, supaya warna dan bentuk tidak menjadi pembawa makna tunggal.
class AppSparkline extends StatelessWidget {
  const AppSparkline({
    super.key,
    required this.values,
    required this.summary,
    this.height = 26,
    this.lineColor,
    this.baselineColor,
    this.pointColor,
  });

  /// Deret nilai dalam satuan aslinya; skalanya dihitung sendiri oleh pelukis.
  /// `null` berarti tidak ada data pada titik itu.
  final List<double?> values;

  /// Ringkasan kalimat untuk pembaca layar, misalnya
  /// "Rata-rata jam masuk 08:04, tiga hari terlambat".
  final String summary;

  final double height;
  final Color? lineColor;
  final Color? baselineColor;
  final Color? pointColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;

    return Semantics(
      container: true,
      label: summary,
      child: ExcludeSemantics(
        child: SizedBox(
          height: height,
          child: CustomPaint(
            // Lebar diambil dari induk; grafik ini memang untuk ditaruh di
            // dalam kolom kartu, bukan di dalam baris tanpa batas lebar.
            size: Size.infinite,
            painter: _SparklinePainter(
              values: values,
              line: lineColor ?? palette.dataInk,
              baseline: baselineColor ?? palette.trackSubtle,
              point: pointColor ?? palette.brandAccent,
            ),
          ),
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({
    required this.values,
    required this.line,
    required this.baseline,
    required this.point,
  }) : _fractions = _normalise(values);

  final List<double?> values;
  final Color line;
  final Color baseline;
  final Color point;

  /// Nilai yang sudah dipetakan ke rentang 0..1 saat pelukis dibuat. Melukis
  /// dari daftar yang sudah dihitung berarti setiap frame hanya memetakan
  /// pecahan ke piksel, bukan mencari ulang nilai terkecil dan terbesarnya.
  final List<double?> _fractions;

  static const double _stroke = 1.5;
  static const double _pointRadius = 3;

  static List<double?> _normalise(List<double?> values) {
    double? lowest;
    double? highest;
    for (final value in values) {
      if (value == null) continue;
      if (lowest == null || value < lowest) lowest = value;
      if (highest == null || value > highest) highest = value;
    }
    final low = lowest;
    final high = highest;
    if (low == null || high == null) {
      return List<double?>.filled(values.length, null);
    }
    final span = high - low;
    return <double?>[
      for (final value in values)
        if (value == null)
          null
        else if (span == 0)
          0.5
        else
          (value - low) / span,
    ];
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    // Garis dasar selalu digambar, termasuk saat tidak ada satu pun nilai:
    // palung yang kosong tetap harus punya bentuk supaya "belum ada data"
    // terbaca berbeda dari "komponennya gagal dirender".
    final basePaint = Paint()
      ..color = baseline
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final baseY = size.height - 0.5;
    canvas.drawLine(Offset(0, baseY), Offset(size.width, baseY), basePaint);

    final count = _fractions.length;
    if (count == 0) return;

    final top = _pointRadius;
    final bottom = size.height - _pointRadius - 1;
    if (bottom <= top) return;

    double dx(int index) {
      if (count == 1) return size.width / 2;
      final usable = size.width - _pointRadius * 2;
      return _pointRadius + usable * index / (count - 1);
    }

    double dy(double fraction) => bottom - fraction * (bottom - top);

    // Nilai null memutus deret menjadi beberapa potongan yang dilukis terpisah.
    final segments = <List<Offset>>[];
    var current = <Offset>[];
    for (var i = 0; i < count; i++) {
      final fraction = _fractions[i];
      if (fraction == null) {
        if (current.isNotEmpty) segments.add(current);
        current = <Offset>[];
        continue;
      }
      current.add(Offset(dx(i), dy(fraction)));
    }
    if (current.isNotEmpty) segments.add(current);
    if (segments.isEmpty) return;

    final linePaint = Paint()
      ..color = line
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final segment in segments) {
      if (segment.length == 1) {
        // Satu hari terjepit di antara dua hari kosong tetap harus terlihat.
        canvas.drawCircle(segment.first, _stroke, Paint()..color = line);
        continue;
      }
      final path = Path()..moveTo(segment.first.dx, segment.first.dy);
      for (final offset in segment.skip(1)) {
        path.lineTo(offset.dx, offset.dy);
      }
      canvas.drawPath(path, linePaint);
    }

    canvas.drawCircle(segments.last.last, _pointRadius, Paint()..color = point);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return line != oldDelegate.line ||
        baseline != oldDelegate.baseline ||
        point != oldDelegate.point ||
        !listEquals(values, oldDelegate.values);
  }
}

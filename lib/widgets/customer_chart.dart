
import 'package:flutter/material.dart';

import '../services/realtime_service.dart';

class CustomerChart extends StatelessWidget {
  const CustomerChart({super.key, this.maxValue = 40});

  /// Batas atas sumbu Y (biasanya kapasitas maksimal toko).
  final double maxValue;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<double>>(
      stream: RealtimeService().watchChartValues(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text('Gagal mengambil data grafik.'),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final values = snapshot.data ?? [];

        if (values.isEmpty) {
          return const Center(
            child: Text(
              'Belum ada data pengunjung untuk ditampilkan.',
              textAlign: TextAlign.center,
            ),
          );
        }

        return CustomPaint(
          painter: CustomerChartPainter(values: values, maxValue: maxValue),
          size: Size.infinite,
        );
      },
    );
  }
}

class CustomerChartPainter extends CustomPainter {
  final List<double> values;
  final double maxValue;

  const CustomerChartPainter({required this.values, this.maxValue = 40});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2 ||
        size.width <= 0 ||
        size.height <= 0) {
      return;
    }

    final gridPaint = Paint()
      ..color = Colors.grey.shade200
      ..strokeWidth = 1;

    final linePaint = Paint()
      ..color = const Color(0xFF1565C0)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final dotPaint = Paint()
      ..color = const Color(0xFF1565C0);

    const left = 10.0;
    const rightPadding = 10.0;
    const top = 10.0;
    const bottomPadding = 25.0;

    final right = size.width - rightPadding;
    final bottom = size.height - bottomPadding;

    for (var i = 0; i < 5; i++) {
      final y = top + (bottom - top) * i / 4;
      canvas.drawLine(
        Offset(left, y),
        Offset(right, y),
        gridPaint,
      );
    }

    final points = <Offset>[];

    for (var i = 0; i < values.length; i++) {
      final x =
          left + (right - left) * i / (values.length - 1);

      final normalizedValue =
          (values[i].clamp(0.0, maxValue)).toDouble();

      final y = bottom -
          (normalizedValue / maxValue) * (bottom - top);

      points.add(Offset(x, y));
    }

    final path = Path()
      ..moveTo(points.first.dx, points.first.dy);

    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    canvas.drawPath(path, linePaint);

    for (final point in points) {
      canvas.drawCircle(point, 5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(
    covariant CustomerChartPainter oldDelegate,
  ) {
    if (oldDelegate.maxValue != maxValue ||
        oldDelegate.values.length != values.length) {
      return true;
    }

    for (var i = 0; i < values.length; i++) {
      if (oldDelegate.values[i] != values[i]) {
        return true;
      }
    }

    return false;
  }
}

import 'package:flutter/material.dart';

class PolygonDrawPainter extends CustomPainter {
  final List<Offset> points;
  PolygonDrawPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    // Fill paint
    final fillPaint = Paint()
      ..color = Colors.blue.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    // Border paint
    final borderPaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    if (points.length >= 3) {
      final path = Path()..moveTo(points[0].dx, points[0].dy);
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      path.close();

      canvas.drawPath(path, fillPaint);
      canvas.drawPath(path, borderPaint);
    } else if (points.length >= 2) {
      final path = Path()..moveTo(points[0].dx, points[0].dy);
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }

      canvas.drawPath(path, borderPaint); // only border for incomplete shapes
    }

    // Draw points (black dots)
    for (final point in points) {
      canvas.drawCircle(point, 4, Paint()..color = Colors.black);
    }
  }

  @override
  bool shouldRepaint(covariant PolygonDrawPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}

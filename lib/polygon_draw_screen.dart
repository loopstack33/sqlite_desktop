import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'database_helper.dart';

class PolygonDrawScreen extends StatefulWidget {
  final int mapId;
  final String imagePath;

  const PolygonDrawScreen({
    super.key,
    required this.mapId,
    required this.imagePath,
  });

  @override
  State<PolygonDrawScreen> createState() => _PolygonDrawScreenState();
}

class _PolygonDrawScreenState extends State<PolygonDrawScreen> {
  List<Offset> points = [];

  @override
  void initState() {
    super.initState();
    _loadExistingPolygons();
  }

  void _loadExistingPolygons() {
    final loaded = DatabaseHelper.instance.getPolygonsForMap(widget.mapId);
    setState(() {
      points = loaded.isNotEmpty ? loaded.first : [];
    });
  }

  void _onTapDown(TapDownDetails details, Size imageSize) {
    final localPos = details.localPosition;

    final normalized = Offset(
      localPos.dx / imageSize.width,
      localPos.dy / imageSize.height,
    );

    setState(() {
      points.add(normalized);
    });
  }

  void _savePolygon(Size imageSize) {
    DatabaseHelper.instance.insertPolygon(widget.mapId, points);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Polygon saved")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final image = File(widget.imagePath);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Draw Polygon"),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () => _savePolygon(context.size ?? const Size(1, 1)),
          )
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return GestureDetector(
            onTapDown: (details) => _onTapDown(details, constraints.biggest),
            child: Stack(
              children: [
                Image.file(image, width: constraints.maxWidth, fit: BoxFit.contain),
                CustomPaint(
                  painter: PolygonPainter(points, constraints.biggest),
                  size: constraints.biggest,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class PolygonPainter extends CustomPainter {
  final List<Offset> normalizedPoints;
  final Size imageSize;

  PolygonPainter(this.normalizedPoints, this.imageSize);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final absPoints = normalizedPoints.map((pt) =>
        Offset(pt.dx * size.width, pt.dy * size.height)).toList();

    if (absPoints.length > 1) {
      canvas.drawPoints(ui.PointMode.polygon, absPoints, paint);
    }

    for (final pt in absPoints) {
      canvas.drawCircle(pt, 5, Paint()..color = Colors.blue);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}


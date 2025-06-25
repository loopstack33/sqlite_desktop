import 'dart:io';
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
  List<Map<String, dynamic>> allPolygons = [];
  List<Offset> currentPolygon = [];
  Size imageSize = const Size(1, 1);
  int? editingPolygonIndex;
  Offset? dragStart;
  int? draggingPointIndex;
  bool addingMode = false;
  int selectedStatus = 0;

  final TransformationController _transformationController = TransformationController();

  @override
  void initState() {
    super.initState();
    _loadPolygons();
  }

  void _loadPolygons() {
    final loaded = DatabaseHelper.instance.getPolygonsForMapWithStatus(widget.mapId);
    setState(() {
      allPolygons = loaded;
    });
  }

  bool _isInsideAnyPolygon(Offset point) {
    return allPolygons.any((poly) => _isPointInsidePolygon(point, poly['points']));
  }

  void _onTapDown(TapDownDetails details) {
    if (!addingMode) return;

    final localPos = _transformationController.toScene(details.localPosition);
    final normalized = Offset(
      localPos.dx / imageSize.width,
      localPos.dy / imageSize.height,
    );

    if (normalized.dx < 0 || normalized.dy < 0 || normalized.dx > 1 || normalized.dy > 1) return;

    if (editingPolygonIndex == null && _isInsideAnyPolygon(normalized)) return;

    setState(() {
      if (editingPolygonIndex != null) {
        allPolygons[editingPolygonIndex!]['points'].add(normalized);
      } else {
        currentPolygon.add(normalized);
      }
    });
  }

  void _saveCurrentPolygon() {
    if ((editingPolygonIndex == null && currentPolygon.length < 3) ||
        (editingPolygonIndex != null && allPolygons[editingPolygonIndex!]['points'].length < 3)) return;

    if (editingPolygonIndex != null) {
      DatabaseHelper.instance.updatePolygonWithStatus(widget.mapId, editingPolygonIndex!, allPolygons[editingPolygonIndex!]);
      editingPolygonIndex = null;
    } else {
      allPolygons.add({
        'points': List.of(currentPolygon),
        'status': selectedStatus,
      });
      DatabaseHelper.instance.insertPolygonWithStatus(widget.mapId, currentPolygon, selectedStatus);
      currentPolygon.clear();
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Polygon saved successfully!")),
    );

    Navigator.pop(context);
  }

  void _undoLastPoint() {
    setState(() {
      if (editingPolygonIndex != null && allPolygons[editingPolygonIndex!]['points'].isNotEmpty) {
        allPolygons[editingPolygonIndex!]['points'].removeLast();
      } else if (currentPolygon.isNotEmpty) {
        currentPolygon.removeLast();
      }
    });
  }

  void _deletePolygon(int index) {
    DatabaseHelper.instance.deletePolygon(widget.mapId, index);
    setState(() => allPolygons.removeAt(index));
    Navigator.pop(context);
  }

  void _showPolygonDetails(int index) {
    if (editingPolygonIndex != null) return;


    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Polygon Details"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButton<int>(
              value: allPolygons[index]['status'],
              items: const [
                DropdownMenuItem(value: 0, child: Text("Purchased")),
                DropdownMenuItem(value: 1, child: Text("Not Purchased")),
                DropdownMenuItem(value: 2, child: Text("Bayana")),
                DropdownMenuItem(value: 3, child: Text("Token")),
              ],
              onChanged: (val) {
                setState(() {
                  allPolygons[index]['status'] = val;
                  DatabaseHelper.instance.updatePolygonWithStatus(widget.mapId, index, allPolygons[index]);
                });
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              DatabaseHelper.instance.updatePolygonWithStatus(widget.mapId, index, allPolygons[index]);
              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
          TextButton(
            onPressed: () => _deletePolygon(index),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () {
              setState(() => editingPolygonIndex = index);
              Navigator.pop(context);
            },
            child: const Text("Edit"),
          ),
        ],
      ),
    );
  }

  bool _isPointInsidePolygon(Offset point, List<Offset> polygon) {
    int intersectCount = 0;
    for (int i = 0; i < polygon.length; i++) {
      final a = polygon[i];
      final b = polygon[(i + 1) % polygon.length];
      if (((a.dy > point.dy) != (b.dy > point.dy)) &&
          (point.dx < (b.dx - a.dx) * (point.dy - a.dy) / (b.dy - a.dy) + a.dx)) {
        intersectCount++;
      }
    }
    return intersectCount % 2 == 1;
  }

  void _onPanStart(DragStartDetails details) {
    if (editingPolygonIndex == null) return;

    final local = _transformationController.toScene(details.localPosition);
    final norm = Offset(local.dx / imageSize.width, local.dy / imageSize.height);

    final points = allPolygons[editingPolygonIndex!]['points'] as List<Offset>;
    for (int i = 0; i < points.length; i++) {
      final pt = points[i];
      if ((pt - norm).distance < 0.02) {
        draggingPointIndex = i;
        break;
      }
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (editingPolygonIndex == null || draggingPointIndex == null) return;

    final local = _transformationController.toScene(details.localPosition);
    final norm = Offset(local.dx / imageSize.width, local.dy / imageSize.height);

    if (norm.dx < 0 || norm.dy < 0 || norm.dx > 1 || norm.dy > 1) return;

    setState(() {
      allPolygons[editingPolygonIndex!]['points'][draggingPointIndex!] = norm;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    draggingPointIndex = null;
  }

  void _onPolygonTap(TapUpDetails details) {
    if (editingPolygonIndex != null) return;

    final localTap = _transformationController.toScene(details.localPosition);
    final normalizedTap = Offset(
      localTap.dx / imageSize.width,
      localTap.dy / imageSize.height,
    );

    for (int i = 0; i < allPolygons.length; i++) {
      if (_isPointInsidePolygon(normalizedTap, allPolygons[i]['points'])) {
        _showPolygonDetails(i);
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageFile = File(widget.imagePath);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Draw & Manage Polygons"),
        actions: [
          DropdownButton<int>(
            value: selectedStatus,
            icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
            dropdownColor: Colors.white,
            underline: Container(),
            onChanged: (val) => setState(() => selectedStatus = val ?? 0),
            items: const [
              DropdownMenuItem(value: 0, child: Text("Purchased")),
              DropdownMenuItem(value: 1, child: Text("Not Purchased")),
              DropdownMenuItem(value: 2, child: Text("Bayana")),
              DropdownMenuItem(value: 3, child: Text("Token")),
            ],
          ),
          IconButton(
            icon: Icon(addingMode ? Icons.pan_tool : Icons.add),
            onPressed: () => setState(() => addingMode = !addingMode),
            tooltip: addingMode ? "Pan Mode" : "Add Polygon",
          ),
          if (editingPolygonIndex != null)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() => editingPolygonIndex = null),
            ),
          IconButton(icon: const Icon(Icons.undo), onPressed: _undoLastPoint),
          IconButton(icon: const Icon(Icons.save), onPressed: _saveCurrentPolygon),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          imageSize = Size(constraints.maxWidth, constraints.maxHeight);

          return GestureDetector(
            onTapDown: _onTapDown,
            onTapUp: _onPolygonTap,
            onPanStart: _onPanStart,
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            child: InteractiveViewer(
              transformationController: _transformationController,
              minScale: 1.0,
              maxScale: 5.0,
              panEnabled: editingPolygonIndex == null,
              scaleEnabled: editingPolygonIndex == null,
              child: Stack(
                children: [
                  Image.file(imageFile, width: imageSize.width, fit: BoxFit.contain),
                  CustomPaint(
                    painter: MultiPolygonPainter(allPolygons, currentPolygon, imageSize, editingPolygonIndex),
                    size: imageSize,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class MultiPolygonPainter extends CustomPainter {
  final List<Map<String, dynamic>> polygons;
  final List<Offset> currentPolygon;
  final Size imageSize;
  final int? editingIndex;

  MultiPolygonPainter(this.polygons, this.currentPolygon, this.imageSize, this.editingIndex);

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < polygons.length; i++) {
      final poly = polygons[i];
      final points = (poly['points'] as List<Offset>).map((p) => Offset(p.dx * size.width, p.dy * size.height)).toList();
      final color = [Colors.green, Colors.red, Colors.blue, Colors.yellow][poly['status'] ?? 0];

      if (points.length > 2) {
        final path = Path()..addPolygon(points, true);
        canvas.drawPath(path, Paint()..color = color.withOpacity(0.3));
        canvas.drawPath(path, Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);

      }

      for (var p in points) {
        canvas.drawCircle(p, 4, Paint()..color = color);
      }
    }

    if (currentPolygon.isNotEmpty) {
      final points = currentPolygon.map((p) => Offset(p.dx * size.width, p.dy * size.height)).toList();
      final path = Path()..addPolygon(points, false);
      canvas.drawPath(path, Paint()
        ..color = Colors.grey
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2);
      for (var p in points) {
        canvas.drawCircle(p, 4, Paint()..color = Colors.orange);
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}






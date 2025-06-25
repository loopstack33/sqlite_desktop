import 'dart:io';
import 'package:desktop/polygon_draw_new.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'database_helper.dart';

class MapPickerScreen extends StatefulWidget {
  const MapPickerScreen({super.key});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  List<Map<String, dynamic>> maps = [];

  @override
  void initState() {
    super.initState();
    DatabaseHelper.instance.init().then((_) => _loadMaps());
  }

  void _loadMaps() {
    final result = DatabaseHelper.instance.getAllMaps();
    setState(() {
      maps = result;
    });
  }

  Future<void> _pickMapImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);

    if (result != null) {
      final originalPath = result.files.single.path!;
      final fileName = p.basename(originalPath);

      final dir = await getApplicationDocumentsDirectory();
      final copiedPath = p.join(dir.path, 'maps', fileName);

      // Ensure directory exists
      await Directory(p.dirname(copiedPath)).create(recursive: true);
      await File(originalPath).copy(copiedPath);

      final mapId = DatabaseHelper.instance.insertMap(fileName, copiedPath);
      _loadMaps();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Map Polygon Marker")),
      floatingActionButton: FloatingActionButton(
        onPressed: _pickMapImage,
        child: const Icon(Icons.add),
      ),
      body: ListView.builder(
        itemCount: maps.length,
        itemBuilder: (context, index) {
          final map = maps[index];
          return ListTile(
            leading: Image.file(File(map['image_path']), width: 60, fit: BoxFit.cover),
            title: Text(map['name']),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PolygonDrawScreen(mapId: map['id'], imagePath: map['image_path']),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

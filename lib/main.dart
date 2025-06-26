import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:desktop/db_helper_new.dart';
import 'package:desktop/import_export_screen.dart';
import 'package:desktop/map_page.dart';
import 'package:desktop/map_picker_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'database_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // await DatabaseHelper.instance.init();
  await DbHelper.instance.init();
  await Geolocator.requestPermission();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: HomeScreen()
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ExcelToDataTable()),
                );
              },
              child: const Text('Table Screen'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MapPickerScreen()),
                );
              },
              child: const Text('Map Screen'),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: Icon(Icons.restore),
              label: Text("Flutter Map"),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MapPage()),
                );
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => backupToZip(context),
              icon: Icon(Icons.backup),
              label: Text("Backup Data"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> backupToZip(BuildContext context) async {
    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        title: Text('Backing up...'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Please wait while we create the backup.'),
          ],
        ),
      ),
    );

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final backupDir = Directory(p.join(appDir.path, 'backup'));
      if (!backupDir.existsSync()) {
        backupDir.createSync(recursive: true);
      }

      final dbFile = File(p.join(appDir.path, 'employee_data.db'));
      final mapsDir = Directory(p.join(appDir.path, 'maps'));

      String? selectedPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Backup File',
        fileName: 'backup.zip',
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );

      if (selectedPath == null) {
        Navigator.pop(context);
        return; // User cancelled
      }

      // Create zip directly at user-chosen location
      final encoder = ZipFileEncoder();
      encoder.create(selectedPath);

      // Add database
      if (await dbFile.exists()) {
        encoder.addFile(dbFile);
      }

      // Add maps directory
      if (await mapsDir.exists()) {
        encoder.addDirectory(mapsDir);
      }

      encoder.close();

      Navigator.pop(context); // Close progress dialog

      // Show success
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Backup completed successfully!")),
      );
    } catch (e) {
      Navigator.pop(context); // Close progress dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Backup failed: $e")),
      );
    }
  }

  Future<void> restoreFromZip(BuildContext context) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );

    if (picked == null || picked.files.single.path == null) return;

    final zipFile = File(picked.files.single.path!);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        title: Text('Restoring backup...'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Please wait while we restore your data...'),
          ],
        ),
      ),
    );


    final appDir = await getApplicationDocumentsDirectory();

    final tempDir = Directory(p.join(appDir.path, 'backup'));

    // Clean or create temp restore dir
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    tempDir.createSync(recursive: true);

    // Extract ZIP contents
    final archive = ZipDecoder().decodeBytes(zipFile.readAsBytesSync());
    for (final file in archive) {
      final outPath = p.join(tempDir.path, file.name);
      if (file.isFile) {
        File(outPath)
          ..createSync(recursive: true)
          ..writeAsBytesSync(file.content as List<int>);
      } else {
        Directory(outPath).createSync(recursive: true);
      }
    }

    // If extracted folder contains a single directory like 'backup_xxx', go inside it
    final extractedContent = tempDir.listSync();
    late Directory workingDir;

    if (extractedContent.length == 1 && extractedContent.first is Directory) {
      workingDir = extractedContent.first as Directory;
    } else {
      workingDir = tempDir;
    }

    // STEP 1: Replace maps folder
    final restoredMapsDir = Directory(p.join(workingDir.path, 'maps'));
    final targetMapsDir = Directory(p.join(appDir.path, 'maps'));

    print(restoredMapsDir);
    print(targetMapsDir);

    if (restoredMapsDir.existsSync()) {
      if (targetMapsDir.existsSync()) {
        targetMapsDir.deleteSync(recursive: true);
      }

      copyDirectory(restoredMapsDir, targetMapsDir);
    }

    // STEP 2: Replace employee_data.db
    final restoredDb = File(p.join(workingDir.path, 'employee_data.db'));
    final targetDb = File(p.join(appDir.path, 'employee_data.db'));

    if (restoredDb.existsSync()) {
      // Fully close DB
      DatabaseHelper.instance.close(); // will close if open

      // Ensure the DB file is released before trying to delete
      await Future.delayed(const Duration(seconds: 10));

      if (targetDb.existsSync()) {
        try {
          targetDb.deleteSync();
        } catch (e) {
          print(e);
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("❌ Failed to delete existing DB: $e")),
          );
          return;
        }
      }
      restoredDb.copySync(targetDb.path);
    } else {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ No database file found in backup.')),
      );
      return;
    }

    // STEP 3: Re-initialize the database
    await DatabaseHelper.instance.reinit();

    // STEP 4: Cleanup
    tempDir.deleteSync(recursive: true);

    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("✅ Restore completed successfully!")),
    );
  }

  void copyDirectory(Directory source, Directory destination) {
    for (var entity in source.listSync(recursive: true)) {
      final relativePath = p.relative(entity.path, from: source.path);
      final newPath = p.join(destination.path, relativePath);

      if (entity is File) {
        File(newPath).createSync(recursive: true);
        entity.copySync(newPath);
      } else if (entity is Directory) {
        Directory(newPath).createSync(recursive: true);
      }
    }
  }


}




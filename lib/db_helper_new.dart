import 'dart:io';
import 'dart:convert';
import 'dart:ui';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

class DbHelper {
  static final DbHelper instance = DbHelper._internal();
  DbHelper._internal();

  late Database db;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'map_data.db');
    db = sqlite3.open(dbPath);
    _initialized = true;

    // Villages Table
    db.execute('''
      CREATE TABLE IF NOT EXISTS villages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        points TEXT,
        status INTEGER
      );
    ''');

    // Lands Table
    db.execute('''
      CREATE TABLE IF NOT EXISTS lands (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        village_id INTEGER,
        name TEXT,
        points TEXT,
        status INTEGER,
        FOREIGN KEY(village_id) REFERENCES villages(id) ON DELETE CASCADE
      );
    ''');
  }

  Future<void> reinit() async {
    close();
    await init();
  }

  void close() {
    if (_initialized) {
      db.dispose();
      _initialized = false;
    }
  }

  // ---------------- VILLAGES ----------------
  int insertVillage({
    required String name,
    required List<Offset> points,
    required int status,
  }) {
    final jsonPoints = jsonEncode(points.map((p) => {'x': p.dx, 'y': p.dy}).toList());
    db.execute(
      'INSERT INTO villages (name, points, status) VALUES (?, ?, ?)',
      [name, jsonPoints, status],
    );
    return db.lastInsertRowId;
  }

  void updateVillage(int villageId, String name, List<Offset> points, int status) {
    final jsonPoints = jsonEncode(points.map((p) => {'x': p.dx, 'y': p.dy}).toList());
    db.execute(
      'UPDATE villages SET name = ?, points = ?, status = ? WHERE id = ?',
      [name, jsonPoints, status, villageId],
    );
  }

  void deleteVillage(int villageId) {
    db.execute('DELETE FROM villages WHERE id = ?', [villageId]);
  }

  List<Map<String, dynamic>> getAllVillages() {
    final result = db.select('SELECT * FROM villages');
    return result.map((row) => {
      'id': row['id'],
      'name': row['name'],
      'points': jsonDecode(row['points'] as String)
          .map<Offset>((pt) => Offset(pt['x'].toDouble(), pt['y'].toDouble()))
          .toList(),
      'status': row['status'],
    }).toList();
  }

  // ---------------- LANDS ----------------
  int insertLand({
    required int villageId,
    required String name,
    required List<Offset> points,
    required int status,
  }) {
    final jsonPoints = jsonEncode(points.map((p) => {'x': p.dx, 'y': p.dy}).toList());
    db.execute(
      'INSERT INTO lands (village_id, name, points, status) VALUES (?, ?, ?, ?)',
      [villageId, name, jsonPoints, status],
    );
    return db.lastInsertRowId;
  }

  void updateLand(int landId, String name, List<Offset> points, int status) {
    final jsonPoints = jsonEncode(points.map((p) => {'x': p.dx, 'y': p.dy}).toList());
    db.execute(
      'UPDATE lands SET name = ?, points = ?, status = ? WHERE id = ?',
      [name, jsonPoints, status, landId],
    );
  }

  void deleteLand(int landId) {
    db.execute('DELETE FROM lands WHERE id = ?', [landId]);
  }

  List<Map<String, dynamic>> getLandsForVillage(int villageId) {
    final result = db.select('SELECT * FROM lands WHERE village_id = ?', [villageId]);
    return result.map((row) => {
      'id': row['id'],
      'name': row['name'],
      'points': jsonDecode(row['points'] as String)
          .map<Offset>((pt) => Offset(pt['x'].toDouble(), pt['y'].toDouble()))
          .toList(),
      'status': row['status'],
    }).toList();
  }
}

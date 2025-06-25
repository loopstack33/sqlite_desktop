
import 'dart:io';
import 'dart:convert';
import 'dart:ui';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  DatabaseHelper._internal();

  late Database db;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'employee_data.db');
    db = sqlite3.open(dbPath);
    _initialized = true;

    // Employee Table
    db.execute('''
      CREATE TABLE IF NOT EXISTS employees (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sr TEXT,
        name TEXT,
        designation TEXT,
        joining_date TEXT,
        gross_salary TEXT,
        perks TEXT,
        salary TEXT
      );
    ''');

    // Maps Table
    db.execute('''
      CREATE TABLE IF NOT EXISTS maps (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        image_path TEXT
      );
    ''');

    // Polygons Table
    db.execute('''
      CREATE TABLE IF NOT EXISTS polygons (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        map_id INTEGER,
        points TEXT,
        status INTEGER,
        FOREIGN KEY(map_id) REFERENCES maps(id) ON DELETE CASCADE
      );
    ''');

  }

  /// Force reloads the database (used after restore)
  Future<void> reinit() async {
    close();
    await init(); // Reopen and recreate tables if needed
  }

  void close() {
    print("DB INITIALIZED $_initialized");
    if (_initialized) {
      db.dispose();
      _initialized = false;
      print("DB INITIALIZED $_initialized");
    }
  }

  // ---------------- EMPLOYEES ----------------

  void insertEmployee(Map<String, String> row) {
    final stmt = db.prepare('''
      INSERT INTO employees (sr, name, designation, joining_date, gross_salary, perks, salary)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    ''');
    stmt.execute([
      row['sr'],
      row['name'],
      row['designation'],
      row['joining_date'],
      row['gross_salary'],
      row['perks'],
      row['salary'],
    ]);
    stmt.dispose();
  }

  List<Map<String, String>> getAllEmployees() {
    final result = db.select('SELECT * FROM employees');
    return result.map((row) => {
      'sr': row['sr'] as String,
      'name': row['name'] as String,
      'designation': row['designation'] as String,
      'joining_date': row['joining_date'] as String,
      'gross_salary': row['gross_salary'] as String,
      'perks': row['perks'] as String,
      'salary': row['salary'] as String,
    }).toList();
  }

  void clearAll() {
    db.execute('DELETE FROM employees');
  }

  void deleteEmployee(String sr) {
    db.execute('DELETE FROM employees WHERE sr = ?', [sr]);
  }

  void updateEmployee(Map<String, String> row) {
    db.execute('''
      UPDATE employees
      SET name = ?, designation = ?, joining_date = ?, gross_salary = ?, perks = ?, salary = ?
      WHERE sr = ?
    ''', [
      row['name'],
      row['designation'],
      row['joining_date'],
      row['gross_salary'],
      row['perks'],
      row['salary'],
      row['sr'],
    ]);
  }

  // ---------------- MAPS ----------------

  int insertMap(String name, String imagePath) {
    final stmt = db.prepare('INSERT INTO maps (name, image_path) VALUES (?, ?)');
    stmt.execute([name, imagePath]);
    final id = db.lastInsertRowId;
    stmt.dispose();
    return id;
  }

  List<Map<String, dynamic>> getAllMaps() {
    final result = db.select('SELECT * FROM maps');
    return result.map((row) => {
      'id': row['id'],
      'name': row['name'],
      'image_path': row['image_path'],
    }).toList();
  }

  void deleteMap(int mapId) {
    db.execute('DELETE FROM maps WHERE id = ?', [mapId]);
    db.execute('DELETE FROM polygons WHERE map_id = ?', [mapId]);
  }

  // ---------------- POLYGONS ----------------

  void insertPolygon(int mapId, List<Offset> points) {
    final jsonPoints = jsonEncode(points.map((p) => {'x': p.dx, 'y': p.dy}).toList());
    db.execute('INSERT INTO polygons (map_id, points) VALUES (?, ?)', [mapId, jsonPoints]);
  }

  void insertPolygonWithStatus(int mapId, List<Offset> points, int status) {
    final jsonPoints = jsonEncode(points.map((p) => {'x': p.dx, 'y': p.dy}).toList());
    db.execute(
      'INSERT INTO polygons (map_id, points, status) VALUES (?, ?, ?)',
      [mapId, jsonPoints, status],
    );
  }

  void updatePolygon(int mapId, int index, List<Offset> polygon) {
    final encodedPoints = jsonEncode(polygon.map((p) => {'x': p.dx, 'y': p.dy}).toList());
    final all = getPolygonsRaw(mapId);
    if (index < all.length) {
      db.execute('DELETE FROM polygons WHERE map_id = ? AND points = ?', [mapId, all[index]]);
      db.execute('INSERT INTO polygons (map_id, points) VALUES (?, ?)', [mapId, encodedPoints]);
    }
  }

  void updatePolygonWithStatus(int mapId, int polygonIndex, Map<String, dynamic> data) {
    final allPolygons = getPolygonsForMapWithStatus(mapId);
    if (polygonIndex >= allPolygons.length) return;

    final targetId = allPolygons[polygonIndex]['id'];
    final updatedPoints = data['points'] as List<Offset>;
    final jsonPoints = jsonEncode(updatedPoints.map((p) => {'x': p.dx, 'y': p.dy}).toList());
    final status = data['status'];

    db.execute(
      'UPDATE polygons SET points = ?, status = ? WHERE id = ?',
      [jsonPoints, status, targetId],
    );
  }

  void deletePolygon(int mapId, int polygonIndex) {
    final result = db.select('SELECT id FROM polygons WHERE map_id = ?', [mapId]);
    if (polygonIndex >= result.length) return;

    final polygonId = result[polygonIndex]['id'] as int;
    db.execute('DELETE FROM polygons WHERE id = ?', [polygonId]);
  }

  List<List<Offset>> getPolygonsForMap(int mapId) {
    final result = db.select('SELECT points FROM polygons WHERE map_id = ?', [mapId]);
    return result.map((row) {
      final jsonList = jsonDecode(row['points']) as List;
      return jsonList.map<Offset>((pt) {
        return Offset((pt['x'] as num).toDouble(), (pt['y'] as num).toDouble());
      }).toList();
    }).toList();
  }

  List<Map<String, dynamic>> getPolygonsForMapWithStatus(int mapId) {
    final result = db.select('SELECT id, points, status FROM polygons WHERE map_id = ?', [mapId]);
    return result.map((row) {
      final jsonList = jsonDecode(row['points'] as String) as List;
      return {
        'id': row['id'],
        'points': jsonList.map<Offset>((pt) => Offset((pt['x'] as num).toDouble(), (pt['y'] as num).toDouble())).toList(),
        'status': row['status'] ?? 0,
      };
    }).toList();
  }

  List<String> getPolygonsRaw(int mapId) {
    final result = db.select('SELECT points FROM polygons WHERE map_id = ?', [mapId]);
    return result.map((row) => row['points'] as String).toList();
  }
}




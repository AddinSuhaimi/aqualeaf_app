import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../models/scan_report_fresh.dart';
import '../models/scan_report_dried.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('aqualeaf_app.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 2, onCreate: _createDB);
  }

  // --------------------------
  // CREATE TABLES
  // --------------------------
  Future _createDB(Database db, int version) async {
    // Fresh table
    await db.execute('''
      CREATE TABLE scan_report_fresh (
        scan_id INTEGER PRIMARY KEY AUTOINCREMENT,
        farm_id INTEGER NOT NULL,
        species_id INTEGER NOT NULL,
        timestamp TEXT NOT NULL,
        image_url TEXT,
        impurity_status REAL,
        health_status TEXT,
        quality_status TEXT,
        synced INTEGER DEFAULT 0
      )
    ''');

    // Dried table
    await db.execute('''
      CREATE TABLE scan_report_dried (
        scan_id INTEGER PRIMARY KEY AUTOINCREMENT,
        farm_id INTEGER NOT NULL,
        species_id INTEGER NOT NULL,
        timestamp TEXT NOT NULL,
        image_url TEXT,
        impurity_status REAL,
        appearance TEXT,
        quality_status TEXT,
        synced INTEGER DEFAULT 0
      )
    ''');
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }

  // --------------------------------------------------------
  // INSERT OPERATIONS
  // --------------------------------------------------------
  Future<int> insertFreshReport(ScanReportFresh report) async {
    final db = await instance.database;
    return await db.insert('scan_report_fresh', report.toMap());
  }

  Future<int> insertDriedReport(ScanReportDried report) async {
    final db = await instance.database;
    return await db.insert('scan_report_dried', report.toMap());
  }

  // --------------------------------------------------------
  // FETCH RECENT REPORTS
  // --------------------------------------------------------
  Future<List<ScanReportFresh>> getRecentFreshReports({int limit = 100}) async {
    final db = await instance.database;

    final result = await db.query(
      'scan_report_fresh',
      orderBy: 'timestamp DESC',
      limit: limit,
    );

    return result.map((e) => ScanReportFresh.fromMap(e)).toList();
  }

  Future<List<ScanReportDried>> getRecentDriedReports({int limit = 100}) async {
    final db = await instance.database;

    final result = await db.query(
      'scan_report_dried',
      orderBy: 'timestamp DESC',
      limit: limit,
    );

    return result.map((e) => ScanReportDried.fromMap(e)).toList();
  }

  // --------------------------------------------------------
  // FETCH UNSYNCED REPORTS (for uploading)
  // --------------------------------------------------------
  Future<List<ScanReportFresh>> getUnsyncedFreshReports() async {
    final db = await instance.database;
    final result = await db.query(
      'scan_report_fresh',
      where: 'synced = ?',
      whereArgs: [0],
    );
    return result.map((e) => ScanReportFresh.fromMap(e)).toList();
  }

  Future<List<ScanReportDried>> getUnsyncedDriedReports() async {
    final db = await instance.database;
    final result = await db.query(
      'scan_report_dried',
      where: 'synced = ?',
      whereArgs: [0],
    );
    return result.map((e) => ScanReportDried.fromMap(e)).toList();
  }

  // --------------------------------------------------------
  // MARK AS SYNCED
  // --------------------------------------------------------
  Future<int> markFreshAsSynced(int scanId) async {
    final db = await instance.database;
    return await db.update(
      'scan_report_fresh',
      {'synced': 1},
      where: 'scan_id = ?',
      whereArgs: [scanId],
    );
  }

  Future<int> markDriedAsSynced(int scanId) async {
    final db = await instance.database;
    return await db.update(
      'scan_report_dried',
      {'synced': 1},
      where: 'scan_id = ?',
      whereArgs: [scanId],
    );
  }

  Future<void> markFreshListAsSynced(List<int> scanIds) async {
    final db = await instance.database;
    final batch = db.batch();

    for (final id in scanIds) {
      batch.update(
        'scan_report_fresh',
        {'synced': 1},
        where: 'scan_id = ?',
        whereArgs: [id],
      );
    }

    await batch.commit(noResult: true);
  }

  Future<void> markDriedListAsSynced(List<int> scanIds) async {
    final db = await instance.database;
    final batch = db.batch();

    for (final id in scanIds) {
      batch.update(
        'scan_report_dried',
        {'synced': 1},
        where: 'scan_id = ?',
        whereArgs: [id],
      );
    }

    await batch.commit(noResult: true);
  }
}

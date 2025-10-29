import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/scan_report.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('aqualef_app.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE scan_report (
        scan_id INTEGER PRIMARY KEY AUTOINCREMENT,
        farm_id TEXT NOT NULL,
        species_id TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        image_url TEXT,
        impurity_level REAL,
        discoloration_status TEXT,
        quality_status TEXT,
        synced INTEGER DEFAULT 0
      )
    ''');
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }

  Future<int> insertReport(ScanReport report) async {
    final db = await instance.database;
    return await db.insert('scan_report', report.toMap());
  }

  Future<List<ScanReport>> getAllReports() async {
    final db = await instance.database;
    final result = await db.query('scan_report');
    return result.map((e) => ScanReport.fromMap(e)).toList();
  }

  Future<List<ScanReport>> getUnsyncedReports() async {
    final db = await instance.database;
    final result = await db.query('scan_report', where: 'synced = ?', whereArgs: [0]);
    return result.map((e) => ScanReport.fromMap(e)).toList();
  }

  Future<int> markAsSynced(int scanId) async {
    final db = await instance.database;
    return await db.update('scan_report', {'synced': 1}, where: 'scan_id = ?', whereArgs: [scanId]);
  }

}

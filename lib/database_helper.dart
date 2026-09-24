import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('shiftdrop_v2.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(
      path,
      version: 5,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const textTypeNull = 'TEXT';
    const integerType = 'INTEGER NOT NULL';
    const integerTypeNull = 'INTEGER';
    const realTypeNull = 'REAL';

    await db.execute('''
      CREATE TABLE deliveries (
        id $idType,
        billNumber $textTypeNull,
        itemName $textTypeNull,
        customerName $textType,
        address $textType,
        phone $textType,
        phone2 $textTypeNull,
        codAmount $textType,
        status $textType,
        callAttempts $integerType,
        rescheduledDate $integerTypeNull,
        notes $textTypeNull,
        timestamp $integerType,
        routeOrder $integerTypeNull,
        lat $realTypeNull,
        lng $realTypeNull
      )
    ''');
  }

  // පරණ Database එකක් තියෙන අයට අලුත් columns auto add කිරීම
  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE deliveries ADD COLUMN routeOrder INTEGER');
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE deliveries ADD COLUMN phone2 TEXT');
    }
    if (oldVersion < 5) {
      await db.execute('ALTER TABLE deliveries ADD COLUMN lat REAL');
      await db.execute('ALTER TABLE deliveries ADD COLUMN lng REAL');
    }
  }

  Future<void> insertDelivery(Map<String, dynamic> deliveryData) async {
    final db = await instance.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    deliveryData['timestamp'] = now;
    deliveryData['status'] = 'pending';
    deliveryData['callAttempts'] = 0;
    // අලුත් Parcel එක route එකේ අන්තිමට යන්න
    deliveryData['routeOrder'] = now;
    await db.insert('deliveries', deliveryData);
  }

  Future<int> updateDelivery(int id, Map<String, dynamic> deliveryData) async {
    final db = await instance.database;
    return await db.update('deliveries', deliveryData, where: 'id = ?', whereArgs: [id]);
  }

  Future<bool> billNumberExists(String billNo, {int? excludeId}) async {
    if (billNo.trim().isEmpty) return false;
    final db = await instance.database;
    String where = 'billNumber = ?';
    List<dynamic> args = [billNo.trim()];
    if (excludeId != null) {
      where += ' AND id != ?';
      args.add(excludeId);
    }
    final result = await db.query('deliveries', where: where, whereArgs: args, limit: 1);
    return result.isNotEmpty;
  }

  // 🔍 අලුත්: Search (නම / Bill No / Phone 1 / Phone 2 / Address / Item)
  Future<List<Map<String, dynamic>>> searchDeliveries(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    final db = await instance.database;
    final like = '%$q%';
    return await db.query(
      'deliveries',
      where:
          'customerName LIKE ? OR billNumber LIKE ? OR phone LIKE ? OR phone2 LIKE ? OR address LIKE ? OR itemName LIKE ?',
      whereArgs: List.filled(6, like),
      orderBy: 'timestamp DESC',
      limit: 100,
    );
  }

  Future<List<Map<String, dynamic>>> getMorningCalls() async {
    final db = await instance.database;
    final now = DateTime.now();
    final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59).millisecondsSinceEpoch;
    return await db.query(
      'deliveries',
      where: '(status = ? OR status = ?) AND (rescheduledDate IS NULL OR rescheduledDate <= ?)',
      whereArgs: ['pending', 'rescheduled', endOfToday],
      orderBy: 'callAttempts DESC, timestamp ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getConfirmedDeliveries() async {
    final db = await instance.database;
    return await db.query(
      'deliveries',
      where: 'status = ?',
      whereArgs: ['confirmed'],
      orderBy: 'routeOrder ASC, timestamp ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getAllDeliveries() async {
    final db = await instance.database;
    return await db.query('deliveries', orderBy: 'timestamp DESC');
  }

  Future<int> updateDeliveryStatus(int id, String status, int attempts) async {
    final db = await instance.database;
    return await db.update('deliveries', {'status': status, 'callAttempts': attempts}, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> rescheduleDelivery(int id, int newDateEpoch, String note) async {
    final db = await instance.database;
    return await db.update('deliveries', {'status': 'rescheduled', 'rescheduledDate': newDateEpoch, 'notes': note}, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateNote(int id, String note) async {
    final db = await instance.database;
    return await db.update('deliveries', {'notes': note}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateRouteOrder(List<int> orderedIds) async {
    final db = await instance.database;
    final batch = db.batch();
    for (int i = 0; i < orderedIds.length; i++) {
      batch.update('deliveries', {'routeOrder': i}, where: 'id = ?', whereArgs: [orderedIds[i]]);
    }
    await batch.commit(noResult: true);
  }

  Future<Map<String, dynamic>> getDailyReportSummary() async {
    final db = await instance.database;

    final delivered = await db.query('deliveries', where: 'status = ?', whereArgs: ['delivered']);
    final returned = await db.query('deliveries', where: 'status = ?', whereArgs: ['returned']);
    final pending = await db.query('deliveries', where: 'status = ? OR status = ?', whereArgs: ['pending', 'rescheduled']);

    double totalCod = 0;
    for (var item in delivered) {
      String codStr = item['codAmount'].toString().replaceAll(RegExp(r'[^0-9.]'), '');
      if (codStr.isNotEmpty) {
        totalCod += double.tryParse(codStr) ?? 0;
      }
    }

    return {
      'deliveredCount': delivered.length,
      'returnedCount': returned.length,
      'pendingCount': pending.length,
      'totalCod': totalCod,
      'deliveredList': delivered,
      'returnedList': returned,
    };
  }

  // ✅ Fix: CSV එක සාර්ථකව save වුණාට පස්සේ විතරයි පරණ data delete කරන්නේ
  Future<void> backupAndCleanOldData() async {
    final db = await instance.database;
    final fourteenDaysAgo = DateTime.now().subtract(const Duration(days: 14)).millisecondsSinceEpoch;
    final oldData = await db.query('deliveries', where: 'timestamp < ?', whereArgs: [fourteenDaysAgo]);
    if (oldData.isEmpty) return;

    List<List<dynamic>> csvData = [
      ['Bill No', 'Item', 'Customer Name', 'Address', 'Phone', 'Phone 2', 'COD', 'Status', 'Attempts', 'Notes', 'Rescheduled Date', 'Lat', 'Lng']
    ];
    for (var row in oldData) {
      csvData.add([
        row['billNumber'],
        row['itemName'],
        row['customerName'],
        row['address'],
        row['phone'],
        row['phone2'],
        row['codAmount'],
        row['status'],
        row['callAttempts'],
        row['notes'],
        row['rescheduledDate'],
        row['lat'],
        row['lng'],
      ]);
    }
    final csvString = const ListToCsvConverter().convert(csvData);

    try {
      Directory? directory = await getExternalStorageDirectory();
      directory ??= await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/ShiftDrop_Backup_${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = File(filePath);
      await file.writeAsString(csvString, flush: true);

      // File එක ඇත්තටම ලියවුණාද කියලා තහවුරු කරලා විතරක් delete කරනවා
      if (await file.exists() && await file.length() > 0) {
        await db.delete('deliveries', where: 'timestamp < ?', whereArgs: [fourteenDaysAgo]);
      }
    } catch (_) {
      // Backup අසාර්ථක නම් data delete කරන්නේ නෑ
    }
  }
}

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

  // Existing users ට (පරණ Database එකක් තියෙන අයට) අලුත් columns auto add කිරීම
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
    // අලුතින් එකතු කරන Parcel එක route එකේ අන්තිමට යන්න routeOrder එක timestamp එකෙන්ම set කිරීම
    deliveryData['routeOrder'] = now;
    await db.insert('deliveries', deliveryData);
  }

  // Smart Scanner එකෙන් Edit Mode එකේදී, දැනටම තියෙන Record එකක් Update කිරීම
  Future<int> updateDelivery(int id, Map<String, dynamic> deliveryData) async {
    final db = await instance.database;
    return await db.update('deliveries', deliveryData, where: 'id = ?', whereArgs: [id]);
  }

  // Bill No එක Save කරන්න කලින්, දැනටම Database එකේ එම Bill No එක තියෙනවද Check කිරීම
  // (Edit Mode එකේදී, දැනටම Edit කරන Record එකම Exclude කරන්න excludeId දෙනවා)
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

  // Route screen එකේ, User විසින් manual ලෙස set කරපු පිළිවෙලට (routeOrder) Confirmed Deliveries ලබා ගැනීම
  Future<List<Map<String, dynamic>>> getConfirmedDeliveries() async {
    final db = await instance.database;
    return await db.query(
      'deliveries',
      where: 'status = ?',
      whereArgs: ['confirmed'],
      orderBy: 'routeOrder ASC, timestamp ASC',
    );
  }

  // Report screen එකේ Filter/Select කිරීම සඳහා bills/deliveries ඔක්කොම ලබා ගැනීම
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

  // Pending Calls Screen එකේ Note එක වෙන වෙනම Add/Edit කිරීම සඳහා
  Future<int> updateNote(int id, String note) async {
    final db = await instance.database;
    return await db.update('deliveries', {'notes': note}, where: 'id = ?', whereArgs: [id]);
  }

  // Route screen එකේ User Drag කරලා (හෝ Auto-Order කරලා) හදන අලුත් Order එක Database එකට Save කිරීම
  Future<void> updateRouteOrder(List<int> orderedIds) async {
    final db = await instance.database;
    final batch = db.batch();
    for (int i = 0; i < orderedIds.length; i++) {
      batch.update('deliveries', {'routeOrder': i}, where: 'id = ?', whereArgs: [orderedIds[i]]);
    }
    await batch.commit(noResult: true);
  }

  // අලුතින් එකතු කළ කේතය: End of Day Report එක සඳහා දත්ත ලබා ගැනීම
  Future<Map<String, dynamic>> getDailyReportSummary() async {
    final db = await instance.database;
    
    final delivered = await db.query('deliveries', where: 'status = ?', whereArgs: ['delivered']);
    final returned = await db.query('deliveries', where: 'status = ?', whereArgs: ['returned']);
    final pending = await db.query('deliveries', where: 'status = ? OR status = ?', whereArgs: ['pending', 'rescheduled']);

    double totalCod = 0;
    for (var item in delivered) {
      // අකුරු හෝ රුපියල් සලකුණු තිබුණොත් ඒවා අයින් කරලා ගාණ විතරක් එකතු කිරීම
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

  Future<void> backupAndCleanOldData() async {
    final db = await instance.database;
    final fourteenDaysAgo = DateTime.now().subtract(const Duration(days: 14)).millisecondsSinceEpoch;
    final oldData = await db.query('deliveries', where: 'timestamp < ?', whereArgs: [fourteenDaysAgo]);
    if (oldData.isEmpty) return;
    List<List<dynamic>> csvData = [['Bill No', 'Item', 'Customer Name', 'Address', 'Phone', 'Phone 2', 'COD', 'Status', 'Attempts', 'Notes']];
    for (var row in oldData) {
      csvData.add([row['billNumber'], row['itemName'], row['customerName'], row['address'], row['phone'], row['phone2'], row['codAmount'], row['status'], row['callAttempts'], row['notes']]);
    }
    String csvString = const ListToCsvConverter().convert(csvData);
    Directory? directory = await getExternalStorageDirectory();
    if (directory != null) {
      String filePath = '${directory.path}/ShiftDrop_Backup_${DateTime.now().millisecondsSinceEpoch}.csv';
      File file = File(filePath);
      await file.writeAsString(csvString);
    }
    await db.delete('deliveries', where: 'timestamp < ?', whereArgs: [fourteenDaysAgo]);
  }
}

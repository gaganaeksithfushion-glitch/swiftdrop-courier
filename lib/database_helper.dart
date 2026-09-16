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

    return await openDatabase(path, version: 2, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const textTypeNull = 'TEXT';
    const integerType = 'INTEGER NOT NULL';
    const integerTypeNull = 'INTEGER';

    await db.execute('''
      CREATE TABLE deliveries (
        id $idType,
        billNumber $textTypeNull,
        itemName $textTypeNull,
        customerName $textType,
        address $textType,
        phone $textType,
        codAmount $textType,
        status $textType,         
        callAttempts $integerType,
        rescheduledDate $integerTypeNull, 
        notes $textTypeNull,      
        timestamp $integerType
      )
    ''');
  }

  Future<void> insertDelivery(Map<String, dynamic> deliveryData) async {
    final db = await instance.database;
    deliveryData['timestamp'] = DateTime.now().millisecondsSinceEpoch;
    deliveryData['status'] = 'pending';
    deliveryData['callAttempts'] = 0;
    await db.insert('deliveries', deliveryData);
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

  // අලුතින් එකතු කළ කේතය: Confirm කළ පාර්සල් ටික (Route List එකට) ලබා ගැනීම
  Future<List<Map<String, dynamic>>> getConfirmedDeliveries() async {
    final db = await instance.database;
    return await db.query(
      'deliveries',
      where: 'status = ?',
      whereArgs: ['confirmed'],
      orderBy: 'timestamp ASC', // පරණ ඒවා උඩින් පෙන්වයි
    );
  }

  Future<int> updateDeliveryStatus(int id, String status, int attempts) async {
    final db = await instance.database;
    return await db.update('deliveries', {'status': status, 'callAttempts': attempts}, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> rescheduleDelivery(int id, int newDateEpoch, String note) async {
    final db = await instance.database;
    return await db.update('deliveries', {'status': 'rescheduled', 'rescheduledDate': newDateEpoch, 'notes': note}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> backupAndCleanOldData() async {
    // Backup code remains the same
    final db = await instance.database;
    final fourteenDaysAgo = DateTime.now().subtract(const Duration(days: 14)).millisecondsSinceEpoch;
    final oldData = await db.query('deliveries', where: 'timestamp < ?', whereArgs: [fourteenDaysAgo]);
    if (oldData.isEmpty) return;
    List<List<dynamic>> csvData = [['Bill No', 'Item', 'Customer Name', 'Address', 'Phone', 'COD', 'Status', 'Attempts', 'Notes']];
    for (var row in oldData) {
      csvData.add([row['billNumber'], row['itemName'], row['customerName'], row['address'], row['phone'], row['codAmount'], row['status'], row['callAttempts'], row['notes']]);
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

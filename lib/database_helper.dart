import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'swiftdrop_courier.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE deliveries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            billNumber TEXT,
            itemName TEXT,
            customerName TEXT,
            address TEXT,
            phone TEXT,
            phone2 TEXT,
            codAmount TEXT,
            notes TEXT,
            status TEXT DEFAULT 'pending',
            callAttempts INTEGER DEFAULT 0,
            createdAt TEXT
          )
        ''');
      },
    );
  }

  // Smart Scanner screen එකෙන් අලුත් Parcel එකක් Save කිරීම
  Future<int> insertDelivery(Map<String, dynamic> data) async {
    final db = await database;
    final row = {
      'billNumber': data['billNumber'] ?? '',
      'itemName': data['itemName'] ?? 'Parcel',
      'customerName': data['customerName'] ?? '',
      'address': data['address'] ?? '',
      'phone': data['phone'] ?? '',
      'phone2': data['phone2'] ?? '',
      'codAmount': data['codAmount'] ?? '0',
      'notes': data['notes'] ?? '',
      'status': 'pending',
      'callAttempts': 0,
      'createdAt': DateTime.now().toIso8601String(),
    };
    return await db.insert('deliveries', row);
  }

  // Pending Calls screen එකේ Morning Calls List එක (pending / rescheduled) ලබාගැනීම
  Future<List<Map<String, dynamic>>> getMorningCalls() async {
    final db = await database;
    return await db.query(
      'deliveries',
      where: 'status = ? OR status = ?',
      whereArgs: ['pending', 'rescheduled'],
      orderBy: 'id DESC',
    );
  }

  // Reports screen එකේ සියලුම Bills ලබාගැනීම
  Future<List<Map<String, dynamic>>> getAllDeliveries() async {
    final db = await database;
    return await db.query('deliveries', orderBy: 'id DESC');
  }

  // Status එකක් (confirmed / pending / delivered / returned / rescheduled) Update කිරීම
  Future<int> updateDeliveryStatus(int id, String status, int callAttempts) async {
    final db = await database;
    return await db.update(
      'deliveries',
      {
        'status': status,
        'callAttempts': callAttempts,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Order එකේ Details (Name/Phone/Address/Item/Price) Edit Dialog එකෙන් Update කිරීම
  Future<int> updateDeliveryDetails(int id, Map<String, dynamic> data) async {
    final db = await database;
    return await db.update(
      'deliveries',
      {
        'customerName': data['customerName'] ?? '',
        'billNumber': data['billNumber'] ?? '',
        'phone': data['phone'] ?? '',
        'phone2': data['phone2'] ?? '',
        'address': data['address'] ?? '',
        'itemName': data['itemName'] ?? '',
        'codAmount': data['codAmount'] ?? '0',
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // අවශ්‍ය නම් Delivery එකක් Delete කිරීම
  Future<int> deleteDelivery(int id) async {
    final db = await database;
    return await db.delete('deliveries', where: 'id = ?', whereArgs: [id]);
  }
}

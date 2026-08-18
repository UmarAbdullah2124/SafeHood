import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LocalDB {
  static Database? _db;

  static Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  static Future<Database> _initDB() async {
    final path = join(await getDatabasesPath(), 'profile.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
        CREATE TABLE user(
          id TEXT PRIMARY KEY,
          firstName TEXT,
          lastName TEXT,
          email TEXT,
          phone TEXT,
          cnic TEXT,
          dob TEXT,
          imagePath TEXT
        )
        ''');
      },
    );
  }

  static Future<void> saveUser(Map<String, dynamic> data) async {
    final dbClient = await db;
    await dbClient.insert(
      'user',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<Map<String, dynamic>?> getUser(String id) async {
    final dbClient = await db;
    final res =
    await dbClient.query('user', where: "id=?", whereArgs: [id]);

    return res.isNotEmpty ? res.first : null;
  }
}
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DbHelper {
  static final DbHelper _instance = DbHelper._internal();
  factory DbHelper() => _instance;
  DbHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    String path = join(await getDatabasesPath(), 'wifi_vault.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE passwords(id INTEGER PRIMARY KEY AUTOINCREMENT, content TEXT)',
        );
      },
    );
  }

  // 插入新密码
  Future<int> insertPassword(String password) async {
    final db = await database;
    return await db.insert('passwords', {'content': password});
  }

  // 获取所有密码
  Future<List<Map<String, dynamic>>> getPasswords() async {
    final db = await database;
    return await db.query('passwords', orderBy: 'id DESC');
  }

  // 删除单个密码
  Future<int> deletePassword(int id) async {
    final db = await database;
    return await db.delete('passwords', where: 'id = ?', whereArgs: [id]);
  }
}
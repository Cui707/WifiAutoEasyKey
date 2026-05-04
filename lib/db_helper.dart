import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DbHelper {
  static final DbHelper _instance = DbHelper._internal();
  factory DbHelper() => _instance;
  DbHelper._internal();

  static Database? _database;

  // 预置的常用密码库
  final List<String> _presetPasswords = [
    '12345678',
    '88888888',
    '00000000',
    '11111111',
    '123456789',
    'password',
    '66668888',
    '12344321',
    'qwertyui',
    // 你可以在这里继续添加更多工程现场常用的默认密码
  ];

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
      onCreate: (db, version) async {
        // 1. 创建表
        await db.execute(
          'CREATE TABLE passwords(id INTEGER PRIMARY KEY AUTOINCREMENT, content TEXT)',
        );
        
        // 2. 批量插入预置密码
        for (String pwd in _presetPasswords) {
          await db.insert('passwords', {'content': pwd});
        }
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

  // 可选：重置密码库（清空并重新导入预置密码）
  Future<void> resetToDefault() async {
    final db = await database;
    await db.delete('passwords');
    for (String pwd in _presetPasswords) {
      await db.insert('passwords', {'content': pwd});
    }
  }
}
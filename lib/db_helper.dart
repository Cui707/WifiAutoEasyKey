import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DbHelper {
  static final DbHelper _instance = DbHelper._internal();
  factory DbHelper() => _instance;
  DbHelper._internal();

  static Database? _database;

final List<String> _presetPasswords = [
  '147258369', '369258147', '789456123', '159357456', '95279527', '00112233',
  '12345600',  '123321123',
  '168168168', '16881688', '520520520', '88816888', '66616866', '1234567890',
  '987654321', '88889999', '1122334455', '22334455', '33445566', '44556677',
  '22222222', '33333333', '44444444', '55555555', '77777777', '12341234',
  '23456789', '34567890', '45678901', '56789012', '67890123', '78901234',
  '89012345', '90123456', '8888168', '6666168', '13572468', '24681357', '13579246', 
  '01230123', '11112222', '22221111', '33334444', '44443333',  
  '55667788', '10203040', 'abc12345', 'admin123', 'admin888', 'wifi123456', 'qwertyui',
  'asdfghjkl', '86868686', '65432109', '13145200', '13145211', '52013141',
  '88886666', '66668888', '12121212',
  '20252025','20262026',
  '12345670', '1q2w3e4r', 'a1b2c3d4',  '77778888', '99990000',
  'iloveyou', 'sunshine', 'welcome', 'internet', '09876543',
  '66666666', '00000000', '11111111', '123456789', '01234567', '1234554321',
  '12344321', '99999999', '123123123', '111222333',
  'password', '87654321', '11223344', '12345678' ,  '88888888'
];

  // 获取数据库单例
  Future<Database> get database async {
    if (_database != null) return _database!;
    // 指向正确的初始化函数
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'wifi_vault.db');
    return await openDatabase(
      path,
      version: 2, // 提升版本号
      onCreate: (db, version) async {
        // 第一次安装时：同时创建两张表
        await db.execute(
          'CREATE TABLE passwords(id INTEGER PRIMARY KEY AUTOINCREMENT, content TEXT)',
        );
        await db.execute(
          "CREATE TABLE scan_history("
          "id INTEGER PRIMARY KEY AUTOINCREMENT, "
          "ssid TEXT, result TEXT, password TEXT, time TEXT)"
        );
        // 初始密码入库
        for (String pwd in _presetPasswords) {
          await db.insert('passwords', {'content': pwd});
        }
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // 已经安装了旧版的用户：补齐新表
        if (oldVersion < 2) {
          await db.execute(
            "CREATE TABLE scan_history("
            "id INTEGER PRIMARY KEY AUTOINCREMENT, "
            "ssid TEXT, result TEXT, password TEXT, time TEXT)"
          );
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
  Future<void> _onCreate(Database db, int version) async {
    // 密码库表
    await db.execute(
      "CREATE TABLE passwords(id INTEGER PRIMARY KEY AUTOINCREMENT, content TEXT)"
    );
    // 新增：扫描历史记录表
    await db.execute(
      "CREATE TABLE scan_history("
      "id INTEGER PRIMARY KEY AUTOINCREMENT, "
      "ssid TEXT, "
      "result TEXT, "
      "password TEXT, "
      "time TEXT)"
    );
  }

  // 插入历史记录的方法
  Future<void> insertHistory(Map<String, String> data) async {
    final db = await database; // 假设你的类里有获取数据库的方法
    await db.insert('scan_history', data);
  }

  // 获取所有历史记录（按时间倒序）
  Future<List<Map<String, dynamic>>> getHistory() async {
    final db = await database;
    return await db.query('scan_history', orderBy: 'id DESC');
  }
  
  // 清空记录的方法（方便调试）
  Future<void> clearHistory() async {
    final db = await database;
    await db.delete('scan_history');
  }
}
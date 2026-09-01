import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DbHelper {
  static final DbHelper _instance = DbHelper._internal();
  factory DbHelper() => _instance;
  DbHelper._internal();

  static Database? _database;

final List<String> _presetPasswords = [
  '12341234',
  'admin123', 
  '88886666', '66668888', 
  'iloveyou', 
  '66666666', 'password',  '12345678' ,  '88888888'
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
      version: 3, // 提升版本号以支持多密码库
      onCreate: (db, version) async {
        // 第一次安装时：创建所有表
        await db.execute(
          'CREATE TABLE password_libraries(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, created_at TEXT DEFAULT CURRENT_TIMESTAMP, is_default BOOLEAN DEFAULT 0)'
        );
        await db.execute(
          'CREATE TABLE passwords(id INTEGER PRIMARY KEY AUTOINCREMENT, content TEXT, library_id INTEGER, FOREIGN KEY(library_id) REFERENCES password_libraries(id))'
        );
        await db.execute(
          "CREATE TABLE scan_history("
          "id INTEGER PRIMARY KEY AUTOINCREMENT, "
          "ssid TEXT, result TEXT, password TEXT, time TEXT)"
        );
        // 创建默认密码库并标记为默认
        final defaultLibraryId = await db.insert('password_libraries', {'name': '默认密码库', 'is_default': 1});
        // 初始密码入库到默认密码库
        for (String pwd in _presetPasswords) {
          await db.insert('passwords', {'content': pwd, 'library_id': defaultLibraryId});
        }
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // 从旧版本升级
        if (oldVersion < 2) {
          await db.execute(
            "CREATE TABLE scan_history("
            "id INTEGER PRIMARY KEY AUTOINCREMENT, "
            "ssid TEXT, result TEXT, password TEXT, time TEXT)"
          );
        }
        if (oldVersion < 3) {
          // 添加密码库表
          await db.execute(
            'CREATE TABLE password_libraries(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, created_at TEXT DEFAULT CURRENT_TIMESTAMP, is_default BOOLEAN DEFAULT 0)'
          );
          // 修改密码表添加library_id列
          await db.execute('ALTER TABLE passwords ADD COLUMN library_id INTEGER');
          // 创建默认密码库
          final defaultLibraryId = await db.insert('password_libraries', {'name': '默认密码库', 'is_default': 1});
          // 将现有密码迁移到默认密码库
          await db.update('passwords', {'library_id': defaultLibraryId});
        }
      },
    );
  }

  // 插入新密码到指定密码库
  Future<int> insertPassword(String password, {int? libraryId}) async {
    final db = await database;
    final queryLibraryId = libraryId ?? (await getDefaultLibraryId());
    return await db.insert('passwords', {
      'content': password,
      'library_id': queryLibraryId
    });
  }

  // 获取指定密码库的所有密码
  Future<List<Map<String, dynamic>>> getPasswords({int? libraryId}) async {
    final db = await database;
    final queryLibraryId = libraryId ?? (await getDefaultLibraryId());
    return await db.query('passwords', 
      where: 'library_id = ?', 
      whereArgs: [queryLibraryId],
      orderBy: 'id DESC'
    );
  }

  // 删除单个密码
  Future<int> deletePassword(int id) async {
    final db = await database;
    return await db.delete('passwords', where: 'id = ?', whereArgs: [id]);
  }

// 获取默认密码库ID
  Future<int> getDefaultLibraryId() async {
    final db = await database;
    final result = await db.query('password_libraries', 
      where: 'is_default = 1',
      limit: 1
    );
    return result.isNotEmpty ? result.first['id'] as int : 1;
  }

  // 获取所有密码库
  Future<List<Map<String, dynamic>>> getLibraries() async {
    final db = await database;
    return await db.query('password_libraries', orderBy: 'id DESC');
  }

  // 创建新密码库
  Future<int> createLibrary(String name) async {
    final db = await database;
    return await db.insert('password_libraries', {'name': name});
  }

  // 更新密码库名称
  Future<int> updateLibraryName(int id, String name) async {
    final db = await database;
    return await db.update('password_libraries', {'name': name}, where: 'id = ?', whereArgs: [id]);
  }

  // 删除密码库（同时删除其中的密码）
  Future<int> deleteLibrary(int id) async {
    final db = await database;
    // 删除密码库中的所有密码
    await db.delete('passwords', where: 'library_id = ?', whereArgs: [id]);
    // 删除密码库
    return await db.delete('password_libraries', where: 'id = ?', whereArgs: [id]);
  }

  // 设置默认密码库
  Future<void> setDefaultLibrary(int id) async {
    final db = await database;
    // 清除所有默认标记
    await db.update('password_libraries', {'is_default': 0});
    // 设置新的默认密码库
    await db.update('password_libraries', {'is_default': 1}, where: 'id = ?', whereArgs: [id]);
  }

  // 获取默认密码库名称
  Future<String> getDefaultLibraryName() async {
    final db = await database;
    final result = await db.query('password_libraries', 
      where: 'is_default = 1',
      limit: 1
    );
    return result.isNotEmpty ? result.first['name'] as String : '默认密码库';
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
    final db = await this.database;
    await db.insert('scan_history', data);
  }

  // 获取所有历史记录（按时间倒序）
  Future<List<Map<String, dynamic>>> getHistory() async {
    final db = await this.database;
    return await db.query('scan_history', orderBy: 'id DESC');
  }
  
  // 清空记录的方法（方便调试）
  Future<void> clearHistory() async {
    final db = await this.database;
    await db.delete('scan_history');
  }
}
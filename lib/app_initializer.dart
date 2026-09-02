import 'db_helper.dart';

class AppInitializer {
  static final AppInitializer _instance = AppInitializer._internal();
  factory AppInitializer() => _instance;
  
  AppInitializer._internal();
  
  int? _defaultLibraryId;
  bool _isInitialized = false;
  bool _isInitializing = false;
  
  /// 获取默认密码库ID（带缓存）
  Future<int> getDefaultLibraryId() async {
    if (_isInitialized) {
      return _defaultLibraryId!;
    }
    
    if (_isInitializing) {
      // 等待初始化完成
      while (_isInitializing) {
        await Future.delayed(const Duration(milliseconds: 10));
      }
      return _defaultLibraryId!;
    }
    
    _isInitializing = true;
    try {
      _defaultLibraryId = await DbHelper().getDefaultLibraryId();
      _isInitialized = true;
      return _defaultLibraryId!;
    } catch (e) {
      // 如果查询失败，返回默认值1
      _defaultLibraryId = 1;
      _isInitialized = true;
      return _defaultLibraryId!;
    } finally {
      _isInitializing = false;
    }
  }
  
  /// 重置初始化状态（用于测试或重置）
  void reset() {
    _defaultLibraryId = null;
    _isInitialized = false;
    _isInitializing = false;
  }
  
  /// 检查是否已初始化
  bool get isInitialized => _isInitialized;
}
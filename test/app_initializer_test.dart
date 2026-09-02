import 'package:flutter_test/flutter_test.dart';
import 'package:WifiAutoEasyKey/app_initializer.dart';
import 'package:WifiAutoEasyKey/db_helper.dart';

void main() {
  group('AppInitializer Performance Tests', () {
    test('多次调用getDefaultLibraryId应该使用缓存', () async {
      final initializer = AppInitializer();
      
      // 第一次调用应该查询数据库
      final startTime1 = DateTime.now();
      final result1 = await initializer.getDefaultLibraryId();
      final duration1 = DateTime.now().difference(startTime1);
      
      // 第二次调用应该使用缓存
      final startTime2 = DateTime.now();
      final result2 = await initializer.getDefaultLibraryId();
      final duration2 = DateTime.now().difference(startTime2);
      
      // 验证结果一致
      expect(result1, result2);
      
      // 验证第二次调用更快（缓存生效）
      print('第一次调用耗时: ${duration1.inMilliseconds}ms');
      print('第二次调用耗时: ${duration2.inMilliseconds}ms');
      expect(duration2.inMilliseconds, lessThan(duration1.inMilliseconds));
    });

    test('并发调用getDefaultLibraryId应该正确处理', () async {
      final initializer = AppInitializer();
      
      // 并发调用
      final futures = List.generate(10, (i) => initializer.getDefaultLibraryId());
      final results = await Future.wait(futures);
      
      // 验证所有结果一致
      expect(results.toSet().length, 1);
    });

    test('初始化状态管理', () {
      final initializer = AppInitializer();
      
      // 初始状态
      expect(initializer.isInitialized, false);
      
      // 重置状态
      initializer.reset();
      expect(initializer.isInitialized, false);
    });
  });

  group('Database Query Performance', () {
    test('数据库查询性能', () async {
      final dbHelper = DbHelper();
      
      // 测试getDefaultLibraryId性能
      final startTime = DateTime.now();
      final result = await dbHelper.getDefaultLibraryId();
      final duration = DateTime.now().difference(startTime);
      
      print('数据库查询耗时: ${duration.inMilliseconds}ms');
      expect(result, greaterThan(0));
      
      // 查询应该在合理时间内完成（比如100ms以内）
      expect(duration.inMilliseconds, lessThan(100));
    });
  });
}
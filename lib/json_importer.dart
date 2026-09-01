import 'dart:convert';
import 'package:flutter/material.dart';
import 'db_helper.dart';

class JsonImporter {
  static Future<void> importPasswordsFromJson(String jsonString, {int? libraryId, BuildContext? context}) async {
    try {
      final jsonData = json.decode(jsonString);
      
      // 检查JSON格式
      if (jsonData is! List) {
        throw FormatException('JSON数据格式错误，应为密码数组');
      }
      
      // 验证密码数据
      for (final item in jsonData) {
        if (item is! String) {
          throw FormatException('密码数组中包含非字符串元素');
        }
        if (item.trim().isEmpty) {
          throw FormatException('发现空密码');
        }
      }
      
      // 导入密码
      final dbHelper = DbHelper();
      for (final password in jsonData) {
        await dbHelper.insertPassword(password.trim(), libraryId: libraryId);
      }
      
      // 显示成功消息
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('成功导入密码')),
        );
      }
    } catch (e) {
      // 显示错误消息
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败: $e')),
        );
      }
      rethrow;
    }
  }

  // 预设的JSON格式示例
  static String getJsonFormatExample() {
    return '''
[
  "12345678",
  "password",
  "88888888",
  "admin123",
  "qwerty",
  "iloveyou"
]
''';
  }
}
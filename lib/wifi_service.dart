import 'dart:async';
import 'package:wifi_iot/wifi_iot.dart';
import 'db_helper.dart';

enum ConnectionStatus { idle, testing, success, failed }

class WifiService {
  final DbHelper _dbHelper = DbHelper();
  
  // 用于向 UI 报告进度的回调
  Function(String currentPassword, int index, int total)? onProgress;

  Future<String?> startBruteForce(String ssid) async {
    // 1. 从数据库获取所有密码
    final List<Map<String, dynamic>> passwordMaps = await _dbHelper.getPasswords();
    final List<String> passwords = passwordMaps.map((e) => e['content'] as String).toList();
    
    if (passwords.isEmpty) return null;

    // 2. 依次尝试
    for (int i = 0; i < passwords.length; i++) {
      String currentPwd = passwords[i];
      
      // 更新 UI 进度
      if (onProgress != null) {
        onProgress!(currentPwd, i + 1, passwords.length);
      }

      bool isConnected = await _attemptConnection(ssid, currentPwd);

      if (isConnected) {
        return currentPwd; // 成功找回密码
      }

      // 3. 关键：给系统 Wi-Fi 栈一点缓冲时间
      // 频繁切换连接会导致 Android 系统暂时忽略 App 的请求
      await Future.delayed(const Duration(seconds: 2));
    }

    return null; // 全部失败
  }

  Future<bool> _attemptConnection(String ssid, String password) async {
    try {
      // 断开当前连接，确保纯净重连
      await WiFiForIoTPlugin.disconnect();

      bool result = await WiFiForIoTPlugin.connect(
        ssid,
        password: password,
        security: NetworkSecurity.WPA, // 大多数现代家庭网络
        joinOnce: true, // 建议设为 true，避免在系统 Wi-Fi 列表留下过多垃圾配置
      );

      // 在某些安卓版本中，connect 返回 true 仅代表“指令已发出”
      // 我们需要额外验证是否真的拿到了 IP 或者联网了
      if (result) {
        // 等待 3 秒进行二次确认
        await Future.delayed(const Duration(seconds: 3));
        return await WiFiForIoTPlugin.isConnected();
      }
      
      return false;
    } catch (e) {
      print("连接尝试异常: $e");
      return false;
    }
  }
}
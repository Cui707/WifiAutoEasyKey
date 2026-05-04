import 'package:flutter/material.dart';
import 'package:wifi_iot/wifi_iot.dart';
import 'package:permission_handler/permission_handler.dart';
import 'db_helper.dart';
import 'wifi_service.dart'; // 确保引入了逻辑层

class SingleWifiPage extends StatefulWidget {
  const SingleWifiPage({super.key});

  @override
  State<SingleWifiPage> createState() => _SingleWifiPageState();
}

class _SingleWifiPageState extends State<SingleWifiPage> {
  List<WlanNetwork> _networks = [];
  bool _isScanning = false;
  final DbHelper _dbHelper = DbHelper();
  final WifiService _wifiService = WifiService();

  @override
  void initState() {
    super.initState();
    _requestPermissionAndScan();
  }

  // 1. 请求权限并开始扫描
  Future<void> _requestPermissionAndScan() async {
    setState(() => _isScanning = true);
    
    var status = await Permission.location.request();
    if (status.isGranted) {
      // 扫描周围的热点
      List<WlanNetwork> ht = await WiFiForIoTPlugin.loadWifiList();
      setState(() {
        _networks = ht;
        _isScanning = false;
      });
    } else {
      setState(() => _isScanning = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("需要定位权限才能扫描 Wi-Fi")),
        );
      }
    }
  }

  // 2. 核心轮询连接逻辑
  void _startAttempt(String ssid) async {
    // 先检查库是否为空
    final passwords = await _dbHelper.getPasswords();
    if (passwords.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("密码库为空，请先在‘密码库’选项卡中添加密码")),
        );
      }
      return;
    }

    // 局部状态变量，用于在弹窗内显示进度
    String statusMessage = "准备启动...";
    int current = 0;
    int total = passwords.length;

    // 显示进度弹窗
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // 绑定服务层的进度回调
            _wifiService.onProgress = (pwd, index, all) {
              setDialogState(() {
                statusMessage = "正在尝试: $pwd";
                current = index;
                total = all;
              });
            };

            return AlertDialog(
              title: Text("正在轮询: $ssid"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const LinearProgressIndicator(),
                  const SizedBox(height: 20),
                  Text(statusMessage, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Text("进度: $current / $total", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    // 注意：这里仅关闭了 UI，底层的循环可能需要额外标志位来停止
                    Navigator.pop(context);
                  },
                  child: const Text("停止尝试"),
                ),
              ],
            );
          },
        );
      },
    );

    // 运行底层连接服务
    String? foundPassword = await _wifiService.startBruteForce(ssid);

    // 逻辑执行完毕，关闭进度弹窗
    if (mounted) {
      Navigator.pop(context); 
      _showResultDialog(foundPassword);
    }
  }

  // 3. 结果反馈弹窗
  void _showResultDialog(String? password) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(password != null ? " 🎉 成功找回" : " ❌ 轮询结束"),
        content: Text(
          password != null 
            ? "找到正确密码：\n\n$password" 
            : "密码库内所有密码均已尝试，未匹配成功。"
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("确定"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _requestPermissionAndScan,
        child: _isScanning 
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : const Icon(Icons.refresh),
      ),
      body: _networks.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.wifi_off, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text("未发现 Wi-Fi 或权限不足"),
                  TextButton(
                    onPressed: _requestPermissionAndScan,
                    child: const Text("重新扫描"),
                  )
                ],
              ),
            )
          : ListView.builder(
              itemCount: _networks.length,
              itemBuilder: (context, index) {
                final wifi = _networks[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: ListTile(
                    leading: Icon(
                      Icons.wifi,
                      color: (wifi.level ?? -100) > -60 ? Colors.green : Colors.orange,
                    ),
                    title: Text(wifi.ssid ?? "未知 SSID", style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("信号强度: ${wifi.level} dBm"),
                    trailing: const Icon(Icons.play_circle_fill, color: Colors.blueAccent, size: 32),
                    onTap: () => _startAttempt(wifi.ssid ?? ""),
                  ),
                );
              },
            ),
    );
  }
}
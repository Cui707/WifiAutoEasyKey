import 'package:flutter/material.dart';
import 'wifi_service.dart'; 
import 'db_helper.dart'; 
import 'package:wifi_scan/wifi_scan.dart'; // 需要用到 WiFiAccessPoint 类型

class WifiTask {
  final String ssid;
  final int level; 
  bool isSelected;

  WifiTask({required this.ssid, required this.level, this.isSelected = true});
}

class GlobalWiFiPage extends StatefulWidget {
  const GlobalWiFiPage({super.key});

  @override
  State<GlobalWiFiPage> createState() => _GlobalWiFiPageState();
}

class _GlobalWiFiPageState extends State<GlobalWiFiPage> {
  final WifiService _wifiService = WifiService();
  final DbHelper _dbHelper = DbHelper();

  List<WifiTask> _availableTasks = []; // 扫描到的可勾选列表
  List<Map<String, String>> _results = []; // 运行结果日志
  
  bool _isRunning = false;
  bool _isScanning = false;
  String _currentStatus = "准备就绪";
  double _totalProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _refreshWifiList(); // 页面加载时自动扫描一次
  }

  // 刷新环境中的 WiFi 列表
  void _refreshWifiList() async {
    if (_isRunning) return;
    setState(() {
      _isScanning = true;
      _currentStatus = "正在扫描周围 WiFi...";
    });

    try {
      // 这里的逻辑直接调用 wifi_scan 原始结果以获取 level
      await WiFiScan.instance.startScan();
      await Future.delayed(const Duration(seconds: 2));
      final accessPoints = await WiFiScan.instance.getScannedResults();

      setState(() {
        // 提取 SSID 并去重，保留信号最强的那个
        Map<String, WifiTask> distinctTasks = {};
        for (var ap in accessPoints) {
          if (ap.ssid.isEmpty) continue;
          if (!distinctTasks.containsKey(ap.ssid) || ap.level > distinctTasks[ap.ssid]!.level) {
            distinctTasks[ap.ssid] = WifiTask(ssid: ap.ssid, level: ap.level);
          }
        }
        _availableTasks = distinctTasks.values.toList();
        // 按信号强度排序（强的在前）
        _availableTasks.sort((a, b) => b.level.compareTo(a.level));
        
        _isScanning = false;
        _currentStatus = _availableTasks.isEmpty ? "未发现 WiFi" : "扫描完成，请勾选目标";
      });
    } catch (e) {
      _showMsg("扫描失败: $e");
      setState(() => _isScanning = false);
    }
  }

  // 全选/反选逻辑
  void _toggleAll(bool? value) {
    setState(() {
      for (var task in _availableTasks) {
        task.isSelected = value ?? false;
      }
    });
  }

  // 核心：执行勾选的任务
  void _runSelectedTasks() async {
    final tasksToRun = _availableTasks.where((t) => t.isSelected).toList();
    
    if (tasksToRun.isEmpty) {
      _showMsg("请先勾选需要轮询的 WiFi");
      return;
    }

    final passwords = await _dbHelper.getPasswords();
    if (passwords.isEmpty) {
      _showMsg("密码库为空");
      return;
    }

    setState(() {
      _isRunning = true;
      _results.clear(); // 清空上次日志
    });

    for (int i = 0; i < tasksToRun.length; i++) {
      if (!_isRunning) break;

      String ssid = tasksToRun[i].ssid;
      setState(() {
        _currentStatus = "正在轮询 (${i + 1}/${tasksToRun.length}): $ssid";
        _totalProgress = (i + 1) / tasksToRun.length;
      });

      // 调用 Service 中的单点暴力破解逻辑
      String? foundPassword = await _wifiService.startBruteForce(ssid);

      setState(() {
        _results.insert(0, {
          'ssid': ssid,
          'result': foundPassword != null ? "匹配成功" : "无匹配",
          'password': foundPassword ?? "",
          'time': DateTime.now().toString().substring(11, 19),
        });
      });

      await Future.delayed(const Duration(milliseconds: 1000));
    }

    setState(() {
      _isRunning = false;
      _currentStatus = "所选任务执行完毕";
    });
  }

  void _showMsg(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Color _getSignalColor(int level) {
    if (level > -60) return Colors.green;
    if (level > -80) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("全部 WiFi 模式"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: (_isRunning || _isScanning) ? null : _refreshWifiList,
          )
        ],
      ),
      body: Column(
        children: [
          // 状态及进度显示
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.blue.withOpacity(0.05),
            child: Column(
              children: [
                Text(_currentStatus, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: _totalProgress),
              ],
            ),
          ),
          
          // 1. 待选列表（带勾选和全选）
          if (_availableTasks.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: CheckboxListTile(
                title: const Text("全选可用网络", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                value: _availableTasks.every((t) => t.isSelected),
                onChanged: _isRunning ? null : _toggleAll,
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ),
          
          Expanded(
            flex: 3,
            child: _availableTasks.isEmpty 
              ? Center(child: _isScanning ? const CircularProgressIndicator() : const Text("暂无扫描结果"))
              : ListView.builder(
                  itemCount: _availableTasks.length,
                  itemBuilder: (context, index) {
                    final task = _availableTasks[index];
                    return CheckboxListTile(
                      enabled: !_isRunning,
                      title: Text(task.ssid, style: const TextStyle(fontSize: 15)),
                      subtitle: Text("信号强度: ${task.level} dBm"),
                      secondary: Icon(Icons.wifi, color: _getSignalColor(task.level)),
                      value: task.isSelected,
                      onChanged: (val) => setState(() => task.isSelected = val!),
                    );
                  },
                ),
          ),

          const Divider(height: 1, thickness: 2),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Text("运行日志", style: TextStyle(color: Colors.grey, fontSize: 12)),
          ),

          // 2. 运行结果日志
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.black.withOpacity(0.02),
              child: _results.isEmpty
                  ? const Center(child: Text("尚未开始任务", style: TextStyle(fontSize: 12, color: Colors.grey)))
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final item = _results[index];
                        bool isSuccess = item['result'] == "匹配成功";
                        return ListTile(
                          dense: true,
                          leading: Icon(isSuccess ? Icons.key : Icons.close, color: isSuccess ? Colors.green : Colors.red, size: 20),
                          title: SelectableText("${item['ssid']} -> ${item['result']}"),
                          subtitle: isSuccess ? SelectableText("密码: ${item['password']}", style: const TextStyle(fontWeight: FontWeight.bold)) : null,
                          trailing: Text(item['time']!, style: const TextStyle(fontSize: 10)),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isRunning ? () => setState(() => _isRunning = false) : _runSelectedTasks,
        label: Text(_isRunning ? "停止" : "启动勾选任务"),
        icon: Icon(_isRunning ? Icons.stop : Icons.play_arrow),
      ),
    );
  }
}
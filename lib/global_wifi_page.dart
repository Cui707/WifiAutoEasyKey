import 'package:flutter/material.dart';
import 'wifi_service.dart'; 
import 'db_helper.dart'; 
import 'package:wifi_scan/wifi_scan.dart'; 

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

  List<WifiTask> _availableTasks = []; // 待选列表
  List<Map<String, String>> _results = []; // 运行结果日志
  
  bool _isRunning = false;
  bool _isScanning = false;
  String _currentStatus = "准备就绪";
  
  // 进度控制变量
  double _totalProgress = 0.0;    
  double _innerProgress = 0.0;    
  String _activeSsid = "";        // 正在轮询的 WiFi 名字
  String _currentPwdText = "";    
  String _innerCountText = "";    

  @override
  void initState() {
    super.initState();
    _refreshWifiList(); 
  }

  void _refreshWifiList() async {
    if (_isRunning) return;
    setState(() {
      _isScanning = true;
      _currentStatus = "正在扫描周围 WiFi...";
      _availableTasks.clear();
    });

    try {
      await WiFiScan.instance.startScan();
      await Future.delayed(const Duration(seconds: 2));
      final accessPoints = await WiFiScan.instance.getScannedResults();

      setState(() {
        Map<String, WifiTask> distinctTasks = {};
        for (var ap in accessPoints) {
          if (ap.ssid.isEmpty) continue;
          if (!distinctTasks.containsKey(ap.ssid) || ap.level > distinctTasks[ap.ssid]!.level) {
            distinctTasks[ap.ssid] = WifiTask(ssid: ap.ssid, level: ap.level);
          }
        }
        _availableTasks = distinctTasks.values.toList();
        _availableTasks.sort((a, b) => b.level.compareTo(a.level));
        _isScanning = false;
        _currentStatus = _availableTasks.isEmpty ? "未发现 WiFi" : "扫描完成，请选择目标";
      });
    } catch (e) {
      _showMsg("扫描失败: $e");
      setState(() => _isScanning = false);
    }
  }

  void _toggleAll(bool? value) {
    setState(() {
      for (var task in _availableTasks) {
        task.isSelected = value ?? false;
      }
    });
  }

  void _runSelectedTasks() async {
    final tasksToRun = _availableTasks.where((t) => t.isSelected).toList();
    if (tasksToRun.isEmpty) {
      _showMsg("请先勾选目标");
      return;
    }

    final passwords = await _dbHelper.getPasswords();
    if (passwords.isEmpty) {
      _showMsg("密码库为空");
      return;
    }

    setState(() {
      _isRunning = true;
      _results.clear();
      _totalProgress = 0.0;
    });

    // 绑定进度回调
    _wifiService.onProgress = (pwd, index, total) {
      if (mounted && _isRunning) {
        setState(() {
          _currentPwdText = pwd;
          _innerCountText = "$index / $total";
          _innerProgress = index / total;
        });
      }
    };

    for (int i = 0; i < tasksToRun.length; i++) {
      if (!_isRunning) break;

      String ssid = tasksToRun[i].ssid;
      setState(() {
        _activeSsid = ssid; // 记录当前正在跑的 WiFi 名
        _currentStatus = "总进度: ${i + 1} / ${tasksToRun.length}";
        _totalProgress = i / tasksToRun.length;
      });

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
      _totalProgress = 1.0;
      _innerProgress = 0.0;
      _currentStatus = "全部扫描任务完成";
      _activeSsid = "";
      _currentPwdText = "";
    });
    
    _wifiService.onProgress = null;
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
          // --- 状态监控面板 ---
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              border: const Border(bottom: BorderSide(color: Colors.black12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. 总任务状态
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_currentStatus, style: const TextStyle(fontWeight: FontWeight.bold)),
                    if (_isRunning) Text("${(_totalProgress * 100).toInt()}%"),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: _totalProgress),
                
                // 2. 当前子任务详情（运行时显示）
                if (_isRunning) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12.0),
                    child: Divider(height: 1),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.router, size: 16, color: Colors.blueGrey),
                      const SizedBox(width: 8),
                      const Text("当前目标: ", style: TextStyle(fontSize: 13, color: Colors.blueGrey)),
                      // 这里就是你需要的正在轮询的 WiFi 名字
                      Expanded(
                        child: Text(_activeSsid, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blue)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("尝试密码: $_currentPwdText", style: const TextStyle(fontSize: 12, color: Colors.orange)),
                      Text(_innerCountText, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: _innerProgress, 
                    backgroundColor: Colors.grey.shade300,
                    color: Colors.orange,
                  ),
                ],
              ],
            ),
          ),
          
          // 待选列表
          if (!_isRunning) ...[
            if (_availableTasks.isNotEmpty)
              CheckboxListTile(
                title: const Text("全选", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                value: _availableTasks.every((t) => t.isSelected),
                onChanged: _toggleAll,
                controlAffinity: ListTileControlAffinity.leading,
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
                        title: Text(task.ssid),
                        subtitle: Text("${task.level} dBm"),
                        secondary: Icon(Icons.wifi, color: _getSignalColor(task.level)),
                        value: task.isSelected,
                        onChanged: (val) => setState(() => task.isSelected = val!),
                      );
                    },
                  ),
            ),
          ],

          const Divider(height: 1),

          // 运行日志记录
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.black.withOpacity(0.02),
              child: _results.isEmpty
                  ? const Center(child: Text("等待任务启动...", style: TextStyle(color: Colors.grey, fontSize: 12)))
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final item = _results[index];
                        bool isSuccess = item['result'] == "匹配成功";
                        return ListTile(
                          dense: true,
                          leading: Icon(isSuccess ? Icons.key : Icons.close, color: isSuccess ? Colors.green : Colors.red, size: 18),
                          title: SelectableText("${item['ssid']} - ${item['result']}"),
                          subtitle: isSuccess ? SelectableText("密码: ${item['password']}") : null,
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
        label: Text(_isRunning ? "停止" : "启动全量模式"),
        icon: Icon(_isRunning ? Icons.stop : Icons.play_arrow),
      ),
    );
  }
}
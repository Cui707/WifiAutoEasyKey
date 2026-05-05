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

      // --- 关键点：在这里获取结果 ---
      String? foundPassword = await _wifiService.startBruteForce(ssid);

      final historyItem = {
          'ssid': ssid,
          'result': foundPassword != null ? "匹配成功" : "无匹配",
          'password': foundPassword ?? "",
          'time': DateTime.now().toString().substring(0, 19),
        };

        // 给数据库操作加保险
        try {
          await _dbHelper.insertHistory(historyItem);
        } catch (e) {
          // 如果数据库报错，只在控制台打印，不中断程序
          print("数据库写入失败: $e");
        }

        // 更新 UI 列表（即使数据库失败，UI 也要显示结果）
        setState(() {
          _results.insert(0, historyItem);
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

void _viewHistory() async {
    final history = await _dbHelper.getHistory();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // 允许弹窗高度超过半屏
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75, // 占屏幕 75% 高度
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("持久化历史记录", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                TextButton.icon(
                  onPressed: () {
                    _dbHelper.clearHistory();
                    Navigator.pop(context);
                    _showMsg("历史记录已清空");
                  },
                  icon: const Icon(Icons.delete_sweep, size: 18),
                  label: const Text("清空"),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: history.isEmpty
                  ? const Center(child: Text("本地数据库无记录", style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: history.length,
                      itemBuilder: (context, index) {
                        final item = history[index];
                        bool isSuccess = item['result'] == "匹配成功";
                        return ListTile(
                          dense: true,
                          leading: Icon(isSuccess ? Icons.offline_pin : Icons.history_toggle_off, 
                                       color: isSuccess ? Colors.green : Colors.grey),
                          title: SelectableText(item['ssid'].toString()),
                          subtitle: Text("${item['time']}\n${isSuccess ? '密码: ' + item['password'].toString() : '未匹配'}"),
                          isThreeLine: isSuccess,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
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
            tooltip: '刷新列表',
          ),
          IconButton(
            icon: const Icon(Icons.history), // 使用历史记录图标
            tooltip: '查看扫描历史',
            onPressed: (_isRunning || _isScanning) ? null : _viewHistory,
          ),
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
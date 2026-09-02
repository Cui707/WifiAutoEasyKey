import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'db_helper.dart';
import 'json_importer.dart';

class PasswordVaultPage extends StatefulWidget {
  const PasswordVaultPage({super.key});

  @override
  State<PasswordVaultPage> createState() => _PasswordVaultPageState();
}

class _PasswordVaultPageState extends State<PasswordVaultPage> {
  final DbHelper _dbHelper = DbHelper();
  final TextEditingController _controller = TextEditingController();
  List<Map<String, dynamic>> _passwords = [];
  List<Map<String, dynamic>> _libraries = [];
  int? _selectedLibraryId;

  @override
  void initState() {
    super.initState();
    _refreshPasswords();
  }

  void _refreshPasswords() async {
    final data = await _dbHelper.getPasswords();
    setState(() {
      _passwords = data;
    });
  }

  void _addPassword() async {
    if (_controller.text.isNotEmpty) {
      await _dbHelper.insertPassword(_controller.text);
      _controller.clear();
      _refreshPasswords();
    }
  }

  void _deletePassword(int id) async {
    await _dbHelper.deletePassword(id);
    _refreshPasswords();
  }

  void _showJsonImportDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('JSON批量导入密码'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                maxLines: 8,
                decoration: const InputDecoration(
                  hintText: '粘贴JSON格式的密码数组...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  controller.text = JsonImporter.getJsonFormatExample();
                },
                child: const Text('使用示例格式'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final jsonString = controller.text;
              if (jsonString.isNotEmpty) {
                JsonImporter.importPasswordsFromJson(jsonString, libraryId: _selectedLibraryId);
                Navigator.pop(context);
                _refreshPasswords();
              }
            },
            child: const Text('导入'),
          ),
        ],
      ),
    );
  }

  void _clearCurrentPasswords() async {
    // 显示确认对话框
    bool? confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认清空密码'),
        content: const Text('确定要清空当前密码库中的所有密码吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      await _dbHelper.resetToDefault(); // 使用现有的resetToDefault方法
      _refreshPasswords();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('密码库已清空')),
        );
      }
    }
  }

  void _showAIPromptDialog() {
    final ssidController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('生成AI密码提示词'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ssidController,
              decoration: const InputDecoration(
                hintText: '输入Wi-Fi名称(SSID)...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final ssid = ssidController.text;
              if (ssid.isNotEmpty) {
                final prompt = _generateAIPrompt(ssid);
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('AI密码提示词'),
                    content: SingleChildScrollView(
                      child: SelectableText(prompt),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: prompt));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('提示词已复制到剪贴板')),
                          );
                          Navigator.pop(context);
                        },
                        child: const Text('复制提示词'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('关闭'),
                      ),
                    ],
                  ),
                );
              }
            },
            child: const Text('生成提示词'),
          ),
        ],
      ),
    );
  }

String _generateAIPrompt(String ssid) {
    return """
我出差很久刚回家，我忘记了自己设置的Wi-Fi密码，并且我不能重置路由器重新配置网络。请你根据我的Wi-Fi名称帮助我生成一些可能的密码：

Wi-Fi名称(SSID): $ssid

请基于以下要求生成尽可能多的密码猜测：

1. **基础密码组合**:
    - 数字组合
    - 字母组合
    - 特殊字符：!@#\$%^&*()_+

2. **Wi-Fi名称分析**:
   - 从SSID "$ssid" 中提取的潜在信息
   - 可能的用户习惯或个人信息

3. **综合策略**:
   - 结合数字、字母、特殊字符的复杂组合（不要用有中文汉字）
   - 常见密码模式（如"88888888"、"12345678"等）
   - 用户可能设置的个性化密码

4. **高级分析建议**:
   注意尝试从该WIFI的名称中分析出该路由器的厂家，并通过网络查询该厂家路由器的默认密码。

请生成尽可能多的密码，不限字数、不限英文和数字和符号组合方式，越多越好！
注意：密码字符数不小于8位，即大于等于8位字符数。

**返回格式要求**:
请以JSON格式返回分析结果。不用跟我说任何其他的话，就直接给我一个纯净的json代码块，里面是你推测的全部可能密码，不需要对它们进行分组。
""";
}

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        
        // 密码输入区域
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: '输入单个密码添加',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _addPassword,
                    child: const Icon(Icons.add),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Flexible(
                    flex: 1, // 统一宽度比例
                    child: ElevatedButton(
                      onPressed: _showJsonImportDialog,
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(0, 36), // 确保最小高度
                      ),
                      child: const Text('JSON批量导入'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    flex: 1, // 统一宽度比例
                    child: ElevatedButton(
                      onPressed: _showAIPromptDialog,
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(0, 36), // 确保最小高度
                      ),
                      child: const Text('生成AI提示词'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    flex: 1, // 统一宽度比例
                    child: ElevatedButton(
                      onPressed: _clearCurrentPasswords,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        minimumSize: Size(60, 36), // 设置最小宽度为60
                      ),
                      child: const Text('清空密码'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // 密码列表
        Expanded(
          child: ListView.builder(
            itemCount: _passwords.length,
            itemBuilder: (context, index) {
              return ListTile(
                leading: const Icon(Icons.lock_outline),
                title: Text(_passwords[index]['content']),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  onPressed: () => _deletePassword(_passwords[index]['id']),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
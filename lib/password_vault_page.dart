import 'package:flutter/material.dart';
import 'db_helper.dart';

class PasswordVaultPage extends StatefulWidget {
  const PasswordVaultPage({super.key});

  @override
  State<PasswordVaultPage> createState() => _PasswordVaultPageState();
}

class _PasswordVaultPageState extends State<PasswordVaultPage> {
  final DbHelper _dbHelper = DbHelper();
  final TextEditingController _controller = TextEditingController();
  List<Map<String, dynamic>> _passwords = [];

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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    hintText: '输入猜测的密码...',
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
        ),
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
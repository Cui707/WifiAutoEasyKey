import 'package:flutter/material.dart';
import 'password_vault_page.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // 对应你的四个选项
  static const List<Widget> _widgetOptions = <Widget>[
      const Center(child: Text('选中单个 WiFi 模式')),
      const Center(child: Text('全部 WiFi 轮询模式')),
      const PasswordVaultPage(), // 接入这里
      const Center(child: Text('关于 WifiAutoEasyKey')),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WifiAutoEasyKey'),
        centerTitle: true,
        elevation: 2,
      ),
      body: _widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed, // 四个选项时建议固定展示
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.wifi_find),
            label: '单个WiFi',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.wifi_tethering),
            label: '全部WiFi',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.vpn_key),
            label: '密码库',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.info_outline),
            label: '关于',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blueAccent,
        onTap: _onItemTapped,
      ),
    );
  }
}
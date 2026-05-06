import 'package:flutter/material.dart';
import 'password_vault_page.dart';
import 'single_wifi_page.dart';
import 'global_wifi_page.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // 对应你的四个选项
    static final List<Widget> _widgetOptions = <Widget>[
      const SingleWifiPage(), // 接入扫描页面
      const GlobalWiFiPage(),
      const PasswordVaultPage(),
      const Center(child: Text('WifiAutoEasyKey。基于Flutter的wifi白嫖工具。内置密码库，放置常见wifi密码，对设备扫描到的未连接wifi进行自动轮询尝试。在“密码库”中，可以对库中密码进行增删。在新环境下首次使用“全部WIFI”功能时，先在“单个WIFI”界面逐个点击所有WIFI，触发系统连接申请后，同意并手动结束轮询，之后即可在“全部WIFI”中全自动轮询所有WIFI。')),
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
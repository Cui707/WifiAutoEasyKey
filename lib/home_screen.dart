import 'package:flutter/material.dart';
import 'password_vault_page.dart';
import 'single_wifi_page.dart';
import 'global_wifi_page.dart';
import 'wifi_service.dart';
import 'db_helper.dart';
import 'about_page.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final WifiService _wifiService = WifiService();
  final DbHelper _dbHelper = DbHelper();

// 对应你的三个选项
    static final List<Widget> _widgetOptions = <Widget>[
      const SingleWifiPage(), // 接入扫描页面
      const GlobalWiFiPage(),
      const PasswordVaultPage(),
    ];

  @override
  void initState() {
    super.initState();
    _initializeDefaultLibrary();
  }

  Future<void> _initializeDefaultLibrary() async {
    final defaultLibraryId = await _dbHelper.getDefaultLibraryId();
    _wifiService.setSelectedLibrary(defaultLibraryId);
  }

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
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AboutPage()),
              );
            },
          ),
        ],
      ),
      body: _widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed, // 三个选项时建议固定展示
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
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blueAccent,
        onTap: _onItemTapped,
      ),
    );
  }
}
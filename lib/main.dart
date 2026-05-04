import 'package:flutter/material.dart';
import 'home_screen.dart';

void main() {
  runApp(const WifiAutoEasyKeyApp());
}

class WifiAutoEasyKeyApp extends StatelessWidget {
  const WifiAutoEasyKeyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WifiAutoEasyKey',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blueAccent, // 使用工程感较强的蓝色调
        brightness: Brightness.light,
      ),
      home: const HomeScreen(),
    );
  }
}
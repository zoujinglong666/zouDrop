import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'MainPage.dart';
import 'login/index.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    try {
      await Future.delayed(const Duration(milliseconds: 100)); // 启动缓冲
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (!mounted) return; // 确保页面仍在树中
      final targetPage = (token != null && token.isNotEmpty)
          ? const MainPage()
          : const MainPage();

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => targetPage),
      );
    } catch (e) {
      debugPrint('启动时发生错误: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('初始化失败，请重启 App')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 8),
            Text('正在加载...', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

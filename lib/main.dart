import 'package:flutter/material.dart';
import 'package:zou_drop/pages/SplashPage.dart';

import 'common/Prefs.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Prefs.init(); // 初始化
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '开发模板',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const SplashPage(), // 修改为跳转逻辑页
    );
  }
}

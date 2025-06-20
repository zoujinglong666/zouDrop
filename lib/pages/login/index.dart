import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../MainPage.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _rememberMe = false;
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    _rememberMe = prefs.getBool('remember') ?? false;
    if (_rememberMe) {
      _usernameController.text = prefs.getString('username') ?? '';
      _passwordController.text = prefs.getString('password') ?? '';
      setState(() {});
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    FocusScope.of(context).unfocus(); // 收起键盘

    await Future.delayed(const Duration(seconds: 1));

    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    final prefs = await SharedPreferences.getInstance();

    if (_rememberMe) {
      await prefs.setString('username', username);
      await prefs.setString('password', password);
    } else {
      await prefs.remove('username');
      await prefs.remove('password');
    }

    // 模拟登录成功，存 token
    await prefs.setBool('remember', _rememberMe);
    await prefs.setString('token', username);

    setState(() => _isLoading = false);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const Icon(Icons.lock, size: 80, color: Colors.blueAccent),
                const SizedBox(height: 16),
                const Text('登录', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),

                // 用户名
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: '用户名',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                  value == null || value.trim().isEmpty ? '请输入用户名' : null,
                ),
                const SizedBox(height: 16),

                // 密码
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  decoration: InputDecoration(
                    labelText: '密码',
                    prefixIcon: const Icon(Icons.lock),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                    ),
                  ),
                  validator: (value) =>
                  value == null || value.isEmpty ? '请输入密码' : null,
                ),
                const SizedBox(height: 12),

                // 记住密码
                Row(
                  children: [
                    Checkbox(
                      value: _rememberMe,
                      onChanged: (val) => setState(() => _rememberMe = val ?? false),
                    ),
                    const Text('记住密码'),
                  ],
                ),
                const SizedBox(height: 16),

                // 登录按钮
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2)
                        : const Text('登录', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

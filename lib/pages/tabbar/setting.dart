import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:file_picker/file_picker.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _nameCtr = TextEditingController();
  final TextEditingController _portCtr = TextEditingController();
  final TextEditingController _udpPortCtr = TextEditingController(); // ✅ 新增
  final TextEditingController _tcpPortCtr = TextEditingController(); // ✅ 新增

  bool quickSave = false;
  bool autoFinish = true;
  bool saveToGallery = false;
  String savePath = '/storage/emulated/0/Download';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }
  Future<void> _loadSettings() async {
    final sp = await SharedPreferences.getInstance();
    setState(() {
      _nameCtr.text = sp.getString('deviceName') ?? '我的设备';
      _portCtr.text = (sp.getInt('port') ?? 53321).toString();
      _udpPortCtr.text = (sp.getInt('udpPort') ?? 4567).toString(); // ✅ 新增
      _tcpPortCtr.text = (sp.getInt('tcpPort') ?? 5000).toString(); // ✅ 新增
      quickSave = sp.getBool('quickSave') ?? false;
      autoFinish = sp.getBool('autoFinish') ?? true;
      saveToGallery = sp.getBool('saveToGallery') ?? false;
      savePath = sp.getString('savePath') ?? savePath;
    });
  }

  Future<void> _saveSetting(String key, dynamic val) async {
    final sp = await SharedPreferences.getInstance();
    if (val is String) await sp.setString(key, val);
    if (val is bool) await sp.setBool(key, val);
    if (val is int) await sp.setInt(key, val);
  }

  void _updatePort(String key, String value) {
    final int? newPort = int.tryParse(value);
    if (newPort != null && newPort >= 1024 && newPort <= 65535) {
      _saveSetting(key, newPort);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$key 已保存')));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入有效的端口号（1024-65535）')));
    }
  }

  Future<void> _pickFolder() async {
    // String? path = await FilePicker.platform.getDirectoryPath();
    // if (path != null && path.isNotEmpty) {
    //   setState(() => savePath = path);
    //   _saveSetting('savePath', path);
    // }
  }

  @override
  void dispose() {
    _nameCtr.dispose();
    _portCtr.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSettingCard(
            title: '设备名称',
            child: TextField(
              controller: _nameCtr,
              decoration: const InputDecoration(
                hintText: '输入设备名称',
                border: InputBorder.none,
              ),
              onSubmitted: (v) => _saveSetting('deviceName', v),
            ),
          ),
          const SizedBox(height: 16),
          _buildSettingCard(
            title: 'UDP 广播端口',
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _udpPortCtr,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: '1024 ~ 65535',
                      border: InputBorder.none,
                    ),
                    onSubmitted: (v) => _updatePort('udpPort', v),
                  ),
                ),
                _buildGradientButton(
                  text: '保存',
                  onTap: () => _updatePort('udpPort', _udpPortCtr.text),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildSettingCard(
            title: 'TCP 监听端口',
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tcpPortCtr,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: '1024 ~ 65535',
                      border: InputBorder.none,
                    ),
                    onSubmitted: (v) => _updatePort('tcpPort', v),
                  ),
                ),
                _buildGradientButton(
                  text: '保存',
                  onTap: () => _updatePort('tcpPort', _tcpPortCtr.text),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildSwitchCard(
            title: '快速接收',
            subtitle: '启用后自动接收文件，无需确认',
            value: quickSave,
            onChanged: (v) {
              setState(() => quickSave = v);
              _saveSetting('quickSave', v);
            },
          ),
          const SizedBox(height: 16),
          _buildSwitchCard(
            title: '自动完成',
            subtitle: '传输完成后自动关闭对话框',
            value: autoFinish,
            onChanged: (v) {
              setState(() => autoFinish = v);
              _saveSetting('autoFinish', v);
            },
          ),
          const SizedBox(height: 16),
          _buildSwitchCard(
            title: '保存到相册',
            subtitle: '如果是图片/视频，保存到系统相册',
            value: saveToGallery,
            onChanged: (v) {
              setState(() => saveToGallery = v);
              _saveSetting('saveToGallery', v);
            },
          ),
          const SizedBox(height: 16),
          _buildSettingCard(
            title: '默认保存路径',
            child: Row(
              children: [
                Expanded(child: Text(savePath, style: const TextStyle(fontSize: 14))),
                _buildGradientButton(
                  text: '修改',
                  onTap: _pickFolder,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSettingCard(
            title: '后台服务',
            child: _buildGradientButton(
              text: '重启服务',
              onTap: () {
                // TODO: 服务控制逻辑
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingCard({required String title, required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 0),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF00D4FF),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _buildSwitchCard({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF00D4FF),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF888888)),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.white,
            activeTrackColor: const Color(0xFF00D4FF),
          ),
        ],
      ),
    );
  }

  Widget _buildGradientButton({required String text, required VoidCallback onTap}) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00D4FF), Color(0xFF0099CC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

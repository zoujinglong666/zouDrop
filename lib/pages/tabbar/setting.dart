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
      _udpPortCtr.text = (sp.getInt('udpPort') ?? 53321).toString(); // ✅ 新增
      _tcpPortCtr.text = (sp.getInt('tcpPort') ?? 53322).toString(); // ✅ 新增
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
        children: [
          ListTile(
            title: const Text('设备名称'),
            subtitle: TextField(
              controller: _nameCtr,
              decoration: const InputDecoration(hintText: '输入设备名称'),
              onSubmitted: (v) => _saveSetting('deviceName', v),
            ),
          ),
          ListTile(
            title: const Text('UDP 广播端口'),
            subtitle: TextField(
              controller: _udpPortCtr,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: '1024 ~ 65535'),
              onSubmitted: (v) => _updatePort('udpPort', v),
            ),
            trailing: ElevatedButton(
              onPressed: () => _updatePort('udpPort', _udpPortCtr.text),
              child: const Text('保存'),
            ),
          ),
          ListTile(
            title: const Text('TCP 监听端口'),
            subtitle: TextField(
              controller: _tcpPortCtr,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: '1024 ~ 65535'),
              onSubmitted: (v) => _updatePort('tcpPort', v),
            ),
            trailing: ElevatedButton(
              onPressed: () => _updatePort('tcpPort', _tcpPortCtr.text),
              child: const Text('保存'),
            ),
          ),
          SwitchListTile(
            title: const Text('快速接收'),
            subtitle: const Text('启用后自动接收文件，无需确认'),
            value: quickSave,
            onChanged: (v) {
              setState(() => quickSave = v);
              _saveSetting('quickSave', v);
            },
          ),
          SwitchListTile(
            title: const Text('自动完成'),
            subtitle: const Text('传输完成后自动关闭对话框'),
            value: autoFinish,
            onChanged: (v) {
              setState(() => autoFinish = v);
              _saveSetting('autoFinish', v);
            },
          ),
          SwitchListTile(
            title: const Text('保存到相册'),
            subtitle: const Text('如果是图片/视频，保存到系统相册'),
            value: saveToGallery,
            onChanged: (v) {
              setState(() => saveToGallery = v);
              _saveSetting('saveToGallery', v);
            },
          ),
          ListTile(
            title: const Text('默认保存路径'),
            subtitle: Text(savePath),
            trailing: ElevatedButton(
              onPressed: _pickFolder,
              child: const Text('修改'),
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text('后台服务'),
            trailing: ElevatedButton(
              onPressed: () {
                // TODO: 服务控制逻辑
              },
              child: const Text('重启服务'),
            ),
          ),
        ],
      ),
    );
  }
}

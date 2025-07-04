import 'dart:io';
import 'dart:math' as Math;
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:udp/udp.dart';
import 'dart:convert';
import '../../common/Prefs.dart'; // 添加Prefs导入

// 文件历史记录模型
class FileHistory {
  final String fileName;
  final String fileSize;
  final String deviceName;
  final String deviceIp;
  final DateTime sendTime;

  FileHistory({
    required this.fileName,
    required this.fileSize,
    required this.deviceName,
    required this.deviceIp,
    required this.sendTime,
  });

  // 转换为JSON
  Map<String, dynamic> toJson() => {
    'fileName': fileName,
    'fileSize': fileSize,
    'deviceName': deviceName,
    'deviceIp': deviceIp,
    'sendTime': sendTime.toIso8601String(),
  };

  // 从JSON创建对象
  factory FileHistory.fromJson(Map<String, dynamic> json) => FileHistory(
    fileName: json['fileName'],
    fileSize: json['fileSize'],
    deviceName: json['deviceName'],
    deviceIp: json['deviceIp'],
    sendTime: DateTime.parse(json['sendTime']),
  );
}

class DeviceInfo {
  final String name;
  final String ip;
  final int port;

  DeviceInfo({required this.name, required this.ip, required this.port});
}

class DeviceSearchPage extends StatefulWidget {
  const DeviceSearchPage({super.key});

  @override
  State<DeviceSearchPage> createState() => _DeviceSearchPageState();
}

class _DeviceSearchPageState extends State<DeviceSearchPage>
    with SingleTickerProviderStateMixin {
  List<DeviceInfo> devices = [];
  bool isLoading = true;
  bool isUploading = false;
  double uploadProgress = 0.0;
  String currentFileName = "";
  String currentFileSize = "";
  bool showUploadSuccess = false;
  List<FileHistory> fileHistory = []; // 添加发送历史列表

  late TabController _tabController;
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _tabIndex = _tabController.index;
      });
    });
    discoverDevices();
    _loadFileHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // 加载发送历史
  Future<void> _loadFileHistory() async {
    final historyJson = Prefs.get('file_send_history');
    if (historyJson != null && historyJson is List) {
      setState(() {
        fileHistory =
            historyJson
                .map((item) => FileHistory.fromJson(item))
                .toList()
                .cast<FileHistory>();
        // 按时间倒序排列
        fileHistory.sort((a, b) => b.sendTime.compareTo(a.sendTime));
      });
    }
  }

  // 保存发送历史
  Future<void> _saveFileHistory() async {
    final historyJson = fileHistory.map((history) => history.toJson()).toList();
    await Prefs.set('file_send_history', historyJson);
  }

  // 添加发送历史记录
  void _addToHistory(DeviceInfo device) {
    final history = FileHistory(
      fileName: currentFileName,
      fileSize: currentFileSize,
      deviceName: device.name,
      deviceIp: device.ip,
      sendTime: DateTime.now(),
    );

    setState(() {
      fileHistory.insert(0, history); // 添加到列表开头
      // 限制历史记录数量，最多保存50条
      if (fileHistory.length > 50) {
        fileHistory = fileHistory.sublist(0, 50);
      }
    });

    _saveFileHistory(); // 保存到本地存储
  }

  // 清空历史记录
  Future<void> _clearHistory() async {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("清空历史记录"),
            content: const Text("确定要清空所有发送历史记录吗？"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("取消"),
              ),
              TextButton(
                onPressed: () {
                  setState(() => fileHistory.clear());
                  _saveFileHistory();
                  Navigator.pop(context);
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('历史记录已清空')));
                },
                child: const Text("确定", style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );
  }

  Future<void> discoverDevices() async {
    setState(() {
      isLoading = true;
      devices.clear();
    });

    try {
      final sender = await UDP.bind(Endpoint.any(port: Port(0)));
      final broadcast = Endpoint.broadcast(port: Port(5678));
      const message = "ZOU_DROP_DISCOVERY";
      await sender.send(message.codeUnits, broadcast);

      final found = <DeviceInfo>[];
      final startTime = DateTime.now();

      await for (final datagram in sender.asStream(
        timeout: Duration(seconds: 3),
      )) {
        if (datagram == null) break;

        final data = utf8.decode(datagram.data);
        try {
          final json = jsonDecode(data);
          if (json is Map<String, dynamic> &&
              json.containsKey("name") &&
              json.containsKey("ipList") &&
              json.containsKey("port")) {
            final ipList = (json['ipList'] as List).cast<String>();
            for (final ip in ipList) {
              found.add(
                DeviceInfo(name: json['name'], ip: ip, port: json['port']),
              );
            }
          }
        } catch (_) {}
        if (DateTime.now().difference(startTime).inSeconds >= 3) break;
      }

      sender.close();

      setState(() {
        devices = found;
        isLoading = false;
      });
    } catch (e) {
      print("UDP error: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  void handleDeviceTap(DeviceInfo device) {
    // TODO: 发起 WebSocket 或 HTTP 请求连接
    print("点击连接: ${device.name} ${device.ip}:${device.port}");
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('连接到 ${device.name}')));
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return "0 B";

    const units = ['B', 'KB', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB', 'YB'];
    int i = (bytes == 0) ? 0 : (Math.log(bytes) / Math.log(1024)).floor();

    double size = bytes / Math.pow(1024, i);
    return '${size.toStringAsFixed(2)} ${units[i]}';
  }

  Future<void> sendFileViaTcp(DeviceInfo device) async {
    const XTypeGroup anyType = XTypeGroup(label: '所有文件', extensions: ['*']);
    final XFile? pickedFile = await openFile(acceptedTypeGroups: [anyType]);

    if (pickedFile == null) return;

    final file = File(pickedFile.path);
    if (!await file.exists()) return;

    final fileName = pickedFile.name;
    final fileSize = await file.length();
    final formattedSize = _formatFileSize(fileSize);

    setState(() {
      isUploading = true;
      uploadProgress = 0.0;
      currentFileName = fileName;
      currentFileSize = formattedSize;
      showUploadSuccess = false;
    });

    try {
      final socket = await Socket.connect(
        '10.9.17.94',
        9999,
        timeout: const Duration(seconds: 5),
      );

      // ===== ✅ 添加 header =====
      final header = {'filename': fileName, 'filesize': fileSize};
      final headerJson = utf8.encode(jsonEncode(header));
      final headerLength = ByteData(4)..setUint32(0, headerJson.length);

      // 写入 header 长度 + header json
      socket.add(headerLength.buffer.asUint8List());
      socket.add(headerJson);

      // ===== ✅ 发送文件内容 =====
      final fileStream = file.openRead();
      int sent = 0;

      // 使用分块读取并更新进度
      const int chunkSize = 64 * 1024; // 64KB 块大小
      final raf = file.openSync();

      try {
        while (sent < fileSize) {
          final chunk = raf.readSync(
            fileSize - sent > chunkSize ? chunkSize : fileSize - sent,
          );
          socket.add(chunk);
          sent += chunk.length;
          setState(() => uploadProgress = sent / fileSize); // 更新进度
        }
        print("📤 文件发送完成，总大小: $fileSize bytes");
      } finally {
        raf.closeSync();
        setState(() {
          uploadProgress = 1.0;
          isUploading = false;
          showUploadSuccess = true;
        });

        // 添加到发送历史
          _addToHistory(device);

        // 3秒后隐藏成功提示
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() => showUploadSuccess = false);
          }
        });
      }

      await socket.flush();
      await socket.close();
    } catch (e) {
      print("❌ 发送失败: $e");
      setState(() {
        isUploading = false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('文件发送失败: $e'), backgroundColor: Colors.red),
        );
      });
    }
  }

  // 格式化日期时间
  String _formatDateTime(DateTime dateTime) {
    return "${dateTime.year}-${_twoDigits(dateTime.month)}-${_twoDigits(dateTime.day)} ${_twoDigits(dateTime.hour)}:${_twoDigits(dateTime.minute)}";
  }

  // 将数字格式化为两位数
  String _twoDigits(int n) {
    if (n >= 10) return "$n";
    return "0$n";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("文件传输"),
        backgroundColor: const Color(0xFF0099CC),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
          unselectedLabelStyle: const TextStyle(fontSize: 16),
          tabs: const [
            Tab(text: "设备", icon: Icon(Icons.devices)),
            Tab(text: "历史", icon: Icon(Icons.history)),
          ],
        ),
        actions: [
          _tabIndex == 0
              ? IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: discoverDevices,
                tooltip: "刷新设备",
              )
              : IconButton(
                icon: const Icon(Icons.delete_sweep),
                onPressed: fileHistory.isEmpty ? null : _clearHistory,
                tooltip: "清空历史",
              ),
        ],
      ),
      body: Stack(
        children: [
          // 主内容 - TabBarView
          TabBarView(
            controller: _tabController,
            children: [
              // 设备列表页
              _buildDevicesView(),
              // 历史记录页
              _buildHistoryView(),
            ],
          ),

          // 上传进度条覆盖层
          if (isUploading)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: Center(
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.85,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.upload_file,
                          size: 48,
                          color: Color(0xFF0099CC),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "上传文件中...",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "$currentFileName ($currentFileSize)",
                          style: TextStyle(color: Colors.grey[600]),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        LinearProgressIndicator(
                          value: uploadProgress,
                          backgroundColor: Colors.grey[200],
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF0099CC),
                          ),
                          minHeight: 10,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "${(uploadProgress * 100).toStringAsFixed(1)}%",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // 上传成功提示
          if (showUploadSuccess)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: Center(
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.85,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle,
                          size: 64,
                          color: Colors.green,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "上传成功!",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "$currentFileName 已成功发送",
                          style: TextStyle(color: Colors.grey[600]),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // 构建设备列表视图
  Widget _buildDevicesView() {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF0099CC)),
      );
    }

    if (devices.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.devices_other, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              "未发现设备",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "请确保设备在同一网络下并已启动应用",
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: discoverDevices,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0099CC),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text("重新搜索"),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: devices.length,
      itemBuilder: (context, index) {
        final device = devices[index];
        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF0099CC).withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.devices,
                color: Color(0xFF0099CC),
                size: 28,
              ),
            ),
            title: Text(
              device.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Text(
              "${device.ip}:${device.port}",
              style: TextStyle(color: Colors.grey[600]),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.send, color: Color(0xFF0099CC)),
              onPressed: () => sendFileViaTcp(device),
              tooltip: "发送文件",
            ),
            onTap: () => sendFileViaTcp(device),
          ),
        );
      },
    );
  }

  // 构建历史记录视图
  Widget _buildHistoryView() {
    if (fileHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.history, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              "暂无发送历史",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text("成功发送文件后将显示在这里", style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: fileHistory.length,
      itemBuilder: (context, index) {
        final history = fileHistory[index];
        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF0099CC).withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.insert_drive_file,
                color: Color(0xFF0099CC),
                size: 28,
              ),
            ),
            title: Text(
              history.fileName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.straighten, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      history.fileSize,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.devices, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        history.deviceName,
                        style: TextStyle(color: Colors.grey[600]),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      _formatDateTime(history.sendTime),
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }
}

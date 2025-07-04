import 'dart:io';
import 'dart:math' as Math;
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:udp/udp.dart';
import 'dart:convert';

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

class _DeviceSearchPageState extends State<DeviceSearchPage> {
  List<DeviceInfo> devices = [];
  bool isLoading = true;
  bool isUploading = false;
  double uploadProgress = 0.0;
  String currentFileName = "";
  String currentFileSize = "";
  bool showUploadSuccess = false;

  @override
  void initState() {
    super.initState();
    discoverDevices();
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

  Future<void> sendFileViaTcp(String serverIp, int serverPort) async {
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
        serverIp,
        serverPort,
        timeout: const Duration(seconds: 5),
      );
      print("✅ 已连接到 Web 服务端 $serverIp:$serverPort");

      // ===== ✅ 添加 header =====
      final header = {
        'filename': fileName,
        'filesize': fileSize,
      };
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("局域网设备搜索"),
        backgroundColor: const Color(0xFF00D4FF),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: discoverDevices,
          ),
        ],
      ),
      body: Stack(
        children: [
          // 主内容
          isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF00D4FF)))
              : devices.isEmpty
              ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.devices_other, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text("未发现设备", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text("请确保设备在同一网络下并已启动应用", style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: discoverDevices,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D4FF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text("重新搜索"),
                ),
              ],
            ),
          )
              : ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: devices.length,
            itemBuilder: (context, index) {
              final device = devices[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00D4FF).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(Icons.devices, color: Color(0xFF00D4FF), size: 28),
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
                    icon: const Icon(Icons.send, color: Color(0xFF00D4FF)),
                    onPressed: () => sendFileViaTcp("10.9.17.94", 9999),
                    tooltip: "发送文件",
                  ),
                  onTap: () => sendFileViaTcp("10.9.17.94", 9999),
                ),
              );
            },
          ),

          // 上传进度条覆盖层
          if (isUploading)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: Center(
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.85,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.upload_file, size: 48, color: Color(0xFF00D4FF)),
                        const SizedBox(height: 16),
                        Text(
                          "上传文件中...",
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00D4FF)),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.85,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle, size: 64, color: Colors.green),
                        const SizedBox(height: 16),
                        const Text(
                          "上传成功!",
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
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
}
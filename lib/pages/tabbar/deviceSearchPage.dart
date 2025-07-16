import 'dart:io';
import 'dart:math' as Math;
import 'dart:typed_data';
import 'dart:convert';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:udp/udp.dart';
import '../../common/Prefs.dart';
import '../../components/GradientButton.dart'; // 添加Prefs导入
import 'package:open_file/open_file.dart';

// 文件历史记录模型
class FileHistory {
  final String fileName;
  final String fileSize;
  final String deviceName;
  final String deviceIp;
  final DateTime sendTime;
  final String filePath; // 新增

  FileHistory({
    required this.fileName,
    required this.fileSize,
    required this.deviceName,
    required this.deviceIp,
    required this.sendTime,
    required this.filePath, // 新增
  });

  // 转换为JSON
  Map<String, dynamic> toJson() => {
    'fileName': fileName,
    'fileSize': fileSize,
    'deviceName': deviceName,
    'deviceIp': deviceIp,
    'sendTime': sendTime.toIso8601String(),
    'filePath': filePath, // 新增
  };

  // 从JSON创建对象
  factory FileHistory.fromJson(Map<String, dynamic> json) => FileHistory(
    fileName: json['fileName'],
    fileSize: json['fileSize'],
    deviceName: json['deviceName'],
    deviceIp: json['deviceIp'],
    sendTime: DateTime.parse(json['sendTime']),
    filePath: json['filePath'] ?? '', // 新增
  );
}

class DeviceInfo {
  final String name;
  final String ip;
  final int port;
  final String source;
  DeviceInfo({required this.name, required this.ip, required this.port, this.source = 'web'});
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
    searchFlutter();
    discoverDevices();
    _loadFileHistory();
  }

  Future<void> searchFlutter() async {
    // 1. UDP发现服务端
    RawDatagramSocket.bind(InternetAddress.anyIPv4, 0).then((socket) {
      socket.broadcastEnabled = true;
      // 发送发现包
      socket.send(
        utf8.encode('ZOU_DROP_DISCOVERY'),
        InternetAddress('255.255.255.255'),
        5678,
      );

      socket.listen((event) async {
        if (event == RawSocketEvent.read) {
          final datagram = socket.receive();
          if (datagram != null) {
            final response = utf8.decode(datagram.data);
            print('发现服务端: $response');
            final info = json.decode(response);
            final ip = (info['ipList'] as List).first; // 取第一个IP
            final port = info['port'];
            String ipStr = 'http://$ip:$port';

            // 2. 连接socket.io并注册为flutter设备
            final sio = IO.io(ipStr, <String, dynamic>{
              'transports': ['websocket'],
              'autoConnect': false,
            });
            print('sio: $sio');
            try {
              sio.connect();
              sio.on('connect', (_) {
                print('已连接socket.io');
                sio.emit('JOIN_ROOM', {'device': 'flutter'});
              });
            } catch (e) {
              print('连接失败: $e');
            }

            // 3. 监听服务端推送
            sio.on('INIT_USER', (data) {
              print('收到用户列表: $data');
            });
            sio.on('JOIN_ROOM', (data) {
              print('有新用户加入: $data');
            });
            sio.on('LEAVE_ROOM', (data) {
              print('有用户离开: $data');
            });

            sio.on('disconnect', (_) {
              print('❌ 断开连接，将尝试重新连接');
              Future.delayed(Duration(seconds: 5), () {
                if (!sio.connected) {
                  searchFlutter(); // 重试连接
                }
              });
            });

            // 只发现一次就关闭UDP socket
            // socket.close();
          }
        }
      });
    });
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
  void _addToHistory(DeviceInfo device, String filePath) {
    final history = FileHistory(
      fileName: currentFileName,
      fileSize: currentFileSize,
      deviceName: device.name,
      deviceIp: device.ip,
      sendTime: DateTime.now(),
      filePath: filePath, // 新增
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

  void listenForAck(Socket socket) async {
    final buffer = BytesBuilder();

    await for (var data in socket) {
      buffer.add(data);

      // 至少要有4字节长度
      if (buffer.length >= 4) {
        final bytes = buffer.toBytes();
        final length = ByteData.sublistView(bytes, 0, 4).getUint32(0);

        if (bytes.length >= 4 + length) {
          final jsonBytes = bytes.sublist(4, 4 + length);
          final jsonStr = utf8.decode(jsonBytes);
          final ack = json.decode(jsonStr);
          if (ack['status'] == 'ok') {
            print('✅ 文件接收完成');
            // 这里可以弹窗、更新UI等
          }
          break;
        }
      }
    }
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
          print(json);
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
        print(found.toString());
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
        3000,
        timeout: const Duration(seconds: 5),
      );
      // await receiveAck(socket);

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
        listenForAck(socket);
      } finally {
        raf.closeSync();
        setState(() {
          uploadProgress = 1.0;
          isUploading = false;
          showUploadSuccess = true;
        });

        // 添加到发送历史
        _addToHistory(device, file.path); // 传入本地路径

        // 3秒后隐藏成功提示
        Future.delayed(const Duration(seconds: 1), () {
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

  Future<void> receiveAck(Socket socket) async {

    // 用于缓存数据
    final buffer = BytesBuilder();
    // 监听数据
    await for (var data in socket) {
      buffer.add(data);
      // 至少要有4字节长度
      if (buffer.length >= 4) {
        final bytes = buffer.toBytes();
        final length = ByteData.sublistView(bytes, 0, 4).getUint32(0);

        // 判断是否收齐
        if (bytes.length >= 4 + length) {
          final jsonBytes = bytes.sublist(4, 4 + length);
          final jsonStr = utf8.decode(jsonBytes);
          final ack = json.decode(jsonStr);
          print('收到服务端回执: $ack');
          // 处理后续逻辑...
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('收到服务端回执: $ack'), backgroundColor: Colors.blue),
          );
          // 如果只收一次，可以 break 或 return
          break;
        }
      }
    }
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
        // 自动识别来源
        String source = device.source;
        if (device.ip.startsWith('192.168.') || device.ip.startsWith('10.') || device.ip.startsWith('172.')) {
          if (device.name.toLowerCase().contains('android')) {
            source = 'Android';
          } else if (device.name.toLowerCase().contains('ios')) {
            source = 'iOS';
          } else if (device.name.toLowerCase().contains('pc') || device.name.toLowerCase().contains('windows') || device.name.toLowerCase().contains('mac')) {
            source = 'PC';
          } else if (device.ip == /* 本机IP获取逻辑 */ '') {
            source = '本机';
          }
        }
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  title: Row(
                    crossAxisAlignment: CrossAxisAlignment.center, // 让tip和文字在竖直方向居中
                    children: [
                      Expanded(
                        child: Text(
                          device.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _buildSourceTip(source),
                    ],
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
              ),
            ],
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
            onTap: () async {
              if (history.filePath.isNotEmpty && await File(history.filePath).exists()) {
                final result = await OpenFile.open(history.filePath);
                // if (result.type != 'done') {
                //   ScaffoldMessenger.of(context).showSnackBar(
                //     SnackBar(content: Text('无法打开文件: \\${result.message}')),
                //   );
                // }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('文件不存在或路径无效')),
                );
              }
            },
          ),
        );
      },
    );
  }
}

Widget _buildSourceTip(String source) {
  IconData icon;
  Color color;
  switch (source.toLowerCase()) {
    case 'android':
      icon = Icons.android;
      color = Colors.green;
      break;
    case 'ios':
      icon = Icons.phone_iphone;
      color = Colors.blue;
      break;
    case 'pc':
      icon = Icons.computer;
      color = Colors.grey;
      break;
    case '本机':
      icon = Icons.home;
      color = Colors.orange;
      break;
    default:
      icon = Icons.device_unknown;
      color = Colors.grey;
  }
  return Container(
    margin: const EdgeInsets.only(left: 6),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 2),
        Text(source, style: TextStyle(fontSize: 12, color: color)),
      ],
    ),
  );
}

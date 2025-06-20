import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as Math;
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../components/StatusIndicator.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final int udpPort = 4567;
  final int tcpPort = 5000;
  Map<String, String> deviceNames = {};
  late Connectivity _connectivity;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  RawDatagramSocket? udpSocket;
  ServerSocket? tcpServer;
  Socket? connectedSocket;

  List<String> discoveredIps = [];
  List<String> localIps = [];
  double progress = 0.0;
  String log = '';
  String? connectedIp;
  bool isSearching = false;
  bool showLog = true; // 默认显示日志
  bool isUdpServiceRunning = false;
  bool isTcpServerRunning = false;
  Map<String, DateTime> deviceLastSeen = {}; // 新增：存储设备最后心跳时间
  Timer? _deviceCleanupTimer; // 新增：设备清理定时器
  final Duration _offlineThreshold = const Duration(seconds: 10); // 新增：离线
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _initialize();
    // 监听网络状态变化
    WidgetsBinding.instance.addObserver(this);
    _connectivity = Connectivity();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
      result,
    ) {
      if (result != ConnectivityResult.none) {
        // 网络恢复时，重新获取本地IP并重启UDP发现
        _refreshNetworkInfo();
      } else {
        _log('网络已断开');
      }
    });
  }






  Future<void> _initialize() async {
    await _requestPermissions();
    localIps = await _getLocalIPs();
    await _startUdpDiscovery();
    await _startTcpServer();
  }

  bool _isPrivate(String ip) {
    try {
      final parts = ip.split('.').map(int.parse).toList();
      if (parts.length != 4) return false;

      if (parts[0] == 10) return true; // 10.0.0.0/8
      if (parts[0] == 192 && parts[1] == 168) return true; // 192.168.0.0/16
      if (parts[0] == 172 && parts[1] >= 16 && parts[1] <= 31) {
        return true; // 172.16.0.0/12
      }

      return false;
    } catch (_) {
      return false; // 避免非法 IP 导致崩溃
    }
  }

  Future<List<String>> _getLocalIPs() async {
    final ips = <String>{}; // 用 Set 去重
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          final ip = addr.address;
          if (_isPrivate(ip)) ips.add(ip);
        }
      }
    } catch (e, s) {
      _log('获取本地 IP 失败: $e\n$s');
    }
    return ips.toList();
  }

  void _renameDevice(String ip) async {
    final currentName = deviceNames[ip] ?? ip;
    final controller = TextEditingController(text: currentName);

    final result = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('重命名设备'),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: '设备名称'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(null),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed:
                    () => Navigator.of(context).pop(controller.text.trim()),
                child: const Text('保存'),
              ),
            ],
          ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        deviceNames[ip] = result;
      });
      _log('设备 $ip 重命名为 "$result"');
    }
  }

  Future<void> _sendBroadcast() async {
    try {
      if (udpSocket == null) {
        _log('UDP Socket 未初始化，无法发送广播');
        return;
      }

      final message = utf8.encode('landrop_hello');
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );

      final Set<String> sentBroadcasts = {};

      for (var interface in interfaces) {
        if (interface.addresses.isEmpty) continue;

        for (var addr in interface.addresses) {
          final ip = addr.address;
          final segments = ip.split('.');
          if (segments.length == 4) {
            final broadcastIP =
                '${segments[0]}.${segments[1]}.${segments[2]}.255';

            // 避免重复广播
            if (sentBroadcasts.contains(broadcastIP)) continue;
            sentBroadcasts.add(broadcastIP);

            final broadcast = InternetAddress(broadcastIP);
            udpSocket?.send(message, broadcast, udpPort);

          }
        }
      }

      if (sentBroadcasts.isEmpty) {
        _log('未找到有效的广播地址');
      }
    } catch (e, stack) {
      _log('发送UDP广播失败: $e\n$stack');
    }
  }



  Future<void> _pickAnyFile() async {
    if (connectedSocket == null) {
      _log('请先连接设备后再发送文件');
      return;
    }

    try {
      // 选择任意类型文件
      const XTypeGroup anyType = XTypeGroup(label: '所有文件', extensions: ['*']);
      final XFile? pickedFile = await openFile(acceptedTypeGroups: [anyType]);

      if (pickedFile == null) {
        _log('未选择任何文件');
        return;
      }

      final file = File(pickedFile.path);
      if (!await file.exists()) {
        _log('文件不存在：${pickedFile.path}');
        return;
      }

      final fileName = pickedFile.name;
      final fileSize = await file.length();
      final formattedSize = _formatFileSize(fileSize);
      _log('准备发送文件：$fileName，大小：$formattedSize');

      // 通知对方要发送文件（格式约定）
      connectedSocket!.write('FILE:$fileName:$fileSize\n');

      const int chunkSize = 64 * 1024;
      final raf = file.openSync();
      int sent = 0;

      setState(() => progress = 0.0);

      try {
        while (sent < fileSize) {
          final chunk = raf.readSync(
            fileSize - sent > chunkSize ? chunkSize : fileSize - sent,
          );
          connectedSocket!.add(chunk);
          sent += chunk.length;
          setState(() => progress = sent / fileSize); // 进度更新
        }
        _log('文件发送完成');
      } catch (e) {
        _log('发送文件时出错：$e');
      } finally {
        raf.closeSync();
        setState(() => progress = 1.0);
        // 延迟重置进度条
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) setState(() => progress = 0.0);
        });
      }
    } catch (e) {
      _log('选择或发送文件时出错: $e');
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return "0 B";

    const units = ['B', 'KB', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB', 'YB'];
    int i = (bytes == 0) ? 0 : (Math.log(bytes) / Math.log(1024)).floor();

    double size = bytes / Math.pow(1024, i);
    return '${size.toStringAsFixed(2)} ${units[i]}';
  }

  Future<void> _requestPermissions() async {
    try {
      await [
        Permission.storage,
        Permission.manageExternalStorage,
        Permission.bluetooth,
        Permission.location,
      ].request();
    } catch (e) {
      _log('请求权限时出错: $e');
    }
  }

  Future<String?> getLocalIpAddress() async {
    for (var interface in await NetworkInterface.list(
      includeLoopback: false,
      type: InternetAddressType.IPv4,
    )) {
      for (var addr in interface.addresses) {
        return addr.address; // 返回第一个找到的 IPv4 地址
      }
    }
    return null;
  }

  void _log(String msg) {
    if (!mounted) return;

    setState(() => log += '$msg\n');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // 停止UDP发现服务
  void _stopUdpDiscovery() {
    try {
      udpSocket?.close();
      udpSocket = null;
      isUdpServiceRunning = false;
      _log('UDP发现服务已停止');
    } catch (e) {
      _log('停止UDP发现服务时出错: $e');
    }
  }

  Future<void> _refreshDiscovery() async {
    if (isSearching) {
      _log('正在搜索中，忽略重复刷新请求');
      return;
    }

    setState(() {
      discoveredIps.clear();
      isSearching = true;
    });
    _log('主动刷新设备发现，开始搜索');

    // 如果UDP未启动，先启动
    if (udpSocket == null) {
      await _startUdpDiscovery();
    }

    // 发送广播请求开始搜索
    _sendBroadcast();

    setState(() {
      isSearching = false;
    });
  }

  void _clearLog() => setState(() => log = '');

  Future<void> _startUdpDiscovery() async {
    try {
      if (udpSocket != null) {
        _log('UDP发现服务已经在运行，先停止旧服务');
        _stopUdpDiscovery();
      }

      udpSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        udpPort,
      );
      udpSocket!.broadcastEnabled = true;
      isUdpServiceRunning = true;
      _log('UDP广播发现服务已启动');

      udpSocket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = udpSocket!.receive();
          if (datagram == null) return;

          final ip = datagram.address.address;
          final message = utf8.decode(datagram.data);

          if (message == 'landrop_hello') {
            udpSocket!.send(
              utf8.encode('landrop_reply'),
              datagram.address,
              udpPort,
            );

            if (ip.isNotEmpty && !discoveredIps.contains(ip)) {
              setState(() => discoveredIps.add(ip));
              _log('发现新的设备IP：$ip');
            }
          }
        }
      });

      // 每2秒发送心跳包
      Timer.periodic(const Duration(seconds: 2), (timer) {
        if (udpSocket == null) {
          timer.cancel();
          return;
        }
        _sendBroadcast();
      });
    } catch (e) {
      isUdpServiceRunning = false;
      _log('启动UDP发现服务失败: $e');
    }
  }

  Future<void> _startTcpServer() async {
    try {
      tcpServer?.close(); // 若已有监听，先关闭
      tcpServer = await ServerSocket.bind(InternetAddress.anyIPv4, tcpPort);
      setState(() {
        isTcpServerRunning = true;
      });
      tcpServer!.listen(
        (client) {
          final remoteIp = client.remoteAddress.address;
          _log('收到来自 $remoteIp 的连接请求');
          _receiveFile(client);
        },
        onError: (err) => _log('TCP监听错误: $err'),
        cancelOnError: true,
      );

      _log('TCP服务器已启动，端口：$tcpPort');
    } catch (e) {
      setState(() {
        isTcpServerRunning = false;
      });
      _log('启动TCP服务器失败: $e');
    }
  }

  void _disconnect() async {
    if (connectedSocket != null) {
      try {
        await connectedSocket!.close();
      } catch (_) {}
      setState(() {
        connectedSocket = null;
        connectedIp = null;
      });
      _log('已断开连接');
    }
  }

  Future<void> _connectTo(String ip) async {
    if (localIps.contains(ip)) {
      _log('忽略连接自己设备IP：$ip');
      return;
    }

    if (connectedSocket != null) {
      _log('已有连接，先断开当前连接');
      try {
        await connectedSocket!.close();
      } catch (_) {}
      setState(() {
        connectedSocket = null;
        connectedIp = null;
      });
    }

    setState(() => progress = 0.1);

    try {
      _log('正在连接到设备 $ip...');
      final socket = await Socket.connect(ip, tcpPort).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('连接超时，请检查设备是否在线'),
      );

      setState(() {
        connectedSocket = socket;
        connectedIp = ip;
        progress = 0.0;
      });

      _log('成功连接到设备 $ip');
      _receiveFile(socket);
    } catch (e) {
      setState(() => progress = 0.0);

      String errorMsg = '连接设备 $ip 失败';
      if (e is SocketException) {
        switch (e.osError?.errorCode) {
          case 111:
            errorMsg = '连接被拒绝，目标设备可能未启动服务或端口被占用';
            break;
          case 113:
            errorMsg = '无法访问目标设备，可能不在同一网络或被防火墙阻止';
            break;
          case 110:
            errorMsg = '连接超时，目标设备可能不在线或网络不稳定';
            break;
          default:
            errorMsg = '$errorMsg，错误：${e.message}';
        }
      } else if (e is TimeoutException) {
        errorMsg = '连接超时，请检查设备是否在线';
      } else {
        errorMsg = '$errorMsg，错误：$e';
      }

      _log(errorMsg);
    }
  }

  Future<void> _pickAndSendFile() async {
    if (connectedSocket == null) {
      _log('请先连接设备后再发送文件');
      return;
    }

    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
      );
      if (pickedFile == null) {
        _log('未选择图片');
        return;
      }

      final file = File(pickedFile.path);
      if (!await file.exists()) {
        _log('图片文件不存在：${pickedFile.path}');
        return;
      }

      final fileName = pickedFile.name;
      final fileSize = await file.length();
      final formattedSize = _formatFileSize(fileSize);
      _log('准备发送图片文件：$fileName，大小：$formattedSize');

      connectedSocket!.write('FILE:$fileName:$fileSize\n');

      const int chunkSize = 64 * 1024;
      final raf = file.openSync();
      int sent = 0;

      setState(() => progress = 0.0);

      try {
        while (sent < fileSize) {
          final chunk = raf.readSync(
            fileSize - sent > chunkSize ? chunkSize : fileSize - sent,
          );
          connectedSocket!.add(chunk);
          sent += chunk.length;
          setState(() => progress = sent / fileSize);
        }
        _log('图片文件发送完成');
      } catch (e) {
        _log('发送图片文件时出错：$e');
      } finally {
        raf.closeSync();
        setState(() => progress = 1.0);
        // 延迟重置进度条
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) setState(() => progress = 0.0);
        });
      }
    } catch (e) {
      _log('选择或发送图片时出错: $e');
    }
  }

  void _receiveFile(Socket socket) {
    File? outFile;
    IOSink? outSink;
    int expectedLength = 0;
    int received = 0;
    bool headerProcessed = false;
    List<int> buffer = [];

    socket.listen(
      (data) async {
        buffer.addAll(data);
        while (true) {
          if (!headerProcessed) {
            final newlineIndex = buffer.indexOf(10);
            if (newlineIndex == -1) break;

            final headerText = utf8.decode(buffer.sublist(0, newlineIndex + 1));
            if (headerText.startsWith('FILE:')) {
              final parts = headerText.split(':');
              if (parts.length >= 3) {
                final name = parts[1];
                expectedLength = int.tryParse(parts[2].trim()) ?? 0;

                final dirPath = '/storage/emulated/0/Download/';
                Directory(dirPath).createSync(recursive: true);
                outFile = File('$dirPath$name');
                outSink = outFile!.openWrite();

                _log('开始接收文件：$name，大小：$expectedLength 字节');

                buffer = buffer.sublist(newlineIndex + 1);
                if (buffer.isNotEmpty) {
                  outSink!.add(buffer);
                  received += buffer.length;
                  setState(() => progress = received / expectedLength);
                }
                headerProcessed = true;
                buffer = [];
              } else {
                buffer.clear();
                break;
              }
            } else {
              buffer.clear();
              break;
            }
          } else {
            if (buffer.isEmpty) break;
            outSink!.add(buffer);
            received += buffer.length;
            setState(() => progress = received / expectedLength);
            buffer = [];

            if (received >= expectedLength) {
              outSink!.close();
              _log('文件接收完成');
              if (outFile != null && await outFile!.exists()) {
                final result = await OpenFile.open(outFile!.path);
                _log('打开文件结果：${result.message}');
              }
              headerProcessed = false;
              expectedLength = received = 0;
            }
          }
        }
      },
      onDone: () {
        outSink?.close();
        _log('连接关闭，文件写入结束');
        setState(() {
          connectedSocket = null;
          connectedIp = null;
        });
      },
      onError: (e) {
        _log('接收错误：$e');
        print('接收错误：$e');
      },
    );
  }

  Future<void> _refreshNetworkInfo() async {
    try {
      final newIps = await _getLocalIPs();
      if (newIps.isNotEmpty && !_listEquals(newIps, localIps)) {
        setState(() {
          localIps = newIps;
        });
        _log('新的本机IP地址：${localIps.join(", ")}');
        // 重启 UDP 发现服务
        await _restartUdpDiscovery();
      } else if (newIps.isEmpty) {
        _log('未检测到有效的本地IP地址');
      }
    } catch (e) {
      _log('刷新网络信息时出错: $e');
    }
  }

  bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<void> _restartUdpDiscovery() async {
    _stopUdpDiscovery();
    await _startUdpDiscovery();
    _log('UDP广播发现服务已重启');
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('使用帮助'),
            content: const SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('1. 确保两台设备在同一WiFi网络下'),
                  SizedBox(height: 8),
                  Text('2. 点击"刷新查找设备"按钮搜索网络中的其他设备'),
                  SizedBox(height: 8),
                  Text('3. 在设备列表中点击"连接设备"按钮'),
                  SizedBox(height: 8),
                  Text('4. 连接成功后，点击"选择并发送图片"或"选择任意文件"'),
                  SizedBox(height: 8),
                  Text('5. 文件将发送到对方设备的Download文件夹中'),
                  SizedBox(height: 16),
                  Text('注意事项:', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text('• 如果搜索不到设备，请尝试在两台设备上都点击刷新按钮'),
                  Text('• 设备名称可以通过点击设备名进行修改'),
                  Text('• 传输大文件时请保持应用在前台运行'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('了解了'),
              ),
            ],
          ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopUdpDiscovery();
    tcpServer?.close();
    connectedSocket?.close();
    _scrollController.dispose();
    _connectivitySubscription?.cancel();
    _deviceCleanupTimer?.cancel(); // 新增：取消定时器
    super.dispose();
  }

  void _startDeviceCleanupTimer() {
    _deviceCleanupTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted) return;
      final now = DateTime.now();
      List<String> offlineIps = [];
      for (var ip in discoveredIps) {
        if (deviceLastSeen.containsKey(ip)) {
          if (now.difference(deviceLastSeen[ip]!) > _offlineThreshold) {
            offlineIps.add(ip);
          }
        }
      }

      if (offlineIps.isNotEmpty) {
        setState(() {
          for (var offlineIp in offlineIps) {
            discoveredIps.remove(offlineIp);
            deviceNames.remove(offlineIp);
            deviceLastSeen.remove(offlineIp);
            _log('设备 $offlineIp 已离线，已从列表移除');
            if (connectedIp == offlineIp) {
              _disconnect(); // 如果连接的是离线设备，则断开连接
            }
          }
        });
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _log('应用回到前台，重新检查网络状态...');
      _refreshNetworkInfo();
    }
  }

  bool isLocalIp(String ip) {
    return localIps.contains(ip);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ZouDrop'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showHelpDialog,
            tooltip: '使用帮助',
          ),
        ],
      ),
      body: Column(
        children: [
          // 进度条
          LinearProgressIndicator(value: progress),

          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              StatusIndicator(
                isActive: isUdpServiceRunning,
                textBuilder: (isActive) => isActive ? 'UDP服务正常' : 'UDP服务未开启',
              ),
              StatusIndicator(
                isActive: isTcpServerRunning,
                textBuilder: (isActive) => isActive ? 'TCP服务正常' : 'TCP服务未开启',
              ),
            ],
          ),

          // 主体内容
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(8),
              children: [
                // 刷新按钮
                ElevatedButton.icon(
                  onPressed: isSearching ? null : _refreshDiscovery,
                  icon:
                      isSearching
                          ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.refresh),
                  label: Text(isSearching ? '正在搜索设备...' : '刷新查找设备'),
                ),
                const SizedBox(height: 8),

                // 设备列表
                if (discoveredIps.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: Text('未发现设备，请点击刷新按钮搜索')),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      '发现的设备:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),

                ...discoveredIps.map(
                  (ip) => Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      leading: Icon(
                        connectedIp == ip ? Icons.link : Icons.devices,
                        color: connectedIp == ip ? Colors.green : Colors.grey,
                      ),
                      title: GestureDetector(
                        onTap: () => _renameDevice(ip),
                        child: Text(
                          deviceNames[ip] ?? ip,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      subtitle: Text(
                        connectedIp == ip
                            ? '✅ 已连接'
                            : connectedSocket == null
                            ? '⚠️ 未连接'
                            : '🔌 正在连接其他设备',
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                      trailing: ElevatedButton(
                        onPressed:
                            isSearching || (connectedIp == ip)
                                ? null
                                : () => _connectTo(ip),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isLocalIp(ip) ? Colors.grey : null,
                        ),
                        child: Text(isLocalIp(ip) ? '本机' : '连接设备'),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // 文件操作按钮
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed:
                            connectedSocket != null ? _pickAndSendFile : null,
                        icon: const Icon(Icons.image),
                        label: const Text('发送图片'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed:
                            connectedSocket != null ? _pickAnyFile : null,
                        icon: const Icon(Icons.attach_file),
                        label: const Text('发送文件'),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                _buildLog(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLog(BuildContext context) => SizedBox(
    width: double.infinity,
    child: Column(
      children: [
        // 顶部行
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('操作日志:', style: TextStyle(fontWeight: FontWeight.bold)),
            TextButton.icon(
              onPressed: _clearLog,
              icon: const Icon(Icons.clear_all, size: 16),
              label: const Text('清空'),
            ),
          ],
        ),
        // 日志框
        Container(
          height: 200,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          width: double.infinity,
          // 这里也可设置保证铺满
          child:
              showLog
                  ? SingleChildScrollView(
                    controller: _scrollController,
                    child: Text(
                      log.isEmpty ? '暂无日志' : log,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black87,
                      ),
                    ),
                  )
                  : null,
        ),
      ],
    ),
  );
}

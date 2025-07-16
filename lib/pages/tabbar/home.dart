import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as Math;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../common/DeviceManager.dart';
import 'package:app_settings/app_settings.dart';
import 'package:flutter/services.dart';
import '../../components/AnimatedGradientLinearProgress.dart';
import '../../components/GradientButton.dart';
import '../../common/UrlDetector.dart';

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
  Timer? _deviceCleanupTimer; // 新增：设备清理定时器
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    DeviceManager().addListener(_onDevicesChanged);
    _initialize();
    // 监听网络状态变化
    WidgetsBinding.instance.addObserver(this);
    _connectivity = Connectivity();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
      result,
    ) {
      if (result != ConnectivityResult.none) {
        // 网络恢复时，重新获取本地IP并重启UDP发现
        // _refreshNetworkInfo();
      } else {
        _log('网络已断开');
      }
    });
  }

  void _onDevicesChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _showSendTextDialog() async {
    final textController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.white,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 标题区域
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00D4FF), Color(0xFF0099CC)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.send,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Text(
                          '发送文本消息',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF333333),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // 输入框
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF00D4FF).withOpacity(0.3),
                        width: 2,
                      ),
                      color: Colors.grey[50],
                    ),
                    child: TextField(
                      controller: textController,
                      style: const TextStyle(
                        color: Color(0xFF333333),
                        fontSize: 16,
                      ),
                      decoration: const InputDecoration(
                        hintText: '请输入要发送的文本内容...',
                        hintStyle: TextStyle(
                          color: Color(0xFF999999),
                          fontSize: 16,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(20),
                      ),
                      maxLines: 5,
                      minLines: 3,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 按钮区域
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF00D4FF).withOpacity(0.5),
                              width: 1.5,
                            ),
                          ),
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: TextButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              '取消',
                              style: TextStyle(
                                color: Color(0xFF00D4FF),
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF00D4FF), Color(0xFF0099CC)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ElevatedButton(
                            onPressed:
                                () => Navigator.of(
                                  context,
                                ).pop(textController.text.trim()),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              '发送',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );

    if (result != null && result.isNotEmpty && connectedSocket != null) {
      try {
        // 发送文本消息
        final message = 'TEXT:$result\n';
        _log('发送文本消息: $result');
        connectedSocket!.write(message);
        await connectedSocket!.flush();
        _log('文本消息发送成功');
      } catch (e) {
        _log('发送文本消息失败: $e');
      }
    }
  }

  Future<void> _initialize() async {
    await _requestPermissions(context);
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
        final connectivityResult = await Connectivity().checkConnectivity();
        _log(connectivityResult.toString());

        _log('未找到有效的广播地址');
      }
    } catch (e, stack) {
      _log('发送UDP广播失败: $e\n$stack');
    }
  }

  Future<void> _pickAnyFile() async {
    if (connectedSocket == null) {
      _showErrorDialog('请先连接设备后再发送文件');
      return;
    }

    try {
      _log('正在选择文件...');

      // 使用更宽泛的文件类型组
      const List<XTypeGroup> typeGroups = [
        XTypeGroup(
          label: '所有文件',
          extensions: ['*'],
        ),
        XTypeGroup(
          label: '文档',
          extensions: ['pdf', 'doc', 'docx', 'txt', 'rtf'],
        ),
        XTypeGroup(
          label: '图片',
          extensions: ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'],
        ),
        XTypeGroup(
          label: '视频',
          extensions: ['mp4', 'avi', 'mov', 'wmv', 'flv', 'mkv'],
        ),
        XTypeGroup(
          label: '音频',
          extensions: ['mp3', 'wav', 'flac', 'aac', 'm4a'],
        ),
      ];

      final XFile? pickedFile = await openFile(
        acceptedTypeGroups: typeGroups,
        initialDirectory: null, // 让用户选择起始目录
      );

      if (pickedFile == null) {
        _log('用户取消了文件选择');
        return;
      }

      final file = File(pickedFile.path);

      // 检查文件是否存在
      if (!await file.exists()) {
        _showErrorDialog('文件不存在：${pickedFile.path}');
        return;
      }

      // 检查文件大小（限制为100MB）
      final fileSize = await file.length();
      // const maxFileSize = 100 * 1024 * 1024; // 100MB
      // if (fileSize > maxFileSize) {
      //   _showErrorDialog('文件过大，请选择小于100MB的文件');
      //   return;
      // }

      final fileName = pickedFile.name;
      final formattedSize = _formatFileSize(fileSize);
      _log('准备发送文件：$fileName，大小：$formattedSize');

      // 显示发送确认对话框
      final shouldSend = await _showSendConfirmDialog(fileName, formattedSize);
      if (!shouldSend) {
        _log('用户取消了文件发送');
        return;
      }

      await _sendFileWithProgress(file, fileName, fileSize);

    } catch (e) {
      _log('选择或发送文件时出错: $e');
      _showErrorDialog('文件发送失败: $e');
    }
  }
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 8),
            Text('错误'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('成功'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
// 新增：发送确认对话框
  Future<bool> _showSendConfirmDialog(String fileName, String fileSize) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认发送'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('文件名：$fileName'),
            Text('大小：$fileSize'),
            Text('目标设备：$connectedIp'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('发送'),
          ),
        ],
      ),
    ) ?? false;
  }

// 新增：带进度的文件发送
  Future<void> _sendFileWithProgress(File file, String fileName, int fileSize) async {
    try {
      // 发送文件头信息
      final header = 'FILE:$fileName:$fileSize\n';
      connectedSocket!.write(header);
      await connectedSocket!.flush();

      _log('开始发送文件数据...');

      const int chunkSize = 64 * 1024; // 64KB chunks
      final raf = file.openSync();
      int sent = 0;

      setState(() => progress = 0.0);

      try {
        while (sent < fileSize) {
          final remainingBytes = fileSize - sent;
          final currentChunkSize = remainingBytes > chunkSize ? chunkSize : remainingBytes;

          final chunk = raf.readSync(currentChunkSize);
          connectedSocket!.add(chunk);
          await connectedSocket!.flush(); // 确保数据发送

          sent += chunk.length;
          final currentProgress = sent / fileSize;

          setState(() => progress = currentProgress);

          // 添加小延迟以避免网络拥塞
          if (sent < fileSize) {
            await Future.delayed(const Duration(milliseconds: 10));
          }

          _log('发送进度: ${(currentProgress * 100).toStringAsFixed(1)}%');
        }

        _log('文件发送完成：$fileName');
        _showSuccessDialog('文件发送成功');

      } catch (e) {
        _log('发送文件时出错：$e');
        _showErrorDialog('文件发送失败：$e');
      } finally {
        raf.closeSync();
        setState(() => progress = 1.0);

        // 延迟重置进度条
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => progress = 0.0);
        });
      }

    } catch (e) {
      _log('发送文件头时出错：$e');
      _showErrorDialog('发送文件失败：$e');
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return "0 B";

    const units = ['B', 'KB', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB', 'YB'];
    int i = (bytes == 0) ? 0 : (Math.log(bytes) / Math.log(1024)).floor();

    double size = bytes / Math.pow(1024, i);
    return '${size.toStringAsFixed(2)} ${units[i]}';
  }

  Future<void> _requestPermissions(BuildContext context) async {
    try {
      final statuses =
          await [
            Permission.storage,
            Permission.manageExternalStorage,
            Permission.bluetooth,
            Permission.location, // WiFi 必需的定位权限
          ].request();

      // ❗ 检查定位权限（WiFi功能需要）
      if (statuses[Permission.location]?.isGranted != true) {
        _log('定位权限未开启，WiFi 功能可能无法使用');

        final shouldOpen = await showDialog<bool>(
          context: context,
          builder:
              (_) => AlertDialog(
                title: const Text('权限提示'),
                content: const Text('您尚未授予定位权限，部分局域网功能将无法使用。\n是否前往设置开启？'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('取消'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('前往设置'),
                  ),
                ],
              ),
        );

        if (shouldOpen == true) {
          AppSettings.openAppSettings(type: AppSettingsType.location);
        }

        return;
      }

      // ✅ 可选：检查 WiFi 是否连接
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult != ConnectivityResult.wifi) {
        _log('当前未连接 WiFi，可能无法使用局域网功能');

        final shouldOpenWifi = await showDialog<bool>(
          context: context,
          builder:
              (_) => AlertDialog(
                title: const Text('网络提示'),
                content: const Text(
                  '您当前未连接 WiFi，局域网功能可能无法使用。\n是否前往打开 WiFi 设置？',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('取消'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('前往设置'),
                  ),
                ],
              ),
        );

        if (shouldOpenWifi == true) {
          AppSettings.openAppSettings(type: AppSettingsType.wifi);
        }
      }
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
      isSearching = true;
    });

    try {
      _log('开始刷新设备发现...');

      // 清理旧的设备列表
      setState(() {
        discoveredIps.clear();
      });

      // 重新获取本地IP
      localIps = await _getLocalIPs();
      _log('本地IP地址：${localIps.join(", ")}');

      // 重启UDP服务
      await _restartUdpDiscovery();

      // 发送多次广播以提高发现率
      for (int i = 0; i < 3; i++) {
        await _sendBroadcast();
        await Future.delayed(const Duration(milliseconds: 500));
      }

      _log('设备发现刷新完成');

    } catch (e) {
      _log('刷新设备发现时出错: $e');
    } finally {
      // 延迟结束搜索状态，给设备响应时间
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            isSearching = false;
          });
        }
      });
    }
  }

  void _clearLog() => setState(() => log = '');

  // Future<void> _startUdpDiscovery() async {
  //   try {
  //     if (udpSocket != null) {
  //       _log('UDP发现服务已经在运行，先停止旧服务');
  //       _stopUdpDiscovery();
  //     }
  //
  //     udpSocket = await RawDatagramSocket.bind(
  //       InternetAddress.anyIPv4,
  //       udpPort,
  //     );
  //     udpSocket!.broadcastEnabled = true;
  //     isUdpServiceRunning = true;
  //     _log('UDP广播发现服务已启动');
  //
  //     udpSocket!.listen((event) {
  //       if (event == RawSocketEvent.read) {
  //         final datagram = udpSocket!.receive();
  //         if (datagram == null) return;
  //
  //         final ip = datagram.address.address;
  //         final message = utf8.decode(datagram.data);
  //
  //         if (message == 'landrop_hello') {
  //           udpSocket!.send(
  //             utf8.encode('landrop_reply'),
  //             datagram.address,
  //             udpPort,
  //           );
  //
  //           if (ip.isNotEmpty && !discoveredIps.contains(ip)) {
  //             setState(() => discoveredIps.add(ip));
  //
  //             DeviceManager().addOrUpdateDevice(ip, null);
  //             _log('发现新的设备IP：$ip');
  //           }
  //         }
  //       }
  //     });
  //
  //     // 每2秒发送心跳包
  //     Timer.periodic(const Duration(seconds: 2), (timer) {
  //       if (udpSocket == null) {
  //         timer.cancel();
  //         return;
  //       }
  //       _sendBroadcast();
  //     });
  //   } catch (e) {
  //     isUdpServiceRunning = false;
  //     _log('启动UDP发现服务失败: $e');
  //   }
  // }
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
            // 回复发现请求
            udpSocket!.send(
              utf8.encode('landrop_reply'),
              datagram.address,
              udpPort,
            );

            // 添加设备到列表
            if (ip.isNotEmpty && !discoveredIps.contains(ip) && !localIps.contains(ip)) {
              setState(() => discoveredIps.add(ip));
              DeviceManager().addOrUpdateDevice(ip, null);
              _log('发现新的设备IP：$ip');
            }
          } else if (message == 'landrop_reply') {
            // 处理回复
            if (ip.isNotEmpty && !discoveredIps.contains(ip) && !localIps.contains(ip)) {
              setState(() => discoveredIps.add(ip));
              DeviceManager().addOrUpdateDevice(ip, null);
              _log('收到设备回复：$ip');
            }
          }
        }
      });

      // 优化心跳包发送频率
      Timer.periodic(const Duration(seconds: 5), (timer) {
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
        _log('正在断开与 $connectedIp 的连接...');
        await connectedSocket!.close();
        _log('已成功断开连接');
      } catch (e) {
        _log('断开连接时出错: $e');
      } finally {
        setState(() {
          connectedSocket = null;
          connectedIp = null;
          progress = 0.0; // 重置进度
        });
      }
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
        print('接收到数据，buffer长度: ${buffer.length}');
        print('接收到的原始字节: $data');

        while (true) {
          if (!headerProcessed) {
            final newlineIndex = buffer.indexOf(10);
            print('查找换行符，位置: $newlineIndex');
            if (newlineIndex == -1) {
              print('未找到换行符，等待更多数据');
              break;
            }

            final headerText = utf8.decode(buffer.sublist(0, newlineIndex + 1));
            print('解析的headerText: "$headerText"');
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
            } else if (headerText.startsWith('TEXT:')) {
              // 处理文本消息
              // 改进文本消息处理
              print('检测到TEXT消息');
              final textContent = headerText.substring(
                5,
                headerText.length - 1,
              ); // 去掉 'TEXT:' 和换行符
              _log('收到文本消息: $textContent');
              print('收到文本消息，长度: ${textContent.length}, 内容: "$textContent"');

              // 确保在主线程中显示弹框
              WidgetsBinding.instance.addPostFrameCallback((_) {
                print('准备在主线程中显示弹框');
                _showTextMessageDialog(textContent);
              });

              buffer.clear();
              break;
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

  void _showTextMessageDialog(String textContent) {
    if (!mounted) {
      return;
    }
    // 使用 Future.delayed 确保在下一个帧中显示弹框
    Future.delayed(Duration.zero, () {
      if (!mounted) return;
      showDialog(
            context: context,
            barrierDismissible: false, // 防止意外关闭
            builder:
                (context) => Dialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: Colors.white,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 标题区域
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF00D4FF),
                                    Color(0xFF0099CC),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.message,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Text(
                                '收到文本消息',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF333333),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // 文本内容区域
                        Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(
                            minHeight: 100,
                            maxHeight: 300,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFF00D4FF).withOpacity(0.3),
                              width: 2,
                            ),
                            color: Colors.grey[50],
                          ),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(20),
                            child: RichText(
                              text: TextSpan(
                                children: UrlDetector.parseTextWithUrls(
                                  textContent,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // 按钮区域
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 48,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(
                                      0xFF00D4FF,
                                    ).withOpacity(0.5),
                                    width: 1.5,
                                  ),
                                ),
                                child: TextButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                  style: TextButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    '关闭',
                                    style: TextStyle(
                                      color: Color(0xFF00D4FF),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Container(
                                height: 48,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF00D4FF),
                                      Color(0xFF0099CC),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ElevatedButton(
                                  onPressed: () {
                                    print('用户点击复制按钮');
                                    Clipboard.setData(
                                      ClipboardData(text: textContent),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('文本已复制到剪贴板'),
                                        backgroundColor: Color(0xFF00D4FF),
                                      ),
                                    );
                                    Navigator.of(context).pop();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    '复制',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
          )
          .then((_) {
            print('文本消息弹框已关闭');
          })
          .catchError((error) {
            print('显示文本消息弹框时出错: $error');
          });
    });
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
    DeviceManager().removeListener(_onDevicesChanged);
    DeviceManager().disposeManager();
    super.dispose();
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
          AnimatedGradientLinearProgress(
            value: progress,
            height: 4,
            showPercentage: false,
            enableGlow: true,
            reverse: false,
            // 设置为 true 将从右向左
            gradientColors: [Color(0xFF00D4FF), Color(0xFF0099CC)],
            backgroundColor: Colors.grey.shade200,
          ),
          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatusCard(
                icon: Icons.wifi,
                title: 'UDP服务',
                isActive: isUdpServiceRunning,
                activeColor: const Color(0xFF00B8D4),
              ),
              _buildStatusCard(
                icon: Icons.wifi,
                title: 'TCP服务',
                isActive: isTcpServerRunning,
                activeColor: const Color(0xFF00B8D4),
              ),
              _buildStatusCard(
                icon: Icons.devices,
                title: '设备数量',
                isActive: isTcpServerRunning,
                activeColor: const Color(0xFF00B8D4),
                customText: discoveredIps.length.toString(),
              ),
            ],
          ),

          // 主体内容
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshDiscovery,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  // 刷新按钮
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: isSearching ? null : _refreshDiscovery,
                      icon:
                          isSearching
                              ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF00D4FF),
                                ),
                              )
                              : const Icon(
                                Icons.refresh,
                                color: Color(0xFF00D4FF),
                              ),
                      label: Text(
                        isSearching ? '正在搜索设备...' : '刷新查找设备',
                        style: const TextStyle(
                          color: Color(0xFF00D4FF),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        elevation: 0,
                        side: const BorderSide(
                          color: Color(0xFF00D4FF),
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 设备列表
                  if (discoveredIps.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Center(
                        child: Text(
                          '未发现设备，请点击刷新按钮搜索',
                          style: TextStyle(color: Color(0xFF00D4FF)),
                        ),
                      ),
                    )
                  else ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        '发现的设备:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00D4FF),
                          fontSize: 16,
                        ),
                      ),
                    ),
                    ...discoveredIps.map(
                      (ip) => Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          gradient:
                              connectedIp == ip
                                  ? const LinearGradient(
                                    colors: [
                                      Color(0xFF00D4FF),
                                      Color(0xFF0099CC),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                  : null,
                          color: connectedIp == ip ? null : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  connectedIp == ip
                                      ? const Color(
                                        0xFF00D4FF,
                                      ).withOpacity(0.10)
                                      : Colors.black.withOpacity(0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              gradient:
                                  connectedIp == ip
                                      ? const LinearGradient(
                                        colors: [
                                          Color(0xFF00D4FF),
                                          Color(0xFF0099CC),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      )
                                      : null,
                              color:
                                  connectedIp == ip
                                      ? null
                                      : const Color(0xFFF0F0F0),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              connectedIp == ip ? Icons.link : Icons.devices,
                              color:
                                  connectedIp == ip
                                      ? Colors.white
                                      : const Color(0xFF00D4FF),
                              size: 22,
                            ),
                          ),
                          title: GestureDetector(
                            onTap: () => _renameDevice(ip),
                            child: Text(
                              deviceNames[ip] ?? ip,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                                color:
                                    connectedIp == ip
                                        ? Colors.white
                                        : const Color(0xFF222222),
                              ),
                            ),
                          ),
                          subtitle: Text(
                            connectedIp == ip
                                ? '✅ 已连接'
                                : connectedSocket == null
                                ? '⚠️ 未连接'
                                : '🔌 正在连接其他设备',
                            style: TextStyle(
                              color:
                                  connectedIp == ip
                                      ? Colors.white70
                                      : const Color(0xFF888888),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          trailing: ElevatedButton(
                            onPressed: isSearching
                                ? null
                                : connectedIp == ip
                                ? () => _disconnect() // 如果已连接，显示断开连接
                                : connectedSocket != null
                                ? null // 如果连接了其他设备，禁用按钮
                                : () => _connectTo(ip), // 如果未连接，显示连接
                            style: ElevatedButton.styleFrom(
                              backgroundColor: connectedIp == ip
                                  ? Color(0xfff8696b)
                              // 已连接时显示红色
                                  : connectedSocket != null
                                  ? Colors.grey.withOpacity(0.5) // 连接其他设备时显示灰色
                                  : Colors.white,
                              foregroundColor: connectedIp == ip
                                  ? Colors.white
                                  : connectedSocket != null
                                  ? Colors.grey
                                  : const Color(0xFF00D4FF),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              isLocalIp(ip)
                                  ? '本机'
                                  : connectedIp == ip
                                  ? '断开连接'
                                  : connectedSocket != null
                                  ? '已连接其他'
                                  : '连接设备',
                              style: TextStyle(
                                color: connectedIp == ip
                                    ? Colors.white
                                    : connectedSocket != null
                                    ? Colors.grey
                                    : const Color(0xFF00D4FF),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                  // 这里还不能使用花括号
                  if (connectedSocket != null)
                    // 文件操作按钮
                    Row(
                      children: [
                        Expanded(
                          child: GradientButton(
                            enabled: connectedSocket != null,
                            icon: const Icon(Icons.image, color: Colors.white),
                            label: '发送图片',
                            onPressed: _pickAndSendFile,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GradientButton(
                            enabled: connectedSocket != null,
                            icon: const Icon(
                              Icons.attach_file,
                              color: Colors.white,
                            ),
                            label: '发送文件',
                            onPressed: _pickAnyFile,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // 添加发送文本按钮
                        Expanded(
                          child: GradientButton(
                            enabled: connectedSocket != null,
                            icon: const Icon(
                              Icons.message,
                              color: Colors.white,
                            ),
                            label: '发送文本',
                            onPressed: _showSendTextDialog,
                          ),
                        ),
                      ],
                    ),
                  if (connectedSocket != null) const SizedBox(height: 24),
                  // 日志区域
                  _buildLogModern(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  // 状态卡片
  Widget _buildStatusCard({
    required IconData icon,
    required String title,
    required bool isActive,
    required Color activeColor,
    String? customText,
  }) {
    return Container(
      width: 70,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? const Color(0x2200D4FF) : const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color:
                isActive
                    ? const Color(0xFF00D4FF).withOpacity(0.06)
                    : Colors.black.withOpacity(0.01),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
        border: Border.all(
          color: isActive ? const Color(0x3300D4FF) : const Color(0xFFE0E0E0),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isActive ? const Color(0xFF00D4FF) : const Color(0xFFB0BEC5),
            size: 18,
          ),
          const SizedBox(height: 4),
          Text(
            customText ?? (isActive ? '正常' : '未开启'),
            style: TextStyle(
              fontSize: 11,
              color:
                  isActive ? const Color(0xFF00D4FF) : const Color(0xFFB0BEC5),
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            title,
            style: const TextStyle(fontSize: 10, color: Color(0xFF888888)),
          ),
        ],
      ),
    );
  }

  // 现代化日志区域
  Widget _buildLogModern(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF00D4FF), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00D4FF).withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 0),
            child: Row(
              children: [
                const Icon(Icons.list_alt, size: 18, color: Color(0xFF00D4FF)),
                const SizedBox(width: 6),
                const Text(
                  '操作日志',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFF00D4FF),
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _clearLog,
                  icon: const Icon(
                    Icons.clear_all,
                    size: 16,
                    color: Color(0xFF00D4FF),
                  ),
                  label: const Text(
                    '清空',
                    style: TextStyle(fontSize: 12, color: Color(0xFF00D4FF)),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF00D4FF),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 120,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Text(
                log.isEmpty ? '暂无日志' : log,
                style: const TextStyle(fontSize: 12, color: Color(0xFF222222)),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:async';

import '../../common/DeviceManager.dart';

class SendPage extends StatefulWidget {
  const SendPage({super.key});

  @override
  State<SendPage> createState() => _SendPageState();
}

class _SendPageState extends State<SendPage> {
  final List<Map<String, dynamic>> menuItems = [
    {
      'icon': Icons.text_fields,
      'title': '文本',
      'type': 'text',
    },
    {
      'icon': Icons.image,
      'title': '图片',
      'type': 'image',
    },
    {
      'icon': Icons.video_camera_back,
      'title': '视频',
      'type': 'video',
    },
  ];

  int selectedMenuIndex = 0;
  final TextEditingController _textController = TextEditingController();
  Socket? connectedSocket;
  String? connectedIp;

  @override
  void dispose() {
    _textController.dispose();
    connectedSocket?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false, // 防止输入法弹起时压缩布局
      appBar: AppBar(title: const Text('发送页面')),
      body: SafeArea(
        child: Column(
          children: [
            // 固定的顶部区域
            Container(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '选择要发送的类型',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 120,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: menuItems.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final item = menuItems[index];
                        final isSelected = selectedMenuIndex == index;
                        return InkWell(
                          onTap: () {
                            setState(() {
                              selectedMenuIndex = index;
                            });
                            print('Selected type: ${item['type']}');
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            width: 100,
                            decoration: BoxDecoration(
                              gradient: isSelected
                                  ? const LinearGradient(
                                      colors: [Color(0xFF00D4FF), Color(0xFF0099CC)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : null,
                              color: isSelected ? null : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.transparent
                                    : const Color(0xFF00D4FF),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: isSelected
                                      ? const Color(0xFF00D4FF).withOpacity(0.10)
                                      : Colors.black.withOpacity(0.03),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  item['icon'],
                                  size: 32,
                                  color: isSelected ? Colors.white : const Color(0xFF00D4FF),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  item['title'],
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: isSelected ? Colors.white : const Color(0xFF00D4FF),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            // 可滚动的内容区域
            Expanded(
              child: selectedMenuIndex == 0 ? _buildTextSendWidget() : _buildDeviceCard(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextSendWidget() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '发送文本消息',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          // 使用Expanded让文本框占据剩余空间
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF00D4FF)),
              ),
              child: TextField(
                controller: _textController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  hintText: '请输入要发送的文本内容...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                ),
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 发送按钮区域
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _textController.text.trim().isEmpty ? null : _sendText,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00D4FF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: const Text(
                      '发送文本',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _textController.text.trim().isEmpty ? null : _testSendText,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: const Text(
                      '测试发送',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _sendText() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    // 获取连接的设备
    final devices = DeviceManager().mapToList();
    if (devices.isEmpty) {
      _showMessage('请先连接设备');
      return;
    }

    // 选择要发送的设备
    final selectedDevice = await _showDeviceSelectionDialog(devices);
    if (selectedDevice == null) return;

    try {
      _showMessage('正在连接到设备 ${selectedDevice.ip}...');

      // 连接到目标设备
      final socket = await Socket.connect(selectedDevice.ip, 5000).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('连接超时'),
      );

      // 发送文本消息 - 修复：直接使用write方法，不要再次编码
      final message = 'TEXT:$text\n';
      print('_sendText - 发送文本消息: "$message"');
      socket.write(message);  // 修改这里，不要使用utf8.encode

      // 等待数据发送完成
      await socket.flush();

      // 等待一小段时间确保数据发送完成
      await Future.delayed(const Duration(milliseconds: 1000));

      print('发送完成，准备关闭socket');
      // 关闭socket
      await socket.close();

      _showMessage('文本发送成功');
      _textController.clear();

    } catch (e) {
      String errorMsg = '发送失败';
      if (e is SocketException) {
        errorMsg = '连接失败: ${e.message}';
      } else if (e is TimeoutException) {
        errorMsg = '连接超时，请检查设备是否在线';
      } else {
        errorMsg = '发送失败: $e';
      }
      _showMessage(errorMsg);
      print('发送文本错误: $e');
    }
  }

  Future<void> _testSendText() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    // 获取本机IP地址
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );

      String? localIp;
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          final ip = addr.address;
          if (ip.startsWith('192.168.') || ip.startsWith('10.') ||
              (ip.startsWith('172.') && int.parse(ip.split('.')[1]) >= 16 && int.parse(ip.split('.')[1]) <= 31)) {
            localIp = ip;
            break;
          }
        }
        if (localIp != null) break;
      }

      if (localIp == null) {
        _showMessage('未找到有效的本地IP地址');
        return;
      }

      _showMessage('正在测试发送到本机 $localIp...');

      // 连接到本机
      final socket = await Socket.connect(localIp, 5000).timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw TimeoutException('连接超时'),
      );

      // 发送文本消息 - 修复：直接使用write方法，不要再次编码
      final message = 'TEXT:$text\n';
      print('_testSendText - 发送文本消息: "$message"');
      socket.write(message);  // 修改这里，不要使用utf8.encode

      // 等待数据发送完成
      await socket.flush();

      // 等待一小段时间确保数据发送完成
      await Future.delayed(const Duration(milliseconds: 1000));

      print('测试发送完成，准备关闭socket');
      // 关闭socket
      await socket.close();

      _showMessage('测试发送成功');

    } catch (e) {
      _showMessage('测试发送失败: $e');
      print('测试发送错误: $e');
    }
  }



  Future<Device?> _showDeviceSelectionDialog(List<Device> devices) async {
    return showDialog<Device>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择接收设备'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: devices.length,
            itemBuilder: (context, index) {
              final device = devices[index];
              return ListTile(
                leading: Icon(
                  Icons.devices,
                  color: device.isOnline ? const Color(0xFF00D4FF) : Colors.grey,
                ),
                title: Text(device.name),
                subtitle: Text(device.ip),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: device.isOnline ? const Color(0xFF00FF88) : Colors.grey,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    device.isOnline ? '在线' : '离线',
                    style: TextStyle(
                      color: device.isOnline ? Colors.white : Colors.grey[700],
                      fontSize: 12,
                    ),
                  ),
                ),
                onTap: device.isOnline ? () => Navigator.of(context).pop(device) : null,
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF00D4FF),
      ),
    );
  }

  Widget _buildDeviceCard() {
    return Expanded(
      child: AnimatedBuilder(
        animation: DeviceManager(),
        builder: (context, _) {
          final devices = DeviceManager().mapToList();

          if (devices.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('暂无设备', style: TextStyle(color: Color(0xFF00D4FF))),
            );
          }

          return ListView.builder(
            itemCount: devices.length,
            itemBuilder: (context, index) {
              final device = devices[index];
              final isOnline = device.isOnline;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: isOnline
                          ? const Color(0xFF00D4FF).withOpacity(0.10)
                          : Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isOnline ? const Color(0xFF00D4FF) : const Color(0xFFE0E0E0),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.devices,
                      color: isOnline ? Colors.white : Colors.grey,
                      size: 22,
                    ),
                  ),
                  title: Text(
                    device.name,
                    style: TextStyle(
                      color: isOnline ? const Color(0xFF222222) : Colors.grey[700],
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Text(
                    device.ip,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF888888)),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: isOnline
                          ? const Color(0x2200FF88)
                          : Colors.grey.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isOnline ? '在线' : '离线',
                      style: TextStyle(
                        color: isOnline ? const Color(0xFF00FF88) : Colors.grey,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

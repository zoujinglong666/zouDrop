import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('发送页面')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(12.0),
            child: Text(
              '选择要发送的类型',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
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
          _buildDeviceCard()
        ],
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

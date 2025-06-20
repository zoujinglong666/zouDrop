import 'package:flutter/material.dart';

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
            height: 120, // 卡片高度
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: menuItems.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final item = menuItems[index];
                return _buildMenuCard(item);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard(Map<String, dynamic> item) {
    return InkWell(
      onTap: () {
        print('Selected type: ${item['type']}');
      },
      borderRadius: BorderRadius.circular(12),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 3,
        child: SizedBox(
          width: 100,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(item['icon'], size: 32, color: Colors.blue),
              const SizedBox(height: 8),
              Text(
                item['title'],
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

}

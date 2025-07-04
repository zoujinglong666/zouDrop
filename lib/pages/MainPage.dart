import 'package:flutter/material.dart';
import 'package:zou_drop/pages/tabbar/deviceSearchPage.dart';
import 'package:zou_drop/pages/tabbar/home.dart';
import 'package:zou_drop/pages/tabbar/send.dart';
import 'package:zou_drop/pages/tabbar/setting.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage>
    with SingleTickerProviderStateMixin {
  int selectedIndex = 0;

  final List<Widget> pages = const [HomePage(), SendPage(),DeviceSearchPage(), SettingsPage()];

  final List<_TabItem> tabs = const [
    _TabItem(icon: Icons.home, label: '接收'),
    _TabItem(icon: Icons.send, label: '发送'),
    _TabItem(icon: Icons.search, label: '设备搜索'),
    _TabItem(icon: Icons.settings, label: '设置'),
  ];

  void onTabTapped(int index) {
    setState(() {
      selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom + 64;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // 给页面内容预留底部空间
          Padding(
            padding: EdgeInsets.only(bottom: bottomPadding),
            child: IndexedStack(index: selectedIndex, children: pages),
          ),

          // 底部导航栏加 SafeArea
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              child: _CustomTabBar(
                tabs: tabs,
                selectedIndex: selectedIndex,
                onTap: onTabTapped,
                activeColor: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

}

class _TabItem {
  final IconData icon;
  final String label;

  const _TabItem({required this.icon, required this.label});
}

class _CustomTabBar extends StatelessWidget {
  final List<_TabItem> tabs;
  final int selectedIndex;
  final Function(int) onTap;
  final Color activeColor;

  const _CustomTabBar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onTap,
    this.activeColor = Colors.blue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60, // 减小高度
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(tabs.length, (index) {
          final tab = tabs[index];
          final isSelected = index == selectedIndex;

          return GestureDetector(
            onTap: () => onTap(index),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              padding: isSelected
                  ? const EdgeInsets.symmetric(horizontal: 16, vertical: 8)
                  : const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF00D4FF),
                          Color(0xFF0099CC),
                        ],
                      )
                    : null,
                borderRadius: BorderRadius.circular(12),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: const Color(0xFF00D4FF).withOpacity(0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    children: [
                      Icon(
                        tab.icon,
                        size: isSelected ? 22 : 20, // 减小图标尺寸
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFF666666),
                      ),
                      // 更小的连接状态指示器
                      if (isSelected)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF00FF88),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4), // 减小间距
                  Text(
                    tab.label,
                    style: TextStyle(
                      fontSize: 10, // 减小字体
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF888888),
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      letterSpacing: 0.3,
                    ),
                  ),
                  // 更小的速度指示条
                  if (isSelected)
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      width: 12,
                      height: 1.5,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF00FF88),
                            Color(0xFF00D4FF),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(0.75),
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

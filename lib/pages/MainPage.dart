import 'package:flutter/material.dart';
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

  final List<Widget> pages = const [HomePage(), SendPage(), SettingsPage()];

  final List<_TabItem> tabs = const [
    _TabItem(icon: Icons.home, label: '接收'),
    _TabItem(icon: Icons.send, label: '发送'),
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
      decoration: BoxDecoration(
        color: Colors.white,
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
              padding:
                  isSelected
                      ? const EdgeInsets.symmetric(horizontal: 20, vertical: 12)
                      : const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color:
                    isSelected
                        ? activeColor.withOpacity(0.5)
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                boxShadow:
                    isSelected
                        ? [
                          BoxShadow(
                            color: activeColor.withOpacity(0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                        : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    tab.icon,
                    size: isSelected ? 28 : 24,
                    color:
                        isSelected ? activeColor : Colors.grey.withOpacity(0.6),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tab.label,
                    style: TextStyle(
                      fontSize: 13,
                      color:
                          isSelected
                              ? activeColor
                              : Colors.grey.withOpacity(0.6),
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.normal,
                      letterSpacing: 0.4,
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

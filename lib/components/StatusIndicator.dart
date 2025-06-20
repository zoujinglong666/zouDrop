import 'package:flutter/material.dart';

class StatusIndicator extends StatelessWidget {
  final bool isActive;
  final String activeText;
  final String inactiveText;
  final String Function(bool isActive)? textBuilder;
  final Color activeColor;
  final Color inactiveColor;
  final double iconSize;
  final TextStyle? textStyle;

  const StatusIndicator({
    super.key,
    required this.isActive,
    this.activeText = '',
    this.inactiveText = '',
    this.textBuilder,
    this.activeColor = Colors.green,
    this.inactiveColor = Colors.red,
    this.iconSize = 12,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? activeColor : inactiveColor;
    final text = textBuilder != null
        ? textBuilder!(isActive)
        : (isActive ? activeText : inactiveText);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.circle, color: color, size: iconSize),
        const SizedBox(width: 4),
        Text(
          text,
          style: textStyle ??
              TextStyle(
                color: color,
                fontSize: 14,
              ),
        ),
      ],
    );
  }
}

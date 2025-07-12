import 'package:flutter/material.dart';

class AnimatedGradientLinearProgress extends StatelessWidget {
  final double value; // 0.0 - 1.0
  final double height;
  final Duration duration;
  final Color backgroundColor;
  final List<Color> gradientColors;
  final BorderRadius borderRadius;
  final bool showPercentage;
  final TextStyle? textStyle;
  final bool enableGlow;
  final bool reverse;

  const AnimatedGradientLinearProgress({
    super.key,
    required this.value,
    this.height = 8,
    this.duration = const Duration(milliseconds: 600),
    this.backgroundColor = const Color(0xFFE0E0E0),
    this.gradientColors = const [Color(0xFF4A90E2), Color(0xFF50E3C2)],
    this.borderRadius = const BorderRadius.all(Radius.circular(5)),
    this.showPercentage = false,
    this.textStyle,
    this.enableGlow = false,
    this.reverse = false,
  });

  @override
  Widget build(BuildContext context) {
    final textPercent = '${(value.clamp(0.0, 1.0) * 100).toStringAsFixed(0)}%';

    return Stack(
      alignment: Alignment.center,
      children: [
        // 背景条
        Container(
          height: height,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: borderRadius,
          ),
          clipBehavior: Clip.hardEdge,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: value.clamp(0.0, 1.0)),
            duration: duration,
            builder: (context, animatedValue, _) {
              return Align(
                alignment:
                reverse ? Alignment.centerRight : Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: animatedValue,
                  child: Container(
                    height: height,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: gradientColors,
                        begin: reverse ? Alignment.centerRight : Alignment.centerLeft,
                        end: reverse ? Alignment.centerLeft : Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.horizontal(
                        left: reverse ? Radius.circular(height / 2) : Radius.zero,
                        right: reverse ? Radius.zero : Radius.circular(height / 2),
                      ),
                      boxShadow: enableGlow
                          ? [
                        BoxShadow(
                          color: gradientColors.last.withOpacity(0.6),
                          blurRadius: 6,
                          spreadRadius: 1,
                        )
                      ]
                          : null,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        // 百分比文字
        // if (showPercentage)
        //   Text(
        //     textPercent,
        //     style: textStyle ??
        //         TextStyle(
        //           fontSize: height * 0.6,
        //           fontWeight: FontWeight.bold,
        //           color: Colors.black87,
        //         ),
        //   ),
      ],
    );
  }
}

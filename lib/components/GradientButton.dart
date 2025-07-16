import 'package:flutter/material.dart';

class GradientButton extends StatelessWidget {
  final bool enabled;
  final Icon icon;
  final String label;
  final VoidCallback? onPressed;
  final List<Color> activeColors;
  final List<Color> disabledColors;

  const GradientButton({
    super.key,
    required this.enabled,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.activeColors = const [Color(0xFF00D4FF), Color(0xFF0099CC)],
    this.disabledColors = const [Color(0xFFF5F6FA), Color(0xFFF5F6FA)],
  });

  @override
  Widget build(BuildContext context) {
    final colors = enabled ? activeColors : disabledColors;

    return Container(
      height: 44,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.all(Radius.circular(10)),
      ),
      child: ElevatedButton.icon(
        onPressed: enabled ? onPressed : null,
        icon: icon,
        label: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}

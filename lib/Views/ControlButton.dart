import 'package:flutter/material.dart';

class ControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool destructive;
  final double iconSize;

  const ControlButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.destructive = false,
    this.iconSize = 40,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color.fromRGBO(0, 217, 255, 0.2),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(999),
        child: Center(
          child: Icon(
            icon,
            color: destructive ? const Color(0xFFD90000) : const Color(0xFF00D9FF),
            size: iconSize,
          ),
        ),
      ),
    );
  }
}

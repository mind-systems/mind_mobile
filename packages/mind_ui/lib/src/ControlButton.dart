import 'package:flutter/material.dart';

class ControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
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
    final cs = Theme.of(context).colorScheme;
    final isDisabled = onPressed == null;
    return Opacity(
      opacity: isDisabled ? 0.4 : 1.0,
      child: Material(
        color: cs.primary.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(999),
          child: Center(
            child: Icon(
              icon,
              color: destructive ? const Color(0xFFD90000) : cs.primary,
              size: iconSize,
            ),
          ),
        ),
      ),
    );
  }
}

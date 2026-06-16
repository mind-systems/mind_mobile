import 'package:flutter/material.dart';

/// A horizontal bar cell that visualises a single metric value in the range
/// 0..1. Intended for use inside BciDataScreen — not exported from the package.
class BciMetricBar extends StatelessWidget {
  final double? value;
  final Color color;
  final String label;

  const BciMetricBar({
    super.key,
    required this.value,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final clamped = (value ?? 0.0).clamp(0.0, 1.0);
    final valueText = value != null ? '${(clamped * 100).round()}' : '--';
    final textTheme = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        return AnimatedOpacity(
          opacity: value != null ? 1.0 : 0.3,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(label, style: textTheme.bodyMedium),
                  const Spacer(),
                  Text(
                    valueText,
                    style: textTheme.bodySmall,
                    textAlign: TextAlign.right,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOut,
                height: 24,
                width: maxWidth * clamped,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

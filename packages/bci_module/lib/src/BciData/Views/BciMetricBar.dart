import 'package:flutter/material.dart';

/// A vertical bar widget that visualises a single metric value in the range
/// 0..1. Intended for use inside BciDataScreen — not exported from the package.
class BciMetricBar extends StatelessWidget {
  final double? value;
  final Color color;
  final String label;

  static const double _barWidth = 36.0;
  static const double _maxBarHeight = 120.0;

  const BciMetricBar({
    super.key,
    required this.value,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final clamped = (value ?? 0.0).clamp(0.0, 1.0);
    final opacity = value == null ? 0.3 : 1.0;

    return SizedBox(
      width: _barWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            height: _maxBarHeight,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: AnimatedOpacity(
                opacity: opacity,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOut,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOut,
                  width: _barWidth,
                  height: _maxBarHeight * clamped,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

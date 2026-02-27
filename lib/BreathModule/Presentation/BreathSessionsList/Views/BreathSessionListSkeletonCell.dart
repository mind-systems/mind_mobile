import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class BreathSessionListSkeletonCell extends StatelessWidget {
  final bool animated;

  const BreathSessionListSkeletonCell({
    super.key,
    this.animated = true,
  });

  static const _highlightColor = Color(0xFF2A3A50); // shimmer only

  Widget _block(double width, double height, Color baseColor) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: BorderRadius.circular(4),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final baseColor = Theme.of(context).cardColor;

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title placeholder (2 lines)
          _block(200, 16, baseColor),
          const SizedBox(height: 6),
          _block(150, 16, baseColor),
          const SizedBox(height: 8),
          // Subtitle placeholder
          _block(180, 14, baseColor),
          const SizedBox(height: 12),
          // Divider
          _block(double.infinity, 1, baseColor),
          const SizedBox(height: 8),
          // Duration placeholder
          Align(
            alignment: Alignment.centerRight,
            child: _block(50, 12, baseColor),
          ),
        ],
      ),
    );

    if (!animated) return content;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: _highlightColor,
      child: content,
    );
  }
}

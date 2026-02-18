import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class BreathSessionListSkeletonCell extends StatelessWidget {
  final bool animated;

  const BreathSessionListSkeletonCell({
    super.key,
    this.animated = true,
  });

  static const _baseColor = Color(0xFF1A2433);
  static const _highlightColor = Color(0xFF2A3A50);

  Widget _block(double width, double height) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: _baseColor,
          borderRadius: BorderRadius.circular(4),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title placeholder (2 lines)
          _block(200, 16),
          const SizedBox(height: 6),
          _block(150, 16),
          const SizedBox(height: 8),
          // Subtitle placeholder
          _block(180, 14),
          const SizedBox(height: 12),
          // Divider
          _block(double.infinity, 1),
          const SizedBox(height: 8),
          // Duration placeholder
          Align(
            alignment: Alignment.centerRight,
            child: _block(50, 12),
          ),
        ],
      ),
    );

    if (!animated) return content;

    return Shimmer.fromColors(
      baseColor: _baseColor,
      highlightColor: _highlightColor,
      child: content,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class BreathSessionListSkeletonCell extends StatelessWidget {
  final bool animated;

  const BreathSessionListSkeletonCell({
    super.key,
    this.animated = true,
  });

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title placeholder (2 lines)
          Container(
            width: 200,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: 150,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(4),
            ),
          ),

          const SizedBox(height: 8),

          // Subtitle placeholder
          Container(
            width: 180,
            height: 14,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(4),
            ),
          ),

          const SizedBox(height: 12),

          // Divider
          Divider(
            height: 1,
            thickness: 1,
            color: Colors.grey[300],
          ),

          const SizedBox(height: 8),

          // Duration placeholder
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              width: 50,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ],
      ),
    );

    if (!animated) return content;

    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: content,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class BreathSessionListSkeletonCell extends StatelessWidget {
  final bool animated;

  const BreathSessionListSkeletonCell({
    super.key,
    this.animated = true,
  });

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
    final theme = Theme.of(context);
    final baseColor = theme.cardColor;
    final pixel = 1 / MediaQuery.of(context).devicePixelRatio;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 14),
              // Title placeholder (2 lines)
              _block(200, 14, baseColor),
              const SizedBox(height: 5),
              _block(140, 14, baseColor),
              const SizedBox(height: 10),
              // Duration + subtitle row
              Row(
                children: [
                  _block(44, 13, baseColor),
                  const SizedBox(width: 8),
                  _block(160, 13, baseColor),
                ],
              ),
              const SizedBox(height: 14),
            ],
          ),
        ),
        // Hairline divider
        Container(
          height: pixel,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          color: baseColor,
        ),
      ],
    );

    if (!animated) return content;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: theme.highlightColor,
      child: content,
    );
  }
}

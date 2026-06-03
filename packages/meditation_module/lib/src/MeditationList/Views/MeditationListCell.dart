import 'package:flutter/material.dart';

class MeditationListCell extends StatelessWidget {
  final String poseId;
  final String title;
  final VoidCallback? onTap;

  const MeditationListCell({
    required this.poseId,
    required this.title,
    this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final assetName = 'meditation-pose-${poseId.replaceAll('_', '-')}.png';

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 8),
            Image.asset(
              'assets/images/modules/meditation/$assetName',
              height: 120,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) =>
                  const SizedBox(height: 120),
            ),
          ],
        ),
      ),
    );
  }
}

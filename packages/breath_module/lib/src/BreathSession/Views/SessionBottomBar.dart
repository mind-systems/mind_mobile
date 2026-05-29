import 'package:flutter/material.dart';
import '../BreathSessionLayout.dart';

class SessionBottomBar extends StatelessWidget {
  const SessionBottomBar({
    super.key,
    required this.trailingActions,
    this.leadingActions = const [],
    this.iconSize = BreathSessionLayout.kIconSize,
  });

  final List<Widget> trailingActions;
  final List<Widget> leadingActions;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return ColoredBox(
      color: Theme.of(context).cardColor.withValues(alpha: 0.3),
      child: Padding(
        padding: EdgeInsets.only(
          left: 32,
          right: 32,
          top: BreathSessionLayout.kBottomBarVPadding,
          bottom: BreathSessionLayout.kBottomBarVPadding + mq.padding.bottom,
        ),
        // Resolves via IconButton → IconButtonTheme → IconTheme. A non-null IconButtonTheme.iconSize anywhere up the tree will shadow this.
        child: IconTheme.merge(
          data: IconThemeData(size: iconSize),
          child: Row(
            children: [
              Row(spacing: 8, children: leadingActions),
              const Spacer(),
              Row(spacing: 8, children: trailingActions),
            ],
          ),
        ),
      ),
    );
  }
}

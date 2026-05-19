import 'package:flutter/material.dart';
import '../BreathSessionLayout.dart';

class SessionBottomBar extends StatelessWidget {
  const SessionBottomBar({
    super.key,
    required this.actions,
    this.iconSize = BreathSessionLayout.kIconSize,
  });

  final List<Widget> actions;
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
            mainAxisAlignment: MainAxisAlignment.end,
            spacing: 8,
            children: actions,
          ),
        ),
      ),
    );
  }
}

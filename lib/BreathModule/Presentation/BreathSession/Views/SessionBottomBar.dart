import 'package:flutter/material.dart';

class SessionBottomBar extends StatelessWidget {
  const SessionBottomBar({super.key, required this.actions});
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).cardColor.withValues(alpha: 0.3),
      child: Padding(
        padding: EdgeInsets.only(
          left: 32,
          right: 32,
          top: 8,
          bottom: 8 + MediaQuery.of(context).padding.bottom,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: actions,
        ),
      ),
    );
  }
}

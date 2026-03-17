import 'package:flutter/material.dart';

class BlinkingCursor extends StatefulWidget {
  final Color color;
  final bool active;

  const BlinkingCursor({super.key, required this.color, required this.active});

  @override
  State<BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    if (widget.active) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant BlinkingCursor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _controller.repeat(reverse: true);
    } else if (!widget.active && oldWidget.active) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: widget.active ? 1.0 : 0.0,
      child: FadeTransition(
        opacity: _controller,
        child: Container(
          width: 2,
          height: 16,
          margin: const EdgeInsets.only(left: 1),
          color: widget.color,
        ),
      ),
    );
  }
}

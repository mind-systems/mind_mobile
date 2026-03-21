import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class AutoScrollCarousel extends StatefulWidget {
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  const AutoScrollCarousel({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
  });

  @override
  State<AutoScrollCarousel> createState() => _AutoScrollCarouselState();
}

class _AutoScrollCarouselState extends State<AutoScrollCarousel>
    with SingleTickerProviderStateMixin {
  late final ScrollController _scrollController;
  late final Ticker _ticker;

  Duration _lastTickTime = Duration.zero;
  bool _forward = true;
  bool _userHasScrolled = false;

  // ~25 logical pixels per second
  static const double _pixelsPerSecond = 25.0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _ticker = createTicker(_onTick);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        _ticker.start();
      }
    });
  }

  void _onTick(Duration elapsed) {
    if (_userHasScrolled) return;
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    final max = position.maxScrollExtent;
    if (max <= 0) return;

    final dt = _lastTickTime == Duration.zero
        ? 0.0
        : (elapsed - _lastTickTime).inMicroseconds / 1e6;
    _lastTickTime = elapsed;

    final delta = _pixelsPerSecond * dt * (_forward ? 1 : -1);
    final newPixels = (position.pixels + delta).clamp(0.0, max);

    if (newPixels >= max && _forward) {
      _forward = false;
    } else if (newPixels <= 0 && !_forward) {
      _forward = true;
    }

    _scrollController.jumpTo(newPixels);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _userHasScrolled = true,
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        primary: false,
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: widget.itemCount,
        itemBuilder: (context, index) {
          return Padding(
            padding: EdgeInsets.only(right: index < widget.itemCount - 1 ? 10 : 0),
            child: widget.itemBuilder(context, index),
          );
        },
      ),
    );
  }
}

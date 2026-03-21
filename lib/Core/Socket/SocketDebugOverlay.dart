import 'package:flutter/material.dart';
import 'package:mind/Core/App.dart';
import 'package:mind/Core/Socket/SocketConnectionState.dart';

class SocketDebugOverlay extends StatefulWidget {
  const SocketDebugOverlay({super.key});

  @override
  State<SocketDebugOverlay> createState() => _SocketDebugOverlayState();
}

class _SocketDebugOverlayState extends State<SocketDebugOverlay> {
  static const double _cardWidth = 280.0;
  // 8.2% of card width visible on the right edge, 20.6% down the screen
  static const double _visibleFraction = 0.082;
  static const double _topFraction = 0.206;

  double? _top;
  double? _left;

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _top = (_top ?? 0) + details.delta.dy;
      _left = (_left ?? 0) + details.delta.dx;
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final top = _top ?? size.height * _topFraction;
    final left = _left ?? size.width - _cardWidth * _visibleFraction;

    return Stack(
      children: [
        Positioned(
          top: top,
          left: left,
          child: GestureDetector(
            onPanUpdate: _onPanUpdate,
            child: _buildCard(context),
          ),
        ),
      ],
    );
  }

  Widget _buildCard(BuildContext context) {
    final service = App.shared.liveSocketService;
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 280,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            StreamBuilder<SocketConnectionState>(
              stream: service.connectionState,
              initialData: SocketConnectionState.disconnected,
              builder: (context, snapshot) {
                final state = snapshot.data ?? SocketConnectionState.disconnected;
                final (label, color) = switch (state) {
                  SocketConnectionState.connected    => ('connected', Colors.greenAccent),
                  SocketConnectionState.connecting   => ('connecting', Colors.orangeAccent),
                  SocketConnectionState.disconnected => ('disconnected', Colors.redAccent),
                };
                return Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'socket: $label',
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 4),
            ValueListenableBuilder<String>(
              valueListenable: service.lastSentMessage,
              builder: (context, value, _) {
                return Text(
                  '↑ ${value.isEmpty ? '—' : value}',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                );
              },
            ),
            const SizedBox(height: 2),
            ValueListenableBuilder<String>(
              valueListenable: service.lastReceivedMessage,
              builder: (context, value, _) {
                return Text(
                  '↓ ${value.isEmpty ? '—' : value}',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

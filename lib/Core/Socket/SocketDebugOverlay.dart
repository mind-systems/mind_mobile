import 'package:flutter/material.dart';
import 'package:mind/Core/App.dart';
import 'package:mind/Core/Socket/SocketConnectionState.dart';

class SocketDebugOverlay extends StatefulWidget {
  const SocketDebugOverlay({super.key});

  @override
  State<SocketDebugOverlay> createState() => _SocketDebugOverlayState();
}

class _SocketDebugOverlayState extends State<SocketDebugOverlay> {
  double _top = 60;
  double _left = 16;

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _top += details.delta.dy;
      _left += details.delta.dx;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: _top,
          left: _left,
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

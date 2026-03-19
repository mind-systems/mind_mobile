import 'dart:async';

import 'package:mind/McpModule/Core/Models/Token.dart';
import 'package:mind/McpModule/Core/Models/TokenNotifierEvent.dart';
import 'package:mind/McpModule/Core/TokenNotifier.dart';
import 'package:mind/McpModule/Presentation/McpScreen/IMcpService.dart';
import 'package:mind/McpModule/Presentation/McpScreen/Models/McpScreenDTOs.dart';

class McpService implements IMcpService {
  final TokenNotifier _tokenNotifier;
  final StreamController<McpScreenEvent> _controller = StreamController.broadcast();
  StreamSubscription<dynamic>? _subscription;

  McpService({required TokenNotifier tokenNotifier}) : _tokenNotifier = tokenNotifier {
    _subscription = _tokenNotifier.stream.listen(_onNotifierState);
  }

  void _onNotifierState(dynamic state) {
    final event = state.lastEvent;
    if (event == null) return;

    switch (event) {
      case TokensLoaded e:
        _controller.add(TokensLoadedEvent(e.tokens.map(_toDTO).toList()));
      case TokenCreated e:
        _controller.add(TokenCreatedEvent(token: _toDTO(e.token), plainToken: e.plainToken));
      case TokenRevoked e:
        _controller.add(TokenRevokedEvent(e.id));
      case TokenError e:
        _controller.add(TokenErrorEvent(e.message));
    }
  }

  TokenItemDTO _toDTO(Token token) {
    return TokenItemDTO(
      id: token.id,
      name: token.name,
      createdAtFormatted: _formatDate(token.createdAt),
    );
  }

  String _formatDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final day = dt.day.toString().padLeft(2, '0');
    final month = months[dt.month - 1];
    final year = dt.year;
    return 'Created $day $month $year';
  }

  @override
  Stream<McpScreenEvent> observeChanges() => _controller.stream;

  @override
  Future<void> loadTokens() => _tokenNotifier.loadTokens();

  @override
  Future<void> createToken(String name) => _tokenNotifier.createToken(name);

  @override
  Future<void> revokeToken(String id) => _tokenNotifier.revokeToken(id);

  void dispose() {
    _subscription?.cancel();
    _controller.close();
  }
}

import 'dart:developer';

import 'package:rxdart/rxdart.dart';

import 'package:mind/Core/Api/ITokenApi.dart';
import 'package:mind/Core/Api/Models/CreateTokenRequest.dart';
import 'package:mind/McpModule/Core/Models/Token.dart';
import 'package:mind/McpModule/Core/Models/TokenNotifierEvent.dart';

class TokenNotifierState {
  final List<Token> tokens;
  final TokenNotifierEvent? lastEvent;

  const TokenNotifierState({required this.tokens, this.lastEvent});
}

class TokenNotifier {
  final ITokenApi _api;

  final BehaviorSubject<TokenNotifierState> _subject = BehaviorSubject.seeded(
    const TokenNotifierState(tokens: []),
  );

  TokenNotifier({required ITokenApi api}) : _api = api;

  Stream<TokenNotifierState> get stream => _subject.stream;

  TokenNotifierState get currentState => _subject.value;

  Future<void> loadTokens() async {
    try {
      final dtos = await _api.fetchTokens();
      final tokens = dtos.map((dto) => Token(
        id: dto.id,
        name: dto.name,
        createdAt: DateTime.parse(dto.createdAt),
      )).toList();
      _subject.add(TokenNotifierState(tokens: tokens, lastEvent: TokensLoaded(tokens)));
    } catch (e) {
      log('[TokenNotifier] loadTokens error: $e', name: 'TokenNotifier');
      _subject.add(TokenNotifierState(tokens: _subject.value.tokens, lastEvent: TokenError(e.toString())));
    }
  }

  Future<void> createToken(String name) async {
    try {
      final response = await _api.createToken(CreateTokenRequest(name: name));
      final token = Token(
        id: response.metadata.id,
        name: response.metadata.name,
        createdAt: DateTime.parse(response.metadata.createdAt),
      );
      final updated = [token, ..._subject.value.tokens];
      _subject.add(TokenNotifierState(tokens: updated, lastEvent: TokenCreated(token: token, plainToken: response.token)));
    } catch (e) {
      log('[TokenNotifier] createToken error: $e', name: 'TokenNotifier');
      _subject.add(TokenNotifierState(tokens: _subject.value.tokens, lastEvent: TokenError(e.toString())));
    }
  }

  Future<void> revokeToken(String id) async {
    try {
      await _api.revokeToken(id);
      final updated = _subject.value.tokens.where((t) => t.id != id).toList();
      _subject.add(TokenNotifierState(tokens: updated, lastEvent: TokenRevoked(id)));
    } catch (e) {
      log('[TokenNotifier] revokeToken error: $e', name: 'TokenNotifier');
      _subject.add(TokenNotifierState(tokens: _subject.value.tokens, lastEvent: TokenError(e.toString())));
    }
  }

  void dispose() {
    _subject.close();
  }
}

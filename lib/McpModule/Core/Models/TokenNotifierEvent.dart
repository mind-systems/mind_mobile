import 'package:mind/McpModule/Core/Models/Token.dart';

sealed class TokenNotifierEvent {}

class TokensLoaded extends TokenNotifierEvent {
  final List<Token> tokens;
  TokensLoaded(this.tokens);
}

class TokenCreated extends TokenNotifierEvent {
  final Token token;
  final String plainToken;
  TokenCreated({required this.token, required this.plainToken});
}

class TokenRevoked extends TokenNotifierEvent {
  final String id;
  TokenRevoked(this.id);
}

class TokenError extends TokenNotifierEvent {
  final String message;
  TokenError(this.message);
}

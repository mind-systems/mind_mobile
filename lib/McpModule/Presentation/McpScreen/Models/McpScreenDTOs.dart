class TokenItemDTO {
  final String id;
  final String name;
  final String createdAtFormatted;

  TokenItemDTO({
    required this.id,
    required this.name,
    required this.createdAtFormatted,
  });
}

sealed class McpScreenEvent {}

class TokensLoadedEvent extends McpScreenEvent {
  final List<TokenItemDTO> tokens;
  TokensLoadedEvent(this.tokens);
}

class TokenCreatedEvent extends McpScreenEvent {
  final TokenItemDTO token;
  final String plainToken;
  TokenCreatedEvent({required this.token, required this.plainToken});
}

class TokenRevokedEvent extends McpScreenEvent {
  final String id;
  TokenRevokedEvent(this.id);
}

class TokenErrorEvent extends McpScreenEvent {
  final String message;
  TokenErrorEvent(this.message);
}

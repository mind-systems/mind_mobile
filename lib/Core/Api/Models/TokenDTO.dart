class TokenDTO {
  final String id;
  final String name;
  final String createdAt;

  TokenDTO({
    required this.id,
    required this.name,
    required this.createdAt,
  });

}

class CreateTokenResponse {
  final String token;
  final TokenDTO metadata;

  CreateTokenResponse({required this.token, required this.metadata});

}

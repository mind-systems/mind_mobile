class TokenDTO {
  final String id;
  final String name;
  final String createdAt;

  TokenDTO({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  factory TokenDTO.fromJson(Map<String, dynamic> json) => TokenDTO(
    id: json['id'] as String,
    name: json['name'] as String,
    createdAt: json['createdAt'] as String,
  );
}

class CreateTokenResponse {
  final String token;
  final TokenDTO metadata;

  CreateTokenResponse({required this.token, required this.metadata});

  factory CreateTokenResponse.fromJson(Map<String, dynamic> json) => CreateTokenResponse(
    token: json['token'] as String,
    metadata: TokenDTO.fromJson(json),
  );
}

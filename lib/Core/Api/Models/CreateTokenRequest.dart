class CreateTokenRequest {
  final String name;

  CreateTokenRequest({required this.name});

  Map<String, dynamic> toJson() => {'name': name};
}

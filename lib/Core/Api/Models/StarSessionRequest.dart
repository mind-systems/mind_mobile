class StarSessionRequest {
  final String id;
  final bool starred;

  StarSessionRequest({required this.id, required this.starred});

  Map<String, dynamic> toJson() {
    return {'starred': starred};
  }
}

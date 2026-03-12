class UpdateUserRequest {
  final String? name;
  final String? language;

  UpdateUserRequest({this.name, this.language});

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (name != null) map['name'] = name;
    if (language != null) map['language'] = language;
    return map;
  }
}

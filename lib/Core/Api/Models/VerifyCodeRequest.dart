class VerifyCodeRequest {
  final String email;
  final String code;
  final String? language;

  VerifyCodeRequest({required this.email, required this.code, this.language});

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'email': email, 'code': code};
    if (language != null && language!.isNotEmpty) map['language'] = language;
    return map;
  }
}

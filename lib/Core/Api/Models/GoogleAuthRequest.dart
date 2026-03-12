class GoogleAuthRequest {
  final String serverAuthCode;
  final String? language;

  GoogleAuthRequest({required this.serverAuthCode, this.language});

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'serverAuthCode': serverAuthCode};
    if (language != null && language!.isNotEmpty) map['language'] = language;
    return map;
  }
}

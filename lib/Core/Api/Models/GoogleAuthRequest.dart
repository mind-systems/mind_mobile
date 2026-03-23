class GoogleAuthRequest {
  final String serverAuthCode;
  final String? language;
  final String? redirectUri;

  GoogleAuthRequest({
    required this.serverAuthCode,
    this.language,
    this.redirectUri,
  });

  Map<String, dynamic> toJson() => {
    'serverAuthCode': serverAuthCode,
    if (language != null && language!.isNotEmpty) 'language': language,
    if (redirectUri != null) 'redirectUri': redirectUri,
  };
}

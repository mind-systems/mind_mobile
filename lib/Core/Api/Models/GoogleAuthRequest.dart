class GoogleAuthRequest {
  final String serverAuthCode;

  GoogleAuthRequest({required this.serverAuthCode});

  Map<String, dynamic> toJson() => {
    'serverAuthCode': serverAuthCode,
  };
}

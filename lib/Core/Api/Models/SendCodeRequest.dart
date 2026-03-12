class SendCodeRequest {
  final String email;
  final String language;

  SendCodeRequest({required this.email, required this.language});

  Map<String, dynamic> toJson() => {
    'email': email,
    'locale': language,
  };
}

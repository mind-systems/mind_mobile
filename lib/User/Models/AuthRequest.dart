import 'package:mind/User/Models/User.dart';

class AuthUserData {
  final String? firebaseUid;
  final String name;
  final String email;

  AuthUserData({
    this.firebaseUid,
    required this.email,
    required this.name,
  });

  Map<String, dynamic> toJson() => {
    'firebaseUid': firebaseUid,
    'name': name,
    'email': email,
  };

  factory AuthUserData.fromUser(User user) => AuthUserData(
    firebaseUid: user.firebaseUid,
    name: user.name,
    email: user.email,
  );
}

class AuthRequest {
  final String idToken;
  final AuthUserData user;

  AuthRequest({required this.idToken, required this.user});

  Map<String, dynamic> toJson() => {
    'idToken': idToken,
    'user': user.toJson(),
  };
}

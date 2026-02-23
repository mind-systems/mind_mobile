import 'package:mind/User/Models/User.dart';

class AuthRequest {
  final String token;
  final String? firebaseUid;
  final String name;
  final String email;

  AuthRequest({required this.token, required User user})
  : firebaseUid = user.firebaseUid,
    name = user.name,
    email = user.email;

  Map<String, dynamic> toJson() => {
    'token': token,
    'firebase_uid': firebaseUid,
    'name': name,
    'email': email,
  };
}

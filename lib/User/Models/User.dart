import 'package:uuid/uuid.dart';

class User {
  final String id;
  final String name;
  final String email;
  final bool isGuest;

  User({
    required this.id,
    required this.email,
    required this.name,
    required this.isGuest,
  });

  factory User.guest() {
    return User(
      id: const Uuid().v4(),
      email: '',
      name: 'Guest',
      isGuest: true,
    );
  }

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'],
    name: json['name'],
    email: json['email'],
    isGuest: false,
  );
}

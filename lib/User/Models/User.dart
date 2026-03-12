import 'package:uuid/uuid.dart';

class User {
  final String id;
  final String name;
  final String email;
  final String language;
  final bool isGuest;

  User({
    required this.id,
    required this.email,
    required this.name,
    required this.language,
    required this.isGuest,
  });

  factory User.guest() {
    return User(
      id: const Uuid().v4(),
      email: '',
      name: 'Guest',
      language: '',
      isGuest: true,
    );
  }

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'],
    name: json['name'],
    email: json['email'],
    language: json['language'] ?? '',
    isGuest: false,
  );

  User copyWith({String? name, String? language}) => User(
    id: id,
    email: email,
    name: name ?? this.name,
    language: language ?? this.language,
    isGuest: isGuest,
  );
}

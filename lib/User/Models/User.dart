import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:uuid/uuid.dart';

class User {
  final String id;
  final String? firebaseUid;
  final String name;
  final String email;
  final bool isGuest;

  User({
    required this.id,
    this.firebaseUid,
    required this.email,
    required this.name,
    required this.isGuest,
  });

  factory User.guest() {
    return User(
      id: const Uuid().v4(),
      firebaseUid: null,
      email: '',
      name: 'Guest',
      isGuest: true,
    );
  }

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'],
    firebaseUid: json['firebaseUid'],
    name: json['name'],
    email: json['email'],
    isGuest: false,
  );

  factory User.fromFirebaseUser(firebase_auth.User? user) {
    final email = user?.email;
    if (email == null || email.isEmpty) {
      throw Exception('Email is required to create a user');
    }

    final name = user?.displayName?.isNotEmpty == true
        ? user!.displayName!
        : email.split('@').first;

    return User(
      id: const Uuid().v4(),
      firebaseUid: user?.uid,
      email: email,
      name: name,
      isGuest: false,
    );
  }
}

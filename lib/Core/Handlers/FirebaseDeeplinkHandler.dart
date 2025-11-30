import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:mind/User/UserRepository.dart';

class FirebaseDeeplinkHandler {
  final UserRepository userRepository;
  final firebase_auth.FirebaseAuth _firebaseAuth =
      firebase_auth.FirebaseAuth.instance;

  FirebaseDeeplinkHandler({required this.userRepository});

  Future<bool> handle(String link) async {
    if (_firebaseAuth.isSignInWithEmailLink(link)) {
      try {
        await userRepository.completePasswordlessSignIn(link);
        return true;
      } catch (e) {
        rethrow;
      }
    }

    return false;
  }
}

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:mind/User/UserNotifier.dart';

class FirebaseDeeplinkHandler {
  final UserNotifier userNotifier;
  final firebase_auth.FirebaseAuth _firebaseAuth =
      firebase_auth.FirebaseAuth.instance;

  FirebaseDeeplinkHandler({required this.userNotifier});

  Future<bool> handle(String link) async {
    if (_firebaseAuth.isSignInWithEmailLink(link)) {
      try {
        await userNotifier.completePasswordlessSignIn(link);
        return true;
      } catch (e) {
        rethrow;
      }
    }

    return false;
  }
}

import 'package:google_sign_in/google_sign_in.dart';
import 'package:mind/User/Infrastructure/IGoogleAuthProvider.dart';
import 'package:mind/User/Models/GoogleSignInCanceledException.dart';

class GoogleAuthProvider implements IGoogleAuthProvider {
  final GoogleSignIn _google = GoogleSignIn.instance;
  GoogleSignInAccount? _pickedAccount;

  @override
  Future<void> pickGoogleAccount() async {
    try {
      _pickedAccount = await _google.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw GoogleSignInCanceledException();
      }
      rethrow;
    }
  }

  @override
  Future<String> getServerAuthCode() async {
    final account = _pickedAccount;
    _pickedAccount = null;
    if (account == null) {
      throw StateError('pickGoogleAccount() must be called before getServerAuthCode()');
    }
    final serverAuth = await account.authorizationClient.authorizeServer(['email']);
    if (serverAuth == null) {
      throw Exception('Google Sign-In did not return a serverAuthCode.');
    }
    return serverAuth.serverAuthCode;
  }

  @override
  Future<void> signOut() => _google.signOut();
}

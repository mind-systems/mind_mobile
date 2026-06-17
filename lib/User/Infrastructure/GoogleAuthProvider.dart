import 'package:flutter/services.dart';
import 'package:mind/Logger.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mind/Core/Environment.dart';
import 'package:mind/User/Infrastructure/IGoogleAuthProvider.dart';
import 'package:mind/User/Models/GoogleSignInCanceledException.dart';

class GoogleAuthProvider implements IGoogleAuthProvider {
  final GoogleSignIn _google = GoogleSignIn.instance;

  @override
  Future<({String code, String? redirectUri})> getServerAuthCode() async {
    try {
      return await _gmsFlow();
    } on GoogleSignInCanceledException {
      rethrow;
    } catch (e) {
      logPrint('[GoogleAuthProvider] GMS failed ($e), falling back to browser flow');
      return await _browserFlow();
    }
  }

  Future<({String code, String? redirectUri})> _gmsFlow() async {
    try {
      final serverAuth =
          await _google.authorizationClient.authorizeServer(['email']);
      if (serverAuth == null) {
        throw Exception('Google Sign-In did not return a serverAuthCode.');
      }
      return (code: serverAuth.serverAuthCode, redirectUri: null);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw GoogleSignInCanceledException();
      }
      rethrow; // non-cancel → outer catch → browser fallback
    }
    // MissingPluginException, PlatformException → outer catch automatically
  }

  Future<({String code, String? redirectUri})> _browserFlow() async {
    final env = Environment.instance;
    final redirectUri = '${env.deeplinkUrl}/auth/google/callback';

    final authUrl = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
      'client_id': '${env.googleServerClientIdPlain}.apps.googleusercontent.com',
      'redirect_uri': redirectUri,
      'response_type': 'code',
      'scope': 'email',
      'access_type': 'offline',
    });

    try {
      final result = await FlutterWebAuth2.authenticate(
        url: authUrl.toString(),
        callbackUrlScheme: 'https',
        options: FlutterWebAuth2Options(
          httpsHost: env.linkDomain,
          httpsPath: '/auth/google/callback',
        ),
      );
      final code = Uri.parse(result).queryParameters['code'];
      if (code == null || code.isEmpty) {
        throw Exception('No authorization code in callback URL');
      }
      return (code: code, redirectUri: redirectUri);
    } on PlatformException catch (e) {
      if (e.code == 'CANCELED') throw GoogleSignInCanceledException();
      rethrow;
    }
  }

  @override
  Future<void> signOut() => _google.signOut();
}

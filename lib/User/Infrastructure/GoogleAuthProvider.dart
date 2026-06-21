import 'package:flutter/services.dart';
import 'package:mind/Logger.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mind/Core/Environment.dart';
import 'package:mind/User/Infrastructure/IGoogleAuthProvider.dart';
import 'package:mind/User/Models/GoogleSignInCanceledException.dart';
import 'package:mind/User/Models/NoConnectionException.dart';

class GoogleAuthProvider implements IGoogleAuthProvider {
  final GoogleSignIn _google = GoogleSignIn.instance;

  @override
  Future<({String code, String? redirectUri})> getServerAuthCode() async {
    try {
      return await _gmsFlow();
    } on GoogleSignInException catch (e) {
      if (_isNetworkError(e)) {
        logPrint('[GoogleAuthProvider] GMS failed with network error ($e) — skipping browser fallback');
        throw NoConnectionException();
      }
      // GMS genuinely unavailable (e.g. no Play Services) — fall back to browser
      logPrint('[GoogleAuthProvider] GMS unavailable ($e), falling back to browser flow');
      return await _browserFlow();
    } catch (e) {
      // MissingPluginException / other paths that legitimately need the browser
      logPrint('[GoogleAuthProvider] GMS failed ($e), falling back to browser flow');
      return await _browserFlow();
    }
  }

  Future<({String code, String? redirectUri})> _gmsFlow() async {
    logPrint('[GoogleAuthProvider] starting GMS flow');
    final serverAuth =
        await _google.authorizationClient.authorizeServer(['email']);
    if (serverAuth == null) {
      throw Exception('Google Sign-In did not return a serverAuthCode.');
    }
    return (code: serverAuth.serverAuthCode, redirectUri: null);
  }

  Future<({String code, String? redirectUri})> _browserFlow() async {
    logPrint('[GoogleAuthProvider] starting browser flow');
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
      logPrint('[GoogleAuthProvider] browser flow PlatformException — code: ${e.code}, message: ${e.message}, details: ${e.details}');
      rethrow;
    } catch (e) {
      logPrint('[GoogleAuthProvider] browser flow unexpected error: $e');
      rethrow;
    }
  }

  /// Returns true when the GMS exception represents a network failure.
  ///
  /// `GoogleSignInException.code` is always `unknownError` for network errors,
  /// so we match on the description string instead. Both `'network error'` (human
  /// readable) and `'[7]'` (GMS status 7 = NETWORK_ERROR) are acceptable signals.
  /// This string-matching is intentionally confined to this single helper.
  bool _isNetworkError(GoogleSignInException e) {
    final desc = e.description?.toLowerCase() ?? '';
    return desc.contains('network error') || desc.contains('[7]');
  }

  @override
  Future<void> signOut() => _google.signOut();
}

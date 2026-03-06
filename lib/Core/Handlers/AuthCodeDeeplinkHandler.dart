import 'package:mind/Core/Environment.dart';
import 'package:mind/User/UserNotifier.dart';

class AuthCodeDeeplinkHandler {
  final UserNotifier _userNotifier;

  AuthCodeDeeplinkHandler({required UserNotifier userNotifier})
      : _userNotifier = userNotifier;

  Future<bool> handle(Uri uri) async {
    if (uri.host != Environment.instance.linkDomain || uri.path != '/deeplink-auth') {
      return false;
    }

    final code = uri.queryParameters['code'];
    if (code == null || code.isEmpty) {
      return false;
    }

    await _userNotifier.completePasswordlessSignIn(code);
    return true;
  }
}

import 'package:mind/Core/Environment.dart';
import 'package:mind/User/UserNotifier.dart';

class AuthCodeDeeplinkHandler {
  final UserNotifier _userNotifier;

  AuthCodeDeeplinkHandler({required UserNotifier userNotifier})
      : _userNotifier = userNotifier;

  Future<bool> handle(Uri uri) async {
    final isHttpsLink = uri.scheme == 'https' &&
        uri.host == Environment.instance.linkDomain &&
        uri.path == '/deeplink-auth';

    final isCustomScheme = uri.scheme == Environment.instance.deeplinkScheme &&
        uri.host == 'deeplink-auth';

    if (!isHttpsLink && !isCustomScheme) return false;

    final code = uri.queryParameters['code'];
    if (code == null || code.isEmpty) return false;

    await _userNotifier.completePasswordlessSignIn(code);
    return true;
  }
}

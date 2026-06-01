import 'package:mind_l10n/mind_l10n.dart';
import 'package:mind_ui/mind_ui.dart';

import 'package:mind/Core/Environment.dart';
import 'package:mind/Core/GlobalUI/GlobalKeys.dart';
import 'package:mind/User/Models/OtpLockedException.dart';
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

    try {
      await _userNotifier.completePasswordlessSignIn(code);
    } on OtpLockedException {
      _showLocalizedSnackBar((l10n) => l10n.loginTooManyAttemptsError);
      return true;
    } catch (_) {
      _showLocalizedSnackBar((l10n) => l10n.loginCodeInvalidError);
      return true;
    }
    return true;
  }

  void _showLocalizedSnackBar(String Function(AppLocalizations) pick) {
    final context = rootScaffoldMessengerKey.currentContext;
    if (context == null) return;
    final message = pick(AppLocalizations.of(context)!);
    rootScaffoldMessengerKey.currentState
        ?.showSnackBar(SnackBarBuilder.build(SnackBarEvent.error(message)));
  }
}

import 'package:mind_l10n/mind_l10n.dart';
import 'package:mind_l10n/l10n/app_localizations_en.dart';
import 'package:mind_ui/mind_ui.dart';

import 'package:mind/Core/Environment.dart';
import 'package:mind/Core/GlobalUI/GlobalKeys.dart';
import 'package:mind/User/Models/OtpLockedException.dart';
import 'package:mind/User/UserNotifier.dart';

class AuthCodeDeeplinkHandler {
  final UserNotifier _userNotifier;
  final void Function(SnackBarEvent) _onError;

  AuthCodeDeeplinkHandler({
    required UserNotifier userNotifier,
    void Function(SnackBarEvent)? onError,
  })  : _userNotifier = userNotifier,
        _onError = onError ?? _defaultOnError;

  static void _defaultOnError(SnackBarEvent event) {
    rootScaffoldMessengerKey.currentState
        ?.showSnackBar(SnackBarBuilder.build(event));
  }

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
    final l10n = context != null
        ? AppLocalizations.of(context)!
        : AppLocalizationsEn();
    _onError(SnackBarEvent.error(pick(l10n)));
  }
}

import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:mind/Core/Handlers/AuthCodeDeeplinkHandler.dart';

class DeeplinkRouter {
  final AppLinks _appLinks = AppLinks();
  final AuthCodeDeeplinkHandler _authCodeHandler;

  StreamSubscription? _linkSubscription;

  DeeplinkRouter({required AuthCodeDeeplinkHandler authCodeHandler})
    : _authCodeHandler = authCodeHandler;

  Future<void> init() async {
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (Uri uri) async {
        await _handleDeepLink(uri);
      },
      onError: (error) {},
    );
  }

  Future<void> _handleDeepLink(Uri uri) async {
    try {
      await _authCodeHandler.handle(uri);
    } catch (e) {
      return;
    }
  }

  void dispose() {
    _linkSubscription?.cancel();
    _linkSubscription = null;
  }
}

import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:mind/Core/Handlers/AuthCodeDeeplinkHandler.dart';
import 'package:mind/Core/Handlers/BreathSessionDeeplinkHandler.dart';

class DeeplinkRouter {
  final AppLinks _appLinks = AppLinks();
  final AuthCodeDeeplinkHandler _authCodeHandler;
  final BreathSessionDeeplinkHandler _sessionHandler;

  StreamSubscription? _linkSubscription;

  DeeplinkRouter({
    required AuthCodeDeeplinkHandler authCodeHandler,
    required BreathSessionDeeplinkHandler sessionHandler,
  })  : _authCodeHandler = authCodeHandler,
        _sessionHandler = sessionHandler;

  Future<void> init() async {
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (Uri uri) async => await _handleDeepLink(uri),
      onError: (_) {},
    );
  }

  Future<void> _handleDeepLink(Uri uri) async {
    if (_sessionHandler.handle(uri)) return;
    await _authCodeHandler.handle(uri);
  }

  void dispose() {
    _linkSubscription?.cancel();
    _linkSubscription = null;
  }
}

import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:mind/Core/Handlers/FirebaseDeeplinkHandler.dart';

class DeeplinkRouter {
  final AppLinks _appLinks = AppLinks();
  final FirebaseDeeplinkHandler _firebaseHandler;

  StreamSubscription? _linkSubscription;

  DeeplinkRouter({required FirebaseDeeplinkHandler firebaseHandler})
    : _firebaseHandler = firebaseHandler;

  Future<void> init() async {
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (Uri uri) async {
        await _handleDeepLink(uri);
      },
      onError: (error) {},
    );
  }

  /// Обработка входящей ссылки
  Future<void> _handleDeepLink(Uri uri) async {
    final uriString = uri.toString();

    // Пытаемся обработать через Firebase handler
    try {
      await _firebaseHandler.handle(uriString);
    } catch (e) {
      return;
    }
  }

  void dispose() {
    _linkSubscription?.cancel();
    _linkSubscription = null;
  }
}

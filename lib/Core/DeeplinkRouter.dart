import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
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
        debugPrint('📲 Received deep link: $uri');
        await _handleDeepLink(uri);
      },
      onError: (error) {
        debugPrint('❌ Error in deep link stream: $error');
      },
    );
  }

  /// Обработка входящей ссылки
  Future<void> _handleDeepLink(Uri uri) async {
    debugPrint('🔗 Processing deep link: $uri');

    final uriString = uri.toString();

    // Пытаемся обработать через Firebase handler
    try {
      final handled = await _firebaseHandler.handle(uriString);
      if (handled) return;
    } catch (e) {
      debugPrint('❌ Handler error: $e');
      return;
    }

    debugPrint('⚠️ Unknown deep link: $uri');
  }

  void dispose() {
    _linkSubscription?.cancel();
    _linkSubscription = null;
  }
}

import 'package:go_router/go_router.dart';
import 'package:breath_module/breath_module.dart' show BreathSessionScreen;
import 'package:mind/Core/Environment.dart';

class BreathSessionDeeplinkHandler {
  final GoRouter _router;

  BreathSessionDeeplinkHandler({required GoRouter router}) : _router = router;

  static String buildSessionUrl(String sessionId) =>
      '${Environment.instance.deeplinkUrl}/breath/$sessionId';

  bool handle(Uri uri) {
    if (uri.host != Environment.instance.linkDomain ||
        uri.pathSegments.length != 2 ||
        uri.pathSegments.first != 'breath') {
      return false;
    }
    final sessionId = uri.pathSegments[1];
    if (sessionId.isEmpty) return false;
    _router.push(BreathSessionScreen.path, extra: sessionId);
    return true;
  }
}

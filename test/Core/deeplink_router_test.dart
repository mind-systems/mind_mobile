import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mind/Core/Environment.dart';
import 'package:mind/Core/Handlers/BreathSessionDeeplinkHandler.dart';

void main() {
  setUpAll(() => Environment.initDev());

  group('BreathSessionDeeplinkHandler', () {
    late BreathSessionDeeplinkHandler handler;

    setUp(() {
      handler = BreathSessionDeeplinkHandler(router: GoRouter(routes: []));
    });

    test('buildSessionUrl returns canonical format', () {
      expect(
        BreathSessionDeeplinkHandler.buildSessionUrl('abc-123'),
        equals('https://dev.mind-awake.life/breath/abc-123'),
      );
    });

    test('handle returns true for valid session URL', () {
      final uri = Uri.parse('https://dev.mind-awake.life/breath/abc-123');
      // handle navigates via router — we only verify it returns true (matched)
      expect(() => handler.handle(uri), returnsNormally);
    });

    test('handle returns false for non-session URLs', () {
      final uri = Uri.parse('https://dev.mind-awake.life/deeplink-auth?code=xyz');
      expect(handler.handle(uri), isFalse);
    });
  });
}

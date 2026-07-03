import 'package:flutter_test/flutter_test.dart';

import 'package:mind/Core/Grpc/ActivityType.dart';
import 'package:mind/Core/Grpc/ModuleSession.dart';
import 'package:mind/Core/Grpc/ModuleState.dart';
import 'package:mind/Core/Grpc/SessionRegistry.dart';

// ──────────────────────────────────────────────────────────────────────────────
// Helpers
// ──────────────────────────────────────────────────────────────────────────────

ModuleSession sess(
  String id,
  ActivityType type, {
  ModuleStateStatus status = ModuleStateStatus.active,
  bool isPaused = false,
}) {
  return ModuleSession(
    id: id,
    activityType: type,
    status: status,
    isPaused: isPaused,
  );
}

// ──────────────────────────────────────────────────────────────────────────────
// Tests
// ──────────────────────────────────────────────────────────────────────────────

void main() {
  late SessionRegistry registry;

  setUp(() {
    registry = SessionRegistry();
  });

  tearDown(() {
    registry.dispose();
  });

  group('SessionRegistry — upsert-by-id', () {
    test(
      'should not duplicate entries and the read-back reflects the latest frame',
      () {
        registry.upsert(sess('breath-1', ActivityType.breath, isPaused: false));
        registry.upsert(sess('breath-1', ActivityType.breath, isPaused: true));

        final latest = registry.childOfType(ActivityType.breath);
        expect(latest, isNotNull);
        expect(latest!.id, 'breath-1');
        expect(latest.isPaused, isTrue);
      },
    );

    test(
      'should keep a single resolvable root after re-upserting the same root id with changed status',
      () {
        registry.upsert(sess('root-1', ActivityType.root, isPaused: false));
        registry.upsert(sess(
          'root-1',
          ActivityType.root,
          status: ModuleStateStatus.active,
          isPaused: true,
        ));

        expect(registry.rootId, 'root-1');
      },
    );
  });

  group('SessionRegistry — removeTerminal (remove-only-child)', () {
    test(
      'should remove only the child when a root and one breath child are present',
      () {
        registry.upsert(sess('root-1', ActivityType.root));
        registry.upsert(sess('breath-1', ActivityType.breath));

        registry.removeTerminal('breath-1');

        expect(registry.childOfType(ActivityType.breath), isNull);
      },
    );

    test(
      'should not drop the root when a child terminates',
      () {
        registry.upsert(sess('root-1', ActivityType.root));
        registry.upsert(sess('breath-1', ActivityType.breath));

        registry.removeTerminal('breath-1');

        expect(registry.rootId, 'root-1');
      },
    );
  });

  group('SessionRegistry — rootId', () {
    test('should return the ActivityType.root entry\'s id', () {
      registry.upsert(sess('root-1', ActivityType.root));

      expect(registry.rootId, 'root-1');
    });

    test('should be null when no root is present', () {
      registry.upsert(sess('breath-1', ActivityType.breath));

      expect(registry.rootId, isNull);
    });

    test('should never return a child id', () {
      registry.upsert(sess('root-1', ActivityType.root));
      registry.upsert(sess('breath-1', ActivityType.breath));

      expect(registry.rootId, isNot('breath-1'));
      expect(registry.rootId, 'root-1');
    });
  });

  group('SessionRegistry — childOfType', () {
    test('should return the sole breath child', () {
      registry.upsert(sess('root-1', ActivityType.root));
      registry.upsert(sess('breath-1', ActivityType.breath));

      final child = registry.childOfType(ActivityType.breath);

      expect(child, isNotNull);
      expect(child!.id, 'breath-1');
    });

    test('should be null when none of that type exist', () {
      registry.upsert(sess('root-1', ActivityType.root));

      expect(registry.childOfType(ActivityType.breath), isNull);
    });

    test('should not return the root or a meditation child', () {
      registry.upsert(sess('root-1', ActivityType.root));
      registry.upsert(sess('meditation-1', ActivityType.meditation));

      final child = registry.childOfType(ActivityType.breath);

      expect(child, isNull);
      final meditationChild = registry.childOfType(ActivityType.meditation);
      expect(meditationChild, isNotNull);
      expect(meditationChild!.id, isNot('root-1'));
    });
  });

  group('SessionRegistry — route-by-activity_type', () {
    test(
      'should yield two distinct entries resolvable via rootId and childOfType(breath)',
      () {
        registry.upsert(sess('root-1', ActivityType.root));
        registry.upsert(sess('breath-1', ActivityType.breath));

        expect(registry.rootId, 'root-1');
        final breathChild = registry.childOfType(ActivityType.breath);
        expect(breathChild, isNotNull);
        expect(breathChild!.id, 'breath-1');
      },
    );
  });

  group('SessionRegistry — clear', () {
    test(
      'should empty the registry so rootId is null and childOfType resolves nothing',
      () {
        registry.upsert(sess('root-1', ActivityType.root));
        registry.upsert(sess('breath-1', ActivityType.breath));

        registry.clear();

        expect(registry.rootId, isNull);
        expect(registry.childOfType(ActivityType.breath), isNull);
        expect(registry.childOfType(ActivityType.root), isNull);
      },
    );
  });
}

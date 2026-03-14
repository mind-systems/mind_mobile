import 'package:flutter_test/flutter_test.dart';
import 'package:mind/Core/Socket/TelemetryBuffer.dart';

void main() {
  group('TelemetryBuffer', () {
    late TelemetryBuffer buffer;

    setUp(() {
      buffer = TelemetryBuffer(capacity: 3);
    });

    test('starts empty', () {
      expect(buffer.isEmpty, isTrue);
      expect(buffer.droppedCount, 0);
    });

    test('enqueue adds samples', () {
      buffer.enqueue({'phase': 'inhale'});
      expect(buffer.isEmpty, isFalse);
    });

    test('flush returns all samples and clears buffer', () {
      buffer.enqueue({'phase': 'inhale'});
      buffer.enqueue({'phase': 'hold'});

      final flushed = buffer.flush();

      expect(flushed.length, 2);
      expect(flushed[0]['phase'], 'inhale');
      expect(flushed[1]['phase'], 'hold');
      expect(buffer.isEmpty, isTrue);
    });

    test('overflow drops oldest and increments droppedCount', () {
      buffer.enqueue({'id': 1});
      buffer.enqueue({'id': 2});
      buffer.enqueue({'id': 3});
      buffer.enqueue({'id': 4});

      expect(buffer.droppedCount, 1);

      final flushed = buffer.flush();
      expect(flushed.length, 3);
      expect(flushed[0]['id'], 2);
      expect(flushed[1]['id'], 3);
      expect(flushed[2]['id'], 4);
    });

    test('flush does not reset droppedCount', () {
      buffer.enqueue({'id': 1});
      buffer.enqueue({'id': 2});
      buffer.enqueue({'id': 3});
      buffer.enqueue({'id': 4});

      expect(buffer.droppedCount, 1);
      buffer.flush();
      expect(buffer.droppedCount, 1);
    });

    test('resetDropCount resets droppedCount to zero', () {
      buffer.enqueue({'id': 1});
      buffer.enqueue({'id': 2});
      buffer.enqueue({'id': 3});
      buffer.enqueue({'id': 4});

      buffer.resetDropCount();
      expect(buffer.droppedCount, 0);
    });

    test('multiple overflows accumulate droppedCount', () {
      buffer.enqueue({'id': 1});
      buffer.enqueue({'id': 2});
      buffer.enqueue({'id': 3});
      buffer.enqueue({'id': 4});
      buffer.enqueue({'id': 5});

      expect(buffer.droppedCount, 2);

      final flushed = buffer.flush();
      expect(flushed.length, 3);
      expect(flushed[0]['id'], 3);
    });
  });
}

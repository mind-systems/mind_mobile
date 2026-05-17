import 'CommonModels/TickSource.dart';

abstract class ITickService {
  Stream<TickData> get tickStream;
  TickSource get source;
  void dispose();
}

class TickData {
  final int intervalMs;

  TickData(this.intervalMs);
}

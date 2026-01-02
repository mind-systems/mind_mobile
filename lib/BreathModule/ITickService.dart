abstract class ITickService {
  Stream<TickData> get tickStream;
}

class TickData {
  final int intervalMs;

  TickData(this.intervalMs);
}

abstract class ITickService {
  Stream<TickData> get tickStream;
  void dispose();
}

class TickData {
  final int intervalMs;

  TickData(this.intervalMs);
}

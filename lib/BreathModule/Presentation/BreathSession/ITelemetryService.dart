abstract class ITelemetryService {
  void sendSample(String sessionId, String phase, int durationMs);
}

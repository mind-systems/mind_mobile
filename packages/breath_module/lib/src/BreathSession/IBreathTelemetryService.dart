abstract class IBreathTelemetryService {
  void sendSample(String sessionId, String phase, int durationMs);
}

abstract interface class ILiveSocketService {
  Stream<Map<String, dynamic>> get sessionStateEvents;
  void emitLive(String event, [Map<String, dynamic>? data]);
}

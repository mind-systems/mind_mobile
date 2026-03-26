abstract interface class ILiveSocketService {
  Stream<Map<String, dynamic>> get sessionStateEvents;
  Stream<Map<String, dynamic>> get syncChangedEvents;
  void emitLive(String event, [Map<String, dynamic>? data]);
}

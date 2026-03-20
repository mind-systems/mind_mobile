abstract class ISyncStateDao {
  Future<int> getLastEventId();
  Future<void> setLastEventId(int eventId);
  Future<void> reset();
}

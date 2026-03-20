import 'package:mind/Core/Api/Models/BatchSessionsResponse.dart';
import 'package:mind/Core/Api/Models/SyncResponse.dart';

abstract class ISyncApi {
  Future<SyncResponse> fetchChanges(int lastEventId);
  Future<BatchSessionsResponse> fetchSessionsBatch(List<String> ids);
}

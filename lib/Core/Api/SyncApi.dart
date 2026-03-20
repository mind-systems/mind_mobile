import 'package:mind/Core/Api/HttpClient.dart';
import 'package:mind/Core/Api/ISyncApi.dart';
import 'package:mind/Core/Api/Models/BatchSessionsResponse.dart';
import 'package:mind/Core/Api/Models/SyncResponse.dart';

class SyncApi implements ISyncApi {
  final HttpClient _http;

  SyncApi(this._http);

  @override
  Future<SyncResponse> fetchChanges(int lastEventId) async {
    final response = await _http.get('/sync/changes?after=$lastEventId');
    return SyncResponse.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<BatchSessionsResponse> fetchSessionsBatch(List<String> ids) async {
    final joinedIds = ids.join(',');
    final response = await _http.get('/breath_sessions/batch?ids=$joinedIds');
    return BatchSessionsResponse.fromJson(response.data as Map<String, dynamic>);
  }
}

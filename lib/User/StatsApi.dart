import 'package:mind/Core/Grpc/generated/stats.pb.dart' as statsProto;
import 'package:mind/Core/Grpc/generated/stats.pbgrpc.dart' show StatsServiceClient;
import 'package:mind/User/IStatsApi.dart';
import 'package:mind/User/Models/UserStatsDTO.dart';

class StatsApi implements IStatsApi {
  final StatsServiceClient _statsService;

  StatsApi(this._statsService);

  @override
  Future<UserStatsDTO> fetchStats() async {
    final response = await _statsService.getStats(statsProto.GetStatsRequest()).timeout(const Duration(seconds: 10));
    return _mapStats(response);
  }

  UserStatsDTO _mapStats(statsProto.GetStatsResponse response) {
    return UserStatsDTO(
      totalSessions: response.totalSessions,
      totalDurationSeconds: response.totalDurationSeconds,
      currentStreak: response.currentStreak,
      longestStreak: response.longestStreak,
      lastSessionDate: response.hasLastSessionDate() ? response.lastSessionDate : null,
      maxCompletedComplexity: response.maxCompletedComplexity.toInt(),
    );
  }
}

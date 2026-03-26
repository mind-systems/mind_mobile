import 'package:mind/Core/Api/Models/UpdateUserRequest.dart';
import 'package:mind/Core/Grpc/generated/breath_sessions.pb.dart' as bsProto;
import 'package:mind/Core/Grpc/generated/breath_sessions.pbgrpc.dart' show BreathSessionServiceClient;
import 'package:mind/Core/Grpc/generated/stats.pb.dart' as statsProto;
import 'package:mind/Core/Grpc/generated/stats.pbgrpc.dart' show StatsServiceClient;
import 'package:mind/Core/Grpc/generated/users.pb.dart' as usersProto;
import 'package:mind/Core/Grpc/generated/users.pbgrpc.dart' show UserServiceClient;
import 'package:mind/User/IUserApi.dart';
import 'package:mind/User/Models/SuggestionDTO.dart';
import 'package:mind/User/Models/UserStatsDTO.dart';

class UserGrpcApi implements IUserApi {
  final UserServiceClient _userService;
  final StatsServiceClient _statsService;
  final BreathSessionServiceClient _breathSessionService;

  UserGrpcApi(this._userService, this._statsService, this._breathSessionService);

  @override
  Future<void> updateUser(UpdateUserRequest request) async {
    await _userService.updateProfile(usersProto.UpdateProfileRequest(name: request.name, language: request.language));
  }

  @override
  Future<UserStatsDTO> fetchStats() async {
    final response = await _statsService.getStats(statsProto.GetStatsRequest());
    return _mapStats(response);
  }

  @override
  Future<List<SuggestionDTO>> fetchSuggestions(String timeOfDay) async {
    final response = await _breathSessionService.getSuggestions(bsProto.GetSuggestionsRequest(timeOfDay: _mapTimeOfDay(timeOfDay)));
    return response.suggestions.map(_mapSuggestion).toList();
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

  SuggestionDTO _mapSuggestion(bsProto.BreathSessionDto dto) {
    return SuggestionDTO(
      id: dto.id,
      title: dto.description,
      description: dto.description,
      iconUrl: null,
    );
  }

  bsProto.TimeOfDay _mapTimeOfDay(String timeOfDay) {
    if (timeOfDay == 'midday') return bsProto.TimeOfDay.MIDDAY;
    if (timeOfDay == 'evening') return bsProto.TimeOfDay.EVENING;
    return bsProto.TimeOfDay.MORNING;
  }
}

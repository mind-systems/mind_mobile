import 'package:mind/Core/Api/Models/UpdateUserRequest.dart';
import 'package:mind/User/Models/SuggestionDTO.dart';
import 'package:mind/User/Models/UserStatsDTO.dart';

abstract class IUserApi {
  Future<void> updateUser(UpdateUserRequest request);
  Future<UserStatsDTO> fetchStats();
  Future<List<SuggestionDTO>> fetchSuggestions(String timeOfDay);
}

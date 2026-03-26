import 'package:mind/User/Models/UserStatsDTO.dart';

abstract class IStatsApi {
  Future<UserStatsDTO> fetchStats();
}

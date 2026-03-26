import 'package:mind/Core/Api/Models/UpdateUserRequest.dart';
import 'package:mind/Core/Grpc/generated/breath_sessions.pb.dart' as bsProto;
import 'package:mind/Core/Grpc/generated/breath_sessions.pbgrpc.dart' show BreathSessionServiceClient;
import 'package:mind/Core/Grpc/generated/users.pb.dart' as usersProto;
import 'package:mind/Core/Grpc/generated/users.pbgrpc.dart' show UserServiceClient;
import 'package:mind/User/IUserApi.dart';
import 'package:mind/User/Models/SuggestionDTO.dart';

class UserGrpcApi implements IUserApi {
  final UserServiceClient _userService;
  final BreathSessionServiceClient _breathSessionService;

  UserGrpcApi(this._userService, this._breathSessionService);

  @override
  Future<void> updateUser(UpdateUserRequest request) async {
    await _userService.updateProfile(usersProto.UpdateProfileRequest(name: request.name, language: request.language));
  }

  @override
  Future<List<SuggestionDTO>> fetchSuggestions(String timeOfDay) async {
    final response = await _breathSessionService.getSuggestions(bsProto.GetSuggestionsRequest(timeOfDay: _mapTimeOfDay(timeOfDay)));
    return response.suggestions.map(_mapSuggestion).toList();
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

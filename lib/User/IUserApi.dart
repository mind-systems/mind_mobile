import 'package:mind/Core/Api/Models/UpdateUserRequest.dart';
import 'package:mind/User/Models/SuggestionDTO.dart';

abstract class IUserApi {
  Future<void> updateUser(UpdateUserRequest request);
  Future<List<SuggestionDTO>> fetchSuggestions(String timeOfDay);
}

import 'package:mind/Core/Api/HttpClient.dart';
import 'package:mind/Core/Api/IPersonalAccessTokenApi.dart';
import 'package:mind/Core/Api/Models/CreateTokenRequest.dart';
import 'package:mind/Core/Api/Models/TokenDTO.dart';

class PersonalAccessTokenApi implements IPersonalAccessTokenApi {
  final HttpClient _http;

  PersonalAccessTokenApi(this._http);

  @override
  Future<List<TokenDTO>> fetchTokens() async {
    final response = await _http.get('/auth/tokens');
    final list = response.data as List<dynamic>;
    return list.map((item) => TokenDTO.fromJson(item as Map<String, dynamic>)).toList();
  }

  @override
  Future<CreateTokenResponse> createToken(CreateTokenRequest request) async {
    final response = await _http.post('/auth/tokens', data: request.toJson());
    return CreateTokenResponse.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<void> revokeToken(String tokenId) async {
    await _http.delete('/auth/tokens/$tokenId');
  }
}

import 'package:mind/Core/Api/HttpClient.dart';
import 'package:mind/Core/Api/ITokenApi.dart';
import 'package:mind/Core/Api/Models/CreateTokenRequest.dart';
import 'package:mind/Core/Api/Models/TokenDTO.dart';

class TokenApi implements ITokenApi {
  final HttpClient _http;

  TokenApi(this._http);

  @override
  Future<List<TokenDTO>> fetchTokens() async {
    final response = await _http.get('/tokens');
    final list = response.data as List<dynamic>;
    return list.map((item) => TokenDTO.fromJson(item as Map<String, dynamic>)).toList();
  }

  @override
  Future<CreateTokenResponse> createToken(CreateTokenRequest request) async {
    final response = await _http.post('/tokens', data: request.toJson());
    return CreateTokenResponse.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<void> revokeToken(String tokenId) async {
    await _http.delete('/tokens/$tokenId');
  }
}

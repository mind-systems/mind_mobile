import 'package:mind/Core/Api/Models/CreateTokenRequest.dart';
import 'package:mind/Core/Api/Models/TokenDTO.dart';

abstract class IPersonalAccessTokenApi {
  Future<List<TokenDTO>> fetchTokens();
  Future<CreateTokenResponse> createToken(CreateTokenRequest request);
  Future<void> revokeToken(String tokenId);
}

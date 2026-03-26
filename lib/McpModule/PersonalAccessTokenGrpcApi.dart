import 'package:mind/Core/Api/IPersonalAccessTokenApi.dart';
import 'package:mind/Core/Api/Models/CreateTokenRequest.dart';
import 'package:mind/Core/Api/Models/TokenDTO.dart';
import 'package:mind/Core/Grpc/generated/auth.pb.dart' as proto;
import 'package:mind/Core/Grpc/generated/auth.pbgrpc.dart' show AuthServiceClient;

class PersonalAccessTokenGrpcApi implements IPersonalAccessTokenApi {
  final AuthServiceClient _authService;

  PersonalAccessTokenGrpcApi(this._authService);

  @override
  Future<List<TokenDTO>> fetchTokens() async {
    final response = await _authService.listTokens(proto.ListTokensRequest());
    return response.tokens.map((dto) => TokenDTO(id: dto.id, name: dto.name, createdAt: dto.createdAt)).toList();
  }

  @override
  Future<CreateTokenResponse> createToken(CreateTokenRequest request) async {
    final response = await _authService.createToken(proto.CreateTokenRequest(name: request.name));
    return CreateTokenResponse(token: response.token, metadata: TokenDTO(id: response.id, name: response.name, createdAt: response.createdAt));
  }

  @override
  Future<void> revokeToken(String tokenId) async {
    await _authService.deleteToken(proto.DeleteTokenRequest(id: tokenId));
  }
}

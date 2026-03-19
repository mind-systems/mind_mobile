import 'package:mind/McpModule/Presentation/McpScreen/Models/McpScreenDTOs.dart';

abstract class IMcpService {
  Stream<McpScreenEvent> observeChanges();
  Future<void> loadTokens();
  Future<void> createToken(String name);
  Future<void> revokeToken(String id);
}

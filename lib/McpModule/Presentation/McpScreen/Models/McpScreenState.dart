import 'package:mind/McpModule/Presentation/McpScreen/Models/McpScreenDTOs.dart';

class McpScreenState {
  final List<TokenItemDTO> tokens;
  final bool isLoading;
  final String? revealToken;
  final String? revealTokenName;

  const McpScreenState({
    required this.tokens,
    required this.isLoading,
    this.revealToken,
    this.revealTokenName,
  });

  McpScreenState copyWith({
    List<TokenItemDTO>? tokens,
    bool? isLoading,
    Object? revealToken = _sentinel,
    Object? revealTokenName = _sentinel,
  }) {
    return McpScreenState(
      tokens: tokens ?? this.tokens,
      isLoading: isLoading ?? this.isLoading,
      revealToken: revealToken == _sentinel ? this.revealToken : revealToken as String?,
      revealTokenName: revealTokenName == _sentinel ? this.revealTokenName : revealTokenName as String?,
    );
  }
}

const _sentinel = Object();

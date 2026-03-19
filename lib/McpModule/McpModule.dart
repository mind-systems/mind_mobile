import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind/Core/App.dart';
import 'package:mind/McpModule/McpCoordinator.dart';
import 'package:mind/McpModule/McpService.dart';
import 'package:mind/McpModule/Presentation/McpScreen/McpScreen.dart';
import 'package:mind/McpModule/Presentation/McpScreen/McpViewModel.dart';

class McpModule {
  static Widget buildMcpScreen(BuildContext context) {
    final service = McpService(tokenNotifier: App.shared.tokenNotifier);
    final coordinator = McpCoordinator(context);
    return ProviderScope(
      overrides: [
        mcpViewModelProvider.overrideWith(() => McpViewModel(service: service, coordinator: coordinator)),
      ],
      child: const McpScreen(),
    );
  }
}

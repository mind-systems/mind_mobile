import 'dart:async';
import 'dart:developer';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind/McpModule/Presentation/McpScreen/IMcpCoordinator.dart';
import 'package:mind/McpModule/Presentation/McpScreen/IMcpService.dart';
import 'package:mind/McpModule/Presentation/McpScreen/Models/McpScreenDTOs.dart';
import 'package:mind/McpModule/Presentation/McpScreen/Models/McpScreenState.dart';

final mcpViewModelProvider =
    NotifierProvider<McpViewModel, McpScreenState>(
      () => throw UnimplementedError('McpViewModel must be overridden at ProviderScope'),
    );

class McpViewModel extends Notifier<McpScreenState> {
  final IMcpService service;
  final IMcpCoordinator coordinator;

  McpViewModel({required this.service, required this.coordinator});

  @override
  McpScreenState build() {
    final subscription = service.observeChanges().listen(_onEvent);
    ref.onDispose(() => subscription.cancel());
    service.loadTokens();
    return const McpScreenState(tokens: [], isLoading: true);
  }

  void _onEvent(McpScreenEvent event) {
    switch (event) {
      case TokensLoadedEvent e:
        state = state.copyWith(tokens: e.tokens, isLoading: false);
      case TokenCreatedEvent e:
        final updated = [e.token, ...state.tokens];
        state = state.copyWith(tokens: updated, revealToken: e.plainToken, revealTokenName: e.token.name);
      case TokenRevokedEvent e:
        final updated = state.tokens.where((t) => t.id != e.id).toList();
        state = state.copyWith(tokens: updated);
      case TokenErrorEvent e:
        log('[McpViewModel] error: ${e.message}', name: 'McpViewModel');
    }
  }

  Future<void> onCreateTap() async {
    final name = await coordinator.showCreateTokenSheet();
    if (name != null) {
      await service.createToken(name);
    }
  }

  Future<void> onRevokeTap(String id) async {
    final confirmed = await coordinator.showRevokeConfirmation();
    if (confirmed) {
      await service.revokeToken(id);
    }
  }

  void onRevealDismissed() {
    state = state.copyWith(revealToken: null, revealTokenName: null);
  }

  void onCopyToken() {
    final token = state.revealToken;
    if (token != null) {
      Clipboard.setData(ClipboardData(text: token));
    }
  }
}

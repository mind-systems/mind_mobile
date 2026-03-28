import 'dart:async';
import 'dart:developer';
import 'dart:math' as math;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:rxdart/rxdart.dart';

import 'package:mind/Core/Grpc/GrpcConnectionState.dart';
import 'package:mind/User/Models/AuthState.dart';

class GrpcConnectionManager {
  final Future<void> Function() _onConnect;
  final void Function() _onDisconnect;
  final bool Function() _isConnected;

  // ── Connection state ──────────────────────────────────────────────────────

  final _connectionState = BehaviorSubject<GrpcConnectionState>.seeded(
    GrpcConnectionState.disconnected,
  );

  Stream<GrpcConnectionState> get connectionState => _connectionState.stream;

  GrpcConnectionState get currentState => _connectionState.value;

  // ── Auth + connection guards ──────────────────────────────────────────────

  bool _isConnecting = false;
  bool _isAuthenticated = false;

  // ── Reconnect state ───────────────────────────────────────────────────────

  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;

  static const Duration _initialDelay = Duration(seconds: 1);
  static const Duration _maxDelay = Duration(seconds: 30);

  // ── Listener subscriptions ────────────────────────────────────────────────

  late final StreamSubscription<AuthState> _authSubscription;
  late final StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  late final StreamSubscription<void> _resumeSubscription;

  // ── Constructor ───────────────────────────────────────────────────────────

  GrpcConnectionManager({
    required Stream<AuthState> authStream,
    required Stream<List<ConnectivityResult>> connectivityStream,
    required Stream<void> resumeStream,
    required Future<void> Function() onConnect,
    required void Function() onDisconnect,
    required bool Function() isConnected,
  })  : _onConnect = onConnect,
        _onDisconnect = onDisconnect,
        _isConnected = isConnected {
    _authSubscription = authStream.listen((state) {
      if (state is AuthenticatedState) {
        _isAuthenticated = true;
        connect();
      } else if (state is GuestState) {
        _isAuthenticated = false;
        disconnect();
      }
    });
    _connectivitySubscription = connectivityStream.listen((results) {
      if (results.contains(ConnectivityResult.none)) {
        log('[GrpcConnectionManager] connectivity lost, disconnecting', name: 'GrpcConnectionManager');
        disconnect();
      } else if (_isAuthenticated) {
        log('[GrpcConnectionManager] connectivity restored, reconnecting', name: 'GrpcConnectionManager');
        connect();
      }
    });
    _resumeSubscription = resumeStream.listen((_) {
      if (_isAuthenticated && !_isConnected()) {
        log('[GrpcConnectionManager] app resumed, not connected — reconnecting', name: 'GrpcConnectionManager');
        connect();
      }
    });
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> connect() async {
    if (_isConnected() || _isConnecting) {
      log(
        '[GrpcConnectionManager] connect() skipped: isConnected=${_isConnected()} _isConnecting=$_isConnecting',
        name: 'GrpcConnectionManager',
      );
      return;
    }
    _isConnecting = true;
    _connectionState.add(GrpcConnectionState.connecting);
    log('[GrpcConnectionManager] connect() start', name: 'GrpcConnectionManager');

    try {
      await _onConnect();
      _resetBackoff();
      _connectionState.add(GrpcConnectionState.connected);
      log('[GrpcConnectionManager] connect() succeeded', name: 'GrpcConnectionManager');
    } catch (e) {
      log('[GrpcConnectionManager] connect() failed: $e', name: 'GrpcConnectionManager');
      disconnect();
      _scheduleReconnectInternal();
    } finally {
      _isConnecting = false;
    }
  }

  void disconnect() {
    log('[GrpcConnectionManager] disconnect()', name: 'GrpcConnectionManager');
    _isConnecting = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _onDisconnect();
    _connectionState.add(GrpcConnectionState.disconnected);
  }

  /// Public entry point so transport-level stream errors in the service can
  /// trigger a reconnect attempt without having direct access to the backoff
  /// internals.
  void scheduleReconnect() {
    _scheduleReconnectInternal();
  }

  // ── Reconnect infrastructure ──────────────────────────────────────────────

  Duration _nextDelay() {
    final base = _initialDelay * math.pow(2, _reconnectAttempt);
    final clamped =
        base.inMilliseconds < _maxDelay.inMilliseconds ? base : _maxDelay;
    final jitter =
        (clamped.inMilliseconds * 0.25 * (math.Random().nextDouble() * 2 - 1))
            .round();
    _reconnectAttempt++;
    final ms =
        (clamped.inMilliseconds + jitter).clamp(0, _maxDelay.inMilliseconds);
    return Duration(milliseconds: ms);
  }

  void _scheduleReconnectInternal() {
    if (!_isAuthenticated) return;
    _reconnectTimer?.cancel();
    final delay = _nextDelay();
    log(
      '[GrpcConnectionManager] reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempt)',
      name: 'GrpcConnectionManager',
    );
    _reconnectTimer = Timer(delay, () {
      if (_isAuthenticated) connect();
    });
  }

  void _resetBackoff() {
    _reconnectAttempt = 0;
  }

  // ── Disposal ──────────────────────────────────────────────────────────────

  void dispose() {
    disconnect();
    _authSubscription.cancel();
    _connectivitySubscription.cancel();
    _resumeSubscription.cancel();
    _connectionState.close();
  }
}

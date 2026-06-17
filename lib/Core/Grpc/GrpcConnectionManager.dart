import 'dart:async';
import 'dart:math' as math;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:rxdart/rxdart.dart';

import 'package:mind/Core/Grpc/BackoffConfig.dart';
import 'package:mind/Logger.dart';
import 'package:mind/Core/Grpc/GrpcConnectionState.dart';
import 'package:mind/User/Models/AuthState.dart';

class GrpcConnectionManager {
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

  late final BackoffConfig _backoffConfig;
  late final TimerFactory _timerFactory;

  // ── Listener subscriptions ────────────────────────────────────────────────

  late final StreamSubscription<AuthState> _authSubscription;
  late final StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  late final StreamSubscription<void> _resumeSubscription;

  // ── Constructor ───────────────────────────────────────────────────────────

  GrpcConnectionManager({
    required Stream<AuthState> authStream,
    required Stream<List<ConnectivityResult>> connectivityStream,
    required Stream<void> resumeStream,
    BackoffConfig? backoffConfig,
    TimerFactory? timerFactory,
  })  : _backoffConfig = backoffConfig ?? BackoffConfig(),
        _timerFactory = timerFactory ?? Timer.new {
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
        logPrint('[GrpcConnectionManager] connectivity lost, disconnecting');
        disconnect();
      } else if (_isAuthenticated) {
        logPrint('[GrpcConnectionManager] connectivity restored, reconnecting');
        connect();
      }
    });
    _resumeSubscription = resumeStream.listen((_) {
      if (_isAuthenticated && currentState != GrpcConnectionState.connected) {
        logPrint('[GrpcConnectionManager] app resumed, not connected — reconnecting');
        connect();
      }
    });
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  void connect() {
    if (currentState == GrpcConnectionState.connected || _isConnecting) {
      logPrint('[GrpcConnectionManager] connect() skipped: currentState=$currentState _isConnecting=$_isConnecting');
      return;
    }
    _isConnecting = true;
    _connectionState.add(GrpcConnectionState.connecting);
    logPrint('[GrpcConnectionManager] connect() start');
    _connectionState.add(GrpcConnectionState.connected);
    logPrint('[GrpcConnectionManager] connect() succeeded');
    _isConnecting = false;
  }

  void disconnect() {
    logPrint('[GrpcConnectionManager] disconnect()');
    _isConnecting = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _connectionState.add(GrpcConnectionState.disconnected);
  }

  /// Call this once a stream is successfully established to reset the backoff
  /// counter. Consumers (channel, service) each call this independently after
  /// their own stream is open; the first call resets the counter.
  void confirmConnected() {
    _resetBackoff();
  }

  /// Public entry point so transport-level stream errors in the service can
  /// trigger a reconnect attempt without having direct access to the backoff
  /// internals.
  void scheduleReconnect() {
    _scheduleReconnectInternal();
  }

  // ── Reconnect infrastructure ──────────────────────────────────────────────

  Duration _nextDelay() {
    final exp = math.min(_reconnectAttempt, 6);
    final base = _backoffConfig.initialDelay * math.pow(2, exp);
    final clamped =
        base.inMilliseconds < _backoffConfig.maxDelay.inMilliseconds ? base : _backoffConfig.maxDelay;
    final jitter =
        (clamped.inMilliseconds * 0.25 * (_backoffConfig.random.nextDouble() * 2 - 1))
            .round();
    _reconnectAttempt++;
    final ms =
        (clamped.inMilliseconds + jitter).clamp(0, _backoffConfig.maxDelay.inMilliseconds);
    return Duration(milliseconds: ms);
  }

  void _scheduleReconnectInternal() {
    if (!_isAuthenticated) return;
    _reconnectTimer?.cancel();
    final delay = _nextDelay();
    logPrint('[GrpcConnectionManager] reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempt)');
    _reconnectTimer = _timerFactory(delay, () {
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

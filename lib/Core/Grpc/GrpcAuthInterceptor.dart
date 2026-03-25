import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:grpc/grpc.dart';
import 'package:mind/User/LogoutNotifier.dart';

class GrpcAuthInterceptor extends ClientInterceptor {
  final FlutterSecureStorage _storage;
  final LogoutNotifier _logoutNotifier;

  static const String _tokenKey = 'jwt_token';

  String? _cachedToken;

  GrpcAuthInterceptor({
    required FlutterSecureStorage storage,
    required LogoutNotifier logoutNotifier,
  })  : _storage = storage,
        _logoutNotifier = logoutNotifier;

  Future<void> _addAuthMetadata(Map<String, String> metadata, String uri) async {
    final token = await _storage.read(key: _tokenKey);
    _cachedToken = token;
    if (token != null) {
      metadata['authorization'] = 'Bearer $token';
    }
  }

  void _onUnauthenticatedError(Object error) {
    if (error is GrpcError && error.code == StatusCode.unauthenticated) {
      _logoutNotifier.triggerLogout();
    }
  }

  @override
  ResponseFuture<R> interceptUnary<Q, R>(
    ClientMethod<Q, R> method,
    Q request,
    CallOptions options,
    ClientUnaryInvoker<Q, R> invoker,
  ) {
    final mergedOptions = options.mergedWith(CallOptions(providers: [_addAuthMetadata]));
    final response = invoker(method, request, mergedOptions);
    unawaited(response.then<void>((_) {}, onError: (Object e) {
      _onUnauthenticatedError(e);
    }));
    return response;
  }

  @override
  ResponseStream<R> interceptStreaming<Q, R>(
    ClientMethod<Q, R> method,
    Stream<Q> requests,
    CallOptions options,
    ClientStreamingInvoker<Q, R> invoker,
  ) {
    final mergedOptions = options.mergedWith(
      CallOptions(metadata: {
        if (_cachedToken != null) 'authorization': 'Bearer $_cachedToken',
      }),
    );
    final response = invoker(method, requests, mergedOptions);
    unawaited(response.trailers.then<void>((_) {}, onError: (Object e) {
      _onUnauthenticatedError(e);
    }));
    return response;
  }
}

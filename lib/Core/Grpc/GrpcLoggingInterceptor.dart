import 'dart:async';

import 'package:grpc/grpc.dart';
import 'package:mind/Logger.dart';

class GrpcLoggingInterceptor extends ClientInterceptor {
  @override
  ResponseFuture<R> interceptUnary<Q, R>(
    ClientMethod<Q, R> method,
    Q request,
    CallOptions options,
    ClientUnaryInvoker<Q, R> invoker,
  ) {
    final response = invoker(method, request, options);
    unawaited(response.then<void>((_) {}, onError: (Object e) {
      logPrint('[gRPC] ${method.path} ERROR: $e');
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
    final response = invoker(method, requests, options);
    unawaited(response.trailers.then<void>((_) {}, onError: (Object e) {
      logPrint('[gRPC] ${method.path} ERROR: $e');
    }));
    return response;
  }
}

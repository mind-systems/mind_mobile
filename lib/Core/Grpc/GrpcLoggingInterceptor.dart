import 'dart:async';

import 'package:grpc/grpc.dart';
import 'package:mind/Logger.dart';
import 'package:observe/observe.dart';

class GrpcLoggingInterceptor extends ClientInterceptor {
  CallOptions _withTraceparent(CallOptions options) {
    final span = startSpan();
    final carrier = <String, String>{};
    runWithContext(
      TraceContext(
        traceId: span.traceId,
        spanId: span.spanId,
        traceFlags: span.traceFlags,
      ),
      () => inject(MapCarrier(carrier)),
    );
    return options.mergedWith(CallOptions(metadata: carrier));
  }

  @override
  ResponseFuture<R> interceptUnary<Q, R>(
    ClientMethod<Q, R> method,
    Q request,
    CallOptions options,
    ClientUnaryInvoker<Q, R> invoker,
  ) {
    final response = invoker(method, request, _withTraceparent(options));
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
    final response = invoker(method, requests, _withTraceparent(options));
    unawaited(response.trailers.then<void>((_) {}, onError: (Object e) {
      logPrint('[gRPC] ${method.path} ERROR: $e');
    }));
    return response;
  }
}

import 'dart:async';

import 'package:grpc/grpc.dart';
import 'package:mind/Logger.dart';
import 'package:observe/observe.dart';

class GrpcLoggingInterceptor extends ClientInterceptor {
  @override
  ResponseFuture<R> interceptUnary<Q, R>(
    ClientMethod<Q, R> method,
    Q request,
    CallOptions options,
    ClientUnaryInvoker<Q, R> invoker,
  ) {
    final span = startSpan();
    final ctx = TraceContext(
      traceId: span.traceId,
      spanId: span.spanId,
      traceFlags: span.traceFlags,
    );
    return runWithContext<ResponseFuture<R>>(ctx, () {
      final carrier = <String, String>{};
      inject(MapCarrier(carrier));
      final traced = options.mergedWith(CallOptions(metadata: carrier));
      final response = invoker(method, request, traced);
      unawaited(response.then<void>((_) {}, onError: (Object e) {
        logPrint('[gRPC] ${method.path} ERROR: $e');
      }));
      return response;
    });
  }

  @override
  ResponseStream<R> interceptStreaming<Q, R>(
    ClientMethod<Q, R> method,
    Stream<Q> requests,
    CallOptions options,
    ClientStreamingInvoker<Q, R> invoker,
  ) {
    final span = startSpan();
    final ctx = TraceContext(
      traceId: span.traceId,
      spanId: span.spanId,
      traceFlags: span.traceFlags,
    );
    return runWithContext<ResponseStream<R>>(ctx, () {
      final carrier = <String, String>{};
      inject(MapCarrier(carrier));
      final traced = options.mergedWith(CallOptions(metadata: carrier));
      final response = invoker(method, requests, traced);
      unawaited(response.trailers.then<void>((_) {}, onError: (Object e) {
        logPrint('[gRPC] ${method.path} ERROR: $e');
      }));
      return response;
    });
  }
}

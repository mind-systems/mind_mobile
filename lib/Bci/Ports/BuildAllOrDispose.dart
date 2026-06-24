import 'dart:async';

/// Runs each step in [steps] in order. A step builds a resource and returns
/// its async disposer. If a later step throws, the disposers returned by the
/// already-completed steps are invoked in reverse order — each guarded against
/// BOTH a synchronous throw and an async rejection so a dispose failure cannot
/// mask the original build error — and then the original error is rethrown. On
/// success, returns normally and the built resources are retained by the caller
/// (via the side effects the step closures performed).
void buildAllOrDispose(List<Future<void> Function() Function()> steps) {
  final disposers = <Future<void> Function()>[];
  try {
    for (final step in steps) {
      disposers.add(step());
    }
  } catch (_) {
    for (final dispose in disposers.reversed) {
      try {
        // catchError guards an async rejection; the try/catch guards a
        // *synchronous* throw from the dispose() call itself (a non-`async`
        // disposer, e.g. the real native dispose, throws before catchError is
        // ever attached). Both must be swallowed here so they cannot abort the
        // reverse-dispose loop or mask the original error below.
        unawaited(dispose().catchError((Object _) {}));
      } catch (_) {/* swallow synchronous dispose throw */}
    }
    rethrow;
  }
}

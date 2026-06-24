import 'dart:async';

/// Thrown by [SerialCommandQueue.enqueue] when a command is dropped because
/// the queue was closed before that command's slot became active.
///
/// Extends [StateError] so existing `isA<StateError>()` assertions still match.
/// Callers that fire-and-forget an enqueue can selectively swallow this type
/// without also silencing genuine command-body errors.
class QueueClosedException extends StateError {
  QueueClosedException(super.message);
}

/// Serial command queue (actor) — a single-slot executor that runs one
/// submitted command to completion before starting the next.
///
/// **CONSTRAINT 1 — strictly one-directional dependency (no self-deadlock).**
/// A command executing inside the queue's single slot must **never** `await`
/// another command enqueued on the **same** queue. Doing so would stall the
/// queue permanently: the outer command waits for the inner to start, but the
/// inner cannot start until the outer finishes.
///
/// Pure Dart — no Flutter or Riverpod imports.
class SerialCommandQueue {
  Future<void> _tail = Future<void>.value();
  bool _closed = false;

  /// Whether the queue has been closed to new enqueues.
  bool get isClosed => _closed;

  /// Resolves when all currently-enqueued commands have settled.
  Future<void> get idle => _tail;

  /// Closes the queue to new enqueues.
  ///
  /// Commands already chained in the tail that have not yet started will be
  /// dropped — their returned future completes with a [StateError]
  /// (poison-pill tail-drop). The currently-executing command (if any) runs
  /// to completion.
  void close() {
    _closed = true;
  }

  /// Submits [command] to the queue and returns a [Future] that carries its
  /// result or error to the caller.
  ///
  /// - If the queue is already closed at enqueue time, the returned future
  ///   completes immediately with a [StateError] — the command is never run.
  /// - Each continuation re-checks [isClosed] before running: if the queue was
  ///   closed after this call but before this slot becomes active, the command
  ///   is dropped and the returned future completes with a [StateError].
  /// - A throwing command does **not** poison the queue — subsequent commands
  ///   still run.
  Future<T> enqueue<T>(Future<T> Function() command) {
    final completer = Completer<T>();

    if (_closed) {
      completer.completeError(
        QueueClosedException('SerialCommandQueue: enqueue after close'),
        StackTrace.current,
      );
      return completer.future;
    }

    _tail = _tail.then<void>(
      (_) async {
        // Re-check after previous command settled — close() may have been
        // called between enqueue time and this slot becoming active.
        if (_closed) {
          completer.completeError(
            QueueClosedException('SerialCommandQueue: command dropped (queue closed)'),
          );
          return;
        }
        try {
          final result = await command();
          completer.complete(result);
        } catch (e, st) {
          completer.completeError(e, st);
        }
      },
      onError: (Object e, StackTrace st) {
        // _tail is designed to never reject; this handler is a safety net.
        // Drop the command and keep the queue alive.
        completer.completeError(
          StateError('SerialCommandQueue: unexpected queue rejection: $e'),
        );
      },
    );

    return completer.future;
  }
}

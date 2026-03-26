import 'package:rxdart/rxdart.dart';

/// Private mediator between [GrpcAuthInterceptor] (producer) and [UserNotifier] (sole consumer).
///
/// [GrpcAuthInterceptor] calls [triggerLogout] on every UNAUTHENTICATED (code 16) response.
/// [UserNotifier] subscribes and calls [clearSession], which guards against
/// repeated invocations and emits on [UserNotifier.sessionExpiredStream] only
/// when an authenticated session is actually cleared.
///
/// External code must not subscribe to this class directly — use
/// [UserNotifier.sessionExpiredStream] instead.
class LogoutNotifier {
  final PublishSubject<void> _subject = PublishSubject<void>();

  Stream<void> get stream => _subject.stream;

  void triggerLogout() {
    _subject.add(null);
  }

  void dispose() {
    _subject.close();
  }
}

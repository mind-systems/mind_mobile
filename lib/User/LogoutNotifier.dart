import 'package:rxdart/rxdart.dart';

/// Доменный нотифаер для события логаута (сессия истекла, 401).
///
/// Эмитит событие при [triggerLogout].
/// Используется AuthInterceptor и GlobalListeners.
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

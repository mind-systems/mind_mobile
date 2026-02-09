import 'package:mind/BreathModule/Presentation/BreathSessionsList/Models/BreathSessionListItemDTO.dart';

/// Сервис адаптации доменных моделей BreathSession в презентационные DTO
/// для списка сессий.
///
/// - Не знает про UI
/// - Не формирует строки
/// - Работает только с DTO и событиями
///
/// Все изменения приходят через observeChanges().
/// Методы fetch/refresh завершаются после выполнения запроса (для обработки ошибок), данные эмитятся через stream.
abstract class IBreathSessionListService {
  /// Подписка на все события изменения списка сессий.
  ///
  /// Эмитит:
  /// - PageLoadedEvent (пагинация)
  /// - SessionsRefreshedEvent (pull-to-refresh)
  /// - SessionCreatedEvent
  /// - SessionUpdatedEvent
  /// - SessionDeletedEvent
  ///
  /// При подписке может сразу эмитить актуальное состояние,
  /// если данные уже есть в кеше.
  Stream<BreathSessionListEvent> observeChanges();

  /// Загружает страницу сессий.
  ///
  /// Результат приходит через observeChanges()
  /// как PageLoadedEvent.
  ///
  /// [page] — номер страницы (начиная с 0)
  /// [pageSize] — количество элементов на странице
  Future<void> fetchPage(int page, int pageSize);

  /// Полная синхронизация (pull-to-refresh).
  ///
  /// Полностью сбрасывает текущий список
  /// и загружает первую страницу.
  ///
  /// Результат приходит через observeChanges()
  /// как SessionsRefreshedEvent.
  ///
  /// [pageSize] — количество элементов первой страницы
  Future<void> refresh(int pageSize);
}

/// Базовый тип всех событий списка сессий
sealed class BreathSessionListEvent {}

/// Загружена страница данных (пагинация)
class PageLoadedEvent extends BreathSessionListEvent {
  final int page;
  final List<BreathSessionListItemDTO> items;
  final bool hasMore;

  PageLoadedEvent({
    required this.page,
    required this.items,
    required this.hasMore,
  });
}

/// Полный рефреш списка (pull-to-refresh)
class SessionsRefreshedEvent extends BreathSessionListEvent {
  final List<BreathSessionListItemDTO> items;
  final bool hasMore;

  SessionsRefreshedEvent({
    required this.items,
    required this.hasMore,
  });
}

/// Создана новая сессия
class SessionCreatedEvent extends BreathSessionListEvent {
  final BreathSessionListItemDTO session;

  SessionCreatedEvent(this.session);
}

/// Обновлена существующая сессия
class SessionUpdatedEvent extends BreathSessionListEvent {
  final BreathSessionListItemDTO session;

  SessionUpdatedEvent(this.session);
}

/// Удалена сессия
class SessionDeletedEvent extends BreathSessionListEvent {
  final String id;

  SessionDeletedEvent(this.id);
}
